import Foundation
#if REVENANT_CARRIES_LOCALIZED_STRING
import AppIntents
#endif

public protocol Tip {
    var title: Title { get }
    var message: Message? { get }
    var image: Image? { get }
    var actions: [Action] { get }
    var rules: [Rule] { get }
    var options: [Option] { get }
    var id: ID { get }
    typealias ID = String
    typealias Title = LocalizedStringResource
    typealias Message = LocalizedStringResource
    typealias Image = LocalizedStringResource
    typealias Action = Tips.Action
    typealias Rule = Tips.Rule
    typealias Option = Tips.TipOption
    typealias Status = Tips.Status
    typealias InvalidationReason = Tips.InvalidationReason
    typealias Event = Tips.Event<Tips.EmptyDonation>
    typealias IgnoresDisplayFrequency = Tips.IgnoresDisplayFrequency
    typealias MaxDisplayCount = Tips.MaxDisplayCount
    typealias MaxDisplayDuration = Tips.MaxDisplayDuration

    var status: Status { get }
    var statusUpdates: AsyncStream<Status> { get }
    var shouldDisplay: Bool { get }
    var shouldDisplayUpdates: AsyncMapSequence<AsyncStream<Status>, Bool> { get }

    func invalidate(reason: InvalidationReason)
    func resetEligibility() async
}

public struct AnyTip: Tip {
    public typealias ID = String

    public let id: String
    public let title: LocalizedStringResource
    public let message: LocalizedStringResource?
    public let image: LocalizedStringResource?
    public let actions: [Tips.Action]
    public let rules: [Tips.Rule]
    public let options: [Tips.TipOption]
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

public enum Tips {
    public enum Status: Hashable, Sendable {
        case pending
        case available
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

    public enum InvalidationReason: Hashable, Sendable {
        case actionPerformed
        case displayCountExceeded
        case displayDurationExceeded
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

    public struct Action: Identifiable, Sendable {
        public typealias ID = String

        public let id: String
        public let title: LocalizedStringResource?
        public let handler: @Sendable () -> Void
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

        public var label: LocalizedStringResource? { return title }
    }

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

    public protocol RuleInput {
        var donations: [Event<EmptyDonation>.Donation] { get }
    }

    public struct Rule: Sendable {
        public enum CompoundOperation: Hashable, Sendable {
            case conjunction
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

        public let condition: any EventPredicateExpression
        public let operation: CompoundOperation

        public init(_ condition: any EventPredicateExpression) {
            self.condition = condition
            self.operation = .conjunction
        }

        public init(_ conditions: [any EventPredicateExpression], _ operation: CompoundOperation) {
            self.condition = RevenantAnyPredicate(conditions: conditions, operation: operation)
            self.operation = operation
        }
    }

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

    struct RevenantAnyPredicate: EventPredicateExpression {
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

    public protocol TipOption: Sendable {
        var id: String { get }
    }

    public struct IgnoresDisplayFrequency: TipOption {
        public let id: String

        public init(_ id: String = "ignoresDisplayFrequency") {
            self.id = id
        }
    }

    public struct MaxDisplayCount: TipOption {
        public let id: String
        public let count: Int

        public init(_ count: Int) {
            self.id = "maxDisplayCount"
            self.count = count
        }
    }

    public struct MaxDisplayDuration: TipOption {
        public let id: String
        public let duration: TimeInterval

        public init(_ duration: TimeInterval) {
            self.id = "maxDisplayDuration"
            self.duration = duration
        }
    }

    public struct ParameterOption: Sendable, Equatable {
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

    public struct Parameter<Value>: Identifiable, Sendable where Value: Decodable, Value: Encodable, Value: Sendable {
        public typealias ID = String
        public typealias Value = Value

        public let id: String
        public var wrappedValue: Value
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

    public struct Event<DonationInfo>: Identifiable, Sendable where DonationInfo: Decodable, DonationInfo: Encodable,
                                                   DonationInfo: Sendable {
        public typealias ID = String
        public typealias Value = DonationInfo

        public let id: String
        public private(set) var donations: [Donation]

        public struct Donation: Codable, Sendable {
            public let value: [String: String]
            public let date: Date

            public init(value: [String: String] = [:], date: Date = Date()) {
                self.value = value
                self.date = date
            }

            public subscript<Output>(dynamicMember keyPath: KeyPath<[String: String], Output>) -> Output? {
                for name in RevenantDonationKeys.of(keyPath) {
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

        public func donate() async where DonationInfo == EmptyDonation {
            await sendDonation(EmptyDonation())
        }

        public func donate(_ donation: DonationInfo) async {
            await sendDonation(donation)
        }

        public func sendDonation(_ completion: (@Sendable () -> Void)? = nil) where DonationInfo == EmptyDonation {
            sendDonation(EmptyDonation(), completion)
        }

        public func sendDonation(_ donation: DonationInfo, _ completion: (@Sendable () -> Void)? = nil) {
            Store.shared.record(id: id, value: Store.values(of: donation))
            completion?()
        }

        public func deleteDonations() async throws {
            Store.shared.delete(id: id)
        }
    }

    public struct EmptyDonation: Codable, Sendable {
        public init() {}
        public init(from decoder: any Decoder) throws {}
        public func encode(to encoder: any Encoder) throws {}
    }

    public struct DonationTimeRange: Hashable, Codable, Sendable {
        public let count: Int
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

        public static var minute: DonationTimeRange { return .minutes(1) }
        public static var hour: DonationTimeRange { return .hours(1) }
        public static var day: DonationTimeRange { return .days(1) }
        public static var week: DonationTimeRange { return .weeks(1) }

        public static func == (a: DonationTimeRange, b: DonationTimeRange) -> Bool {
            return a.count == b.count && a.unit == b.unit
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(count)
            hasher.combine(unit)
        }

        public var hashValue: Int { return count.hashValue ^ unit.hashValue }

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

    public struct DonationLimit: Sendable {
        public let maximumCount: Int?
        public let maximumAge: TimeInterval?

        public init(maximumCount: Int? = nil, maximumAge: TimeInterval? = nil) {
            self.maximumCount = maximumCount
            self.maximumAge = maximumAge
        }
    }
}
