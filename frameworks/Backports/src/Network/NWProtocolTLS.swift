@_implementationOnly import CBoringSSL
@_implementationOnly import CommonCrypto
import Foundation
import Security

public enum NWProtocolTLS {
    public final class SecurityProtocolOptions: @unchecked Sendable {
        public var serverName: String?
        public var applicationProtocols: [String] = []
        public var peerAuthenticationRequired = true
        public var localIdentity: SecIdentity?

        public init() {}
    }

    public final class Options: @unchecked Sendable {
        public let securityProtocolOptions = SecurityProtocolOptions()

        public init() {}
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

@available(iOS 10.0, macOS 10.12, *)
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
    case 0x0804:
        return .rsaSignatureMessagePSSSHA256
    case 0x0805:
        return .rsaSignatureMessagePSSSHA384
    case 0x0806:
        return .rsaSignatureMessagePSSSHA512
    default:
        return nil
    }
}

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

final class NWTLSSession {
    private let context: OpaquePointer
    private let ssl: OpaquePointer
    private let serverSide: Bool
    private let serverName: String?
    private let alpnOffer: ProtocolList?
    private let signingKey: SecKey?
    private var verifyFailure: OSStatus?
    private(set) var isEstablished = false
    private(set) var wantsWrite = false

    init?(descriptor: Int32, options: NWProtocolTLS.SecurityProtocolOptions, defaultServerName: String?, serverSide: Bool) {
        guard let method = TLS_method(), let context = SSL_CTX_new(method) else {
            return nil
        }
        SSL_CTX_set_min_proto_version(context, UInt16(TLS1_2_VERSION))
        let peerRequired = options.peerAuthenticationRequired
        let name = options.serverName ?? defaultServerName
        let offer = options.applicationProtocols.isEmpty ? nil : ProtocolList(options.applicationProtocols)

        var signing: SecKey?
        if serverSide {
            guard let identity = options.localIdentity, NWTLSSession.installCertificate(identity, into: context),
                  let key = NWTLSSession.privateKey(of: identity) else {
                SSL_CTX_free(context)
                return nil
            }
            signing = key
            SSL_CTX_set_private_key_method(context, revenantPrivateKeyMethod)
            #if os(macOS)
            var preferences: [UInt16] = [0x0804, 0x0805, 0x0806, 0x0401, 0x0501, 0x0601, 0x0201]
            #else
            var preferences: [UInt16] = [0x0401, 0x0501, 0x0601, 0x0201]
            SSL_CTX_set_max_proto_version(context, UInt16(TLS1_2_VERSION))
            #endif
            SSL_CTX_set_signing_algorithm_prefs(context, &preferences, preferences.count)
            var mode = SSL_VERIFY_NONE
            if peerRequired {
                mode = SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT
            }
            if peerRequired {
                SSL_CTX_set_custom_verify(context, mode, revenantVerifyChain)
            }
            if let offer {
                SSL_CTX_set_alpn_select_cb(context, revenantSelectProtocol, Unmanaged.passUnretained(offer).toOpaque())
            }
        } else if peerRequired {
            SSL_CTX_set_custom_verify(context, SSL_VERIFY_PEER, revenantVerifyChain)
        }

        guard let ssl = SSL_new(context) else {
            SSL_CTX_free(context)
            return nil
        }
        self.context = context
        self.ssl = ssl
        self.serverSide = serverSide
        self.signingKey = signing
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
        }
    }

    deinit {
        SSL_free(ssl)
        SSL_CTX_free(context)
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
            return .failed(verifyFailure ?? revenantPeerHandshakeFailed)
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
        guard let chain = SSL_get0_peer_certificates(ssl) else {
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
        var result = SecTrustResultType.invalid
        guard !certificates.isEmpty, SecTrustCreateWithCertificates(certificates as CFArray, policy, &trust) == errSecSuccess,
              let trust, SecTrustEvaluate(trust, &result) == errSecSuccess,
              result == .proceed || result == .unspecified else {
            verifyFailure = revenantCertificateChainInvalid
            return ssl_verify_invalid
        }
        return ssl_verify_ok
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

    private static func installCertificate(_ identity: SecIdentity, into context: OpaquePointer) -> Bool {
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else {
            return false
        }
        let certificateData = SecCertificateCopyData(certificate) as Data
        guard let x509 = certificateData.withUnsafeBytes({ raw -> OpaquePointer? in
            var pointer = raw.bindMemory(to: UInt8.self).baseAddress
            return d2i_X509(nil, &pointer, raw.count)
        }) else {
            return false
        }
        defer {
            X509_free(x509)
        }
        return SSL_CTX_use_certificate(context, x509) == 1
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
