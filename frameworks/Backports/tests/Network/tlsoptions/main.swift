import Darwin
import Dispatch
import Foundation
import Network
import Security

let opensslPath = CommandLine.arguments[1]
let certificatePath = CommandLine.arguments[2]
let keyPath = CommandLine.arguments[3]
let identityPath = CommandLine.arguments[4]
let leafPath = CommandLine.arguments[5]
let authorityPath = CommandLine.arguments[6]
let expectedLeaf = try! Data(contentsOf: URL(fileURLWithPath: leafPath))

final class Locked<Value> {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withValue<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

let leafObservation = Locked("unseen")

struct Scenario {
    let name: String
    let serverArguments: [String]
    let reportsCipher: Bool
    let reportsLeaf: Bool
    let configure: (sec_protocol_options_t) -> Void
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

func dispatchData(_ text: String) -> dispatch_data_t {
    let bytes = Array(text.utf8)
    return bytes.withUnsafeBytes { unsafeBitCast(DispatchData(bytes: $0), to: dispatch_data_t.self) }
}

func leafData(_ trust: sec_trust_t) -> Data? {
    let reference: SecTrust? = sec_trust_copy_ref(trust).takeRetainedValue()
    guard let reference, let leaf = SecTrustGetCertificateAtIndex(reference, 0) else {
        return nil
    }
    return SecCertificateCopyData(leaf) as Data
}

func observe(_ trust: sec_trust_t, pin: Data) -> Bool {
    let matches = leafData(trust) == pin
    leafObservation.withValue { $0 = matches ? "match" : "mismatch" }
    return matches
}

func unauthenticated(_ options: sec_protocol_options_t) {
    sec_protocol_options_set_peer_authentication_required(options, false)
}

func startServer(port: UInt16, arguments: [String]) -> (process: Process, transcript: Locked<String>) {
    let transcript = Locked("")
    let pipe = Pipe()
    pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        transcript.withValue { $0 += String(decoding: data, as: UTF8.self) }
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    let identity = arguments.contains("-nocert") ? [] : ["-cert", certificatePath, "-key", keyPath]
    process.arguments = ["timeout", "60", opensslPath, "s_server", "-accept", String(port)] + identity + arguments
    process.standardInput = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try! process.run()
    return (process, transcript)
}

func describe(_ error: NWError) -> String {
    switch error {
    case .tls(let status):
        return "tls=\(status)"
    default:
        return "other"
    }
}

func parameters(_ configure: (sec_protocol_options_t) -> Void) -> NWParameters {
    let tls = NWProtocolTLS.Options()
    configure(tls.securityProtocolOptions)
    return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
}

func settle(_ parameters: NWParameters, port: UInt16) -> String {
    let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: parameters)
    let outcome = Locked("timeout")
    let settled = DispatchSemaphore(value: 0)
    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            outcome.withValue { $0 = "ready" }
            settled.signal()
        case .failed(let error):
            outcome.withValue { $0 = "failed \(describe(error))" }
            settled.signal()
        case .waiting(let error):
            outcome.withValue { $0 = "waiting \(describe(error))" }
            settled.signal()
        default:
            break
        }
    }
    connection.start(queue: DispatchQueue(label: "revenant.tlsoptions.client"))
    _ = settled.wait(timeout: .now() + 20)
    connection.cancel()
    return outcome.withValue { $0 }
}

let verifyQueue = DispatchQueue(label: "revenant.tlsoptions.verify")
let challengeQueue = DispatchQueue(label: "revenant.tlsoptions.challenge")
let clientIdentity = sec_identity_create(loadIdentity(identityPath))!

