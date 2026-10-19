// TipKit: the tips an app offers, the rules that decide which one to show, and the events that record
// what the owner did with them.
//
// A tip is a piece of advice with a rule: "when the owner has been ignoring the search for a week, show
// them the shortcut". The rules, the display count, the donations and the datastore are all the app's
// own, and every one of them is a value here. What TipKit's system service adds is the *presentation*:
// the popover the system draws over the app's own views. These releases have no such service, so the
// tip is drawn in the app, by the views at the bottom of this module. `facts/TipKit/Rendering.md`.

import Foundation
#if CHARON_CARRIES_LOCALIZED_STRING
import AppIntents
#endif

/// A tip: some advice, the rules that say when it may be shown, and the options that bound it.
public protocol Tip {
    /// What the tip is called.
    var title: Title { get }
    /// The text under the title.
    var message: Message? { get }
    /// The image beside the text.
    var image: Image? { get }
    /// What the owner can do with the tip.
    var actions: [Action] { get }
    /// The rules that decide whether the tip may be shown.
    var rules: [Rule] { get }
    /// The options that bound how often it is shown.
    var options: [Option] { get }
    /// The name the datastore knows this tip by.
    var id: ID { get }
    /// The name the datastore knows this tip by.
    typealias ID = String
    /// The text a tip is called.
    typealias Title = LocalizedStringResource
    /// The text under a tip's title.
    typealias Message = LocalizedStringResource
    /// The image beside a tip's text.
    typealias Image = LocalizedStringResource
    /// What the owner can do with a tip.
    typealias Action = Tips.Action
    /// The rules that decide whether a tip may be shown.
    typealias Rule = Tips.Rule
    /// The options that bound how often a tip is shown.
    typealias Option = Tips.TipOption
    /// Where a tip is in its life.
    typealias Status = Tips.Status
    /// Why a tip was taken off the list.
    typealias InvalidationReason = Tips.InvalidationReason
    /// A rule's input, which is what the rules read.
    typealias Event = Tips.Event<Tips.EmptyDonation>
    /// The option that shows a tip as often as the rules allow.
    typealias IgnoresDisplayFrequency = Tips.IgnoresDisplayFrequency
    /// The option that bounds how many times a tip is shown.
    typealias MaxDisplayCount = Tips.MaxDisplayCount
    /// The option that bounds for how long a tip is shown.
    typealias MaxDisplayDuration = Tips.MaxDisplayDuration

    /// Where the tip is in its life, which the datastore answers and the popover reads.
    var status: Status { get }
    /// The stream of the tip's status as it changes.
    var statusUpdates: AsyncStream<Status> { get }
    /// Whether the tip may be shown now, which is what the popover's modifier asks.
    var shouldDisplay: Bool { get }
    /// The stream of `shouldDisplay`.
    var shouldDisplayUpdates: AsyncMapSequence<AsyncStream<Status>, Bool> { get }

    /// Take the tip off the list, which is what an action or a swipe does.
    func invalidate(reason: InvalidationReason)
    /// Put the tip back in the list, the way a test starts.
    func resetEligibility() async
}

/// A tip of any kind, with the values a group or a popover needs, erased.
public struct AnyTip: Tip {
    public typealias ID = String

    /// The name the datastore knows this tip by.
    public let id: String
    public let title: LocalizedStringResource
    public let message: LocalizedStringResource?
    public let image: LocalizedStringResource?
    public let actions: [Tips.Action]
    public let rules: [Tips.Rule]
    public let options: [Tips.TipOption]
    /// The kind of tip this was erased from, which is what the framework's type-taking test helpers
    /// filter the datastore over (`Tips.showTipsForTesting(_: [any Tip.Type])`).
    public let kind: String

    public init(_ tip: some Tip) {
        self.kind = String(describing: type(of: tip))
        self.id = tip.id
        self.title = tip.title
        self.message = tip.message
        self.image = tip.image
        self.actions = tip.actions
        self.rules = tip.rules
        self.options = tip.options
    }

    /// A tip whose rules and options are the ones the tip itself keeps, with the values read back out
    /// of it.
    public init(erasing tip: some Tip) {
        self.init(tip)
    }

