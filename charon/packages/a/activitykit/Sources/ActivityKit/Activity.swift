// The activity itself: what the app registers, what it updates, and how it ends it.
//
// `Activity` is the framework's handle on a registration the system's own daemon owns. Where there is
// no daemon there is no registration, and the framework's answer for that is the error
// `ActivityAuthorizationError.unsupported` - so `request` throws it, `activities` is empty, and the
// three update streams carry nothing. Every value that is the app's own - the attributes, the content,
// the alert, the dismissal policy - is real, and the push token is `nil` because only the daemon mints
// one. `facts/ActivityKit/Availability.md`.

import Foundation

/// A Live Activity: a thing the app registers and the system shows on the Lock Screen and in the
/// Dynamic Island, and updates while it is there.
public final class Activity<Attributes>: Identifiable, CharonRegisteredActivity where Attributes: ActivityAttributes {
    public typealias ContentState = Attributes.ContentState
    public typealias ID = String

    /// The attributes the activity was registered with, which never change over its life.
    public let attributes: Attributes
    /// The name the system's own daemon knows the activity by.
    public let id: String

    /// The state the surface draws.
    private var storedState: ContentState
    /// Where the activity is in its life.
    private var storedState_: ActivityState = .pending
    private var storedContent: ActivityContent<ContentState>
    /// The token the daemon mints for this activity, which is `nil` where there is no daemon.
    public private(set) var pushToken: Data?

    /// Every activity of this kind the app has registered, which is empty where there is no daemon.
    public static var activities: [Activity<Attributes>] { return CharonActivityRegistry.shared.activities(of: Attributes.self) }

    /// The stream of activities as they are registered and end.
    public static var activityUpdates: ActivityUpdates { return ActivityUpdates() }

    internal init(attributes: Attributes, state: ContentState, id: String) {
        self.attributes = attributes
        self.storedState = state
        self.storedContent = ActivityContent(state: state, staleDate: nil)
        self.id = id
    }

    /// Register an activity, the way the framework's own first spelling did.
    public static func request(attributes: Attributes, contentState: ContentState,
                               pushType: PushType? = nil) throws -> Activity<Attributes> {
        return try request(attributes: attributes, content: ActivityContent(state: contentState, staleDate: nil),
                           pushType: pushType)
    }

    /// Register an activity with the content it shows.
    public static func request(attributes: Attributes, content: ActivityContent<ContentState>,
                               pushType: PushType? = nil) throws -> Activity<Attributes> {
        guard CharonActivitySupport.shared.areActivitiesEnabled else {
            throw ActivityAuthorizationError.unsupported
        }
        return try CharonActivityRegistry.shared.register(attributes: attributes, content: content)
    }

    /// Register an activity, saying how long it is shown for.
    public static func request(attributes: Attributes, content: ActivityContent<ContentState>,
                               pushType: PushType? = nil, style: ActivityStyle) throws -> Activity<Attributes> {
        let activity = try request(attributes: attributes, content: content, pushType: pushType)
        CharonActivityRegistry.shared.setStyle(style, for: activity)
        return activity
    }

    /// Register an activity with an alert and the date it starts at.
    public static func request(attributes: Attributes, content: ActivityContent<ContentState>,
                               pushType: PushType? = nil, style: ActivityStyle,
                               alertConfiguration: AlertConfiguration, start: Date) throws -> Activity<Attributes> {
        let activity = try request(attributes: attributes, content: content, pushType: pushType, style: style)
        CharonActivityRegistry.shared.setAlert(alertConfiguration, starting: start, for: activity)
        return activity
    }

    /// Register an activity with an alert and the date it starts at, the older spelling.
    public static func request(attributes: Attributes, content: ActivityContent<ContentState>,
                               pushType: PushType? = nil, style: ActivityStyle,
                               alertConfiguration: AlertConfiguration, startDate: Date) throws -> Activity<Attributes> {
        return try request(attributes: attributes, content: content, pushType: pushType, style: style,
                            alertConfiguration: alertConfiguration, start: startDate)
    }

    /// Where the activity is in its life, for the registry's own record: the state as it is, without
    /// the stale date's answer, which is the surface's business.
    public var charonActivityState: ActivityState { return storedState_ }

    /// Where the activity is in its life, which is `stale` once its content is past its stale date.
    public var activityState: ActivityState {
        guard storedState_ != .ended && storedState_ != .dismissed else { return storedState_ }
        if let stale = storedContent.staleDate, stale <= Date() { return .stale }
        return storedState_
    }

    /// The stream of the activity's state as it changes.
    public var activityStateUpdates: ActivityStateUpdates { return ActivityStateUpdates(activity: self) }

    /// The state the surface draws, the way the framework's own first spelling reached it.
    public var contentState: ContentState { return storedState }

    /// The stream of the activity's content state as it changes.
    public var contentStateUpdates: ContentStateUpdates { return ContentStateUpdates(activity: self) }

    /// The content the surface draws: the state, when it goes stale, and how relevant it is.
    public var content: ActivityContent<ContentState> { return storedContent }

    /// The stream of the activity's content as it changes.
    public var contentUpdates: ContentUpdates { return ContentUpdates(activity: self) }

    /// The stream of the activity's push token, which the daemon mints once the activity is registered.
    public var pushTokenUpdates: PushTokenUpdates { return PushTokenUpdates(activity: self, startToken: false) }

    /// The token the daemon mints for the app as a whole, which every activity of the app shares.
    public static var pushToStartToken: Data? { return CharonActivityRegistry.shared.pushToStartToken(of: Attributes.self) }