let scenarios: [Scenario] = [
    Scenario(name: "verify-accept", serverArguments: [], reportsCipher: false, reportsLeaf: false, configure: { options in
        sec_protocol_options_set_verify_block(options, { _, _, complete in complete(true) }, verifyQueue)
    }),
    Scenario(name: "verify-reject", serverArguments: [], reportsCipher: false, reportsLeaf: false, configure: { options in
        sec_protocol_options_set_verify_block(options, { _, _, complete in complete(false) }, verifyQueue)
    }),
    Scenario(name: "pin-match", serverArguments: [], reportsCipher: false, reportsLeaf: true, configure: { options in
        sec_protocol_options_set_verify_block(options, { _, trust, complete in complete(observe(trust, pin: expectedLeaf)) }, verifyQueue)
    }),
    Scenario(name: "pin-mismatch", serverArguments: [], reportsCipher: false, reportsLeaf: true, configure: { options in
        sec_protocol_options_set_verify_block(options, { _, trust, complete in complete(observe(trust, pin: Data([0x30, 0x00]))) }, verifyQueue)
    }),
    Scenario(name: "cipher-allowed", serverArguments: [], reportsCipher: true, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_t.TLSv12)
        sec_protocol_options_add_tls_ciphersuite(options, SSLCipherSuite(0xC02F))
    }),
    Scenario(name: "cipher-refused", serverArguments: [], reportsCipher: true, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_t.TLSv12)
        sec_protocol_options_add_tls_ciphersuite(options, SSLCipherSuite(0xC02B))
    }),
    Scenario(name: "ocsp", serverArguments: [], reportsCipher: false, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_tls_ocsp_enabled(options, true)
    }),
    Scenario(name: "sct", serverArguments: [], reportsCipher: false, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_tls_sct_enabled(options, true)
    }),
    Scenario(name: "challenge-identity", serverArguments: ["-Verify", "1", "-CAfile", authorityPath], reportsCipher: false, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_t.TLSv12)
        sec_protocol_options_set_challenge_block(options, { _, complete in complete(clientIdentity) }, challengeQueue)
    }),
    Scenario(name: "challenge-none", serverArguments: ["-Verify", "1", "-CAfile", authorityPath], reportsCipher: false, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_t.TLSv12)
        sec_protocol_options_set_challenge_block(options, { _, complete in complete(nil) }, challengeQueue)
    }),
    Scenario(name: "psk-client", serverArguments: ["-nocert", "-psk", "736563726574", "-cipher", "ECDHE-PSK-AES128-CBC-SHA"], reportsCipher: true, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_t.TLSv12)
        sec_protocol_options_add_pre_shared_key(options, dispatchData("secret"), dispatchData("client"))
    }),
    Scenario(name: "dh-refused", serverArguments: [], reportsCipher: false, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_tls_diffie_hellman_parameters(options, dispatchData("parameters"))
    }),
    Scenario(name: "cipher-unknown", serverArguments: [], reportsCipher: false, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_add_tls_ciphersuite(options, SSLCipherSuite(0xFFFF))
    }),
    Scenario(name: "psk-wrong-key",serverArguments: ["-nocert", "-psk", "736563726574", "-cipher", "ECDHE-PSK-AES128-CBC-SHA"], reportsCipher: false, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_t.TLSv12)
        sec_protocol_options_add_pre_shared_key(options, dispatchData("wrong"), dispatchData("client"))
    }),
    Scenario(name: "group-default-no-shared",serverArguments: ["-tls1_2", "-cipher", "AES128-SHA"], reportsCipher: true, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_t.TLSv12)
        sec_protocol_options_append_tls_ciphersuite_group(options, tls_ciphersuite_group_t.default)
    }),
    Scenario(name: "group-compatibility-allowed", serverArguments: ["-tls1_2", "-cipher", "AES128-SHA"], reportsCipher: true, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_t.TLSv12)
        sec_protocol_options_append_tls_ciphersuite_group(options, tls_ciphersuite_group_t.compatibility)
    }),
    Scenario(name: "group-legacy-refused", serverArguments: [], reportsCipher: false, reportsLeaf: false, configure: { options in
        unauthenticated(options)
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_t.TLSv12)
        sec_protocol_options_append_tls_ciphersuite_group(options, tls_ciphersuite_group_t.legacy)
    }),
]

func pskServer(name: String, port: UInt16, clientKey: String, cipher: String = "ECDHE-PSK-AES128-CBC-SHA") -> String {
    let tls = NWProtocolTLS.Options()
    unauthenticated(tls.securityProtocolOptions)
    sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, tls_protocol_version_t.TLSv12)
    sec_protocol_options_add_pre_shared_key(tls.securityProtocolOptions, dispatchData("secret"), dispatchData("client"))
    let queue = DispatchQueue(label: "revenant.tlsoptions.psk.server")
    let accepted = Locked<[NWConnection]>([])
    let listener = try! NWListener(using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options()), on: NWEndpoint.Port(rawValue: port)!)
    listener.newConnectionHandler = { connection in
        accepted.withValue { $0.append(connection) }
        connection.start(queue: queue)
    }
    listener.start(queue: queue)
    usleep(500_000)
    let pipe = Pipe()
    let client = Process()
    client.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    client.arguments = ["timeout", "20", opensslPath, "s_client", "-connect", "127.0.0.1:\(port)", "-tls1_2",
                        "-cipher", cipher, "-psk", clientKey, "-psk_identity", "client"]
    client.standardInput = FileHandle.nullDevice
    client.standardOutput = pipe
    client.standardError = pipe
    try! client.run()
    let transcript = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    client.waitUntilExit()
    listener.cancel()
    let outcome = client.terminationStatus == 0 ? "ready" : "failed"
    if outcome != "ready" {
        FileHandle.standardError.write(Data("client log for \(name):\n\(transcript)\n".utf8))
    }
    return "\(name) \(outcome) cipher=\(cipherName(in: transcript))"
}

func cipherName(in transcript: String) -> String {
    guard let range = transcript.range(of: "cipher is ", options: .caseInsensitive) else {
        return "none"
    }
    return transcript[range.upperBound...].prefix { !$0.isNewline }.trimmingCharacters(in: .whitespaces)
}

for (index, scenario) in scenarios.enumerated() {
    let port = UInt16(14700 + index)
    let (process, transcript) = startServer(port: port, arguments: scenario.serverArguments)
    usleep(500_000)
    leafObservation.withValue { $0 = "unseen" }
    let outcome = settle(parameters(scenario.configure), port: port)
    Thread.sleep(forTimeInterval: 0.3)
    let log = transcript.withValue { $0 }
    if outcome != "ready" {
        FileHandle.standardError.write(Data("server log for \(scenario.name):\n\(log)\n".utf8))
    }
    process.terminate()
    process.waitUntilExit()
    var line = "\(scenario.name) \(outcome)"
    if scenario.reportsCipher {
        line += " cipher=\(cipherName(in: log))"
    }
    if scenario.reportsLeaf {
        line += " leaf=\(leafObservation.withValue { $0 })"
    }
    print(line)
}

print(pskServer(name: "psk-server", port: 14800, clientKey: "736563726574"))
print(pskServer(name: "psk-server-wrong-key", port: 14801, clientKey: "77726f6e67"))
print(pskServer(name: "psk-server-static-refused", port: 14802, clientKey: "736563726574", cipher: "PSK-AES128-CBC-SHA"))
