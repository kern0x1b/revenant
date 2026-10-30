#if !REVENANT_BACKPORT
import Network
#endif
import Darwin
import Dispatch
import Foundation

func serve(_ type: Int32, _ handler: @escaping (Int32) -> Void) -> UInt16 {
    let fd = socket(AF_INET, type, 0)
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    address.sin_port = 0
    withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            _ = bind(fd, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    withUnsafeMutablePointer(to: &bound) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            _ = getsockname(fd, socketAddress, &length)
        }
    }
    if type == SOCK_STREAM {
        _ = listen(fd, 4)
    }
    let port = UInt16(bigEndian: bound.sin_port)
    Thread.detachNewThread {
        handler(fd)
    }
    return port
}

func echoTCP(_ listener: Int32) {
    while true {
        let client = accept(listener, nil, nil)
        if client < 0 {
            return
        }
        Thread.detachNewThread {
            var buffer = [UInt8](repeating: 0, count: 256)
            while true {
                let count = recv(client, &buffer, buffer.count, 0)
                if count <= 0 {
                    break
                }
                _ = send(client, buffer, count, 0)
            }
            close(client)
        }
    }
}

func echoUDP(_ socketFD: Int32) {
    var buffer = [UInt8](repeating: 0, count: 256)
    while true {
        var peer = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let count = withUnsafeMutablePointer(to: &peer) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                recvfrom(socketFD, &buffer, buffer.count, 0, socketAddress, &length)
            }
        }
        if count <= 0 {
            return
        }
        _ = withUnsafePointer(to: &peer) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                sendto(socketFD, buffer, count, 0, socketAddress, length)
            }
        }
    }
}

func token(_ state: NWConnection.State) -> String {
    switch state {
    case .setup:
        return "setup"
    case .waiting:
        return "waiting"
    case .preparing:
        return "preparing"
    case .ready:
        return "ready"
    case .failed:
        return "failed"
    case .cancelled:
        return "cancelled"
    @unknown default:
        return "unknown"
    }
}

let queue = DispatchQueue(label: "revenant.network.test")
let wait: DispatchTimeInterval = .seconds(5)

func observe(_ connection: NWConnection, _ name: String, _ log: @escaping (String) -> Void) {
    connection.stateUpdateHandler = { state in
        log("\(name) state \(token(state))")
    }
}

func tcpExchange() {
    let port = serve(SOCK_STREAM, echoTCP)
    let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    let ready = DispatchSemaphore(value: 0)
    let received = DispatchSemaphore(value: 0)
    let cancelled = DispatchSemaphore(value: 0)
    var log: [String] = []
    connection.stateUpdateHandler = { state in
        log.append("tcp state \(token(state))")
        switch state {
        case .ready:
            ready.signal()
        case .cancelled:
            cancelled.signal()
        default:
            break
        }
    }
    connection.start(queue: queue)
    print(ready.wait(timeout: .now() + wait) == .success ? "tcp reached ready" : "tcp never ready")
    connection.send(content: Data("hello world".utf8), completion: .contentProcessed { error in
        print("tcp send completed without error: \(error == nil)")
    })
    connection.receive(minimumIncompleteLength: 11, maximumLength: 11) { data, _, complete, error in
        print("tcp received \(String(data: data ?? Data(), encoding: .utf8) ?? "nil") complete \(complete) error \(error == nil)")
        received.signal()
    }
    print(received.wait(timeout: .now() + wait) == .success ? "tcp receive returned" : "tcp receive timed out")
    connection.cancel()
    print(cancelled.wait(timeout: .now() + wait) == .success ? "tcp cancelled" : "tcp cancel timed out")
    queue.sync {
        for line in log {
            print(line)
        }
    }
}

func udpExchange() {
    let socketFD = socket(AF_INET, SOCK_DGRAM, 0)
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    address.sin_port = 0
    withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            _ = bind(socketFD, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    withUnsafeMutablePointer(to: &bound) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            _ = getsockname(socketFD, socketAddress, &length)
        }
    }
    Thread.detachNewThread {
        echoUDP(socketFD)
    }
    let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: UInt16(bigEndian: bound.sin_port))!, using: .udp)
    let ready = DispatchSemaphore(value: 0)
    let received = DispatchSemaphore(value: 0)
    connection.stateUpdateHandler = { state in
        if case .ready = state {
            ready.signal()
        }
    }
    connection.start(queue: queue)
    print(ready.wait(timeout: .now() + wait) == .success ? "udp reached ready" : "udp never ready")
    connection.send(content: Data("ping".utf8), completion: .contentProcessed { _ in })
    connection.receive(minimumIncompleteLength: 1, maximumLength: 64) { data, _, complete, error in
        print("udp received \(String(data: data ?? Data(), encoding: .utf8) ?? "nil") complete \(complete) error \(error == nil)")
        received.signal()
    }
    print(received.wait(timeout: .now() + wait) == .success ? "udp receive returned" : "udp receive timed out")
    connection.cancel()
    close(socketFD)
}