    public var status: Tips.Status { return Tips.Store.shared.status(of: self) }
    public var statusUpdates: AsyncStream<Tips.Status> { return Tips.statusStream(for: id) }
    public var shouldDisplay: Bool { return Tips.Store.shared.shouldDisplay(self) }
    public var shouldDisplayUpdates: AsyncMapSequence<AsyncStream<Tips.Status>, Bool> {
        return statusUpdates.map { status in Tips.Store.shared.shouldDisplay(self) && status == .available }
    }

    public func invalidate(reason: Tips.InvalidationReason) {
        Tips.Store.shared.invalidate(id, of: kind, reason: reason)
    }
    public func resetEligibility() async { Tips.Store.shared.reset(id) }
}

/// The tips: their rules, their events, the datastore, and the configuration the app gives them.
public enum Tips {
    // MARK: - The life of a tip

    /// Where a tip is in its life.
    public enum Status: Hashable, Sendable {
        /// The datastore has not decided yet.
        case pending
        /// The tip may be shown now.
        case available
        /// The tip is off the list, and why.
        case invalidated(Tips.InvalidationReason)

        public static func == (a: Status, b: Status) -> Bool {
            switch (a, b) {
                case (.pending, .pending), (.available, .available): return true
                case (.invalidated(let l), .invalidated(let r)): return l == r
                default: return false
                }
        }
        public func hash(into hasher: inout Hasher) {
            switch self {
                case .pending: hasher.combine(0)
                case .available: hasher.combine(1)
                case .invalidated(let reason): hasher.combine(2); hasher.combine(reason)
                }
        }
        public var hashValue: Int {
            switch self {
                case .pending: return 0
                case .available: return 1
                case .invalidated(let reason): return 2 &* 31 &+ reason.hashValue
                }
        }
    }

    /// Why a tip is off the list.
    public enum InvalidationReason: Hashable, Sendable {
        /// The owner did what the tip asked.
        case actionPerformed
        /// The tip has been shown as often as its options allow.
        case displayCountExceeded
        /// The tip has been shown for as long as its options allow.
        case displayDurationExceeded
        /// The owner closed the tip.
        case tipClosed

        public static func == (a: InvalidationReason, b: InvalidationReason) -> Bool { return a.raw == b.raw }
        public func hash(into hasher: inout Hasher) { hasher.combine(raw) }
        public var hashValue: Int { return raw.hashValue }
        private var raw: Int {
            switch self {
            case .actionPerformed: return 0
            case .displayCountExceeded: return 1
            case .displayDurationExceeded: return 2
            case .tipClosed: return 3
            }
        }
    }

    // MARK: - What the owner can do

    /// What the owner can do with a tip.
    public struct Action: Identifiable, Sendable {
        public typealias ID = String

        /// The name the tip's own sheet knows the action by.
        public let id: String
        /// What the action is called, which is what the button is labelled.
        public let title: LocalizedStringResource?
        /// What the action does, which is the app's own.
        public let handler: @Sendable () -> Void
        /// Where the action sits among the tip's, which is the order the buttons are in.
        public let index: Int

        public init(id: String, title: LocalizedStringResource, perform handler: @escaping @Sendable () -> Void) {
            self.id = id
            self.title = title
            self.handler = handler
            self.index = 0
        }

        public init(id: String, perform handler: @escaping @Sendable () -> Void, _ title: LocalizedStringResource? = nil) {
            self.id = id
            self.title = title
            self.handler = handler
            self.index = 0
        }

        /// The label the button carries, which is the title the app gave.
        public var label: LocalizedStringResource? { return title }
    }

    /// The builder a tip's actions are written with.
    public struct ActionBuilder {
        public static func buildPartialBlock(first: Action) -> Action { return first }
        public static func buildPartialBlock(accumulated: Action, next: Action) -> Action { return next }
        public static func buildExpression(_ expression: Action) -> Action { return expression }
        public static func buildFinalResult(_ action: Action) -> Action { return action }
        public static func buildOptional(_ action: Action?) -> Action? { return action }
        public static func buildEither(first: Action) -> Action { return first }
        public static func buildEither(second: Action) -> Action { return second }
        public static func buildArray(_ actions: [Action]) -> [Action] { return actions }
        public static func buildLimitedAvailability(_ action: Action) -> Action { return action }
    }

    // MARK: - The rules

