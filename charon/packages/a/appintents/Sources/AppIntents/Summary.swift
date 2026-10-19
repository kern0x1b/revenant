// How an intent's parameters are put into a sentence, and the string types that sentence is written
// with.
//
// A `ParameterSummary` is a value the app builds with the `ParameterSummary` builder, or a string with
// `\.parameter` holes, or a `When`/`Switch` of them. Nothing here asks a system: the summary is the
// value, and a caller that shows it reads the value.

import Foundation

/// A summary of an intent's parameters.
public protocol ParameterSummary {
    /// The words of the summary, as the app wrote them.
    var summary: String { get }
}

/// The summary an intent that names no other gets: a string with holes, each hole a parameter.
public struct IntentParameterSummary<Intent: AppIntent>: ParameterSummary {
    public let summary: String

    public init() {
        self.summary = Intent.persistentIdentifier
    }

    public init(_ value: String) {
        self.summary = value
    }

    public init(_ value: String, table: String) {
        self.summary = value
    }

    public init(_ value: String, @ParameterSummaryBuilder<Intent> _: () -> Void) {
        self.summary = value
    }

    public init(_ value: String, table: String, @ParameterSummaryBuilder<Intent> _: () -> Void) {
        self.summary = value
    }

    /// The key paths of an intent's parameters, so that a summary can name them by type.
    @resultBuilder
    public enum ParameterKeyPathsBuilder {
        public static func buildBlock() {}
    }

    public init(@ParameterSummaryBuilder<Intent> _: () -> Void) {
        self.summary = Intent.persistentIdentifier
    }
}

/// The builder of a summary that is written as code rather than as a sentence.
@resultBuilder
public enum ParameterSummaryBuilder<Intent: AppIntent> {
    public static func buildBlock() {}
}

extension ParameterSummaryBuilder {
    public static func buildBlock<S>(_ summary: S) -> S where S: ParameterSummary { return summary }
    public static func buildExpression<S>(_ expression: S) -> S where S: ParameterSummary { return expression }
}

/// The builder of a collection of the options a shortcut's tile offers, the framework's own
/// `buildBlock` overloads, one per arity.
@resultBuilder
public enum AppShortcutOptionsCollectionSpecificationBuilder<Value: _IntentValue & Sendable> {}

extension AppShortcutOptionsCollectionSpecificationBuilder {
    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol, _ a7: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6, a7]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol, _ a7: any AppShortcutOptionsCollectionProtocol, _ a8: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6, a7, a8]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol, _ a7: any AppShortcutOptionsCollectionProtocol, _ a8: any AppShortcutOptionsCollectionProtocol, _ a9: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6, a7, a8, a9]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol, _ a7: any AppShortcutOptionsCollectionProtocol, _ a8: any AppShortcutOptionsCollectionProtocol, _ a9: any AppShortcutOptionsCollectionProtocol, _ a10: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol, _ a7: any AppShortcutOptionsCollectionProtocol, _ a8: any AppShortcutOptionsCollectionProtocol, _ a9: any AppShortcutOptionsCollectionProtocol, _ a10: any AppShortcutOptionsCollectionProtocol, _ a11: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol, _ a7: any AppShortcutOptionsCollectionProtocol, _ a8: any AppShortcutOptionsCollectionProtocol, _ a9: any AppShortcutOptionsCollectionProtocol, _ a10: any AppShortcutOptionsCollectionProtocol, _ a11: any AppShortcutOptionsCollectionProtocol, _ a12: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol, _ a7: any AppShortcutOptionsCollectionProtocol, _ a8: any AppShortcutOptionsCollectionProtocol, _ a9: any AppShortcutOptionsCollectionProtocol, _ a10: any AppShortcutOptionsCollectionProtocol, _ a11: any AppShortcutOptionsCollectionProtocol, _ a12: any AppShortcutOptionsCollectionProtocol, _ a13: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol, _ a7: any AppShortcutOptionsCollectionProtocol, _ a8: any AppShortcutOptionsCollectionProtocol, _ a9: any AppShortcutOptionsCollectionProtocol, _ a10: any AppShortcutOptionsCollectionProtocol, _ a11: any AppShortcutOptionsCollectionProtocol, _ a12: any AppShortcutOptionsCollectionProtocol, _ a13: any AppShortcutOptionsCollectionProtocol, _ a14: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14]
    }

    public static func buildBlock(_ a1: any AppShortcutOptionsCollectionProtocol, _ a2: any AppShortcutOptionsCollectionProtocol, _ a3: any AppShortcutOptionsCollectionProtocol, _ a4: any AppShortcutOptionsCollectionProtocol, _ a5: any AppShortcutOptionsCollectionProtocol, _ a6: any AppShortcutOptionsCollectionProtocol, _ a7: any AppShortcutOptionsCollectionProtocol, _ a8: any AppShortcutOptionsCollectionProtocol, _ a9: any AppShortcutOptionsCollectionProtocol, _ a10: any AppShortcutOptionsCollectionProtocol, _ a11: any AppShortcutOptionsCollectionProtocol, _ a12: any AppShortcutOptionsCollectionProtocol, _ a13: any AppShortcutOptionsCollectionProtocol, _ a14: any AppShortcutOptionsCollectionProtocol, _ a15: any AppShortcutOptionsCollectionProtocol) -> [any AppShortcutOptionsCollectionProtocol] {
        return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15]
    }

}
/// A summary that is one case of a value, with what it says in that case.
public struct ParameterSummaryCaseCondition<Intent, Value, Summary>: _ParameterSummarySwitchCase
    where Intent: AppIntent, Value: _IntentValue, Summary: ParameterSummary {
    let value: Value
    let summary: Summary

    public init(_ value: Value, @ParameterSummaryBuilder<Intent> summary: () -> Summary) {
        self.value = value
        self.summary = summary()
    }

    public var summaryText: String { return summary.summary }
}