func refusedConnection() {
    let probe = socket(AF_INET, SOCK_STREAM, 0)
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    address.sin_port = 0
    withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            _ = bind(probe, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    withUnsafeMutablePointer(to: &bound) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            _ = getsockname(probe, socketAddress, &length)
        }
    }
    close(probe)
    let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: UInt16(bigEndian: bound.sin_port))!, using: .tcp)
    let finished = DispatchSemaphore(value: 0)
    var log: [String] = []
    connection.stateUpdateHandler = { state in
        log.append("refused state \(token(state))")
        switch state {
        case .failed, .waiting:
            finished.signal()
        default:
            break
        }
    }
    connection.start(queue: queue)
    print(finished.wait(timeout: .now() + wait) == .success ? "refused connection reported" : "refused connection silent")
    queue.sync {
        for line in log {
            print(line)
        }
    }
    connection.cancel()
}

func pathStatus() {
    let monitor = NWPathMonitor()
    let first = DispatchSemaphore(value: 0)
    var loopback = false
    monitor.pathUpdateHandler = { path in
        loopback = path.availableInterfaces.contains { $0.type == .loopback }
        first.signal()
    }
    monitor.start(queue: queue)
    print(first.wait(timeout: .now() + wait) == .success ? "path update delivered" : "path update missing")
    monitor.cancel()
    queue.sync {
        print("path has loopback interface \(loopback)")
    }
}

func endpoints() {
    let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("127.0.0.1"), port: NWEndpoint.Port(rawValue: 8443)!)
    print("endpoint \(endpoint.debugDescription)")
    let named = NWEndpoint.hostPort(host: NWEndpoint.Host("example.test"), port: 443)
    print("named \(named.debugDescription)")
}

func tcpOptionDefaults() {
    let options = NWProtocolTCP.Options()
    print("tcp defaults noDelay \(options.noDelay) keepalive \(options.enableKeepalive) idle \(options.keepaliveIdle) count \(options.keepaliveCount) interval \(options.keepaliveInterval) fastOpen \(options.enableFastOpen)")
    options.noDelay = true
    options.enableKeepalive = true
    options.keepaliveIdle = 5
    options.keepaliveCount = 2
    options.keepaliveInterval = 5
    let parameters = NWParameters(tls: nil, tcp: options)
    print("tcp parameters preferNoProxies \(parameters.preferNoProxies)")
}

final class LengthPrefixFramer: NWProtocolFramerImplementation {
    static var label: String = "LengthPrefix"
    static let definition = NWProtocolFramer.Definition(implementation: LengthPrefixFramer.self)

    required init(framer: NWProtocolFramer.Instance) {
    }

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        return .ready
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        var consumed = true
        while consumed {
            consumed = false
            _ = framer.parseInput(minimumIncompleteLength: 4, maximumLength: 65536) { buffer, _ in
                guard let buffer = buffer, buffer.count >= 4 else {
                    return 0
                }
                let length = Int(buffer.loadUnaligned(as: UInt32.self).bigEndian)
                guard buffer.count >= 4 + length else {
                    return 0
                }
                framer.deliverInput(data: Data(buffer[4..<(4 + length)]), message: NWProtocolFramer.Message(definition: LengthPrefixFramer.definition), isComplete: true)
                consumed = true
                return 4 + length
            }
        }
        return 0
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        framer.writeOutput(data: withUnsafeBytes(of: UInt32(messageLength).bigEndian) { Data($0) })
        try! framer.writeOutputNoCopy(length: messageLength)
    }

    func wakeup(framer: NWProtocolFramer.Instance) {
    }

    func stop(framer: NWProtocolFramer.Instance) -> Bool {
        return true
    }

    func cleanup(framer: NWProtocolFramer.Instance) {
    }
}

