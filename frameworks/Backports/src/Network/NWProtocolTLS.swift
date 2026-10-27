@_implementationOnly import CBoringSSL
@_implementationOnly import CommonCrypto
import Foundation
import Security

public enum NWProtocolTLS {
    public final class Options: @unchecked Sendable {
        public let securityProtocolOptions: sec_protocol_options_t

        public init() {
            guard let created = RevenantSecProtocolOptionsCreate() else {
                preconditionFailure("RevenantSecProtocolOptions is not loaded; link the Security backport")
            }
            securityProtocolOptions = Unmanaged<AnyObject>.fromOpaque(created).takeRetainedValue() as! sec_protocol_options_t
        }
    }
}

extension NWProtocolTLS.Options {
    var hasServerCredentials: Bool {
        let configuration = NWTLSConfiguration(securityProtocolOptions, serverSide: false)
        return configuration.localIdentity != nil || !configuration.preSharedKeys.isEmpty
    }
}

struct NWTLSUnsupportedSetting: Error {
    let reason: String
    let status: OSStatus
}

private struct NWPreSharedKey {
    let key: [UInt8]
    let identity: [UInt8]
}

private func revenantCopyBytes(_ handle: UnsafeRawPointer, _ kind: Int32, _ index: Int) -> [UInt8] {
    let length = RevenantSecProtocolOptionsCopyData(handle, kind, index, nil, 0)
    var bytes = [UInt8](repeating: 0, count: length)
    _ = bytes.withUnsafeMutableBytes { RevenantSecProtocolOptionsCopyData(handle, kind, index, $0.baseAddress, $0.count) }
    return bytes
}

private let revenantTLS13Suites: [UInt16] = [0x1301, 0x1302, 0x1303]
private let revenantPFSSuites: [UInt16] = [0xC02C, 0xC02B, 0xCCA9, 0xC030, 0xC02F, 0xCCA8, 0xC00A, 0xC009, 0xC014, 0xC013]
private let revenantNonPFSSuites: [UInt16] = [0x009D, 0x009C, 0x0035, 0x002F]
private let revenantTLS10Suites: [UInt16] = [0xC009, 0xC00A, 0xC013, 0xC014, 0x0035, 0x002F]
private let revenantTLS10TripleDESSuites: [UInt16] = [0xC008, 0xC012, 0x000A]
private let revenantDHESuites: [UInt16] = [0x009F, 0x009E, 0x006B, 0x0067, 0x0039, 0x0033, 0x0016]

private let revenantCiphersuiteGroups: [UInt16: (name: String, suites: [UInt16])] = [
    0: ("default", revenantTLS13Suites + revenantPFSSuites),
    1: ("compatibility", revenantNonPFSSuites + revenantTLS10Suites + revenantTLS10TripleDESSuites),
    2: ("legacy", revenantDHESuites),
    3: ("ats", revenantTLS13Suites + revenantPFSSuites),
    4: ("ats_compatibility", revenantNonPFSSuites),
]

struct NWTLSConfiguration {
    let minimumVersion: UInt16
    let maximumVersion: UInt16
    let serverName: String?
    let applicationProtocols: [String]
    let peerAuthenticationRequired: Bool
    let localIdentity: SecIdentity?
    let ciphersuites: [UInt16]
    let ciphersuiteGroups: [UInt16]
    let ocspEnabled: Bool
    let sctEnabled: Bool
    let hasVerifyBlock: Bool
    let hasChallengeBlock: Bool
    fileprivate let preSharedKeys: [NWPreSharedKey]
    fileprivate let preSharedKeyHint: [UInt8]
    let unsupportedSetting: String?