/// A summary that is what an intent says when no other case matched.
public struct ParameterSummaryDefaultCaseCondition<Intent, Value, Summary>: _ParameterSummarySwitchCase
    where Intent: AppIntent, Value: _IntentValue, Summary: ParameterSummary {
    let summary: Summary

    public init(@ParameterSummaryBuilder<Intent> summary: () -> Summary) {
        self.summary = summary()
    }

    public var summaryText: String { return summary.summary }
}

/// A summary for a parameter whose value is a tuple, one summary per tuple.
public struct ParameterSummaryTupleCaseCondition<Intent, Value, ValueType>: _ParameterSummarySwitchCase
    where Intent: AppIntent, Value: _IntentValue, ValueType: ParameterSummary {
    public typealias Summary = ValueType

    let value: Value
    let summaries: [ValueType]

    public init(_ value: Value, @ParameterSummaryBuilder<Intent> summaries: () -> [ValueType]) {
        self.value = value
        self.summaries = summaries()
    }

    public var summaryText: String { return summaries.map { $0.summary }.joined(separator: " ") }
}

/// The marker of a case of a `Switch`.
public protocol _ParameterSummarySwitchCase {
    var summaryText: String { get }
}

/// A summary that is chosen by the value of a parameter.
public struct ParameterSummarySwitchCondition<Intent, Value, CaseCondition>: ParameterSummary
    where Intent: AppIntent, Value: _IntentValue, CaseCondition: _ParameterSummarySwitchCase {
    let cases: [CaseCondition]

    public init(_ keyPath: KeyPath<Intent, IntentParameter<Value>>,
                @ParameterSummaryCaseBuilder<Intent, Value, CaseCondition> cases: () -> [CaseCondition]) {
        self.cases = cases()
    }

    public var summary: String { return cases.map { $0.summaryText }.joined(separator: " ") }

    /// The widget families a switch's cases are chosen for.
    public enum WidgetFamily: Hashable {
        case widgetFamily
    }
}

/// The builder of a switch's cases.
@resultBuilder
public enum ParameterSummaryCaseBuilder<Intent, Value, CaseCondition>
    where Intent: AppIntent, Value: _IntentValue, CaseCondition: _ParameterSummarySwitchCase {}

extension ParameterSummaryCaseBuilder {
    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition) -> [CaseCondition] { return [a, b] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition,
                                  _ c: CaseCondition) -> [CaseCondition] { return [a, b, c] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition,
                                  _ d: CaseCondition) -> [CaseCondition] { return [a, b, c, d] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition,
                                  _ g: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f, g] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition, _ g: CaseCondition,
                                  _ h: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f, g, h] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition, _ g: CaseCondition, _ h: CaseCondition,
                                  _ i: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f, g, h, i] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition, _ g: CaseCondition, _ h: CaseCondition,
                                  _ i: CaseCondition,
                                  _ j: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f, g, h, i, j] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition, _ g: CaseCondition, _ h: CaseCondition,
                                  _ i: CaseCondition, _ j: CaseCondition,
                                  _ k: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f, g, h, i, j, k] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition, _ g: CaseCondition, _ h: CaseCondition,
                                  _ i: CaseCondition, _ j: CaseCondition, _ k: CaseCondition,
                                  _ l: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f, g, h, i, j, k, l] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition, _ g: CaseCondition, _ h: CaseCondition,
                                  _ i: CaseCondition, _ j: CaseCondition, _ k: CaseCondition, _ l: CaseCondition,
                                  _ m: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f, g, h, i, j, k, l, m] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition, _ g: CaseCondition, _ h: CaseCondition,
                                  _ i: CaseCondition, _ j: CaseCondition, _ k: CaseCondition, _ l: CaseCondition,
                                  _ m: CaseCondition,
                                  _ n: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f, g, h, i, j, k, l, m, n] }

    public static func buildBlock(_ a: CaseCondition, _ b: CaseCondition, _ c: CaseCondition, _ d: CaseCondition,
                                  _ e: CaseCondition, _ f: CaseCondition, _ g: CaseCondition, _ h: CaseCondition,
                                  _ i: CaseCondition, _ j: CaseCondition, _ k: CaseCondition, _ l: CaseCondition,
                                  _ m: CaseCondition, _ n: CaseCondition,
                                  _ o: CaseCondition) -> [CaseCondition] { return [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o] }

    public static func buildExpression<S>(_ expression: S) -> S where S: _ParameterSummarySwitchCase { return expression }
}

