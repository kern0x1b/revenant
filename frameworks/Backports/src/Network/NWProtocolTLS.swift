import Darwin
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

private let revenantDefaultSymbols = UnsafeMutableRawPointer(bitPattern: -2)
private let revenantServerAuthCompleted: OSStatus = -9841
let revenantCertificateFailures: Set<OSStatus> = [-9807, -9812, -9813, -9814, -9815, -9825]

private typealias NWSetALPNFunction = @convention(c) (SSLContext, CFArray) -> OSStatus

private func revenantSymbol<T>(_ name: String, as type: T.Type) -> T? {
    guard let symbol = dlsym(revenantDefaultSymbols, name) else {
        return nil
    }
    return unsafeBitCast(symbol, to: type)
}

private let revenantReadFunction: SSLReadFunc = { connection, data, length in
    Unmanaged<NWTLSSession>.fromOpaque(connection).takeUnretainedValue().readRaw(data, length)
}

private let revenantWriteFunction: SSLWriteFunc = { connection, data, length in
    Unmanaged<NWTLSSession>.fromOpaque(connection).takeUnretainedValue().writeRaw(data, length)
}

final class NWTLSSession {
    private let context: SSLContext
    private let descriptor: Int32
    private let peerAuthenticationRequired: Bool
    private(set) var isEstablished = false
    private(set) var wantsWrite = false

    init?(descriptor: Int32, options: NWProtocolTLS.SecurityProtocolOptions, defaultServerName: String?, serverSide: Bool) {
        guard let context = SSLCreateContext(kCFAllocatorDefault, serverSide ? .serverSide : .clientSide, .streamType) else {
            return nil
        }
        self.context = context
        self.descriptor = descriptor
        self.peerAuthenticationRequired = options.peerAuthenticationRequired
        SSLSetIOFuncs(context, revenantReadFunction, revenantWriteFunction)
        SSLSetConnection(context, Unmanaged.passUnretained(self).toOpaque())
        if serverSide {
            if let identity = options.localIdentity {
                SSLSetCertificate(context, [identity] as CFArray)
            }
        } else if let name = options.serverName ?? defaultServerName {
            SSLSetPeerDomainName(context, name, name.utf8.count)
        }
        if !options.applicationProtocols.isEmpty, let setALPN = revenantSymbol("SSLSetALPNProtocols", as: NWSetALPNFunction.self) {
            _ = setALPN(context, options.applicationProtocols as CFArray)
        }
        if !serverSide && !options.peerAuthenticationRequired {
            SSLSetSessionOption(context, .breakOnServerAuth, true)
        }
    }

    func handshake() -> NWTLSHandshake {
        while true {
            wantsWrite = false
            let status = SSLHandshake(context)
            switch status {
            case noErr:
                isEstablished = true
                return .complete
            case errSSLWouldBlock:
                return .wouldBlock
            case revenantServerAuthCompleted where !peerAuthenticationRequired:
                continue
            default:
                return .failed(status)
            }
        }
    }

    func read(_ buffer: UnsafeMutableRawPointer, _ count: Int) -> (count: Int, status: OSStatus) {
        var processed = 0
        let status = SSLRead(context, buffer, count, &processed)
        return (processed, status)
    }

    func write(_ bytes: UnsafeRawPointer, _ count: Int) -> (count: Int, status: OSStatus) {
        var processed = 0
        let status = SSLWrite(context, bytes, count, &processed)
        return (processed, status)
    }

    func close() {
        SSLClose(context)
        isEstablished = false
    }

    fileprivate func readRaw(_ data: UnsafeMutableRawPointer, _ length: UnsafeMutablePointer<Int>) -> OSStatus {
        let requested = length.pointee
        let count = recv(descriptor, data, requested, 0)
        if count > 0 {
            length.pointee = count
            return noErr
        }
        length.pointee = 0
        if count == 0 {
            return errSSLClosedGraceful
        }
        return errno == EAGAIN ? errSSLWouldBlock : errSSLClosedAbort
    }

    fileprivate func writeRaw(_ data: UnsafeRawPointer, _ length: UnsafeMutablePointer<Int>) -> OSStatus {
        let requested = length.pointee
        let count = send(descriptor, data, requested, 0)
        if count >= 0 {
            length.pointee = count
            return noErr
        }
        length.pointee = 0
        if errno == EAGAIN {
            wantsWrite = true
            return errSSLWouldBlock
        }
        return errSSLClosedAbort
    }
}
