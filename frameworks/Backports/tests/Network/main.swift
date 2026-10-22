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
    var statuses: [String] = []
    monitor.pathUpdateHandler = { path in
        statuses.append("\(path.status)")
        first.signal()
    }
    monitor.start(queue: queue)
    print(first.wait(timeout: .now() + wait) == .success ? "path update delivered" : "path update missing")
    monitor.cancel()
    queue.sync {
        print("path first status \(statuses.first ?? "none")")
    }
}

func endpoints() {
    let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("127.0.0.1"), port: NWEndpoint.Port(rawValue: 8443)!)
    print("endpoint \(endpoint.debugDescription)")
    let named = NWEndpoint.hostPort(host: NWEndpoint.Host("example.test"), port: 443)
    print("named \(named.debugDescription)")
}

tcpExchange()
udpExchange()
refusedConnection()
pathStatus()
endpoints()
