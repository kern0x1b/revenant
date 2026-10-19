import Foundation

public protocol EventPredicateExpression {
    associatedtype Output
    func evaluate(_ input: any Tips.RuleInput) -> Bool
}

public enum PredicateExpressions {
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

    public struct DonationFilter: EventPredicateExpression {
        public typealias Output = Bool

        public let eventID: String
        public let keyPath: String
        public let op: DonationFilterOperator
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

    public struct DonatedWithin: EventPredicateExpression {
        public typealias Output = Bool

        public let eventID: String
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

    public struct LargestSubset: EventPredicateExpression {
        public typealias Output = [Tips.Event<Tips.EmptyDonation>.Donation]

        public let input: DonationFilter
        public let keyPath: String

        public func select(_ donations: any Tips.RuleInput) -> [Tips.Event<Tips.EmptyDonation>.Donation] {
            return CharonDonationSubset.largest(of: CharonDonationSubset.candidates(
                donations.donations, eventID: input.eventID, keyPath: keyPath, value: input.value, op: input.op))
        }

        public func evaluate(_ donations: any Tips.RuleInput) -> Bool { return select(donations).isEmpty == false }
    }

    public struct SmallestSubset: EventPredicateExpression {
        public typealias Output = [Tips.Event<Tips.EmptyDonation>.Donation]

        public let input: DonationFilter
        public let keyPath: String

        public func select(_ donations: any Tips.RuleInput) -> [Tips.Event<Tips.EmptyDonation>.Donation] {
            return CharonDonationSubset.smallest(of: CharonDonationSubset.candidates(
                donations.donations, eventID: input.eventID, keyPath: keyPath, value: input.value, op: input.op))
        }

        public func evaluate(_ donations: any Tips.RuleInput) -> Bool { return select(donations).isEmpty == false }
    }

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

enum CharonDonationValue {
    static func read(_ donation: Tips.Event<Tips.EmptyDonation>.Donation, eventID: String,
                     key: String) -> String? {
        let values: [String: String] = donation.value
        guard values[eventID] != nil else { return nil }
        if let value: String = values[key] { return value }
        return values.count == 1 ? values.values.first : nil
    }

    static func has(_ donation: Tips.Event<Tips.EmptyDonation>.Donation, eventID: String) -> Bool {
        let values: [String: String] = donation.value
        return values[eventID] != nil
    }
}

enum CharonDonationDate {
    static func isAfter(_ donation: Any, _ date: Date) -> Bool {
        guard let donation = donation as? Tips.Event<CharonAnyDonation>.Donation else { return false }
        return donation.date >= date
    }
}

public struct CharonAnyDonation: Codable, Sendable {
    public let value: [String: String]
    public let date: Date

    public init(value: [String: String] = [:], date: Date = Date()) {
        self.value = value
        self.date = date
    }
}

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

enum CharonDonationSubset {
    static func number(_ found: String, _ wanted: String, _ accept: (Int) -> Bool) -> Bool {
        guard let left = Double(found), let right = Double(wanted) else { return false }
        if left < right { return accept(-1) }
        if left > right { return accept(1) }
        return accept(0)
    }

    static func groups(_ donations: [Tips.Event<Tips.EmptyDonation>.Donation], eventID: String,
                       keyPath: String) -> [String: [Tips.Event<Tips.EmptyDonation>.Donation]] {
        var grouped: [String: [Tips.Event<Tips.EmptyDonation>.Donation]] = [:]
        for donation in donations {
            guard let group: String = CharonDonationValue.read(donation, eventID: eventID, key: keyPath) else { continue }
            grouped[group, default: []].append(donation)
        }
        return grouped
    }

    static func candidates(_ donations: [Tips.Event<Tips.EmptyDonation>.Donation], eventID: String, keyPath: String,
                           value: String,
                           op: PredicateExpressions.DonationFilterOperator) -> [String: [Tips.Event<Tips.EmptyDonation>.Donation]] {
        return groups(donations, eventID: eventID, keyPath: keyPath).filter {
            CharonDonationCompare.compare($0.key, value, op)
        }
    }

    static func largest(of grouped: [String: [Tips.Event<Tips.EmptyDonation>.Donation]]) -> [Tips.Event<Tips.EmptyDonation>.Donation] {
        return grouped.sorted { $0.key < $1.key }.last.map { $0.value } ?? []
    }

    static func smallest(of grouped: [String: [Tips.Event<Tips.EmptyDonation>.Donation]]) -> [Tips.Event<Tips.EmptyDonation>.Donation] {
        return grouped.sorted { $0.key < $1.key }.first.map { $0.value } ?? []
    }
}

extension Sequence {
    public func donatedWithin<DonationInfo>(_ timeRange: Tips.DonationTimeRange) -> [Element]
        where Element == Tips.Event<DonationInfo>.Donation {
        let start = timeRange.start(before: Date())
        return filter { (donation: Element) -> Bool in CharonDonationDate.isAfter(donation, start) }
    }

    public func largestSubset<DonationInfo, Value>(groupedBy keyPath: KeyPath<DonationInfo, Value>) -> Self
        where Element == Tips.Event<DonationInfo>.Donation {
        return self
    }

    public func smallestSubset<DonationInfo, Value>(groupedBy keyPath: KeyPath<DonationInfo, Value>) -> Self
        where Element == Tips.Event<DonationInfo>.Donation {
        return self
    }
}

enum CharonDonationKeys {
    static func of<Output>(_ keyPath: KeyPath<[String: String], Output>) -> [String] {
        return CharonKeyPathNames.read(keyPath)
    }
}

enum CharonKeyPathNames {
    static func read<Root, Value>(_ keyPath: KeyPath<Root, Value>) -> [String] {
        let written = keyPath.debugDescription
        guard let start = written.firstIndex(of: ".") else { return [] }
        let name = written[written.index(after: start)...].trimmingCharacters(in: CharacterSet(charactersIn: " .]"))
        return name.isEmpty ? [] : [name]
    }
}
