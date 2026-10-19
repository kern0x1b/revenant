import Foundation

public protocol _IntentValue {
    associatedtype ValueType: _IntentValue = Self
    associatedtype UnwrappedType: _IntentValue = Self
    associatedtype Specification: ResolverSpecification
    static var defaultResolverSpecification: Specification { get }
}

public protocol AnyIntentValue: Sendable {
    associatedtype Value: _IntentValue
    var isOptional: Bool { get }
    var title: LocalizedStringResource { get }
}

public protocol AppValue: PersistentlyIdentifiable, TypeDisplayRepresentable, _IntentValue, Sendable {}

public protocol _IntentValueRepresentable: _IntentValue {
    static var allIntentValueTypes: [any _IntentValue.Type] { get }
    var asIntentValue: any _IntentValue { get }
}

public protocol _SequenceIntentValue: _IntentValue {
    associatedtype Element: _IntentValue
    var sequence: [Element.ValueType] { get }
}

public protocol RangeComparableProperty: _IntentValue, Comparable {}

public struct IntentParameterContext<Value>: AnyIntentValue, @unchecked Sendable
    where Value: _IntentValue, Value: Sendable {
    public struct Storage: @unchecked Sendable {
        public var title: LocalizedStringResource
        public var isOptional: Bool
        public var controlStyle: ControlStyle?
        public var currencyCodes: [String]?
        public var dateKind: IntentParameter<Int>.DateKind?
        public var defaultUnit: (any Hashable)?
        public var descriptionText: LocalizedStringResource?
        public var displayName: (any Hashable)?
        public var displayStyle: (any Hashable)?
        public var inclusiveRange: AnyRange?
        public var inputOptions: String.IntentInputOptions?
        public var parameterMode: (any Hashable)?
        public var size: IntentCollectionSize?
        public var supportedContentTypes: [String]?
        public var supportedValues: [Value.UnwrappedType]?
        public var requestValueDialog: IntentDialog?
        public var requestDisambiguationDialog: IntentDialog?
        public var inputConnectionBehavior: InputConnectionBehavior
        public var unit: (any Hashable)?
        public var unitAdjustForLocale: Bool?
        public var defaultUnitAdjustForLocale: Bool?
        public var supportsNegativeNumbers: Bool?
        public var optionsProvider: (any DynamicOptionsProvider)?
        public var query: (any EntityStringQuery)?

        public init(title: LocalizedStringResource, isOptional: Bool = false) {
            self.title = title
            self.isOptional = isOptional
            self.inputConnectionBehavior = .default
        }
    }

    public enum ControlStyle: Hashable {
        case integer(IntentParameter<Int>.IntControlStyle)
        case double(IntentParameter<Double>.DoubleControlStyle)

        public init(any style: (any Hashable)?) {
            if let style = style as? IntentParameter<Int>.IntControlStyle {
                self = .integer(style)
            } else if let style = style as? IntentParameter<Double>.DoubleControlStyle {
                self = .double(style)
            } else {
                self = .double(.stepper)
            }
        }

        public var anyHashable: (any Hashable)? {
            switch self {
            case .integer(let style): return style
            case .double(let style): return style
            }
        }
    }

    public var storage: Storage

    public var isOptional: Bool {
        get { storage.isOptional }
        set { storage.isOptional = newValue }
    }

    public var title: LocalizedStringResource {
        get { storage.title }
        set { storage.title = newValue }
    }

    public init(isOptional: Bool = false, title: LocalizedStringResource) {
        storage = Storage(title: title, isOptional: isOptional)
    }

    init(_ storage: Storage) {
        self.storage = storage
    }
}

public struct AnyRange: @unchecked Sendable {
    private let containsValue: @Sendable (Any) -> Bool

    public init<Bound: RangeComparableProperty>(_ range: IntentParameterValueRange<Bound>) {
        containsValue = { any in
            guard let value = any as? Bound else { return false }
            return range.lowerBound <= value && value <= range.upperBound
        }
    }

    public init<Bound: RangeComparableProperty>(_ range: ClosedRange<Bound>) {
        containsValue = { any in
            guard let value = any as? Bound else { return false }
            return range.lowerBound <= value && value <= range.upperBound
        }
    }

