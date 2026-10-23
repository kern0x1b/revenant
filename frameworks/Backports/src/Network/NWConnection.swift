import Foundation

private let nwFramingInputLimit = 1 << 20

public final class NWConnection: @unchecked Sendable {
    public enum State: Equatable, CustomDebugStringConvertible {
        case setup
        case waiting(NWError)
        case preparing
        case ready
        case failed(NWError)
        case cancelled

        public var debugDescription: String {
            switch self {
            case .setup:
                return "setup"
            case .waiting(let error):
                return "waiting(\(error.debugDescription))"
            case .preparing:
                return "preparing"
            case .ready:
                return "ready"
            case .failed(let error):
                return "failed(\(error.debugDescription))"
            case .cancelled:
                return "cancelled"
            }
        }
    }

    public struct ContentContext: Hashable, Sendable {
        public static let defaultMessage = ContentContext(identifier: "defaultMessage")
        public static let defaultStream = ContentContext(identifier: "defaultStream")

        public let identifier: String

        public init(identifier: String) {
            self.identifier = identifier
        }
    }

    public enum SendCompletion {
        case contentProcessed((NWError?) -> Void)
        case idempotent
    }

    private struct PendingSend {
        let data: Data
        var completion: SendCompletion
        var offset: Int
    }

    private struct PendingReceive {
        let minimumIncompleteLength: Int
        let maximumLength: Int
        let completion: (Data?, ContentContext?, Bool, NWError?) -> Void
    }

    public let endpoint: NWEndpoint
    public let parameters: NWParameters
    public private(set) var state: State = .setup
    public private(set) var currentPath: NWPath?
    public var stateUpdateHandler: ((State) -> Void)?
    public var pathUpdateHandler: ((NWPath) -> Void)?