    /// What a rule reads: the events the app has sent, and the donations in them.
    public protocol RuleInput {
        /// The events, newest first.
        var donations: [Event<EmptyDonation>.Donation] { get }
    }

    /// A rule: one condition, or several combined.
    public struct Rule: Sendable {
        /// How several conditions are combined.
        public enum CompoundOperation: Hashable, Sendable {
            /// Every condition has to hold.
            case conjunction
            /// One condition holding is enough.
            case disjunction

            public static func == (a: CompoundOperation, b: CompoundOperation) -> Bool { return a.raw == b.raw }
            public func hash(into hasher: inout Hasher) { hasher.combine(raw) }
            public var hashValue: Int { return raw.hashValue }
            private var raw: Int {
                switch self {
                case .conjunction: return 0
                case .disjunction: return 1
                }
            }
        }

        /// The condition, or the conditions.
        public let condition: any EventPredicateExpression
        /// The operation, when the condition is a compound one.
        public let operation: CompoundOperation

        public init(_ condition: any EventPredicateExpression) {
            self.condition = condition
            self.operation = .conjunction
        }

        public init(_ conditions: [any EventPredicateExpression], _ operation: CompoundOperation) {
            self.condition = CharonAnyPredicate(conditions: conditions, operation: operation)
            self.operation = operation
        }
    }

    /// The builder a tip's rules are written with.
    public struct RuleBuilder {
        public static func buildPartialBlock(first: any EventPredicateExpression) -> any EventPredicateExpression {
            return first
        }
        public static func buildPartialBlock(accumulated: [any EventPredicateExpression],
                                             next: any EventPredicateExpression) -> [any EventPredicateExpression] {
            var all = accumulated
            all.append(next)
            return all
        }
        public static func buildBlock() -> [any EventPredicateExpression] { return [] }
        public static func buildExpression(_ expression: any EventPredicateExpression) -> any EventPredicateExpression {
            return expression
        }
        public static func buildOptional(_ expression: (any EventPredicateExpression)?) -> (any EventPredicateExpression)? {
            return expression
        }
        public static func buildEither(first: any EventPredicateExpression) -> any EventPredicateExpression { return first }
        public static func buildEither(second: any EventPredicateExpression) -> any EventPredicateExpression { return second }
    }

    /// A rule's compound condition, which is the conditions under one operation.
    struct CharonAnyPredicate: EventPredicateExpression {
        typealias Output = Bool

        let conditions: [any EventPredicateExpression]
        let operation: Rule.CompoundOperation

        init(conditions: [any EventPredicateExpression], operation: Rule.CompoundOperation) {
            self.conditions = conditions
            self.operation = operation
        }

        func evaluate(_ input: any Tips.RuleInput) -> Bool {
            switch operation {
            case .conjunction: return conditions.allSatisfy { $0.evaluate(input) }
            case .disjunction: return conditions.contains { $0.evaluate(input) }
            }
        }
    }

    // MARK: - The options

    /// An option that bounds how a tip is shown.
    public protocol TipOption: Sendable {
        /// The name the datastore knows the option by.
        var id: String { get }
    }

    /// The option that shows a tip as often as the rules allow, past the display frequency.
    public struct IgnoresDisplayFrequency: TipOption {
        public let id: String

        public init(_ id: String = "ignoresDisplayFrequency") {
            self.id = id
        }
    }

    /// The option that bounds how many times a tip is shown.
    public struct MaxDisplayCount: TipOption {
        public let id: String
        /// The count the tip is shown at most.
        public let count: Int

        public init(_ count: Int) {
            self.id = "maxDisplayCount"
            self.count = count
        }
    }

    /// The option that bounds for how long a tip is shown.
    public struct MaxDisplayDuration: TipOption {
        public let id: String
        /// The duration the tip is shown for at most, in seconds.
        public let duration: TimeInterval

        public init(_ duration: TimeInterval) {
            self.id = "maxDisplayDuration"
            self.duration = duration
        }
    }

    /// An option on a rule's parameter, which is the parameter's own.
    ///
    /// A marker, and the only value the framework gives one is `.transient`
    /// (`TipKit-ios.swiftinterface:250,258`) -- a `static var` of this type, not a `Bool` an
    /// initialiser takes. So a rule says `options: .transient`, and a parameter asks each option in
    /// turn whether it is that one.
    public struct ParameterOption: Sendable, Equatable {
        /// Whether the value the parameter holds is not kept between runs.
        public static var transient: ParameterOption { return ParameterOption(.transient) }

