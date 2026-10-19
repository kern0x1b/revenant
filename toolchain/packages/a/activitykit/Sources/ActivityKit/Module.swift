import Foundation
#if REVENANT_CARRIES_LOCALIZED_STRING
import AppIntents
#endif

public protocol ActivityAttributes: Decodable, Encodable {
    associatedtype ContentState: Decodable, Encodable, Hashable
}

public enum ActivityStyle: Hashable, Sendable {
    case standard
    case transient
}

public enum ActivityState: Sendable, Codable, Hashable, CustomStringConvertible {
    case pending
    case active
    case ended
    case dismissed
    case stale

    public var description: String {
        switch self {
        case .pending: return "pending"
        case .active: return "active"
        case .ended: return "ended"
        case .dismissed: return "dismissed"
        case .stale: return "stale"
        }
    }

    public static func == (a: ActivityState, b: ActivityState) -> Bool { return a.description == b.description }
}

public struct ActivityContent<State>: Sendable where State: Decodable, State: Encodable, State: Hashable {
    public let state: State
    public let staleDate: Date?
    public let relevanceScore: Double

    public var description: String {
        return "ActivityContent(state: \(state), staleDate: \(staleDate.map { "\($0)" } ?? "nil"), relevanceScore: \(relevanceScore))"
    }

    public init(state: State, staleDate: Date?, relevanceScore: Double = 0.0) {
        self.state = state
        self.staleDate = staleDate
        self.relevanceScore = relevanceScore < 0 ? 0 : (relevanceScore > 1 ? 1 : relevanceScore)
    }
}

public struct PushType: Equatable, Sendable {
    private let name: String

    private init(_ name: String) {
        self.name = name
    }

    public static var token: PushType { return PushType("token") }

    public static func channel(_ name: String) -> PushType { return PushType(name) }

    public static func == (a: PushType, b: PushType) -> Bool { return a.name == b.name }
}

public struct AlertConfiguration: Equatable, Sendable {
    public struct AlertSound: Equatable, Sendable {
        private let name: String?

        private init(_ name: String?) {
            self.name = name
        }

        public static var `default`: AlertSound { return AlertSound(nil) }

        public static func named(_ name: String) -> AlertSound { return AlertSound(name) }

        public static func == (a: AlertSound, b: AlertSound) -> Bool { return a.name == b.name }
    }

    public var title: LocalizedStringResource
    public var body: LocalizedStringResource

    public var sound: AlertSound

    public init(title: LocalizedStringResource, body: LocalizedStringResource, sound: AlertSound) {
        self.title = title
        self.body = body
        self.sound = sound
    }
}

public struct ActivityUIDismissalPolicy: Equatable, Sendable {
    private let until: Date?

    private init(_ until: Date?) {
        self.until = until
    }

    public static let `default` = ActivityUIDismissalPolicy(nil)

    public static let immediate = ActivityUIDismissalPolicy(Date(timeIntervalSince1970: 0))

    public static func after(_ date: Date) -> ActivityUIDismissalPolicy { return ActivityUIDismissalPolicy(date) }

    public static func == (a: ActivityUIDismissalPolicy, b: ActivityUIDismissalPolicy) -> Bool {
        return a.until == b.until
    }
}

public enum ActivityAuthorizationError: Error, CustomNSError, LocalizedError, Hashable {
    case attributesTooLarge
    case unsupported
    case denied
    case globalMaximumExceeded
    case targetMaximumExceeded
    case unsupportedTarget
    case visibility
    case persistenceFailure
    case missingProcessIdentifier
    case unentitled
    case malformedActivityIdentifier
    case nilContent
    case reconnectNotPermitted

    public static var errorDomain: String { return "ActivityKit.ActivityAuthorizationError" }