    init(_ options: sec_protocol_options_t, serverSide: Bool) {
        let handle = Unmanaged.passUnretained(options as AnyObject).toOpaque()
        minimumVersion = RevenantSecProtocolOptionsMinTLS(handle)
        maximumVersion = RevenantSecProtocolOptionsMaxTLS(handle)
        serverName = RevenantSecProtocolOptionsServerName(handle).map { String(cString: $0) }
        applicationProtocols = (0..<RevenantSecProtocolOptionsApplicationProtocolCount(handle)).compactMap { index in
            RevenantSecProtocolOptionsApplicationProtocolAt(handle, index).map { String(cString: $0) }
        }
        peerAuthenticationRequired = RevenantSecProtocolOptionsPeerAuthenticationRequired(handle)
        localIdentity = RevenantSecProtocolOptionsCopyLocalIdentity(handle).map {
            Unmanaged<SecIdentity>.fromOpaque($0).takeRetainedValue()
        }
        ciphersuites = (0..<RevenantSecProtocolOptionsCiphersuiteCount(handle)).map { index in
            UInt16(truncatingIfNeeded: RevenantSecProtocolOptionsCiphersuiteAt(handle, index))
        }
        ciphersuiteGroups = (0..<RevenantSecProtocolOptionsCiphersuiteGroupCount(handle)).map { index in
            UInt16(truncatingIfNeeded: RevenantSecProtocolOptionsCiphersuiteGroupAt(handle, index))
        }
        ocspEnabled = RevenantSecProtocolOptionsOCSPEnabled(handle)
        sctEnabled = RevenantSecProtocolOptionsSCTEnabled(handle)
        hasVerifyBlock = RevenantSecProtocolOptionsHasVerifyBlock(handle)
        hasChallengeBlock = RevenantSecProtocolOptionsHasChallengeBlock(handle)
        preSharedKeys = (0..<RevenantSecProtocolOptionsPreSharedKeyCount(handle)).map { index in
            NWPreSharedKey(key: revenantCopyBytes(handle, 0, index), identity: revenantCopyBytes(handle, 1, index))
        }
        preSharedKeyHint = revenantCopyBytes(handle, 2, 0)
        unsupportedSetting = RevenantSecProtocolOptionsUnsupportedSetting(handle, serverSide).map { String(cString: $0) }
    }
}

enum NWTLSHandshake {
    case complete
    case wouldBlock
    case failed(OSStatus)
}

let revenantCertificateFailures: Set<OSStatus> = [-9807, -9812, -9813, -9814, -9815, -9825]

private let revenantCertificateChainInvalid: OSStatus = -9807
private let revenantPeerHandshakeFailed: OSStatus = -9824

private typealias NWRawSignFunction = @convention(c) (SecKey, Int32, UnsafePointer<UInt8>, Int, UnsafeMutablePointer<UInt8>, UnsafeMutablePointer<Int>) -> OSStatus

private let revenantRawSign: NWRawSignFunction? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "SecKeyRawSign").map {
    unsafeBitCast($0, to: NWRawSignFunction.self)
}

#if os(macOS)
@available(macOS 10.12, *)
private func revenantMessageAlgorithm(_ algorithm: UInt16) -> SecKeyAlgorithm? {
    switch algorithm {
    case 0x0201:
        return .rsaSignatureMessagePKCS1v15SHA1
    case 0x0401:
        return .rsaSignatureMessagePKCS1v15SHA256
    case 0x0501:
        return .rsaSignatureMessagePKCS1v15SHA384
    case 0x0601:
        return .rsaSignatureMessagePKCS1v15SHA512
    #if os(macOS)
    case 0x0804:
        return .rsaSignatureMessagePSSSHA256
    case 0x0805:
        return .rsaSignatureMessagePSSSHA384
    case 0x0806:
        return .rsaSignatureMessagePSSSHA512
    #endif
    default:
        return nil
    }
}
#endif

private func revenantDigestInfo(_ algorithm: UInt16, _ input: UnsafePointer<UInt8>, _ count: Int) -> [UInt8]? {
    switch algorithm {
    case 0x0201:
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1(input, CC_LONG(count), &digest)
        return [0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14] + digest
    case 0x0401:
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(input, CC_LONG(count), &digest)
        return [0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20] + digest
    case 0x0501:
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA384_DIGEST_LENGTH))
        CC_SHA384(input, CC_LONG(count), &digest)
        return [0x30, 0x41, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x02, 0x05, 0x00, 0x04, 0x30] + digest
    case 0x0601:
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        CC_SHA512(input, CC_LONG(count), &digest)
        return [0x30, 0x51, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03, 0x05, 0x00, 0x04, 0x40] + digest
    default:
        return nil
    }
}