    public init<Bound: RangeComparableProperty>(lowerBound: Bound, upperBound: Bound) {
        containsValue = { any in
            guard let value = any as? Bound else { return false }
            return lowerBound <= value && value <= upperBound
        }
    }

    public func contains(_ value: Any) -> Bool { return containsValue(value) }
}

public struct IntentParameterValueRange<Bound: RangeComparableProperty> {
    public let lowerBound: Bound
    public let upperBound: Bound

    public init(_ range: ClosedRange<Bound>) {
        lowerBound = range.lowerBound
        upperBound = range.upperBound
    }

    public init(lowerBound: Bound, upperBound: Bound) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public func contains(_ value: Bound) -> Bool { return lowerBound <= value && value <= upperBound }
}

public protocol ResolverSpecification: Hashable, Sendable, Sequence where Element == any Resolver {
    associatedtype Output: _IntentValue
}

public struct EmptyResolverSpecification<Value: _IntentValue>: ResolverSpecification {
    public typealias Output = Value

    public init() {}

    public func makeIterator() -> IndexingIterator<[any Resolver]> { return [any Resolver]().makeIterator() }



}

public protocol Resolver: Hashable, Sendable {
    associatedtype Input: _IntentValue
    associatedtype Output: _IntentValue
    func resolve(from input: Self.Input, context: IntentParameterContext<Self.Output>) async throws -> Self.Output?
}

extension Resolver {
    public typealias Context = IntentParameterContext
}

public protocol RangeCheckingResolver: Resolver {}

extension RangeCheckingResolver {
    public func checkParameterRangeContains<Value>(value: Value,
                                                    context: IntentParameterContext<Self.Output>) throws -> Bool
        where Value: RangeComparableProperty, Value == Self.Output.ValueType, Self.Output: Sendable {
        guard let range = context.inclusiveRange else { return true }
        return range.contains(value)
    }
}

extension IntentParameterContext {
    public var inclusiveRange: AnyRange? { return storage.inclusiveRange }
    public var controlStyle: (any Hashable)? { return storage.controlStyle?.anyHashable }
    public var currencyCodes: [String]? { return storage.currencyCodes }
    public var dateKind: IntentParameter<Int>.DateKind? { return storage.dateKind }
    public var defaultUnit: (any Hashable)? { return storage.defaultUnit }
    public var displayName: (any Hashable)? { return storage.displayName }
    public var displayStyle: (any Hashable)? { return storage.displayStyle }
    public var inputOptions: String.IntentInputOptions? { return storage.inputOptions }
    public var parameterMode: (any Hashable)? { return storage.parameterMode }
    public var supportsNegativeNumbers: Bool? { return storage.supportsNegativeNumbers }
    public var unit: (any Hashable)? { return storage.unit }
    public var unitAdjustForLocale: Bool? { return storage.unitAdjustForLocale }
}

public struct IntFromStringResolver: RangeCheckingResolver {
    public typealias Input = String
    public typealias Output = Int

    public let radix: Int

    public init(radix: Int = 10) {
        self.radix = radix
    }

    public func resolve(from input: String, context: IntentParameterContext<Int>) async throws -> Int? {
        return Int(input, radix: radix)
    }

    public static func == (a: IntFromStringResolver, b: IntFromStringResolver) -> Bool { return a.radix == b.radix }

    public func hash(into hasher: inout Hasher) { hasher.combine(radix) }
}

public struct DoubleFromStringResolver: RangeCheckingResolver {
    public typealias Input = String
    public typealias Output = Double

    public init() {}

    public func resolve(from input: String, context: IntentParameterContext<Double>) async throws -> Double? {
        return Double(input)
    }


}

public struct BoolFromStringResolver: Resolver {
    public typealias Input = String
    public typealias Output = Bool

    public init() {}

    public func resolve(from input: String, context: IntentParameterContext<Bool>) async throws -> Bool? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch text {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }


}

public struct URLFromStringResolver: Resolver {
    public typealias Input = String
    public typealias Output = URL

    public init() {}

    public func resolve(from input: String, context: IntentParameterContext<URL>) async throws -> URL? {
        return URL(string: input)
    }


}

public struct StringFromIntResolver: Resolver {
    public typealias Input = Int
    public typealias Output = String

    public init() {}

