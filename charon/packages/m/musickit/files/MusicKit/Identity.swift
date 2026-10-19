// The identity every catalogue item has, and the authorization a client asks for.
//
// The declarations are transcribed from MusicKit.swiftinterface of the 16.4 SDK, which is the SDK
// the port's corpus measures against, and what each answers is written down in the package's README.
//
// MusicAuthorization is the one part of MusicKit this port can answer without a service, and it is
// answered as a device with no Apple Music at all: every device this port runs on has no Apple Music
// account, no Music app, and no way to grant one. So `currentStatus` is `.notDetermined` until a
// caller asks, and a request answers `.denied` - the status a device that will not grant says. That is
// the whole of what a device without Apple Music can say, and it is a real answer rather than a
// refusal: a caller that checks the status before it plays gets a decision it can act on.

// Built for armv7-apple-ios6.1.3 - the port's own release, and the minimum the port's Swift standard
// library declares for itself. See README.md: the store holds two builds of swift 6.4.0 and only the
// patched one reaches it, which is why the recipe takes its compiler from swift-runtime and not from
// a path.

import Foundation

/// The identifier every MusicKit item has: the catalogue's own string for it.
@frozen public struct MusicItemID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

extension MusicItemID: CustomStringConvertible {
    public var description: String { rawValue }
}

/// What every item of the catalogue has in common: its identifier, and nothing else.
///
/// A value the catalogue fills in, and one an application cannot make: an item is what the service
/// says it is, and an item made here would be a thing in the catalogue that is not in it.
public protocol MusicItem: Sendable {
    var id: MusicItemID { get }
}

/// Whether this application may use the catalogue and the user's library.
public struct MusicAuthorization {

    /// The four states the status has. The names and the raw values are the ones the interface gives.
    public enum Status: String, Sendable {
        case notDetermined
        case denied
        case restricted
        case authorized

        public init?(rawValue: String) {
            // The interface's own spelling is the failable one, and a case that is not one of the
            // four is not a status: the raw values are the four case names and nothing else.
            switch rawValue {
            case "notDetermined": self = .notDetermined
            case "denied": self = .denied
            case "restricted": self = .restricted
            case "authorized": self = .authorized
            default: return nil
            }
        }
    }

    /// The status as it stands, without asking for anything.
    ///
    /// A device with no Apple Music has not been asked, so this is `.notDetermined` — which is what the
    /// status is before anybody asks, and not a failure.
    public static var currentStatus: Status { .notDetermined }

    /// Ask for the authorization, and answer what the device grants.
    ///
    /// On this port the answer is `.denied`, and it is a real answer rather than a refusal: there is
    /// no Apple Music on the device to grant from, and the status a device that will not grant says
    /// is `.denied`. The call does not fail and does not block.
    public static func request() async -> Status { .denied }
}

extension MusicAuthorization.Status: CustomStringConvertible {
    public var description: String { rawValue }
}