    private var queue: DispatchQueue?
    private var descriptor: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var writeSource: DispatchSourceWrite?
    private var readActive = false
    private var writeActive = false
    private var connecting = false
    private var endOfStream = false
    private var sends: [PendingSend] = []
    private var receives: [PendingReceive] = []
    private var inbound = Data()
    private var acceptedDescriptor: Int32 = -1
    private var framer: NWProtocolFramer.Instance?
    private var framerImplementation: (any NWProtocolFramerImplementation)?
    private var framedInput: [Data] = []
    private var outboundPayload = Data()

    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, using parameters: NWParameters) {
        self.endpoint = .hostPort(host: host, port: port)
        self.parameters = parameters
    }

    public init(to endpoint: NWEndpoint, using parameters: NWParameters) {
        self.endpoint = endpoint
        self.parameters = parameters
    }

    init(accepted descriptor: Int32, endpoint: NWEndpoint, using parameters: NWParameters) {
        self.endpoint = endpoint
        self.parameters = parameters
        self.acceptedDescriptor = descriptor
    }

    deinit {
        teardownSources()
        if descriptor >= 0 {
            Darwin.close(descriptor)
        }
        if acceptedDescriptor >= 0 {
            Darwin.close(acceptedDescriptor)
        }
    }

    public func start(queue: DispatchQueue) {
        guard state == .setup, self.queue == nil else {
            return
        }
        self.queue = queue
        queue.async {
            if self.acceptedDescriptor >= 0 {
                let fd = self.acceptedDescriptor
                self.acceptedDescriptor = -1
                self.setState(.preparing)
                guard self.parameters.tlsOptions == nil else {
                    Darwin.close(fd)
                    self.fail(.posix(errno: ENOTSUP))
                    return
                }
                self.attach(fd, connecting: false)
            } else {
                self.open()
            }
        }
    }

    public func cancel() {
        perform {
            self.close(to: .cancelled)
        }
    }

    public func send(content: Data?, contentContext: ContentContext = .defaultMessage, isComplete: Bool = false, completion: SendCompletion) {
        let data = content ?? Data()
        perform {
            if let framer = self.framer, let implementation = self.framerImplementation {
                let before = self.sends.count
                self.outboundPayload = data
                implementation.handleOutput(framer: framer, message: NWProtocolFramer.Message(), messageLength: data.count, isComplete: isComplete)
                self.outboundPayload = Data()
                if self.sends.count > before {
                    self.sends[self.sends.count - 1].completion = completion
                } else {
                    self.sends.append(PendingSend(data: Data(), completion: completion, offset: 0))
                }
            } else {
                self.sends.append(PendingSend(data: data, completion: completion, offset: 0))
            }
            self.flushSends()
        }
    }

    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, ContentContext?, Bool, NWError?) -> Void) {
        perform {
            self.receives.append(PendingReceive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, completion: completion))
            self.updateSources()
            self.deliverReceives()
        }
    }

    private func perform(_ work: @escaping () -> Void) {
        if let queue = queue {
            queue.async(execute: work)
        } else {
            work()
        }
    }

    private func setState(_ next: State) {
        state = next
        stateUpdateHandler?(next)
    }

    private func hostText(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .name(let name, _):
            return name
        case .ipv4(let address):
            return address.rawValue.map { String($0) }.joined(separator: ".")
        case .ipv6(let address):
            return address.debugDescription
        }
    }

    private func open() {
        guard state == .setup else {
            return
        }
        setState(.preparing)
        guard parameters.tlsOptions == nil else {
            fail(.posix(.ENOTSUP))
            return
        }
        guard case .hostPort(let host, let port) = endpoint else {
            fail(.posix(.EAFNOSUPPORT))
            return
        }
        let socketType = parameters.transport == .udp ? SOCK_DGRAM : SOCK_STREAM
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = socketType
        var results: UnsafeMutablePointer<addrinfo>? = nil
        let status = getaddrinfo(hostText(host), String(port.rawValue), &hints, &results)
        guard status == 0, let list = results else {
            fail(.dns(status))
            return
        }
        defer {
            freeaddrinfo(results)
        }
        var lastError: Int32 = EHOSTUNREACH
        var entry: UnsafeMutablePointer<addrinfo>? = list
        while let candidate = entry {
            let fd = socket(candidate.pointee.ai_family, candidate.pointee.ai_socktype, candidate.pointee.ai_protocol)
            if fd < 0 {
                lastError = errno
            } else {
                _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK)
                if connect(fd, candidate.pointee.ai_addr, candidate.pointee.ai_addrlen) == 0 {
                    attach(fd, connecting: false)
                    return
                }
                if errno == EINPROGRESS {
                    attach(fd, connecting: true)
                    return
                }
                lastError = errno
                Darwin.close(fd)
            }
            entry = candidate.pointee.ai_next
        }
        fail(.posix(errno: lastError))
    }

    private func attach(_ fd: Int32, connecting: Bool) {
        descriptor = fd
        if parameters.transport == .tcp {
            parameters.tcpOptions?.apply(to: fd)
        }
        startFramer()
        self.connecting = connecting
        let read = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        read.setEventHandler { [weak self] in
            self?.handleReadable()
        }
        let write = DispatchSource.makeWriteSource(fileDescriptor: fd, queue: queue)
        write.setEventHandler { [weak self] in
            self?.handleWritable()
        }
        readSource = read
        writeSource = write
        if connecting {
            setWriteActive(true)
        } else {
            becomeReady()
        }
    }

    private func becomeReady() {
        let path = NWPath(status: .satisfied, isExpensive: false, availableInterfaces: [])
        currentPath = path
        setState(.ready)
        pathUpdateHandler?(path)
        updateSources()
        flushSends()
        deliverReceives()
    }

    private func setReadActive(_ active: Bool) {
        guard let source = readSource, active != readActive else {
            return
        }
        readActive = active
        active ? source.resume() : source.suspend()
    }

    private func setWriteActive(_ active: Bool) {
        guard let source = writeSource, active != writeActive else {
            return
        }
        writeActive = active
        active ? source.resume() : source.suspend()
    }

    private func updateSources() {
        setReadActive(state == .ready && !endOfStream && !receives.isEmpty)
        setWriteActive(connecting || (state == .ready && !sends.isEmpty))
    }

    private func handleWritable() {
        if connecting {
            var error: Int32 = 0
            var length = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, &length)
            connecting = false
            setWriteActive(false)
            if error == 0 {
                becomeReady()
            } else {
                fail(.posix(errno: error))
            }
            return
        }
        flushSends()
    }

    private func flushSends() {
        guard state == .ready, descriptor >= 0 else {
            return
        }
        while var pending = sends.first {
            let remaining = pending.data.count - pending.offset
            let written = pending.data.withUnsafeBytes { bytes -> Int in
                Darwin.send(descriptor, bytes.baseAddress!.advanced(by: pending.offset), remaining, 0)
            }
            if written < 0 {
                if errno == EAGAIN {
                    setWriteActive(true)
                    return
                }
                let error = NWError.posix(errno: errno)
                sends.removeFirst()
                complete(pending.completion, with: error)
                fail(error)
                return
            }
            pending.offset += written
            if pending.offset < pending.data.count {
                sends[0] = pending
                setWriteActive(true)
                return
            }
            sends.removeFirst()
            complete(pending.completion, with: nil)
        }
        setWriteActive(false)
    }

    private func complete(_ completion: SendCompletion, with error: NWError?) {
        if case .contentProcessed(let handler) = completion {
            handler(error)
        }
    }

    private func handleReadable() {
        guard let first = receives.first else {
            setReadActive(false)
            return
        }
        let isDatagram = parameters.transport == .udp
        var buffer = [UInt8](repeating: 0, count: first.maximumLength)
        let count = recv(descriptor, &buffer, first.maximumLength, 0)
        if count < 0 {
            if errno == EAGAIN {
                return
            }
            fail(.posix(errno: errno))
            return
        }
        if count == 0 {
            endOfStream = true
            setReadActive(false)
            if isDatagram {
                deliverReceive(Data(), complete: true, error: nil)
            } else {
                deliverReceive(inbound.isEmpty ? nil : inbound, complete: true, error: nil)
                inbound = Data()
                deliverReceives()
            }
            return
        }
        if isDatagram {
            deliverReceive(Data(buffer[0..<count]), complete: true, error: nil)
            return
        }
        inbound.append(contentsOf: buffer[0..<count])
        if framer != nil {
            guard inbound.count <= nwFramingInputLimit else {
                fail(.posix(errno: EMSGSIZE))
                return
            }
            runFramer()
        }
        deliverReceives()
    }

    private func deliverReceives() {
        if framer != nil {
            deliverFramedReceives()
            return
        }
        while let first = receives.first {
            if parameters.transport == .udp {
                break
            }
            if endOfStream {
                deliverReceive(inbound.isEmpty ? nil : inbound, complete: true, error: nil)
                inbound = Data()
                continue
            }
            if inbound.count >= first.minimumIncompleteLength || inbound.count >= first.maximumLength {
                let take = min(inbound.count, first.maximumLength)
                deliverReceive(Data(inbound.prefix(take)), complete: false, error: nil)
                inbound.removeFirst(take)
                continue
            }
            break
        }
        updateSources()
    }

    private func deliverReceive(_ data: Data?, complete: Bool, error: NWError?) {
        let pending = receives.removeFirst()
        pending.completion(data, .defaultStream, complete, error)
    }

    private func fail(_ error: NWError) {
        if error == .posix(errno: ECONNREFUSED), state == .preparing {
            close(to: .waiting(error))
        } else {
            close(to: .failed(error))
        }
    }

    private var isClosed: Bool {
        switch state {
        case .failed, .cancelled:
            return true
        default:
            return false
        }
    }

    private func close(to next: State) {
        guard !isClosed else {
            return
        }
        stopFramer()
        teardownSources()
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }
        connecting = false
        if case .waiting = next {
            setState(next)
            return
        }
        endOfStream = true
        currentPath = nil
        let pending = receives
        receives = []
        let failure: NWError?
        if case .failed(let error) = next {
            failure = error
        } else {
            failure = nil
        }
        sends.forEach { complete($0.completion, with: failure) }
        sends = []
        setState(next)
        pending.forEach { $0.completion(nil, nil, true, failure) }
    }

    private func startFramer() {
        guard framer == nil, let options = parameters.defaultProtocolStack.applicationProtocols.first else {
            return
        }
        let instance = NWProtocolFramer.Instance(channel: self)
        let implementation = options.definition.implementation.init(framer: instance)
        framer = instance
        framerImplementation = implementation
        _ = implementation.start(framer: instance)
    }

    private func stopFramer() {
        guard let instance = framer, let implementation = framerImplementation else {
            return
        }
        _ = implementation.stop(framer: instance)
        implementation.cleanup(framer: instance)
        framer = nil
        framerImplementation = nil
        framedInput = []
    }

    private func runFramer() {
        guard let instance = framer, let implementation = framerImplementation else {
            return
        }
        _ = implementation.handleInput(framer: instance)
    }

    private func deliverFramedReceives() {
        while !receives.isEmpty {
            if !framedInput.isEmpty {
                let message = framedInput.removeFirst()
                let pending = receives.removeFirst()
                pending.completion(message, .defaultStream, false, nil)
            } else if endOfStream {
                let pending = receives.removeFirst()
                pending.completion(nil, .defaultStream, true, nil)
            } else {
                break
            }
        }
        updateSources()
    }

    private func teardownSources() {
        if let read = readSource {
            if !readActive {
                read.resume()
            }
            read.cancel()
        }
        if let write = writeSource {
            if !writeActive {
                write.resume()
            }
            write.cancel()
        }
        readSource = nil
        writeSource = nil
        readActive = false
        writeActive = false
    }
}

extension NWConnection: NWFramingChannel {
    func framingParseInput(minimumIncompleteLength: Int, maximumLength: Int, parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool {
        let complete = endOfStream
        if inbound.isEmpty {
            guard complete else {
                return false
            }
            _ = parse(nil, true)
            return true
        }
        guard inbound.count >= minimumIncompleteLength || complete else {
            return false
        }
        let consumed = inbound.withUnsafeMutableBytes { buffer -> Int in
            parse(UnsafeMutableRawBufferPointer(rebasing: buffer.prefix(maximumLength)), complete)
        }
        if consumed > 0 {
            inbound.removeFirst(min(consumed, inbound.count))
        }
        return true
    }

    func framingDeliver(_ data: Data, isComplete: Bool) {
        framedInput.append(data)
    }

    func framingWrite(_ data: Data) {
        sends.append(PendingSend(data: data, completion: .idempotent, offset: 0))
    }

    func framingWritePayload(length: Int) -> Bool {
        guard length >= 0, length <= outboundPayload.count else {
            return false
        }
        sends.append(PendingSend(data: Data(outboundPayload.prefix(length)), completion: .idempotent, offset: 0))
        return true
    }
}
