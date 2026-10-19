// ActivityKit: the Live Activities of iOS 16.1.
//
// A Live Activity is not a value the app keeps: it is a registration the system's activity daemon
// (`chronod`) owns, which hands the app a push token to update it with and draws it on the Lock
// Screen and, from iOS 16.1, in the Dynamic Island. iOS 6.1.3 runs no such daemon and the release has
// no Live Activity surface at all, so the framework's own answer for a device that does not support
// Live Activities is the answer this module gives, and gives it by asking, not by asserting: see
// `CharonActivitySupport`. `facts/ActivityKit/Availability.md`.

import Foundation
#if CHARON_CARRIES_LOCALIZED_STRING
import AppIntents
#endif

/// What an activity carries: the attributes that never change over the activity's life, and the
/// content state that does.
public protocol ActivityAttributes: Decodable, Encodable {
    associatedtype ContentState: Decodable, Encodable, Hashable
}

/// How long an activity is shown for: the standard one stays until the app ends it, a transient one is
/// put away after a while.
public enum ActivityStyle: Hashable, Sendable {
    case standard
    case transient
}

/// Where an activity is in its life.
public enum ActivityState: Sendable, Codable, Hashable, CustomStringConvertible {
    /// The activity is registered and waiting to be shown.
    case pending
    /// The activity is on screen.
    case active
    /// The activity has finished, and stays where it is until it is dismissed.
    case ended
    /// The activity has been dismissed.
    case dismissed
    /// The activity's content is past its stale date, and the surface shows that it is out of date.
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

/// What an activity shows: its content state, the date it goes stale at, and how relevant it is
/// against the others.
public struct ActivityContent<State>: Sendable where State: Decodable, State: Encodable, State: Hashable {
    /// The state the surface draws.
    public let state: State
    /// The date from which the state is out of date, which the surface shows as stale.
    public let staleDate: Date?
    /// How relevant this activity is against the others, from 0 to 1.
    public let relevanceScore: Double

    /// What is shown for the content, the way the framework's own printed form reads it.
    public var description: String {
        return "ActivityContent(state: \(state), staleDate: \(staleDate.map { "\($0)" } ?? "nil"), relevanceScore: \(relevanceScore))"
    }

    public init(state: State, staleDate: Date?, relevanceScore: Double = 0.0) {
        self.state = state
        self.staleDate = staleDate
        // The framework's own initialiser takes a score of any value and the surface is told only what
        // is between 0 and 1; a score outside that is clipped, not refused.
        self.relevanceScore = relevanceScore < 0 ? 0 : (relevanceScore > 1 ? 1 : relevanceScore)
    }
}

/// How a push for an activity is delivered: to the token the daemon handed the app, or to a named
/// channel the daemon keeps for the app.
public struct PushType: Equatable, Sendable {
    private let name: String

    private init(_ name: String) {
        self.name = name
    }

    /// The token the daemon handed the app for this activity.
    public static var token: PushType { return PushType("token") }

    /// A named channel, which every activity of the app shares.
    public static func channel(_ name: String) -> PushType { return PushType(name) }

    public static func == (a: PushType, b: PushType) -> Bool { return a.name == b.name }
}

/// What an activity's alert says when the app pushes one.
public struct AlertConfiguration: Equatable, Sendable {
    /// The sound an alert makes, which is the system's own or one the app named.
    public struct AlertSound: Equatable, Sendable {
        private let name: String?

        private init(_ name: String?) {
            self.name = name
        }

        /// The system's own alert sound.
        public static var `default`: AlertSound { return AlertSound(nil) }

        /// A sound the app named, which is a file in the app's own bundle.
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

/// How long the surface keeps a finished activity's content there.
public struct ActivityUIDismissalPolicy: Equatable, Sendable {
    private let until: Date?

    private init(_ until: Date?) {
        self.until = until
    }

    /// The system's own choice, which is to keep the content for a while and then take it away.
    public static let `default` = ActivityUIDismissalPolicy(nil)

    /// Take the content away as soon as the activity ends.
    public static let immediate = ActivityUIDismissalPolicy(Date(timeIntervalSince1970: 0))