/// A summary that is one of several, chosen by the value of one parameter, with what it says otherwise.
public struct ParameterSummaryWhenCondition<Intent, WhenCondition, Otherwise>: ParameterSummary
    where Intent: AppIntent, WhenCondition: ParameterSummary, Otherwise: ParameterSummary {
    let when: WhenCondition
    let otherwise: Otherwise

    public init<Parameter>(_ keyPath: KeyPath<Intent, Parameter>, _ comparisonOperator: HasValueComparisonOperator,
                           @ParameterSummaryBuilder<Intent> when: () -> WhenCondition,
                           @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise)
        where Parameter: AnyIntentValue {
        self.when = when()
        self.otherwise = otherwise()
    }

    public init<ValueType, Parameter>(_ keyPath: KeyPath<Intent, Parameter>,
                                      _ comparisonOperator: EquatableComparisonOperator, _ value: ValueType,
                                      @ParameterSummaryBuilder<Intent> when: () -> WhenCondition,
                                      @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise)
        where ValueType: Equatable, ValueType == Parameter.Value, Parameter: AnyIntentValue {
        self.when = when()
        self.otherwise = otherwise()
    }

    public init<ValueType, Parameter>(_ keyPath: KeyPath<Intent, Parameter>,
                                      _ comparisonOperator: OneOfComparisonOperator, _ values: [ValueType],
                                      @ParameterSummaryBuilder<Intent> when: () -> WhenCondition,
                                      @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise)
        where ValueType == Parameter.Value, Parameter: AnyIntentValue {
        self.when = when()
        self.otherwise = otherwise()
    }

    public init<ValueType, Parameter>(_ keyPath: KeyPath<Intent, Parameter>,
                                      _ comparisonOperator: ComparableComparisonOperator, _ value: ValueType,
                                      @ParameterSummaryBuilder<Intent> when: () -> WhenCondition,
                                      @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise)
        where ValueType: Comparable, ValueType == Parameter.Value, Parameter: AnyIntentValue {
        self.when = when()
        self.otherwise = otherwise()
    }

    public init<Parameter>(_ keyPath: KeyPath<Intent, Parameter>, identifier comparisonOperator: StringComparisonOperator,
                           _ value: String,
                           @ParameterSummaryBuilder<Intent> when: () -> WhenCondition,
                           @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise)
        where Parameter: AnyIntentValue, Parameter.Value.ValueType: AppEntity {
        self.when = when()
        self.otherwise = otherwise()
    }

    public init<Parameter>(_ keyPath: KeyPath<Intent, Parameter>, identifier comparisonOperator: EquatableComparisonOperator,
                           _ value: String,
                           @ParameterSummaryBuilder<Intent> when: () -> WhenCondition,
                           @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise)
        where Parameter: AnyIntentValue, Parameter.Value.ValueType: AppEntity {
        self.when = when()
        self.otherwise = otherwise()
    }

    public init(widgetFamily comparisonOperator: OneOfComparisonOperator, _ values: [IntentWidgetFamily],
                @ParameterSummaryBuilder<Intent> when: () -> WhenCondition,
                @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise) {
        self.when = when()
        self.otherwise = otherwise()
    }

    public var summary: String { return "\(when.summary) \(otherwise.summary)" }
}

/// The string a summary is written with: a sentence with holes, each hole a parameter of the intent.
public struct ParameterSummaryString<Intent>: ExpressibleByStringInterpolation where Intent: AppIntent {
    public let summary: String

    public init(_ value: String) {
        self.summary = value
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.value)
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var value: String { return literal }

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
        }

        public mutating func appendInterpolation(_ subject: KeyPath<Intent, IntentParameter<some Any & _IntentValue>>) {
            literal += "\\(\(subject))"
        }

        public mutating func appendInterpolation(_ subject: KeyPath<Intent, EntityProperty<some Any & _IntentValue>>) {
            literal += "\\(\(subject))"
        }
    }
}

extension ParameterSummaryString: ParameterSummary {}