    public func resolve(from input: Int, context: IntentParameterContext<String>) async throws -> String? {
        return String(input)
    }


}

public struct StringFromDoubleResolver: Resolver {
    public typealias Input = Double
    public typealias Output = String

    public init() {}

    public func resolve(from input: Double, context: IntentParameterContext<String>) async throws -> String? {
        return String(input)
    }


}

public struct IntFromDoubleResolver: RangeCheckingResolver {
    public typealias Input = Double
    public typealias Output = Int

    public enum RoundingRule: Hashable, Sendable {
        case toNearestOrDown
        case toNearestOrUp
        case down
        case up
    }

    public let roundingRule: RoundingRule

    public init(roundingRule: RoundingRule) {
        self.roundingRule = roundingRule
    }

    public func resolve(from input: Double, context: IntentParameterContext<Int>) async throws -> Int? {
        switch roundingRule {
        case .toNearestOrDown: return Int(input.rounded(.toNearestOrAwayFromZero))
        case .toNearestOrUp: return Int(input.rounded(.toNearestOrAwayFromZero))
        case .down: return Int(input.rounded(.down))
        case .up: return Int(input.rounded(.up))
        }
    }

    public static func == (a: IntFromDoubleResolver, b: IntFromDoubleResolver) -> Bool { return a.roundingRule == b.roundingRule }

    public func hash(into hasher: inout Hasher) { hasher.combine(roundingRule) }
}

public struct IntResolver: RangeCheckingResolver {
    public typealias Input = String
    public typealias Output = Int

    public init() {}

    public func resolve(from input: String, context: IntentParameterContext<Int>) async throws -> Int? {
        return Int(input)
    }


}

public struct DoubleResolver: RangeCheckingResolver {
    public typealias Input = String
    public typealias Output = Double

    public init() {}

    public func resolve(from input: String, context: IntentParameterContext<Double>) async throws -> Double? {
        return Double(input)
    }


}

public struct DoubleFromIntResolver: RangeCheckingResolver {
    public typealias Input = Int
    public typealias Output = Double

    public init() {}

    public func resolve(from input: Int, context: IntentParameterContext<Double>) async throws -> Double? {
        return Double(input)
    }


}

public struct StringSearchCriteriaFromStringResolverSpecificification: Resolver {
    public typealias Input = String
    public typealias Output = StringSearchCriteria

    public init() {}

    public func resolve(from input: String,
                        context: IntentParameterContext<StringSearchCriteria>) async throws -> StringSearchCriteria? {
        return StringSearchCriteria(term: input)
    }

    public static func == (a: StringSearchCriteriaFromStringResolverSpecificification,
                           b: StringSearchCriteriaFromStringResolverSpecificification) -> Bool { return true }

}

public extension String {
    struct IntentInputOptions {
        public enum KeyboardType: Hashable, Sendable {
            case `default`
            case asciiCapable
            case numbersAndPunctuation
            case URL
            case numberPad

            public static func == (a: KeyboardType, b: KeyboardType) -> Bool { true }
        }

        public enum CapitalizationType: Hashable, Sendable {
            case none
            case words
            case sentences
            case allCharacters

            public static func == (a: CapitalizationType, b: CapitalizationType) -> Bool { true }
        }

        public var keyboardType: KeyboardType
        public var capitalizationType: CapitalizationType
        public var multiline: Bool
        public var autocorrect: Bool
        public var smartQuotes: Bool
        public var smartDashes: Bool

        public init(keyboardType: KeyboardType = .default, capitalizationType: CapitalizationType = .none,
                    multiline: Bool = false, autocorrect: Bool = true, smartQuotes: Bool = true,
                    smartDashes: Bool = true) {
            self.keyboardType = keyboardType
            self.capitalizationType = capitalizationType
            self.multiline = multiline
            self.autocorrect = autocorrect
            self.smartQuotes = smartQuotes
            self.smartDashes = smartDashes
        }
    }
}

extension Array: ResultsCollection where Element: _IntentValue, Element == Element.ValueType {
    public typealias Result = Element

    public static var empty: [Element] { return [] }
    public var promptLabel: LocalizedStringResource? { return nil }
    public var usesIndexedCollation: Bool { return false }
    public var items: [Result.ValueType] { return self }
}
