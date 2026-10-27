@_implementationOnly import RevenantTLS
import Foundation
import Security

public enum NWProtocolTLS {
    public final class Options: @unchecked Sendable {
        public let securityProtocolOptions: sec_protocol_options_t

        public init() {
            guard let created = RevenantTLSOptionsCreate() else {
                preconditionFailure("RevenantSecProtocolOptions is not loaded; link the Network backport")
            }
            securityProtocolOptions = Unmanaged<AnyObject>.fromOpaque(created).takeRetainedValue() as! sec_protocol_options_t
        }
    }
}

extension NWProtocolTLS.Options {
    var hasServerCredentials: Bool {
        RevenantTLSOptionsHasServerCredentials(UnsafeRawPointer(Unmanaged.passUnretained(securityProtocolOptions as AnyObject).toOpaque()))
    }
}

struct NWTLSUnsupportedSetting: Error {
    let reason: String
    let status: OSStatus
}

enum NWTLSHandshake {
    case complete
    case wouldBlock
    case failed(OSStatus)
}

let revenantCertificateFailures: Set<OSStatus> = [-9807, -9812, -9813, -9814, -9815, -9825]

final class NWTLSSession {
    private let engine: OpaquePointer

    init(descriptor: Int32, options: sec_protocol_options_t, defaultServerName: String?, serverSide: Bool) throws {
        var reason = [CChar](repeating: 0, count: 512)
        var status: OSStatus = errSSLInternal
        let handle = UnsafeRawPointer(Unmanaged.passUnretained(options as AnyObject).toOpaque())
        let created = reason.withUnsafeMutableBufferPointer { buffer in
            RevenantTLSEngineCreate(handle, descriptor, defaultServerName, serverSide, buffer.baseAddress, buffer.count, &status)
        }
        guard let created else {
            throw NWTLSUnsupportedSetting(reason: String(cString: reason), status: status)
        }
        engine = created
    }

    deinit {
        RevenantTLSEngineFree(engine)
    }

    var isEstablished: Bool {
        RevenantTLSEngineIsEstablished(engine)
    }

    var wantsWrite: Bool {
        RevenantTLSEngineWantsWrite(engine)
    }

    var negotiatedApplicationProtocol: String? {
        var length = 0
        guard let data = RevenantTLSEngineNegotiatedProtocol(engine, &length), length > 0 else {
            return nil
        }
        return String(decoding: UnsafeBufferPointer(start: data, count: length), as: UTF8.self)
    }

    var negotiatedVersion: UInt16? {
        let version = RevenantTLSEngineNegotiatedVersion(engine)
        return version == 0 ? nil : version
    }

    var negotiatedCipherSuite: UInt16? {
        let suite = RevenantTLSEngineNegotiatedCipherSuite(engine)
        return suite == 0 ? nil : suite
    }

    func handshake() -> NWTLSHandshake {
        let status = RevenantTLSEngineHandshake(engine)
        switch status {
        case noErr:
            return .complete
        case errSSLWouldBlock:
            return .wouldBlock
        default:
            return .failed(status)
        }
    }

    func read(_ buffer: UnsafeMutableRawPointer, _ count: Int) -> (count: Int, status: OSStatus) {
        var length = 0
        let status = RevenantTLSEngineRead(engine, buffer, count, &length)
        return (length, status)
    }

    func write(_ bytes: UnsafeRawPointer, _ count: Int) -> (count: Int, status: OSStatus) {
        var length = 0
        let status = RevenantTLSEngineWrite(engine, bytes, count, &length)
        return (length, status)
    }

    func close() {
        RevenantTLSEngineClose(engine)
    }
}
