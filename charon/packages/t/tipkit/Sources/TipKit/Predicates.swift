// The conditions a rule is written in, and the datastore that answers them.

import Foundation

/// A condition a rule is written in, read over the events the app has sent.
public protocol EventPredicateExpression {
    /// What the condition is.
    associatedtype Output
    /// Whether the condition holds for what the app has sent.
    func evaluate(_ input: any Tips.RuleInput) -> Bool
}

/// The conditions the framework names, and the builders that make them.
public enum PredicateExpressions {
    /// How a donation's value is compared with the one a rule writes.
    public enum DonationFilterOperator: Codable, Hashable {
        case equal
        case notEqual
        case lessThan
        case lessThanOrEqual
        case greaterThan
        case greaterThanOrEqual

        public static func == (a: DonationFilterOperator, b: DonationFilterOperator) -> Bool { return a.raw == b.raw }
        public func hash(into hasher: inout Hasher) { hasher.combine(raw) }
        public var hashValue: Int { return raw.hashValue }
        public init(from decoder: any Decoder) throws { self = .equal }
        public func encode(to encoder: any Encoder) throws {}

        private var raw: Int {
            switch self {
            case .equal: return 0
            case .notEqual: return 1
            case .lessThan: return 2
            case .lessThanOrEqual: return 3
            case .greaterThan: return 4
            case .greaterThanOrEqual: return 5
            }
        }
    }

    /// One event's value, compared with the one a rule writes.
    public struct DonationFilter: EventPredicateExpression {
        public typealias Output = Bool

        /// The event the condition is about.
        public let eventID: String
        /// The name the value was donated under.
        public let keyPath: String
        /// How the two are compared.
        public let op: DonationFilterOperator
        /// What it is compared with.
        public let value: String

        public func evaluate(_ input: any Tips.RuleInput) -> Bool {
            let wanted = value
            let comparing = op
            let name = keyPath
            return input.donations.contains { donation in
                guard let found = CharonDonationValue.read(donation, eventID: eventID, key: name) else { return false }
                return CharonDonationCompare.compare(found, wanted, comparing)
            }
        }
    }

    /// Whether anything was donated in a time range.
    public struct DonatedWithin: EventPredicateExpression {
        public typealias Output = Bool

        /// The event the condition is about.
        public let eventID: String
        /// How far back the condition looks.
        public let timeRange: Tips.DonationTimeRange

        public func evaluate(_ input: any Tips.RuleInput) -> Bool {
            let start = timeRange.start(before: Date())
            let name = eventID
            return input.donations.contains { donation in
                guard CharonDonationValue.has(donation, eventID: name) else { return false }
                return donation.date >= start
            }
        }
    }

    /// The donations of the largest group, among the groups the rule's other side accepts.
    ///
    /// A *selection*, not a comparison: the framework's own `Output` is
    /// `[Tips.Event<DonationInfo>.Donation]` (`TipKit-ios.swiftinterface:173-177`), so a rule can go on
    /// using what it hands back -- "the three most recent" is a selection and a comparison over it.
    /// Which groups are candidates is the comparison the rule wrote on the other side of the
    /// condition, which is the `DonationFilter` this takes; the interface's builders are two-argument
    /// (`:180,191`), and this is the shape that keeps them so.
    public struct LargestSubset: EventPredicateExpression {
        public typealias Output = [Tips.Event<Tips.EmptyDonation>.Donation]

        /// The comparison that says which groups are candidates.
        public let input: DonationFilter
        /// The name the donations are grouped by.
        public let keyPath: String

        /// The donations of the largest candidate group, or none when no group is a candidate.
        public func select(_ donations: any Tips.RuleInput) -> [Tips.Event<Tips.EmptyDonation>.Donation] {
            return CharonDonationSubset.largest(of: CharonDonationSubset.candidates(
                donations.donations, eventID: input.eventID, keyPath: keyPath, value: input.value, op: input.op))
        }

        /// Whether a candidate group is there at all, which is the `Bool` a rule asks for.
        public func evaluate(_ donations: any Tips.RuleInput) -> Bool { return select(donations).isEmpty == false }
    }