    /// The stream of that token.
    public static var pushToStartTokenUpdates: PushTokenUpdates {
        return PushTokenUpdates(activity: nil, startToken: true)
    }

    /// Update the state the surface draws.
    public func update(using contentState: ContentState) async {
        await update(ActivityContent(state: contentState, staleDate: nil))
    }

    /// Update the content the surface draws.
    public func update(_ content: ActivityContent<ContentState>) async {
        storedContent = content
        storedState = content.state
        if storedState_ == .pending { storedState_ = .active }
        CharonActivityRegistry.shared.didUpdate(activity: self)
    }

    /// Update the state, with an alert to show with it.
    public func update(using contentState: ContentState, alertConfiguration: AlertConfiguration? = nil) async {
        await update(ActivityContent(state: contentState, staleDate: nil), alertConfiguration: alertConfiguration)
    }

    /// Update the content, with an alert to show with it.
    public func update(_ content: ActivityContent<ContentState>, alertConfiguration: AlertConfiguration? = nil) async {
        await update(content)
        if let alertConfiguration = alertConfiguration {
            CharonActivityRegistry.shared.setAlert(alertConfiguration, starting: Date(), for: self)
        }
    }

    /// Update the content, with an alert to show with it and the date the push is dated.
    public func update(_ content: ActivityContent<ContentState>, alertConfiguration: AlertConfiguration? = nil,
                       timestamp: Date) async {
        await update(content, alertConfiguration: alertConfiguration)
        CharonActivityRegistry.shared.didPush(self, at: timestamp)
    }

    /// End the activity, leaving its state where it is.
    public func end(using contentState: ContentState? = nil,
                     dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        await end(contentState.map { ActivityContent(state: $0, staleDate: nil) }, dismissalPolicy: dismissalPolicy)
    }

    /// End the activity with the content the surface keeps.
    public func end(_ content: ActivityContent<ContentState>?,
                     dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        if let content = content { await update(content) }
        storedState_ = .ended
        CharonActivityRegistry.shared.didEnd(activity: self, dismissalPolicy: dismissalPolicy)
    }

    /// End the activity with the content the surface keeps, and the date the end is dated.
    public func end(_ content: ActivityContent<ContentState>?, dismissalPolicy: ActivityUIDismissalPolicy = .default,
                     timestamp: Date) async {
        await end(content, dismissalPolicy: dismissalPolicy)
        CharonActivityRegistry.shared.didEnd(activity: self, dismissalPolicy: dismissalPolicy, at: timestamp)
    }

    /// The stream of activities as they are registered and end.
    public struct ActivityUpdates: AsyncSequence {
        public typealias Element = Activity<Attributes>

        public struct Iterator: AsyncIteratorProtocol {
            private var sent = false

            public mutating func next() async -> Activity<Attributes>? {
                guard !sent else { return nil }
                sent = true
                return Activity<Attributes>.activities.first
            }
        }

        public func makeAsyncIterator() -> Iterator { return Iterator() }
    }

    /// The stream of an activity's state as it changes.
    public struct ActivityStateUpdates: AsyncSequence {
        public typealias Element = ActivityState

        public struct Iterator: AsyncIteratorProtocol {
            private let activity: Activity<Attributes>
            private var last: ActivityState?

            init(activity: Activity<Attributes>) {
                self.activity = activity
            }

            public mutating func next() async -> ActivityState? {
                let state = activity.activityState
                guard state != last else { return nil }
                last = state
                return state
            }
        }

        public func makeAsyncIterator() -> Iterator { return Iterator(activity: activity) }

        let activity: Activity<Attributes>
    }

    /// The stream of an activity's content state as it changes.
    public struct ContentStateUpdates: AsyncSequence {
        public typealias Element = ContentState

        public struct Iterator: AsyncIteratorProtocol {
            private let activity: Activity<Attributes>
            private var sent = false

            init(activity: Activity<Attributes>) {
                self.activity = activity
            }

            public mutating func next() async -> ContentState? {
                guard !sent else { return nil }
                sent = true
                return activity.contentState
            }
        }

        public func makeAsyncIterator() -> Iterator { return Iterator(activity: activity) }

        let activity: Activity<Attributes>
    }

    /// The stream of an activity's content as it changes.
    public struct ContentUpdates: AsyncSequence {
        public typealias Element = ActivityContent<ContentState>

        public struct Iterator: AsyncIteratorProtocol {
            private let activity: Activity<Attributes>
            private var sent = false

            init(activity: Activity<Attributes>) {
                self.activity = activity
            }

            public mutating func next() async -> ActivityContent<ContentState>? {
                guard !sent else { return nil }
                sent = true
                return activity.content
            }
        }

        public func makeAsyncIterator() -> Iterator { return Iterator(activity: activity) }

        let activity: Activity<Attributes>
    }

    /// The stream of a push token, which the daemon mints and then holds.
    public struct PushTokenUpdates: AsyncSequence {
        public typealias Element = Data

        public struct Iterator: AsyncIteratorProtocol {
            private let activity: Activity<Attributes>?
            private let startToken: Bool
            private var sent = false

            init(activity: Activity<Attributes>?, startToken: Bool) {
                self.activity = activity
                self.startToken = startToken
            }

            public mutating func next() async -> Data? {
                guard !sent else { return nil }
                sent = true
                return startToken ? CharonActivityRegistry.shared.pushToStartToken(of: Attributes.self) : activity?.pushToken
            }
        }

        public func makeAsyncIterator() -> Iterator {
            return Iterator(activity: startToken ? nil : activity, startToken: startToken)
        }

        let activity: Activity<Attributes>?
        let startToken: Bool
    }
}