        enum Kind: String, Sendable {
            case transient
        }

        let kind: Kind

        init(_ kind: Kind) { self.kind = kind }

        public static func == (a: ParameterOption, b: ParameterOption) -> Bool { return a.kind == b.kind }
        public func hash(into hasher: inout Hasher) { hasher.combine(kind) }
        public var hashValue: Int { return kind.hashValue }
    }

    /// A parameter of a rule: a value the rule reads out of the donations, and what to do when it is
    /// of the wrong type.
    ///
    /// The two initialisers are the framework's own (`TipKit-ios.swiftinterface:241,243`): one takes
    /// the key path into the donation type the value is read from, the other the enclosing type's
    /// name and the value's, and both take the options **variadically**, which is what makes
    /// `options: .transient` the way a rule writes it. `wrappedValue` is a `var`, as the framework's
    /// is, so a rule may change the value between runs.
    public struct Parameter<Value>: Identifiable, Sendable where Value: Decodable, Value: Encodable, Value: Sendable {
        public typealias ID = String
        public typealias Value = Value

        /// The name the donation and the rule agree on.
        public let id: String
        /// The value the rule reads.
        public var wrappedValue: Value
        /// Whether the value is not kept between runs, which is what `.transient` says.
        public let isTransient: Bool

        public init<T>(_ keyPath: KeyPath<T, Value>, _ initialValue: Value, _ options: ParameterOption...) {
            self.id = String(describing: keyPath)
            self.wrappedValue = initialValue
            self.isTransient = options.contains(.transient)
        }

        public init(_ enclosingInstance: (some Any).Type, _ name: String, _ initialValue: Value,
                    _ options: ParameterOption...) {
            self.id = "\(enclosingInstance).\(name)"
            self.wrappedValue = initialValue
            self.isTransient = options.contains(.transient)
        }

        public init(_ id: String, _ initialValue: Value, _ options: ParameterOption...) {
            self.id = id
            self.wrappedValue = initialValue
            self.isTransient = options.contains(.transient)
        }
    }

    /// The builder a tip's options are written with.
    public struct OptionsBuilder {
        public static func buildPartialBlock(first: any TipOption) -> any TipOption { return first }
        public static func buildPartialBlock(accumulated: [any TipOption],
                                             next: any TipOption) -> [any TipOption] {
            var all = accumulated
            all.append(next)
            return all
        }
        public static func buildBlock() -> [any TipOption] { return [] }
        public static func buildExpression(_ expression: any TipOption) -> any TipOption { return expression }
        public static func buildFinalResult(_ option: any TipOption) -> any TipOption { return option }
        public static func buildOptional(_ option: (any TipOption)?) -> (any TipOption)? { return option }
        public static func buildEither(first: any TipOption) -> any TipOption { return first }
        public static func buildEither(second: any TipOption) -> any TipOption { return second }
    }

    // MARK: - The events

    /// An event: the owner did something, which the rules read.
    public struct Event<DonationInfo>: Identifiable, Sendable where DonationInfo: Decodable, DonationInfo: Encodable,
                                                   DonationInfo: Sendable {
        public typealias ID = String
        public typealias Value = DonationInfo

        /// The name the datastore knows the event by.
        public let id: String
        /// What the event carries, and when it happened.
        public private(set) var donations: [Donation]

        /// What one event carried.
        public struct Donation: Codable, Sendable {
            /// The value the event carried, read back by the name the app wrote.
            public let value: [String: String]
            /// When it happened.
            public let date: Date

            public init(value: [String: String] = [:], date: Date = Date()) {
                self.value = value
                self.date = date
            }

            /// The value under a name, of the type the app wrote it as: the rule's key path over the
            /// values this donation carries, which is the spelling the framework's own uses.
            public subscript<Output>(dynamicMember keyPath: KeyPath<[String: String], Output>) -> Output? {
                for name in CharonDonationKeys.of(keyPath) {
                    if let found: Output = self.value[name] as? Output { return found }
                }
                return nil
            }

            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.value = try container.decodeIfPresent([String: String].self, forKey: .value) ?? [:]
                self.date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date(timeIntervalSince1970: 0)
            }

            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(value, forKey: .value)
                try container.encode(date, forKey: .date)
            }

