import Darwin
import Dispatch
import Foundation
import Security

let wait: DispatchTimeInterval = .seconds(10)

func loadIdentity() -> SecIdentity {
    let data = Data(identityBytes)
    var items: CFArray?
    let options: [String: Any] = [kSecImportExportPassphrase as String: "revenant", "toMemoryOnly": true]
    let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
    precondition(status == errSecSuccess, "the test identity does not import")
    let entry = (items! as NSArray)[0] as! [String: Any]
    return entry[kSecImportItemIdentity as String] as! SecIdentity
}

func serverParameters(_ identity: SecIdentity) -> NWParameters {
    let tls = NWProtocolTLS.Options()
    tls.securityProtocolOptions.localIdentity = identity
    tls.securityProtocolOptions.applicationProtocols = ["h2"]
    tls.securityProtocolOptions.peerAuthenticationRequired = false
    return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
}

func strictServerParameters(_ identity: SecIdentity) -> NWParameters {
    let tls = NWProtocolTLS.Options()
    tls.securityProtocolOptions.localIdentity = identity
    tls.securityProtocolOptions.applicationProtocols = ["h2"]
    tls.securityProtocolOptions.peerAuthenticationRequired = true
    return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
}

func clientParameters() -> NWParameters {
    let tls = NWProtocolTLS.Options()
    tls.securityProtocolOptions.applicationProtocols = ["http/1.1", "h2"]
    tls.securityProtocolOptions.peerAuthenticationRequired = false
    return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
}

func negotiated(_ connection: NWConnection) -> String {
    connection.negotiatedApplicationProtocol ?? "none"
}

func negotiatedVersion(_ connection: NWConnection) -> String {
    connection.negotiatedTLSVersion.map { String($0, radix: 16) } ?? "none"
}

let identity = loadIdentity()
let queue = DispatchQueue(label: "revenant.network.tls.listener")
let listenerReady = DispatchSemaphore(value: 0)
let serverReceived = DispatchSemaphore(value: 0)
let clientReady = DispatchSemaphore(value: 0)
let clientReceived = DispatchSemaphore(value: 0)
var serverText = "none"
var serverNegotiated = "none"
var serverVersion = "none"
var clientText = "none"
var clientNegotiated = "none"
var clientVersion = "none"

let listener = try! NWListener(using: serverParameters(identity), on: 0)
listener.stateUpdateHandler = { state in
    if case .ready = state {
        listenerReady.signal()
    }
}
listener.newConnectionHandler = { connection in
    connection.start(queue: queue)
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16) { data, _, _, _ in
        serverText = String(data: data ?? Data(), encoding: .utf8) ?? "nil"
        serverNegotiated = negotiated(connection)
        serverVersion = negotiatedVersion(connection)
        connection.send(content: Data("pong".utf8), completion: .contentProcessed { _ in
            serverReceived.signal()
        })
    }
}
listener.start(queue: queue)
_ = listenerReady.wait(timeout: .now() + wait)
let port = listener.port!

let client = NWConnection(host: "127.0.0.1", port: port, using: clientParameters())
client.stateUpdateHandler = { state in
    if case .ready = state {
        clientReady.signal()
    }
}
client.start(queue: queue)
print(clientReady.wait(timeout: .now() + wait) == .success ? "tls listener client ready" : "tls listener client never ready")
client.send(content: Data("ping".utf8), completion: .contentProcessed { _ in })
client.receive(minimumIncompleteLength: 1, maximumLength: 16) { data, _, _, _ in
    clientText = String(data: data ?? Data(), encoding: .utf8) ?? "nil"
    clientNegotiated = negotiated(client)
    clientVersion = negotiatedVersion(client)
    clientReceived.signal()
}
_ = clientReceived.wait(timeout: .now() + wait)
_ = serverReceived.wait(timeout: .now() + wait)
queue.sync {
    print("tls listener client negotiated \(clientNegotiated)")
    print("tls listener server negotiated \(serverNegotiated)")
    print("tls listener client version \(clientVersion)")
    print("tls listener server version \(serverVersion)")
    print("tls listener server received \(serverText)")
    print("tls listener client received \(clientText)")
}
client.cancel()
listener.cancel()

let strictListener = try! NWListener(using: strictServerParameters(identity), on: 0)
strictListener.newConnectionHandler = { connection in
    connection.start(queue: queue)
}
strictListener.start(queue: queue)
let strictClient = NWConnection(host: "127.0.0.1", port: strictListener.port!, using: clientParameters())
let strictReceived = DispatchSemaphore(value: 0)
var strictText = "none"
strictClient.start(queue: queue)
strictClient.send(content: Data("ping".utf8), completion: .contentProcessed { _ in })
strictClient.receive(minimumIncompleteLength: 1, maximumLength: 16) { data, _, _, _ in
    if let data, !data.isEmpty {
        strictText = String(data: data, encoding: .utf8) ?? "nil"
    }
    strictReceived.signal()
}
_ = strictReceived.wait(timeout: .now() + wait)
queue.sync {
    print("tls strict client auth without certificate received \(strictText)")
}
strictClient.cancel()
strictListener.cancel()

let reachHosts: [(String, String)] = [
    ("www.apple.com", "23.36.157.47"),
    ("www.google.com", "142.251.151.119"),
    ("www.cloudflare.com", "104.16.124.96"),
    ("tls13.cloudflare.com", "104.16.132.229"),
    ("web.telegram.org", "149.154.167.99"),
    ("api.telegram.org", "149.154.166.110"),
    ("github.com", "140.82.121.4"),
    ("letsencrypt.org", "63.176.8.218"),
    ("example.com", "172.66.147.243"),
    ("tls-v1-2.badssl.com", "104.154.89.105"),
]

for (name, address) in reachHosts {
    let tls = NWProtocolTLS.Options()
    tls.securityProtocolOptions.serverName = name
    tls.securityProtocolOptions.applicationProtocols = ["h2", "http/1.1"]
    let connection = NWConnection(host: NWEndpoint.Host(address), port: NWEndpoint.Port(rawValue: 443)!,
                                  using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options()))
    let outcome = DispatchSemaphore(value: 0)
    var result = "timeout"
    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            result = "ready alpn \(negotiated(connection)) version \(negotiatedVersion(connection))"
            outcome.signal()
        case .waiting(let error), .failed(let error):
            result = "failed \(error.debugDescription)"
            outcome.signal()
        default:
            break
        }
    }
    let started = Date()
    connection.start(queue: queue)
    _ = outcome.wait(timeout: .now() + .seconds(120))
    print("reach \(name) \(result) after \(Int(Date().timeIntervalSince(started))) s")
    connection.cancel()
}
