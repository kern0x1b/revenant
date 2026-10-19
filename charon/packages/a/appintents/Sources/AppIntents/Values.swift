// The value system: what an intent parameter can carry, and how a value is written as a string and
// read back from one.
//
// `_IntentValue` is the row every value type has in the ledger: a value that names a
// `ResolverSpecification` says how it is written down (its key, its resolver, its default), and the
// parameter (`IntentParameter`) carries the rest. `AnyIntentValue` is the erased view of one, which
// is what a parameter holds at run time.

import Foundation

/// A value an intent parameter can carry.
public protocol _IntentValue {
    associatedtype ValueType: _IntentValue = Self
    associatedtype UnwrappedType: _IntentValue = Self
    /// The specification that says how this value is written down and read back.
    associatedtype Specification: ResolverSpecification
    static var defaultResolverSpecification: Specification { get }
}

/// A value of a parameter, without the parameter's static type: what the framework holds at run time.
public protocol AnyIntentValue: Sendable {
    associatedtype Value: _IntentValue
    /// Whether the parameter may have no value.
    var isOptional: Bool { get }
    var title: LocalizedStringResource { get }
}

/// A value that is also an app-level value: something the app's entities and enums are made of.
public protocol AppValue: PersistentlyIdentifiable, TypeDisplayRepresentable, _IntentValue, Sendable {}

/// A value that a single type can stand for, so that a parameter can carry either (`UnionValue()`).
public protocol _IntentValueRepresentable: _IntentValue {
    static var allIntentValueTypes: [any _IntentValue.Type] { get }
    var asIntentValue: any _IntentValue { get }
}

/// A value that is a sequence of values.
public protocol _SequenceIntentValue: _IntentValue {
    associatedtype Element: _IntentValue
    var sequence: [Element.ValueType] { get }
}

/// A value that can be compared, so that a range can be checked against it.
public protocol RangeComparableProperty: _IntentValue, Comparable {}