private let revenantSignWithKey: @convention(c) (OpaquePointer?, UnsafeMutablePointer<UInt8>?, UnsafeMutablePointer<Int>?, Int, UInt16, UnsafePointer<UInt8>?, Int) -> ssl_private_key_result_t = { ssl, out, outLength, maxOut, algorithm, input, inputLength in
    guard let ssl, let session = SSL_get_ex_data(ssl, 0), let out, let outLength, let input else {
        return ssl_private_key_failure
    }
    return Unmanaged<NWTLSSession>.fromOpaque(session).takeUnretainedValue().sign(algorithm, input, inputLength, out, outLength, maxOut)
}

private let revenantPrivateKeyMethod: UnsafeMutablePointer<SSL_PRIVATE_KEY_METHOD> = {
    let method = UnsafeMutablePointer<SSL_PRIVATE_KEY_METHOD>.allocate(capacity: 1)
    method.initialize(to: SSL_PRIVATE_KEY_METHOD(sign: revenantSignWithKey, decrypt: nil, complete: nil))
    return method
}()

private final class ProtocolList {
    let storage: UnsafeMutablePointer<UInt8>
    let count: Int

    init(_ names: [String]) {
        var wire: [UInt8] = []
        for name in names {
            wire.append(UInt8(name.utf8.count))
            wire.append(contentsOf: name.utf8)
        }
        count = wire.count
        storage = UnsafeMutablePointer<UInt8>.allocate(capacity: max(count, 1))
        for (index, byte) in wire.enumerated() {
            storage[index] = byte
        }
    }

    deinit {
        storage.deallocate()
    }
}

private let revenantVerifyChain: @convention(c) (OpaquePointer?, UnsafeMutablePointer<UInt8>?) -> ssl_verify_result_t = { ssl, _ in
    guard let ssl, let session = SSL_get_ex_data(ssl, 0) else {
        return ssl_verify_invalid
    }
    return Unmanaged<NWTLSSession>.fromOpaque(session).takeUnretainedValue().verifyPeerChain(ssl)
}

private let revenantClientCertificate: @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Int32 = { ssl, _ in
    guard let ssl, let session = SSL_get_ex_data(ssl, 0) else {
        return 0
    }
    return Unmanaged<NWTLSSession>.fromOpaque(session).takeUnretainedValue().installClientIdentity() ? 1 : 0
}

private let revenantClientPreSharedKey: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, UnsafeMutablePointer<CChar>?, UInt32, UnsafeMutablePointer<UInt8>?, UInt32) -> UInt32 = { ssl, _, identity, maximumIdentity, key, maximumKey in
    guard let ssl, let session = SSL_get_ex_data(ssl, 0), let identity, let key else {
        return 0
    }
    return Unmanaged<NWTLSSession>.fromOpaque(session).takeUnretainedValue().clientPreSharedKey(identity, maximumIdentity, key, maximumKey)
}

private let revenantServerPreSharedKey: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, UnsafeMutablePointer<UInt8>?, UInt32) -> UInt32 = { ssl, identity, key, maximumKey in
    guard let ssl, let session = SSL_get_ex_data(ssl, 0), let identity, let key else {
        return 0
    }
    return Unmanaged<NWTLSSession>.fromOpaque(session).takeUnretainedValue().serverPreSharedKey(identity, key, maximumKey)
}

private let revenantSelectProtocol: @convention(c) (OpaquePointer?, UnsafeMutablePointer<UnsafePointer<UInt8>?>?, UnsafeMutablePointer<UInt8>?, UnsafePointer<UInt8>?, UInt32, UnsafeMutableRawPointer?) -> Int32 = { _, out, outLength, input, inputLength, argument in
    guard let out, let outLength, let input, let argument else {
        return SSL_TLSEXT_ERR_NOACK
    }
    let offered = Unmanaged<ProtocolList>.fromOpaque(argument).takeUnretainedValue()
    var selected: UnsafeMutablePointer<UInt8>?
    var selectedLength: UInt8 = 0
    guard SSL_select_next_proto(&selected, &selectedLength, offered.storage, UInt32(offered.count), input, inputLength) == OPENSSL_NPN_NEGOTIATED,
          let selected else {
        return SSL_TLSEXT_ERR_NOACK
    }
    out.pointee = UnsafePointer(selected)
    outLength.pointee = selectedLength
    return SSL_TLSEXT_ERR_OK
}