            private enum CodingKeys: String, CodingKey {
                case value
                case date
            }
        }

        public init(id: String) {
            self.id = id
            self.donations = []
        }

        public init(id: String, donationLimit: DonationLimit?) {
            self.id = id
            self.donations = []
        }

        /// Record that the owner did this, with nothing else.
        public func donate() async where DonationInfo == EmptyDonation {
            await sendDonation(EmptyDonation())
        }

        /// Record that the owner did this, with what the event carries.
        public func donate(_ donation: DonationInfo) async {
            await sendDonation(donation)
        }

        /// Record that the owner did this, with nothing else, and tell the app when it is stored.
        public func sendDonation(_ completion: (@Sendable () -> Void)? = nil) where DonationInfo == EmptyDonation {
            sendDonation(EmptyDonation(), completion)
        }

        /// Record that the owner did this, and tell the app when it is stored.
        public func sendDonation(_ donation: DonationInfo, _ completion: (@Sendable () -> Void)? = nil) {
            Store.shared.record(id: id, value: Store.values(of: donation))
            completion?()
        }

        /// Take the event's donations out of the store, which is what a test and a reset do.
        public func deleteDonations() async throws {
            Store.shared.delete(id: id)
        }
    }

    /// The event that carries nothing, which is what most events are.
    public struct EmptyDonation: Codable, Sendable {
        public init() {}
        public init(from decoder: any Decoder) throws {}
        public func encode(to encoder: any Encoder) throws {}
    }

    /// What a rule reads over the donations: the events, and how far back.
    public struct DonationTimeRange: Hashable, Codable, Sendable {
        /// The range as the datastore keeps it: a number and a unit.
        public let count: Int
        /// The unit the count is in: minutes, hours, days or weeks.
        public let unit: String

        public init(count: Int, unit: String) {
            self.count = count
            self.unit = unit
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.count = try container.decode(Int.self, forKey: .count)
            self.unit = try container.decode(String.self, forKey: .unit)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(count, forKey: .count)
            try container.encode(unit, forKey: .unit)
        }

        private enum CodingKeys: String, CodingKey {
            case count
            case unit
        }

        public static func minutes(_ count: Int) -> DonationTimeRange {
            return DonationTimeRange(count: count, unit: "minutes")
        }
        public static func hours(_ count: Int) -> DonationTimeRange {
            return DonationTimeRange(count: count, unit: "hours")
        }
        public static func days(_ count: Int) -> DonationTimeRange {
            return DonationTimeRange(count: count, unit: "days")
        }
        public static func weeks(_ count: Int) -> DonationTimeRange {
            return DonationTimeRange(count: count, unit: "weeks")
        }

        /// A range of one minute.
        public static var minute: DonationTimeRange { return .minutes(1) }
        /// A range of one hour.
        public static var hour: DonationTimeRange { return .hours(1) }
        /// A range of one day.
        public static var day: DonationTimeRange { return .days(1) }
        /// A range of one week.
        public static var week: DonationTimeRange { return .weeks(1) }

        public static func == (a: DonationTimeRange, b: DonationTimeRange) -> Bool {
            return a.count == b.count && a.unit == b.unit
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(count)
            hasher.combine(unit)
        }

        public var hashValue: Int { return count.hashValue ^ unit.hashValue }

        /// The date before which a donation does not count, which is what the range means.
        public func start(before now: Date) -> Date {
            let seconds: TimeInterval
            switch unit {
            case "minutes": seconds = TimeInterval(count) * 60
            case "hours": seconds = TimeInterval(count) * 3600
            case "weeks": seconds = TimeInterval(count) * 604800
            default: seconds = TimeInterval(count) * 86400
            }
            return now.addingTimeInterval(-seconds)
        }
    }

    /// What the datastore keeps of one event.
    public struct DonationLimit: Sendable {
        /// How many donations are kept, or nothing for all of them.
        public let maximumCount: Int?
        /// How old a donation may be and still be kept.
        public let maximumAge: TimeInterval?

        public init(maximumCount: Int? = nil, maximumAge: TimeInterval? = nil) {
            self.maximumCount = maximumCount
            self.maximumAge = maximumAge
        }
    }
}
