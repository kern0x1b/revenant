import Darwin
import Dispatch
import Foundation
import Network
import Security

let wait: DispatchTimeInterval = .seconds(10)

func loadIdentity() -> SecIdentity {
    let data = Data(base64Encoded: identityBase64)!
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