private func isIPAddress(_ name: String) -> Bool {
    var address = in6_addr()
    var version4 = in_addr()
    return inet_pton(AF_INET, name, &version4) == 1 || inet_pton(AF_INET6, name, &address) == 1
}

private var revenantSignaturePreferences: [UInt16] {
    #if os(macOS)
    return [0x0804, 0x0805, 0x0806, 0x0401, 0x0501, 0x0601, 0x0201]
    #else
    return [0x0401, 0x0501, 0x0601, 0x0201]
    #endif
}

final class NWTLSSession {
    private let options: sec_protocol_options_t
    private let context: OpaquePointer
    private let ssl: OpaquePointer
    private let serverSide: Bool
    private let serverName: String?
    private let alpnOffer: ProtocolList?
    private let localIdentity: SecIdentity?
    private let hasVerifyBlock: Bool
    private let hasChallengeBlock: Bool
    private let preSharedKeys: [NWPreSharedKey]
    private var signingKey: SecKey?
    private var verifyFailure: OSStatus?
    private(set) var isEstablished = false
    private(set) var wantsWrite = false

    init(descriptor: Int32, options: sec_protocol_options_t, defaultServerName: String?, serverSide: Bool) throws {
        let configuration = NWTLSConfiguration(options, serverSide: serverSide)
        if let reason = configuration.unsupportedSetting {
            throw NWTLSUnsupportedSetting(reason: reason, status: errSSLBadConfiguration)
        }
        let usesPreSharedKeys = !configuration.preSharedKeys.isEmpty
        if usesPreSharedKeys && (configuration.peerAuthenticationRequired || configuration.hasVerifyBlock) {
            throw NWTLSUnsupportedSetting(reason: "pre-shared keys need peer authentication turned off and no verify block: a PSK handshake has no certificate to check", status: errSSLBadConfiguration)
        }
        if usesPreSharedKeys && (!configuration.ciphersuites.isEmpty || !configuration.ciphersuiteGroups.isEmpty) {
            throw NWTLSUnsupportedSetting(reason: "pre-shared keys cannot be combined with a ciphersuite list or group: Apple ciphersuite values have no PSK suites", status: errSSLBadConfiguration)
        }
        let names = try NWTLSSession.cipherNames(configuration.ciphersuites, groups: configuration.ciphersuiteGroups, maximumVersion: configuration.maximumVersion)
        guard let method = TLS_method(), let context = SSL_CTX_new(method) else {
            throw NWTLSUnsupportedSetting(reason: "BoringSSL could not allocate a TLS context", status: errSSLInternal)
        }
        guard SSL_CTX_set_min_proto_version(context, configuration.minimumVersion) == 1,
              SSL_CTX_set_max_proto_version(context, configuration.maximumVersion) == 1 else {
            SSL_CTX_free(context)
            throw NWTLSUnsupportedSetting(reason: "BoringSSL rejected the TLS version range", status: errSSLProtocol)
        }
        if !names.isEmpty, SSL_CTX_set_strict_cipher_list(context, names.joined(separator: ":")) != 1 {
            SSL_CTX_free(context)
            throw NWTLSUnsupportedSetting(reason: "BoringSSL rejected the ciphersuite list", status: errSSLBadCipherSuite)
        }
        if usesPreSharedKeys, SSL_CTX_set_cipher_list(context, (["DEFAULT"] + NWTLSSession.preSharedKeyCipherNames + ["!kPSK"]).joined(separator: ":")) != 1 {
            SSL_CTX_free(context)
            throw NWTLSUnsupportedSetting(reason: "BoringSSL rejected the pre-shared key suites", status: errSSLBadCipherSuite)
        }
        let peerRequired = configuration.peerAuthenticationRequired
        let verifies = configuration.hasVerifyBlock
        let name = configuration.serverName ?? defaultServerName
        let offer = configuration.applicationProtocols.isEmpty ? nil : ProtocolList(configuration.applicationProtocols)

        var signing: SecKey?
        if serverSide {
            if let identity = configuration.localIdentity {
                guard NWTLSSession.installCertificate(identity, into: context),
                      let key = NWTLSSession.privateKey(of: identity) else {
                    SSL_CTX_free(context)
                    throw NWTLSUnsupportedSetting(reason: "the server identity has no usable private key", status: errSSLBadConfiguration)
                }
                signing = key
                SSL_CTX_set_private_key_method(context, revenantPrivateKeyMethod)
                var preferences = revenantSignaturePreferences
                SSL_CTX_set_signing_algorithm_prefs(context, &preferences, preferences.count)
            } else if configuration.preSharedKeys.isEmpty {
                SSL_CTX_free(context)
                throw NWTLSUnsupportedSetting(reason: "a server needs a local identity or a pre-shared key", status: errSSLBadConfiguration)
            }
            if peerRequired || verifies {
                let mode = peerRequired ? SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT : SSL_VERIFY_PEER
                SSL_CTX_set_custom_verify(context, mode, revenantVerifyChain)
            }
            if let offer {
                SSL_CTX_set_alpn_select_cb(context, revenantSelectProtocol, Unmanaged.passUnretained(offer).toOpaque())
            }
        } else {
            SSL_CTX_set_cert_cb(context, revenantClientCertificate, nil)
            if peerRequired || verifies {
                SSL_CTX_set_custom_verify(context, SSL_VERIFY_PEER, revenantVerifyChain)
            }
        }

        if usesPreSharedKeys {
            if serverSide {
                SSL_CTX_set_psk_server_callback(context, revenantServerPreSharedKey)
                if !configuration.preSharedKeyHint.isEmpty {
                    var hint = configuration.preSharedKeyHint.map { CChar(bitPattern: $0) }
                    hint.append(0)
                    SSL_CTX_use_psk_identity_hint(context, hint)
                }
            } else {
                SSL_CTX_set_psk_client_callback(context, revenantClientPreSharedKey)
            }
        }
        guard let ssl = SSL_new(context) else {
            SSL_CTX_free(context)
            throw NWTLSUnsupportedSetting(reason: "BoringSSL could not allocate a TLS session", status: errSSLInternal)
        }
        self.options = options
        self.context = context
        self.ssl = ssl
        self.serverSide = serverSide
        self.signingKey = signing
        self.localIdentity = configuration.localIdentity
        self.hasVerifyBlock = verifies
        self.hasChallengeBlock = configuration.hasChallengeBlock
        self.preSharedKeys = configuration.preSharedKeys
        self.serverName = serverSide ? nil : name
        self.alpnOffer = serverSide ? offer : nil
        SSL_set_fd(ssl, descriptor)
        if serverSide {
            SSL_set_accept_state(ssl)
        } else {
            SSL_set_connect_state(ssl)
        }
        SSL_set_ex_data(ssl, 0, Unmanaged.passUnretained(self).toOpaque())

        if !serverSide {
            if let name, !isIPAddress(name) {
                SSL_set_tlsext_host_name(ssl, name)
            }
            if let offer {
                SSL_set_alpn_protos(ssl, offer.storage, offer.count)
            }
            if configuration.ocspEnabled {
                SSL_enable_ocsp_stapling(ssl)
            }
            if configuration.sctEnabled {
                SSL_enable_signed_cert_timestamps(ssl)
            }
        }
    }