    /// Keep the content until this date, and take it away then.
    public static func after(_ date: Date) -> ActivityUIDismissalPolicy { return ActivityUIDismissalPolicy(date) }

    public static func == (a: ActivityUIDismissalPolicy, b: ActivityUIDismissalPolicy) -> Bool {
        return a.until == b.until
    }
}

/// Why an activity could not be registered. The cases are the framework's own, and the error's
/// domain and codes are the ones it publishes.
public enum ActivityAuthorizationError: Error, CustomNSError, LocalizedError, Hashable {
    /// The attributes are larger than the system allows for one activity.
    case attributesTooLarge
    /// This device does not run Live Activities.
    case unsupported
    /// The owner turned Live Activities off.
    case denied
    /// There are already as many activities running as the system allows.
    case globalMaximumExceeded
    /// There are already as many activities of this kind as the system allows.
    case targetMaximumExceeded
    /// The device is not one the activity can be shown on.
    case unsupportedTarget
    /// The activity's kind is not one that may be shown where it asks.
    case visibility
    /// The activity could not be written to the system's own store.
    case persistenceFailure
    /// The app has no process identifier, which the system needs to keep the activity alive.
    case missingProcessIdentifier
    /// The app is not entitled to Live Activities.
    case unentitled
    /// The activity's identifier is not one the system issued.
    case malformedActivityIdentifier
    /// The request is missing the content the activity needs.
    case nilContent
    /// The system would not reconnect to the activity, which it says when the app asks again for an
    /// activity it already has and the daemon will not hand back.
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

/// Whether this device and this app may register Live Activities at all, and whether the system will
/// deliver them as often as the app asks.
public final class ActivityAuthorizationInfo {
    /// Whether Live Activities may be registered on this device, for this app, right now.
    public var areActivitiesEnabled: Bool { return CharonActivitySupport.shared.areActivitiesEnabled }

    /// Whether the system will deliver a push for every update, which it only does to an app the owner
    /// has allowed.
    public var frequentPushesEnabled: Bool { return CharonActivitySupport.shared.frequentPushesEnabled }

    public let activityEnablementUpdates: ActivityEnablementUpdates

    public let frequentPushEnablementUpdates: FrequentPushEnablementUpdates

    public init() {
        self.activityEnablementUpdates = ActivityEnablementUpdates()
        self.frequentPushEnablementUpdates = FrequentPushEnablementUpdates()
    }

    /// The stream of whether Live Activities may be registered, which is a single answer here.
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

        public func makeAsyncIterator() -> Iterator { return Iterator(enabled: CharonActivitySupport.shared.areActivitiesEnabled) }
    }

    /// The stream of whether frequent pushes are allowed, which is a single answer here.
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
            return Iterator(enabled: CharonActivitySupport.shared.frequentPushesEnabled)
        }
    }
}

/// Whether this release and this build may register Live Activities, and how often the system will
/// deliver a push. A caller that has the system's own answer installs it; with none, the answer is the
/// one this release gives, measured rather than asserted - see `facts/ActivityKit/Availability.md`.
public final class CharonActivitySupport {
    public static let shared = CharonActivitySupport()

    /// The reader the system's own answer comes through, when there is one.
    public typealias AvailabilityReader = () -> Bool
    /// The reader the system's answer about frequent pushes comes through, when there is one.
    public typealias FrequentPushReader = () -> Bool

    private var availability: AvailabilityReader?
    private var frequentPushes: FrequentPushReader?

    public init() {}

    /// Install the system's own answers, which is what a release that runs the activity daemon does.
    public func install(areActivitiesEnabled: @escaping AvailabilityReader, frequentPushesEnabled: @escaping FrequentPushReader) {
        availability = areActivitiesEnabled
        frequentPushes = frequentPushesEnabled
    }

    /// Whether Live Activities may be registered. Without a reader this is the release's own answer.
    public var areActivitiesEnabled: Bool { return availability?() ?? false }

    /// Whether frequent pushes are allowed. Without a reader this is the release's own answer.
    public var frequentPushesEnabled: Bool { return frequentPushes?() ?? false }
}