func listenerExchange() {
    let ready = DispatchSemaphore(value: 0)
    let serverReceived = DispatchSemaphore(value: 0)
    let clientReady = DispatchSemaphore(value: 0)
    let clientReceived = DispatchSemaphore(value: 0)
    var serverText = "none"
    var clientText = "none"
    guard let listener = try? NWListener(using: .tcp, on: 0) else {
        print("listener could not start")
        return
    }
    listener.stateUpdateHandler = { state in
        if state == .ready {
            ready.signal()
        }
    }
    listener.newConnectionHandler = { connection in
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16) { data, _, _, _ in
            serverText = String(data: data ?? Data(), encoding: .utf8) ?? "nil"
            connection.send(content: Data("pong".utf8), completion: .contentProcessed { _ in
                serverReceived.signal()
            })
        }
    }
    listener.start(queue: queue)
    print(ready.wait(timeout: .now() + wait) == .success ? "listener reached ready" : "listener never ready")
    guard let port = listener.port else {
        print("listener has no port")
        return
    }
    print("listener port assigned \(port.rawValue != 0)")
    let client = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
    client.stateUpdateHandler = { state in
        if state == .ready {
            clientReady.signal()
        }
    }
    client.start(queue: queue)
    print(clientReady.wait(timeout: .now() + wait) == .success ? "client reached ready" : "client never ready")
    client.send(content: Data("ping".utf8), completion: .contentProcessed { _ in })
    client.receive(minimumIncompleteLength: 1, maximumLength: 16) { data, _, _, _ in
        clientText = String(data: data ?? Data(), encoding: .utf8) ?? "nil"
        clientReceived.signal()
    }
    print(clientReceived.wait(timeout: .now() + wait) == .success ? "client received reply" : "client reply timed out")
    _ = serverReceived.wait(timeout: .now() + wait)
    queue.sync {
        print("listener server received \(serverText) client received \(clientText)")
    }
    client.cancel()
    listener.cancel()
}

func framedExchange() {
    let ready = DispatchSemaphore(value: 0)
    let serverReceived = DispatchSemaphore(value: 0)
    let clientReceived = DispatchSemaphore(value: 0)
    var serverText = "none"
    var clientText = "none"
    let parameters = NWParameters.tcp
    parameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolFramer.Options(definition: LengthPrefixFramer.definition), at: 0)
    guard let listener = try? NWListener(using: parameters, on: 0) else {
        print("framed listener could not start")
        return
    }
    listener.stateUpdateHandler = { state in
        if state == .ready {
            ready.signal()
        }
    }
    listener.newConnectionHandler = { connection in
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
            serverText = String(data: data ?? Data(), encoding: .utf8) ?? "nil"
            connection.send(content: Data("framed ack".utf8), completion: .contentProcessed { _ in
                serverReceived.signal()
            })
        }
    }
    listener.start(queue: queue)
    _ = ready.wait(timeout: .now() + wait)
    guard let port = listener.port else {
        print("framed listener has no port")
        return
    }
    let client = NWConnection(host: "127.0.0.1", port: port, using: parameters)
    client.start(queue: queue)
    client.send(content: Data("hello framed".utf8), completion: .contentProcessed { _ in })
    client.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
        clientText = String(data: data ?? Data(), encoding: .utf8) ?? "nil"
        clientReceived.signal()
    }
    print(clientReceived.wait(timeout: .now() + wait) == .success ? "framed client received a message" : "framed reply timed out")
    _ = serverReceived.wait(timeout: .now() + wait)
    queue.sync {
        print("framed server received \(serverText) client received \(clientText)")
    }
    client.cancel()
    listener.cancel()
}

func contextAndViability() {
    print("default message final \(NWConnection.ContentContext.defaultMessage.isFinal) default stream final \(NWConnection.ContentContext.defaultStream.isFinal)")
    print("constructed final \(NWConnection.ContentContext(identifier: "x").isFinal) \(NWConnection.ContentContext(identifier: "x", isFinal: true).isFinal)")
    let shared = NWParameters.tcp
    let alias = shared
    alias.preferNoProxies = true
    print("parameters shared \(shared.preferNoProxies)")

    let port = serve(SOCK_STREAM, echoTCP)
    let parameters = NWParameters.tcp
    let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: parameters)
    print("connection holds parameters \(connection.parameters === parameters)")
    let ready = DispatchSemaphore(value: 0)
    let viable = DispatchSemaphore(value: 0)
    let received = DispatchSemaphore(value: 0)
    let cancelled = DispatchSemaphore(value: 0)
    var viability: [Bool] = []
    connection.viabilityUpdateHandler = { isViable in
        viability.append(isViable)
        viable.signal()
    }
    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            ready.signal()
        case .cancelled:
            cancelled.signal()
        default:
            break
        }
    }
    connection.start(queue: queue)
    print(ready.wait(timeout: .now() + wait) == .success ? "viability tcp reached ready" : "viability tcp never ready")
    print(viable.wait(timeout: .now() + wait) == .success ? "viability tcp reported" : "viability tcp never reported")
    connection.send(content: Data("hello world".utf8), completion: .contentProcessed { _ in })
    connection.receive(minimumIncompleteLength: 11, maximumLength: 11) { data, context, complete, _ in
        print("final tcp received \(String(data: data ?? Data(), encoding: .utf8) ?? "nil") final \(context?.isFinal ?? false) complete \(complete)")
        received.signal()
    }
    _ = received.wait(timeout: .now() + wait)
    connection.cancel()
    _ = cancelled.wait(timeout: .now() + wait)
    queue.sync {
        print("viability tcp values \(viability)")
    }
}

tcpExchange()
udpExchange()
refusedConnection()
pathStatus()
endpoints()
tcpOptionDefaults()
listenerExchange()
framedExchange()
contextAndViability()