    deinit {
        SSL_free(ssl)
        SSL_CTX_free(context)
    }

    private var optionsHandle: UnsafeRawPointer {
        UnsafeRawPointer(Unmanaged.passUnretained(options as AnyObject).toOpaque())
    }

    var negotiatedApplicationProtocol: String? {
        var data: UnsafePointer<UInt8>?
        var length: UInt32 = 0
        SSL_get0_alpn_selected(ssl, &data, &length)
        guard let data, length > 0 else {
            return nil
        }
        return String(decoding: UnsafeBufferPointer(start: data, count: Int(length)), as: UTF8.self)
    }

    var negotiatedVersion: UInt16? {
        isEstablished ? UInt16(truncatingIfNeeded: SSL_version(ssl)) : nil
    }

    func handshake() -> NWTLSHandshake {
        wantsWrite = false
        let result = SSL_do_handshake(ssl)
        if result == 1 {
            isEstablished = true
            return .complete
        }
        switch SSL_get_error(ssl, result) {
        case SSL_ERROR_WANT_READ:
            return .wouldBlock
        case SSL_ERROR_WANT_WRITE:
            wantsWrite = true
            return .wouldBlock
        default:
            return .failed(verifyFailure ?? NWTLSSession.peerFailure())
        }
    }

    fileprivate func clientPreSharedKey(_ identity: UnsafeMutablePointer<CChar>, _ maximumIdentity: UInt32,
                                        _ key: UnsafeMutablePointer<UInt8>, _ maximumKey: UInt32) -> UInt32 {
        guard let entry = preSharedKeys.first, entry.identity.count < Int(maximumIdentity), entry.key.count <= Int(maximumKey) else {
            return 0
        }
        for (index, byte) in entry.identity.enumerated() {
            identity[index] = CChar(bitPattern: byte)
        }
        identity[entry.identity.count] = 0
        entry.key.withUnsafeBufferPointer { key.update(from: $0.baseAddress!, count: entry.key.count) }
        return UInt32(entry.key.count)
    }

