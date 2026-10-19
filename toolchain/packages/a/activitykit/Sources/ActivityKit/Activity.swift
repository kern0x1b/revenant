import Foundation

public final class Activity<Attributes>: Identifiable, RevenantRegisteredActivity where Attributes: ActivityAttributes {
    public typealias ContentState = Attributes.ContentState
    public typealias ID = String

    public let attributes: Attributes
    public let id: String

    private var storedState: ContentState
    private var storedState_: ActivityState = .pending
    private var storedContent: ActivityContent<ContentState>
    public private(set) var pushToken: Data?

    public static var activities: [Activity<Attributes>] { return RevenantActivityRegistry.shared.activities(of: Attributes.self) }

    public static var activityUpdates: ActivityUpdates { return ActivityUpdates() }

    internal init(attributes: Attributes, state: ContentState, id: String) {
        self.attributes = attributes
        self.storedState = state
        self.storedContent = ActivityContent(state: state, staleDate: nil)
        self.id = id
    }

    public static func request(attributes: Attributes, contentState: ContentState,
                               pushType: PushType? = nil) throws -> Activity<Attributes> {
        return try request(attributes: attributes, content: ActivityContent(state: contentState, staleDate: nil),
                           pushType: pushType)
    }

    public static func request(attributes: Attributes, content: ActivityContent<ContentState>,
                               pushType: PushType? = nil) throws -> Activity<Attributes> {
        guard RevenantActivitySupport.shared.areActivitiesEnabled else {
            throw ActivityAuthorizationError.unsupported
        }
        return try RevenantActivityRegistry.shared.register(attributes: attributes, content: content)
    }

    public static func request(attributes: Attributes, content: ActivityContent<ContentState>,
                               pushType: PushType? = nil, style: ActivityStyle) throws -> Activity<Attributes> {
        let activity = try request(attributes: attributes, content: content, pushType: pushType)
        RevenantActivityRegistry.shared.setStyle(style, for: activity)
        return activity
    }

    public static func request(attributes: Attributes, content: ActivityContent<ContentState>,
                               pushType: PushType? = nil, style: ActivityStyle,
                               alertConfiguration: AlertConfiguration, start: Date) throws -> Activity<Attributes> {
        let activity = try request(attributes: attributes, content: content, pushType: pushType, style: style)
        RevenantActivityRegistry.shared.setAlert(alertConfiguration, starting: start, for: activity)
        return activity
    }

    public static func request(attributes: Attributes, content: ActivityContent<ContentState>,
                               pushType: PushType? = nil, style: ActivityStyle,
                               alertConfiguration: AlertConfiguration, startDate: Date) throws -> Activity<Attributes> {
        return try request(attributes: attributes, content: content, pushType: pushType, style: style,
                            alertConfiguration: alertConfiguration, start: startDate)
    }

    public var revenantActivityState: ActivityState { return storedState_ }

    public var activityState: ActivityState {
        guard storedState_ != .ended && storedState_ != .dismissed else { return storedState_ }
        if let stale = storedContent.staleDate, stale <= Date() { return .stale }
        return storedState_
    }

    public var activityStateUpdates: ActivityStateUpdates { return ActivityStateUpdates(activity: self) }

    public var contentState: ContentState { return storedState }

    public var contentStateUpdates: ContentStateUpdates { return ContentStateUpdates(activity: self) }

    public var content: ActivityContent<ContentState> { return storedContent }

    public var contentUpdates: ContentUpdates { return ContentUpdates(activity: self) }

    public var pushTokenUpdates: PushTokenUpdates { return PushTokenUpdates(activity: self, startToken: false) }

    public static var pushToStartToken: Data? { return RevenantActivityRegistry.shared.pushToStartToken(of: Attributes.self) }

    public static var pushToStartTokenUpdates: PushTokenUpdates {
        return PushTokenUpdates(activity: nil, startToken: true)
    }

    public func update(using contentState: ContentState) async {
        await update(ActivityContent(state: contentState, staleDate: nil))
    }

    public func update(_ content: ActivityContent<ContentState>) async {
        storedContent = content
        storedState = content.state
        if storedState_ == .pending { storedState_ = .active }
        RevenantActivityRegistry.shared.didUpdate(activity: self)
    }

    public func update(using contentState: ContentState, alertConfiguration: AlertConfiguration? = nil) async {
        await update(ActivityContent(state: contentState, staleDate: nil), alertConfiguration: alertConfiguration)
    }

    public func update(_ content: ActivityContent<ContentState>, alertConfiguration: AlertConfiguration? = nil) async {
        await update(content)
        if let alertConfiguration = alertConfiguration {
            RevenantActivityRegistry.shared.setAlert(alertConfiguration, starting: Date(), for: self)
        }
    }

    public func update(_ content: ActivityContent<ContentState>, alertConfiguration: AlertConfiguration? = nil,
                       timestamp: Date) async {
        await update(content, alertConfiguration: alertConfiguration)
        RevenantActivityRegistry.shared.didPush(self, at: timestamp)
    }

    public func end(using contentState: ContentState? = nil,
                     dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        await end(contentState.map { ActivityContent(state: $0, staleDate: nil) }, dismissalPolicy: dismissalPolicy)
    }

    public func end(_ content: ActivityContent<ContentState>?,
                     dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        if let content = content { await update(content) }
        storedState_ = .ended
        RevenantActivityRegistry.shared.didEnd(activity: self, dismissalPolicy: dismissalPolicy)
    }

    public func end(_ content: ActivityContent<ContentState>?, dismissalPolicy: ActivityUIDismissalPolicy = .default,
                     timestamp: Date) async {
        await end(content, dismissalPolicy: dismissalPolicy)
        RevenantActivityRegistry.shared.didEnd(activity: self, dismissalPolicy: dismissalPolicy, at: timestamp)
    }

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
                return startToken ? RevenantActivityRegistry.shared.pushToStartToken(of: Attributes.self) : activity?.pushToken
            }
        }

        public func makeAsyncIterator() -> Iterator {
            return Iterator(activity: startToken ? nil : activity, startToken: startToken)
        }

        let activity: Activity<Attributes>?
        let startToken: Bool
    }
}