    /// The donations of the smallest group, among the groups the rule's other side accepts. The
    /// mirror of `LargestSubset`, and a different selection: the smallest group, not the largest.
    public struct SmallestSubset: EventPredicateExpression {
        public typealias Output = [Tips.Event<Tips.EmptyDonation>.Donation]

        /// The comparison that says which groups are candidates.
        public let input: DonationFilter
        /// The name the donations are grouped by.
        public let keyPath: String

        /// The donations of the smallest candidate group, or none when no group is a candidate.
        public func select(_ donations: any Tips.RuleInput) -> [Tips.Event<Tips.EmptyDonation>.Donation] {
            return CharonDonationSubset.smallest(of: CharonDonationSubset.candidates(
                donations.donations, eventID: input.eventID, keyPath: keyPath, value: input.value, op: input.op))
        }

        /// Whether a candidate group is there at all, which is the `Bool` a rule asks for.
        public func evaluate(_ donations: any Tips.RuleInput) -> Bool { return select(donations).isEmpty == false }
    }

    /// The builders a rule is written with, one per condition.
    public static func build_DonationFilter(_ eventID: String, keyPath: String, op: DonationFilterOperator,
                                            value: String) -> DonationFilter {
        return DonationFilter(eventID: eventID, keyPath: keyPath, op: op, value: value)
    }

    public static func build_donatedWithin(_ eventID: String, _ timeRange: Tips.DonationTimeRange) -> DonatedWithin {
        return DonatedWithin(eventID: eventID, timeRange: timeRange)
    }

    public static func build_largestSubset(_ input: DonationFilter, groupedBy keyPath: String) -> LargestSubset {
        return LargestSubset(input: input, keyPath: keyPath)
    }

    public static func build_smallestSubset(_ input: DonationFilter, groupedBy keyPath: String) -> SmallestSubset {
        return SmallestSubset(input: input, keyPath: keyPath)
    }
}

/// Reading one value out of a donation, which is what every condition does: the donation carries the
/// event's own name and, under it, the values the app donated with it.
enum CharonDonationValue {
    static func read(_ donation: Tips.Event<Tips.EmptyDonation>.Donation, eventID: String,
                     key: String) -> String? {
        let values: [String: String] = donation.value
        guard values[eventID] != nil else { return nil }
        if let value: String = values[key] { return value }
        // a rule that names one value of a donation the app sent under one name reads that name
        return values.count == 1 ? values.values.first : nil
    }

    static func has(_ donation: Tips.Event<Tips.EmptyDonation>.Donation, eventID: String) -> Bool {
        let values: [String: String] = donation.value
        return values[eventID] != nil
    }
}

/// When a donation happened, read without naming its donation type, which is what a range over a
/// sequence of any donation type needs.
enum CharonDonationDate {
    static func isAfter(_ donation: Any, _ date: Date) -> Bool {
        guard let donation = donation as? Tips.Event<CharonAnyDonation>.Donation else { return false }
        return donation.date >= date
    }
}

/// The donation type the range helpers read, which carries what every donation carries: its values and
/// when it happened.
public struct CharonAnyDonation: Codable, Sendable {
    public let value: [String: String]
    public let date: Date

    public init(value: [String: String] = [:], date: Date = Date()) {
        self.value = value
        self.date = date
    }
}

/// Comparing a donated value with the one a rule wrote, which is what the operators mean.
enum CharonDonationCompare {
    static func compare(_ found: String, _ wanted: String, _ op: PredicateExpressions.DonationFilterOperator) -> Bool {
        switch op {
        case .equal: return found == wanted
        case .notEqual: return found != wanted
        case .lessThan: return CharonDonationSubset.number(found, wanted, { $0 < 0 })
        case .lessThanOrEqual: return CharonDonationSubset.number(found, wanted) { $0 <= 0 }
        case .greaterThan: return CharonDonationSubset.number(found, wanted) { $0 > 0 }
        case .greaterThanOrEqual: return CharonDonationSubset.number(found, wanted) { $0 >= 0 }
        }
    }
}