    public var errorCode: Int {
        switch self {
        case .attributesTooLarge: return 1
        case .unsupported: return 2
        case .denied: return 3
        case .globalMaximumExceeded: return 4
        case .targetMaximumExceeded: return 5
        case .unsupportedTarget: return 6
        case .visibility: return 7
        case .persistenceFailure: return 8
        case .missingProcessIdentifier: return 9
        case .unentitled: return 10
        case .malformedActivityIdentifier: return 11
        case .nilContent: return 12
        case .reconnectNotPermitted: return 13
        }
    }

    public var failureReason: String? {
        switch self {
        case .attributesTooLarge: return "The attributes of the activity are too large."
        case .unsupported: return "This device does not support Live Activities."
        case .denied: return "The user has turned Live Activities off."
        case .globalMaximumExceeded: return "The system has as many Live Activities running as it allows."
        case .targetMaximumExceeded: return "The system has as many Live Activities of this kind running as it allows."
        case .unsupportedTarget: return "This device is not one the activity can be shown on."
        case .visibility: return "The activity's kind may not be shown where it asks."
        case .persistenceFailure: return "The activity could not be saved."
        case .missingProcessIdentifier: return "The app has no process identifier."
        case .unentitled: return "The app is not entitled to Live Activities."
        case .malformedActivityIdentifier: return "The activity's identifier is not one the system issued."
        case .nilContent: return "The activity has no content."
        case .reconnectNotPermitted: return "The system will not reconnect to the activity."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .denied: return "Turn Live Activities on in Settings."
        case .unentitled: return "Add the Live Activity entitlement to the app."
        case .unsupported: return nil
        default: return nil
        }
    }

    public static func == (a: ActivityAuthorizationError, b: ActivityAuthorizationError) -> Bool {
        return a.errorCode == b.errorCode
    }
}

public final class ActivityAuthorizationInfo {
    public var areActivitiesEnabled: Bool { return RevenantActivitySupport.shared.areActivitiesEnabled }

    public var frequentPushesEnabled: Bool { return RevenantActivitySupport.shared.frequentPushesEnabled }

    public let activityEnablementUpdates: ActivityEnablementUpdates

    public let frequentPushEnablementUpdates: FrequentPushEnablementUpdates

    public init() {
        self.activityEnablementUpdates = ActivityEnablementUpdates()
        self.frequentPushEnablementUpdates = FrequentPushEnablementUpdates()
    }

    public struct ActivityEnablementUpdates: AsyncSequence {
        public typealias Element = Bool

        public struct Iterator: AsyncIteratorProtocol {
            private var read = false
            private let enabled: Bool

            init(enabled: Bool) {
                self.enabled = enabled
            }

            public mutating func next() async -> Bool? {
                guard !read else { return nil }
                read = true
                return enabled
            }
        }

        public func makeAsyncIterator() -> Iterator { return Iterator(enabled: RevenantActivitySupport.shared.areActivitiesEnabled) }
    }

    public struct FrequentPushEnablementUpdates: AsyncSequence {
        public typealias Element = Bool

        public struct Iterator: AsyncIteratorProtocol {
            private var read = false
            private let enabled: Bool

            init(enabled: Bool) {
                self.enabled = enabled
            }

            public mutating func next() async -> Bool? {
                guard !read else { return nil }
                read = true
                return enabled
            }
        }

        public func makeAsyncIterator() -> Iterator {
            return Iterator(enabled: RevenantActivitySupport.shared.frequentPushesEnabled)
        }
    }
}

public final class RevenantActivitySupport {
    public static let shared = RevenantActivitySupport()

    public typealias AvailabilityReader = () -> Bool
    public typealias FrequentPushReader = () -> Bool

    private var availability: AvailabilityReader?
    private var frequentPushes: FrequentPushReader?

    public init() {}

    public func install(areActivitiesEnabled: @escaping AvailabilityReader, frequentPushesEnabled: @escaping FrequentPushReader) {
        availability = areActivitiesEnabled
        frequentPushes = frequentPushesEnabled
    }

    public var areActivitiesEnabled: Bool { return availability?() ?? false }

    public var frequentPushesEnabled: Bool { return frequentPushes?() ?? false }
}
