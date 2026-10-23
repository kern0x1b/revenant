#if !REVENANT_BACKPORT
import Network
#endif
import Darwin
import Dispatch
import Foundation
import Security

let identityPath = CommandLine.arguments[1]
let wait: DispatchTimeInterval = .seconds(10)

func loadIdentity(_ path: String) -> SecIdentity {
    let data = try! Data(contentsOf: URL(fileURLWithPath: path))
    var items: CFArray?
    let options: [String: Any] = [kSecImportExportPassphrase as String: "revenant", kSecImportToMemoryOnly as String: true]
    let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
    precondition(status == errSecSuccess, "the test identity does not import")
    let entry = (items! as NSArray)[0] as! [String: Any]
    return entry[kSecImportItemIdentity as String] as! SecIdentity
}

func serverParameters(_ identity: SecIdentity) -> NWParameters {
    #if REVENANT_BACKPORT
    let tls = NWProtocolTLS.Options()
    tls.securityProtocolOptions.localIdentity = identity
    tls.securityProtocolOptions.applicationProtocols = ["h2"]
    tls.securityProtocolOptions.peerAuthenticationRequired = false
    return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    #else
    let tls = NWProtocolTLS.Options()
    sec_protocol_options_set_local_identity(tls.securityProtocolOptions, sec_identity_create(identity)!)
    sec_protocol_options_add_tls_application_protocol(tls.securityProtocolOptions, "h2")
    sec_protocol_options_set_peer_authentication_required(tls.securityProtocolOptions, false)
    return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    #endif
}

func clientParameters() -> NWParameters {
    #if REVENANT_BACKPORT
    let tls = NWProtocolTLS.Options()
    tls.securityProtocolOptions.applicationProtocols = ["http/1.1", "h2"]
    tls.securityProtocolOptions.peerAuthenticationRequired = false
    return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    #else
    let tls = NWProtocolTLS.Options()
    sec_protocol_options_add_tls_application_protocol(tls.securityProtocolOptions, "http/1.1")
    sec_protocol_options_add_tls_application_protocol(tls.securityProtocolOptions, "h2")
    sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, _, complete in complete(true) }, DispatchQueue.global())
    return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    #endif
}

func negotiated(_ connection: NWConnection) -> String {
    #if REVENANT_BACKPORT
    return "unavailable"
    #else
    guard let metadata = connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata else {
        return "none"
    }
    return sec_protocol_metadata_get_negotiated_protocol(metadata.securityProtocolMetadata).map { String(cString: $0) } ?? "none"
    #endif
}

let identity = loadIdentity(identityPath)
let queue = DispatchQueue(label: "revenant.network.tls.listener")
let listenerReady = DispatchSemaphore(value: 0)
let serverReceived = DispatchSemaphore(value: 0)
let clientReady = DispatchSemaphore(value: 0)
let clientReceived = DispatchSemaphore(value: 0)
var serverText = "none"
var serverNegotiated = "none"
var clientText = "none"
var clientNegotiated = "none"

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
    clientReceived.signal()
}
_ = clientReceived.wait(timeout: .now() + wait)
_ = serverReceived.wait(timeout: .now() + wait)
queue.sync {
    print("tls listener client negotiated \(clientNegotiated)")
    print("tls listener server negotiated \(serverNegotiated)")
    print("tls listener server received \(serverText)")
    print("tls listener client received \(clientText)")
}
client.cancel()
listener.cancel()