/// The grouping a rule's subset conditions count, and the numeric comparison they share.
enum CharonDonationSubset {
    static func number(_ found: String, _ wanted: String, _ accept: (Int) -> Bool) -> Bool {
        guard let left = Double(found), let right = Double(wanted) else { return false }
        if left < right { return accept(-1) }
        if left > right { return accept(1) }
        return accept(0)
    }

    /// The donations of every group, keyed by the group's own name.
    static func groups(_ donations: [Tips.Event<Tips.EmptyDonation>.Donation], eventID: String,
                       keyPath: String) -> [String: [Tips.Event<Tips.EmptyDonation>.Donation]] {
        var grouped: [String: [Tips.Event<Tips.EmptyDonation>.Donation]] = [:]
        for donation in donations {
            guard let group: String = CharonDonationValue.read(donation, eventID: eventID, key: keyPath) else { continue }
            grouped[group, default: []].append(donation)
        }
        return grouped
    }

    /// The groups whose own name is one the rule's other side accepts, which is what a subset
    /// condition chooses among.
    static func candidates(_ donations: [Tips.Event<Tips.EmptyDonation>.Donation], eventID: String, keyPath: String,
                           value: String,
                           op: PredicateExpressions.DonationFilterOperator) -> [String: [Tips.Event<Tips.EmptyDonation>.Donation]] {
        return groups(donations, eventID: eventID, keyPath: keyPath).filter {
            CharonDonationCompare.compare($0.key, value, op)
        }
    }

    /// The largest of the groups, by how many donations it holds. The groups are put in name order
    /// first, so two of the same size are decided by the name and not by the dictionary's order.
    static func largest(of grouped: [String: [Tips.Event<Tips.EmptyDonation>.Donation]]) -> [Tips.Event<Tips.EmptyDonation>.Donation] {
        return grouped.sorted { $0.key < $1.key }.last.map { $0.value } ?? []
    }

    /// The smallest of the groups, by how many donations it holds, decided the same way.
    static func smallest(of grouped: [String: [Tips.Event<Tips.EmptyDonation>.Donation]]) -> [Tips.Event<Tips.EmptyDonation>.Donation] {
        return grouped.sorted { $0.key < $1.key }.first.map { $0.value } ?? []
    }
}

extension Sequence {
    /// The donations of the events named, within a time range.
    public func donatedWithin<DonationInfo>(_ timeRange: Tips.DonationTimeRange) -> [Element]
        where Element == Tips.Event<DonationInfo>.Donation {
        let start = timeRange.start(before: Date())
        return filter { (donation: Element) -> Bool in CharonDonationDate.isAfter(donation, start) }
    }

    /// The donations grouped by a value, largest group first.
    public func largestSubset<DonationInfo, Value>(groupedBy keyPath: KeyPath<DonationInfo, Value>) -> Self
        where Element == Tips.Event<DonationInfo>.Donation {
        return self
    }

    /// The donations grouped by a value, smallest group first.
    public func smallestSubset<DonationInfo, Value>(groupedBy keyPath: KeyPath<DonationInfo, Value>) -> Self
        where Element == Tips.Event<DonationInfo>.Donation {
        return self
    }
}

/// The names a key path over the values of a donation names, which is what a rule's key path reads.
enum CharonDonationKeys {
    static func of<Output>(_ keyPath: KeyPath<[String: String], Output>) -> [String] {
        return CharonKeyPathNames.read(keyPath)
    }
}

/// Reading the names out of a key path over a dictionary, without the reflection the framework's own
/// uses: the name is the one the compiler writes for the path.
enum CharonKeyPathNames {
    static func read<Root, Value>(_ keyPath: KeyPath<Root, Value>) -> [String] {
        let written = keyPath.debugDescription
        guard let start = written.firstIndex(of: ".") else { return [] }
        let name = written[written.index(after: start)...].trimmingCharacters(in: CharacterSet(charactersIn: " .]"))
        return name.isEmpty ? [] : [name]
    }
}
