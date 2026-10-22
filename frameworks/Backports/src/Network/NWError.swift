import Foundation

public enum NWError: Error, Equatable, CustomDebugStringConvertible {
    case posix(POSIXErrorCode)
    case dns(Int32)
    case tls(OSStatus)

    public var debugDescription: String {
        switch self {
        case .posix(let code):
            return "NWError.posix(\(code.rawValue))"
        case .dns(let code):
            return "NWError.dns(\(code))"
        case .tls(let status):
            return "NWError.tls(\(status))"
        }
    }

    static func posix(errno code: Int32) -> NWError {
        .posix(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
}

public struct NWParameters: Sendable {
    enum Transport: Sendable {
        case tcp
        case udp
    }

    let transport: Transport
    public var allowLocalEndpointReuse = false

    private init(transport: Transport) {
        self.transport = transport
    }

    public static var tcp: NWParameters {
        NWParameters(transport: .tcp)
    }

    public static var udp: NWParameters {
        NWParameters(transport: .udp)
    }
}