    fileprivate func serverPreSharedKey(_ identity: UnsafePointer<CChar>, _ key: UnsafeMutablePointer<UInt8>, _ maximumKey: UInt32) -> UInt32 {
        let given = Array(UnsafeRawBufferPointer(start: identity, count: strlen(identity)))
        guard let entry = preSharedKeys.first(where: { $0.identity == given }), entry.key.count <= Int(maximumKey) else {
            return 0
        }
        entry.key.withUnsafeBufferPointer { key.update(from: $0.baseAddress!, count: entry.key.count) }
        return UInt32(entry.key.count)
    }

    private static func peerFailure() -> OSStatus {
        let reason = ERR_GET_REASON(ERR_peek_error())
        ERR_clear_error()
        switch reason {
        case SSL_R_NO_SHARED_CIPHER:
            return errSSLNegotiation
        case SSL_R_NO_CIPHER_MATCH, SSL_R_NO_CIPHERS_AVAILABLE:
            return errSSLBadCipherSuite
        case SSL_R_SSLV3_ALERT_BAD_CERTIFICATE:
            return errSSLPeerBadCert
        case SSL_R_SSLV3_ALERT_CERTIFICATE_UNKNOWN:
            return errSSLPeerCertUnknown
        case SSL_R_TLSV1_ALERT_UNKNOWN_CA:
            return errSSLPeerUnknownCA
        case SSL_R_SSLV3_ALERT_ILLEGAL_PARAMETER:
            return errSSLIllegalParam
        case SSL_R_SSLV3_ALERT_BAD_RECORD_MAC:
            return errSSLBadRecordMac
        case SSL_R_TLSV1_ALERT_PROTOCOL_VERSION:
            return errSSLPeerProtocolVersion
        default:
            return revenantPeerHandshakeFailed
        }
    }

    func read(_ buffer: UnsafeMutableRawPointer, _ count: Int) -> (count: Int, status: OSStatus) {
        let result = SSL_read(ssl, buffer, Int32(clamping: count))
        if result > 0 {
            return (Int(result), noErr)
        }
        return (0, status(for: result))
    }

    func write(_ bytes: UnsafeRawPointer, _ count: Int) -> (count: Int, status: OSStatus) {
        let result = SSL_write(ssl, bytes, Int32(clamping: count))
        if result > 0 {
            return (Int(result), noErr)
        }
        return (0, status(for: result))
    }

