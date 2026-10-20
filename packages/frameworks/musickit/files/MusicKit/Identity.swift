import Foundation

@frozen public struct MusicItemID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

extension MusicItemID: CustomStringConvertible {
    public var description: String { rawValue }
}

public protocol MusicItem: Sendable {
    var id: MusicItemID { get }
}

public struct MusicAuthorization {

    public enum Status: String, Sendable {
        case notDetermined
        case denied
        case restricted
        case authorized

        public init?(rawValue: String) {
            switch rawValue {
            case "notDetermined": self = .notDetermined
            case "denied": self = .denied
            case "restricted": self = .restricted
            case "authorized": self = .authorized
            default: return nil
            }
        }
    }

    public static var currentStatus: Status { .notDetermined }

    public static func request() async -> Status { .denied }
}

extension MusicAuthorization.Status: CustomStringConvertible {
    public var description: String { rawValue }
}
