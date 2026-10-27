#if !REVENANT_BACKPORT
import Network
#endif
import Darwin
import Dispatch
import Foundation
import Security

let identityPath = CommandLine.arguments[1]
let wait: DispatchTimeInterval = .seconds(10)
let logQueue = DispatchQueue(label: "revenant.network.tls.log")
var serverLog: [String] = []

func record(_ line: String) {
    logQueue.sync {
        serverLog.append(line)
    }
}

func loadIdentity(_ path: String) -> SecIdentity {
    let data = try! Data(contentsOf: URL(fileURLWithPath: path))
    var items: CFArray?
    let options: [String: Any] = [kSecImportExportPassphrase as String: "revenant", kSecImportToMemoryOnly as String: true]
    let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
    precondition(status == errSecSuccess, "the test identity does not import")
    let entry = (items! as NSArray)[0] as! [String: Any]
    return entry[kSecImportItemIdentity as String] as! SecIdentity
}

final class ServerSocket {
    let descriptor: Int32

    init(_ descriptor: Int32) {
        self.descriptor = descriptor
    }
}

private let serverRead: SSLReadFunc = { connection, data, length in
    let socket = Unmanaged<ServerSocket>.fromOpaque(connection).takeUnretainedValue()
    let count = recv(socket.descriptor, data, length.pointee, 0)
    if count > 0 {
        length.pointee = count
        return noErr
    }
    length.pointee = 0
    return count == 0 ? errSSLClosedGraceful : errSSLClosedAbort
}

private let serverWrite: SSLWriteFunc = { connection, data, length in
    let socket = Unmanaged<ServerSocket>.fromOpaque(connection).takeUnretainedValue()
    let count = send(socket.descriptor, data, length.pointee, 0)
    if count >= 0 {
        length.pointee = count
        return noErr
    }
    length.pointee = 0
    return errSSLClosedAbort
}

typealias SetALPNFunction = @convention(c) (SSLContext, CFArray) -> OSStatus
typealias CopyALPNFunction = @convention(c) (SSLContext, UnsafeMutablePointer<CFArray?>) -> OSStatus

func serve(_ descriptor: Int32, identity: SecIdentity, alpn: Bool) {
    let socket = ServerSocket(descriptor)
    guard let context = SSLCreateContext(kCFAllocatorDefault, .serverSide, .streamType) else {
        record("tls server could not create a context")
        close(descriptor)
        return
    }
    SSLSetIOFuncs(context, serverRead, serverWrite)
    SSLSetConnection(context, Unmanaged.passUnretained(socket).toOpaque())
    SSLSetCertificate(context, [identity] as CFArray)
    if alpn, let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "SSLSetALPNProtocols") {
        let setALPN = unsafeBitCast(symbol, to: SetALPNFunction.self)
        _ = setALPN(context, ["revenant"] as CFArray)
    }
    let status = SSLHandshake(context)
    guard status == noErr else {
        record("tls server handshake failed")
        SSLClose(context)
        close(descriptor)
        return
    }
    if let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "SSLCopyALPNProtocols") {
        let copy = unsafeBitCast(symbol, to: CopyALPNFunction.self)
        var protocols: CFArray?
        if copy(context, &protocols) == noErr, let names = protocols as? [String] {
            record("tls server negotiated alpn \(names.joined(separator: ","))")
        } else {
            record("tls server negotiated alpn none")
        }
    }
    var buffer = [UInt8](repeating: 0, count: 16)
    var processed = 0
    if SSLRead(context, &buffer, buffer.count, &processed) == noErr {
        record("tls server received \(String(decoding: buffer[0..<processed], as: UTF8.self))")
    }
    let reply = Array("pong".utf8)
    var written = 0
    _ = SSLWrite(context, reply, reply.count, &written)
    SSLClose(context)
    close(descriptor)
}

func startServer(identity: SecIdentity, alpn: Bool, done: DispatchSemaphore) -> UInt16 {
    let listener = socket(AF_INET, SOCK_STREAM, 0)
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    address.sin_port = 0
    withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            _ = bind(listener, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    _ = listen(listener, 4)
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    withUnsafeMutablePointer(to: &bound) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            _ = getsockname(listener, socketAddress, &length)
        }
    }
    let port = UInt16(bigEndian: bound.sin_port)
    Thread.detachNewThread {
        let client = accept(listener, nil, nil)
        if client >= 0 {
            serve(client, identity: identity, alpn: alpn)
        }
        close(listener)
        done.signal()
    }
    return port
}

func clientParameters(verify: Bool) -> NWParameters {
    let tls = NWProtocolTLS.Options()
    sec_protocol_options_add_tls_application_protocol(tls.securityProtocolOptions, "revenant")
    sec_protocol_options_set_peer_authentication_required(tls.securityProtocolOptions, verify)
    if !verify {
        sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, _, complete in complete(true) }, DispatchQueue.global())
    }
    return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
}

func exchange(verify: Bool, alpn: Bool) -> [String] {
    var lines: [String] = []
    let identity = loadIdentity(identityPath)
    let serverDone = DispatchSemaphore(value: 0)
    let port = startServer(identity: identity, alpn: alpn, done: serverDone)
    let client = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: clientParameters(verify: verify))
    let settled = DispatchSemaphore(value: 0)
    let received = DispatchSemaphore(value: 0)
    var ready = false
    var failed = false
    var reply = "none"
    var states: [String] = []
    client.stateUpdateHandler = { state in
        switch state {
        case .setup:
            states.append("setup")
        case .preparing:
            states.append("preparing")
        case .waiting:
            states.append("waiting")
        case .ready:
            states.append("ready")
            ready = true
            settled.signal()
        case .failed:
            states.append("failed")
            failed = true
            settled.signal()
        case .cancelled:
            states.append("cancelled")
        @unknown default:
            states.append("unknown")
        }
    }
    let queue = DispatchQueue(label: "revenant.network.tls.client")
    client.start(queue: queue)
    _ = settled.wait(timeout: .now() + wait)
    lines.append("tls states \(logQueue.sync { states.joined(separator: " ") })")
    if verify {
        lines.append("tls strict handshake failed \(failed) ready \(ready)")
    } else {
        lines.append("tls client ready \(ready)")
        client.send(content: Data("ping".utf8), completion: .contentProcessed { _ in })
        client.receive(minimumIncompleteLength: 1, maximumLength: 16) { data, _, _, _ in
            reply = String(data: data ?? Data(), encoding: .utf8) ?? "nil"
            received.signal()
        }
        _ = received.wait(timeout: .now() + wait)
        lines.append("tls client received \(reply)")
    }
    client.cancel()
    _ = serverDone.wait(timeout: .now() + wait)
    lines.append(contentsOf: logQueue.sync { serverLog })
    logQueue.sync {
        serverLog = []
    }
    return lines
}

for line in exchange(verify: false, alpn: true) {
    print(line)
}
for line in exchange(verify: true, alpn: false) {
    print(line)
}