    func close() {
        SSL_shutdown(ssl)
        isEstablished = false
    }

    fileprivate func verifyPeerChain(_ ssl: OpaquePointer) -> ssl_verify_result_t {
        guard let chain = SSL_get_peer_full_cert_chain(ssl) else {
            verifyFailure = revenantCertificateChainInvalid
            return ssl_verify_invalid
        }
        var certificates: [SecCertificate] = []
        for index in 0..<sk_X509_num(chain) {
            guard let x509 = sk_X509_value(chain, index) else {
                verifyFailure = revenantCertificateChainInvalid
                return ssl_verify_invalid
            }
            var der: UnsafeMutablePointer<UInt8>?
            let length = i2d_X509(x509, &der)
            guard length > 0, let der else {
                verifyFailure = revenantCertificateChainInvalid
                return ssl_verify_invalid
            }
            let data = Data(bytes: der, count: Int(length))
            OPENSSL_free(der)
            guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
                verifyFailure = revenantCertificateChainInvalid
                return ssl_verify_invalid
            }
            certificates.append(certificate)
        }
        let policy = SecPolicyCreateSSL(!serverSide, serverName as CFString?)
        var trust: SecTrust?
        guard !certificates.isEmpty, SecTrustCreateWithCertificates(certificates as CFArray, policy, &trust) == errSecSuccess,
              let trust else {
            verifyFailure = revenantCertificateChainInvalid
            return ssl_verify_invalid
        }
        if hasVerifyBlock {
            guard RevenantSecProtocolOptionsVerifyTrust(optionsHandle, Unmanaged.passUnretained(trust).toOpaque()) else {
                verifyFailure = revenantCertificateChainInvalid
                return ssl_verify_invalid
            }
            return ssl_verify_ok
        }
        var result = SecTrustResultType.invalid
        guard SecTrustEvaluate(trust, &result) == errSecSuccess, result == .proceed || result == .unspecified else {
            verifyFailure = revenantCertificateChainInvalid
            return ssl_verify_invalid
        }
        return ssl_verify_ok
    }

    fileprivate func installClientIdentity() -> Bool {
        guard let identity = challengedIdentity() ?? localIdentity else {
            return true
        }
        guard let key = NWTLSSession.privateKey(of: identity), let certificate = NWTLSSession.certificate(of: identity) else {
            return false
        }
        defer {
            X509_free(certificate)
        }
        guard SSL_use_certificate(ssl, certificate) == 1 else {
            return false
        }
        signingKey = key
        SSL_set_private_key_method(ssl, revenantPrivateKeyMethod)
        var preferences = revenantSignaturePreferences
        SSL_set_signing_algorithm_prefs(ssl, &preferences, preferences.count)
        return true
    }

    private func challengedIdentity() -> SecIdentity? {
        guard hasChallengeBlock, let raw = RevenantSecProtocolOptionsCopyChallengeIdentity(optionsHandle) else {
            return nil
        }
        return Unmanaged<SecIdentity>.fromOpaque(raw).takeRetainedValue()
    }

    private func status(for result: Int32) -> OSStatus {
        switch SSL_get_error(ssl, result) {
        case SSL_ERROR_WANT_READ:
            return errSSLWouldBlock
        case SSL_ERROR_WANT_WRITE:
            wantsWrite = true
            return errSSLWouldBlock
        case SSL_ERROR_ZERO_RETURN:
            return errSSLClosedGraceful
        default:
            return errSSLClosedAbort
        }
    }

    fileprivate static let preSharedKeyCipherNames = ["ECDHE-PSK-AES128-CBC-SHA", "ECDHE-PSK-AES256-CBC-SHA", "ECDHE-PSK-CHACHA20-POLY1305"]

    private static func cipherNames(_ suites: [UInt16], groups: [UInt16], maximumVersion: UInt16) throws -> [String] {
        var requested: [UInt16] = []
        for group in groups {
            guard let entry = revenantCiphersuiteGroups[group] else {
                throw NWTLSUnsupportedSetting(reason: "ciphersuite group \(group) is refused: its suite list is not in the Apple Security source", status: errSSLBadCipherSuite)
            }
            let known = entry.suites.filter { SSL_get_cipher_by_value($0) != nil }
            let dropped = entry.suites.filter { SSL_get_cipher_by_value($0) == nil }
            guard !known.isEmpty else {
                throw NWTLSUnsupportedSetting(reason: "ciphersuite group \(entry.name) has no suite BoringSSL supports", status: errSSLBadCipherSuite)
            }
            if !dropped.isEmpty {
                let ids = dropped.map { "0x" + String($0, radix: 16) }.joined(separator: ", ")
                fputs("Network: ciphersuite group \(entry.name) drops \(ids), which BoringSSL lacks\n", stderr)
            }
            requested += known
        }
        requested += suites
        var names: [String] = []
        var seen = Set<UInt16>()
        for suite in requested where seen.insert(suite).inserted {
            guard let cipher = SSL_get_cipher_by_value(suite), let name = SSL_CIPHER_get_name(cipher) else {
                throw NWTLSUnsupportedSetting(reason: "ciphersuite 0x\(String(suite, radix: 16)) is unknown to BoringSSL", status: errSSLBadCipherSuite)
            }
            if (0x1301...0x1305).contains(suite) {
                continue
            }
            names.append(String(cString: name))
        }
        if names.isEmpty && !requested.isEmpty && maximumVersion < 0x0304 {
            throw NWTLSUnsupportedSetting(reason: "only TLS 1.3 ciphersuites are listed, but the maximum is TLS 1.2: list a TLS 1.2 ciphersuite too", status: errSSLBadCipherSuite)
        }
        return names
    }

    private static func installCertificate(_ identity: SecIdentity, into context: OpaquePointer) -> Bool {
        guard let certificate = certificate(of: identity) else {
            return false
        }
        defer {
            X509_free(certificate)
        }
        return SSL_CTX_use_certificate(context, certificate) == 1
    }

    private static func certificate(of identity: SecIdentity) -> OpaquePointer? {
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else {
            return nil
        }
        let certificateData = SecCertificateCopyData(certificate) as Data
        return certificateData.withUnsafeBytes { raw -> OpaquePointer? in
            var pointer = raw.bindMemory(to: UInt8.self).baseAddress
            return d2i_X509(nil, &pointer, raw.count)
        }
    }

    private static func privateKey(of identity: SecIdentity) -> SecKey? {
        var key: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &key) == errSecSuccess else {
            return nil
        }
        return key
    }

    fileprivate func sign(_ algorithm: UInt16, _ input: UnsafePointer<UInt8>, _ inputLength: Int,
                          _ out: UnsafeMutablePointer<UInt8>, _ outLength: UnsafeMutablePointer<Int>, _ maxOut: Int) -> ssl_private_key_result_t {
        guard let key = signingKey else {
            return ssl_private_key_failure
        }
        let signature: Data
        #if os(macOS)
        guard #available(macOS 10.12, *), let message = revenantMessageAlgorithm(algorithm),
              let data = SecKeyCreateSignature(key, message, Data(bytes: input, count: inputLength) as CFData, nil) as Data? else {
            return ssl_private_key_failure
        }
        signature = data
        #else
        guard let rawSign = revenantRawSign, let info = revenantDigestInfo(algorithm, input, inputLength) else {
            return ssl_private_key_failure
        }
        let size = SecKeyGetBlockSize(key)
        var buffer = [UInt8](repeating: 0, count: size)
        var length = size
        let status = info.withUnsafeBufferPointer { digest in
            buffer.withUnsafeMutableBufferPointer { output in
                rawSign(key, 1, digest.baseAddress!, digest.count, output.baseAddress!, &length)
            }
        }
        guard status == errSecSuccess else {
            return ssl_private_key_failure
        }
        signature = Data(buffer.prefix(length))
        #endif
        guard signature.count <= maxOut else {
            return ssl_private_key_failure
        }
        signature.copyBytes(to: out, count: signature.count)
        outLength.pointee = signature.count
        return ssl_private_key_success
    }
}
