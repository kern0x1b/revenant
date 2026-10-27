import Darwin
import Foundation

public final class NWListener: @unchecked Sendable {
    public enum State: Equatable, CustomDebugStringConvertible {
        case setup
        case waiting(NWError)
        case ready
        case failed(NWError)
        case cancelled

        public var debugDescription: String {
            switch self {
            case .setup:
                return "setup"
            case .waiting(let error):
                return "waiting(\(error.debugDescription))"
            case .ready:
                return "ready"
            case .failed(let error):
                return "failed(\(error.debugDescription))"
            case .cancelled:
                return "cancelled"
            }
        }
    }

    public let parameters: NWParameters
    public private(set) var state: State = .setup
    public private(set) var port: NWEndpoint.Port?
    public var newConnectionHandler: ((NWConnection) -> Void)?
    public var stateUpdateHandler: ((State) -> Void)?

    private var queue: DispatchQueue?
    private var descriptor: Int32 = -1
    private var readSource: DispatchSourceRead?

    public init(using parameters: NWParameters, on port: NWEndpoint.Port) throws {
        guard parameters.tlsOptions?.hasLocalIdentity ?? true else {
            throw NWError.posix(errno: ENOTSUP)
        }
        self.parameters = parameters
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw NWError.posix(errno: errno)
        }
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = in_addr_t(0)
        address.sin_port = port.rawValue.bigEndian
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(fd, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(fd, 128) == 0 else {
            let error = errno
            Darwin.close(fd)
            throw NWError.posix(errno: error)
        }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK)
        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                _ = getsockname(fd, socketAddress, &length)
            }
        }
        self.descriptor = fd
        self.port = NWEndpoint.Port(rawValue: UInt16(bigEndian: assigned.sin_port))
    }

    deinit {
        readSource?.cancel()
        if descriptor >= 0 {
            Darwin.close(descriptor)
        }
    }

    public func start(queue: DispatchQueue) {
        guard state == .setup, self.queue == nil else {
            return
        }
        self.queue = queue
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptPending()
        }
        readSource = source
        source.resume()
        queue.async {
            self.setState(.ready)
        }
    }

    public func cancel() {
        guard let queue = queue else {
            close(to: .cancelled)
            return
        }
        queue.async {
            self.close(to: .cancelled)
        }
    }

    private func acceptPending() {
        while descriptor >= 0 {
            var storage = sockaddr_storage()
            var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let client = withUnsafeMutablePointer(to: &storage) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    accept(descriptor, socketAddress, &length)
                }
            }
            if client < 0 {
                if errno == EINTR {
                    continue
                }
                if errno != EAGAIN && errno != EWOULDBLOCK {
                    close(to: .failed(.posix(errno: errno)))
                }
                return
            }
            _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL, 0) | O_NONBLOCK)
            let connection = NWConnection(accepted: client, endpoint: peerEndpoint(storage), using: parameters)
            newConnectionHandler?(connection)
        }
    }

    private func peerEndpoint(_ storage: sockaddr_storage) -> NWEndpoint {
        var copy = storage
        return withUnsafePointer(to: &copy) { pointer -> NWEndpoint in
            pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { address in
                var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var host = address.pointee.sin_addr
                inet_ntop(AF_INET, &host, &text, socklen_t(text.count))
                return .hostPort(host: NWEndpoint.Host(String(cString: text)), port: NWEndpoint.Port(rawValue: UInt16(bigEndian: address.pointee.sin_port))!)
            }
        }
    }

    private func setState(_ next: State) {
        state = next
        stateUpdateHandler?(next)
    }

    private func close(to next: State) {
        guard state != .cancelled else {
            return
        }
        readSource?.cancel()
        readSource = nil
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }
        setState(next)
    }
}