/// What a resolver is given about the parameter it resolves for.
///
/// The context is the parameter's own metadata without its value: `isOptional` and `title` are
/// public, and the rest is what the parameter declared, read back through the same erased storage the
/// parameter writes, so a resolver sees exactly what the parameter was built with. The typed views of
/// that storage (`controlStyle` for an `Int` parameter, `inclusiveRange` for a `Double` one,
/// `currencyCodes` for an amount) are the constrained extensions of this type.
public struct IntentParameterContext<Value>: AnyIntentValue, @unchecked Sendable
    where Value: _IntentValue, Value: Sendable {
    /// Everything the parameter declared, whatever the type of its value.
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

    /// The style a numeric parameter is asked with. A number has `Int`'s and `Double`'s own styles,
    /// and the parameter carries whichever its value takes; the erased case keeps the two apart.
    public enum ControlStyle: Hashable {
        case integer(IntentParameter<Int>.IntControlStyle)
        case double(IntentParameter<Double>.DoubleControlStyle)

        /// The style as the parameter's own `controlStyle` reads it back, whichever of the two kinds
        /// of style it is.
        public init(any style: (any Hashable)?) {
            if let style = style as? IntentParameter<Int>.IntControlStyle {
                self = .integer(style)
            } else if let style = style as? IntentParameter<Double>.DoubleControlStyle {
                self = .double(style)
            } else {
                self = .double(.stepper)
            }
        }

        /// The style as the parameter's own `controlStyle` reads it back, whatever the value's type.
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

/// A range, erased: the parameter's own `InclusiveRange`, which is generic over the type it bounds,
/// carried as the two ends and the comparison of that type.
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

    /// Whether the range holds `value`, which is of the range's own bound type or is not in it.
    public func contains(_ value: Any) -> Bool { return containsValue(value) }
}

/// The range a parameter's value must be in, over the type the parameter's value takes.
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

/// A specification of resolvers: how a value of one type is written down and read back. A
/// specification is itself a sequence of resolvers, and it is what `defaultResolverSpecification`
/// names for a value that needs no special handling.
public protocol ResolverSpecification: Hashable, Sendable, Sequence where Element == any Resolver {
    associatedtype Output: _IntentValue
}

/// A specification with no resolver in it, which is what a value whose own description is its text
/// resolves through.
public struct EmptyResolverSpecification<Value: _IntentValue>: ResolverSpecification {
    public typealias Output = Value

    public init() {}

    public func makeIterator() -> IndexingIterator<[any Resolver]> { return [any Resolver]().makeIterator() }



}

/// A resolver: it turns a value of `Input` (a string, an integer, a date) into the value a parameter
/// carries, or nothing when it cannot.
public protocol Resolver: Hashable, Sendable {
    associatedtype Input: _IntentValue
    associatedtype Output: _IntentValue
    func resolve(from input: Self.Input, context: IntentParameterContext<Self.Output>) async throws -> Self.Output?
}

extension Resolver {
    public typealias Context = IntentParameterContext
}

/// A resolver that can tell whether a value is inside the parameter's inclusive range.
public protocol RangeCheckingResolver: Resolver {}

extension RangeCheckingResolver {
    /// Whether `value` is inside `context.inclusiveRange`; a value the range's type cannot compare is
    /// out of range, which is what the framework's own check answers.
    public func checkParameterRangeContains<Value>(value: Value,
                                                    context: IntentParameterContext<Self.Output>) throws -> Bool
        where Value: RangeComparableProperty, Value == Self.Output.ValueType, Self.Output: Sendable {
        guard let range = context.inclusiveRange else { return true }
        return range.contains(value)
    }
}

extension IntentParameterContext {
    /// The range a value of this parameter must be in, when the parameter declared one.
    public var inclusiveRange: AnyRange? { return storage.inclusiveRange }
    /// The style a numeric parameter of this value's type is asked with.
    public var controlStyle: (any Hashable)? { return storage.controlStyle?.anyHashable }
    /// The currencies an amount parameter of this value's type may be in.
    public var currencyCodes: [String]? { return storage.currencyCodes }
    /// Whether a date parameter of this value's type takes a date, a time or both.
    public var dateKind: IntentParameter<Int>.DateKind? { return storage.dateKind }
    /// The unit a measurement parameter of this value's type starts from.
    public var defaultUnit: (any Hashable)? { return storage.defaultUnit }
    /// The way a placemark parameter of this value's type is shown.
    public var displayName: (any Hashable)? { return storage.displayName }
    /// The way a placemark parameter of this value's type is shown.
    public var displayStyle: (any Hashable)? { return storage.displayStyle }
    /// How a string parameter of this value's type is asked for.
    public var inputOptions: String.IntentInputOptions? { return storage.inputOptions }
    /// How an entity parameter of this value's type is asked for.
    public var parameterMode: (any Hashable)? { return storage.parameterMode }
    /// Whether a measurement parameter of this value's type may be negative.
    public var supportsNegativeNumbers: Bool? { return storage.supportsNegativeNumbers }
    /// The unit a measurement parameter of this value's type is asked in.
    public var unit: (any Hashable)? { return storage.unit }
    /// Whether a measurement parameter of this value's type converts its unit for the locale.
    public var unitAdjustForLocale: Bool? { return storage.unitAdjustForLocale }
}

// The resolvers the framework itself names, one per pair of types the parameters use. Each is the real
// conversion: the string forms are the ones the release's own `LosslessStringConvertible` types
// write, so a value written by a parameter and read by a query is the same value.

/// Reads a `String` into an `Int`, in the radix the resolver names (10 unless it names another).
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

/// Reads a `String` into a `Double`.
public struct DoubleFromStringResolver: RangeCheckingResolver {
    public typealias Input = String
    public typealias Output = Double

    public init() {}

    public func resolve(from input: String, context: IntentParameterContext<Double>) async throws -> Double? {
        return Double(input)
    }


}

/// Reads a `String` into a `Bool`: the spellings the release's own `Bool` init takes, and nothing
/// else, so a value that is not one of them is not a value.
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

/// Reads a `String` into a `URL`, with the same spellings `URL(string:)` takes.
public struct URLFromStringResolver: Resolver {
    public typealias Input = String
    public typealias Output = URL

    public init() {}

    public func resolve(from input: String, context: IntentParameterContext<URL>) async throws -> URL? {
        return URL(string: input)
    }


}

/// Reads an `Int` into the string a parameter that asks for one writes.
public struct StringFromIntResolver: Resolver {
    public typealias Input = Int
    public typealias Output = String

    public init() {}

    public func resolve(from input: Int, context: IntentParameterContext<String>) async throws -> String? {
        return String(input)
    }


}

/// Reads a `Double` into the string a parameter that asks for one writes.
public struct StringFromDoubleResolver: Resolver {
    public typealias Input = Double
    public typealias Output = String

    public init() {}

    public func resolve(from input: Double, context: IntentParameterContext<String>) async throws -> String? {
        return String(input)
    }


}

/// Reads a number into an `Int` by the rule the resolver names, which is how a numeric parameter with
/// a step answers.
public struct IntFromDoubleResolver: RangeCheckingResolver {
    public typealias Input = Double
    public typealias Output = Int

    /// How a number that is not a whole one becomes one.
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

/// Reads a `String` into an `Int` with no radix of its own.
public struct IntResolver: RangeCheckingResolver {
    public typealias Input = String
    public typealias Output = Int

    public init() {}

    public func resolve(from input: String, context: IntentParameterContext<Int>) async throws -> Int? {
        return Int(input)
    }


}

/// Reads a `String` into a `Double` with no radix of its own.
public struct DoubleResolver: RangeCheckingResolver {
    public typealias Input = String
    public typealias Output = Double

    public init() {}

    public func resolve(from input: String, context: IntentParameterContext<Double>) async throws -> Double? {
        return Double(input)
    }


}

/// Reads an `Int` into a `Double`.
public struct DoubleFromIntResolver: RangeCheckingResolver {
    public typealias Input = Int
    public typealias Output = Double

    public init() {}

    public func resolve(from input: Int, context: IntentParameterContext<Double>) async throws -> Double? {
        return Double(input)
    }


}

/// Reads the term of a `StringSearchCriteria` out of the string a parameter carries.
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

/// How a string parameter of the framework's own is asked for: which keyboard, which capitalization,
/// and whether it is one line or several.
public extension String {
    struct IntentInputOptions {
        /// The keyboard the parameter is asked with, which is the release's own `UIKeyboardType` under
        /// the name the framework gives it.
        public enum KeyboardType: Hashable, Sendable {
            case `default`
            case asciiCapable
            case numbersAndPunctuation
            case URL
            case numberPad

            public static func == (a: KeyboardType, b: KeyboardType) -> Bool { true }
        }

        /// The capitalization the parameter is asked with.
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

/// A list of values is the collection a query offers and a list parameter carries, which is what
/// `ResultsCollection` needs of it.
extension Array: ResultsCollection where Element: _IntentValue, Element == Element.ValueType {
    public typealias Result = Element

    public static var empty: [Element] { return [] }
    public var promptLabel: LocalizedStringResource? { return nil }
    public var usesIndexedCollation: Bool { return false }
    public var items: [Result.ValueType] { return self }
}

