import Foundation

public struct AppShortcut {
    public let intent: any AppIntent
    public let phrases: [any RevenantShortcutPhrase]
    public let shortTitle: LocalizedStringResource
    public let systemImageName: String
    public let parameterPresentation: AppShortcutParameterPresentationSnapshot

    public init(intent: some AppIntent, phrases: [any RevenantShortcutPhrase], shortTitle: LocalizedStringResource,
                systemImageName: String) {
        self.intent = intent
        self.phrases = phrases
        self.shortTitle = shortTitle
        self.systemImageName = systemImageName
        self.parameterPresentation = AppShortcutParameterPresentationSnapshot()
    }

    public init(intent: some AppIntent, phrases: [any RevenantShortcutPhrase], shortTitle: LocalizedStringResource,
                systemImageName: String, parameterPresentation: some AppShortcutParameterPresentationProtocol) {
        self.intent = intent
        self.phrases = phrases
        self.shortTitle = shortTitle
        self.systemImageName = systemImageName
        self.parameterPresentation = AppShortcutParameterPresentationSnapshot()
    }
}

public struct AppShortcutParameterPresentationSnapshot {
    public var summaries: [String] = []
    public var titles: [String] = []
    public var options: [String] = []
}

public protocol AppShortcutParameterPresentationProtocol {}

public struct AppShortcutParameterPresentation<Intent, Value, Parameter, ParameterKeyPath>
    where Intent: AppIntent, Value: _IntentValue, Value: Sendable,
          Parameter: IntentParameter<Value>, ParameterKeyPath: KeyPath<Intent, Parameter> {
    public let keyPath: ParameterKeyPath

    public init(for summary: AppShortcutParameterPresentationSummary<Intent, Value, Parameter, ParameterKeyPath>,
                @AppShortcutParameterPresentationTitleBuilder<Intent, Value, Parameter, ParameterKeyPath>
                _: () -> AppShortcutParameterPresentationTitle<Intent, Value, Parameter, ParameterKeyPath>) {
        guard let keyPath = summary.keyPath else {
            RevenantUnset.fatal("a parameter presentation is made for the parameter its summary names")
        }
        self.keyPath = keyPath
    }
}

public struct AppShortcutParameterPresentationSummary<Intent, Value, Parameter, ParameterKeyPath>
    where Intent: AppIntent, Value: _IntentValue, Value: Sendable,
          Parameter: IntentParameter<Value>, ParameterKeyPath: KeyPath<Intent, Parameter> {
    public let keyPath: ParameterKeyPath?
    public let table: String?

    public init(_ summary: AppShortcutParameterPresentationSummaryString<Intent, Value, Parameter, ParameterKeyPath>,
                table: String? = nil) {
        self.keyPath = summary.keyPath
        self.table = table
    }
}

public struct AppShortcutParameterPresentationSummaryString<Intent, Value, Parameter, ParameterKeyPath>
    : ExpressibleByStringInterpolation
    where Intent: AppIntent, Value: _IntentValue, Value: Sendable,
          Parameter: IntentParameter<Value>, ParameterKeyPath: KeyPath<Intent, Parameter> {
    public let keyPath: ParameterKeyPath?
    public let text: String

    public init(_ text: String) {
        self.keyPath = nil
        self.text = text
    }

    public init(_ text: String, for keyPath: ParameterKeyPath) {
        self.keyPath = keyPath
        self.text = text
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.text)
    }

    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var text: String { return literal }

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
        }

        public mutating func appendInterpolation(_ subject: ParameterKeyPath) {
            literal += "\\(\(subject))"
        }
    }
}

@resultBuilder
public enum AppShortcutParameterPresentationTitleBuilder<Intent, Value, Parameter, ParameterKeyPath>
    where Intent: AppIntent, Value: _IntentValue, Value: Sendable,
          Parameter: IntentParameter<Value>, ParameterKeyPath: KeyPath<Intent, Parameter> {}

extension AppShortcutParameterPresentationTitleBuilder {
    public static func buildBlock(_ title: AppShortcutParameterPresentationTitle<Intent, Value, Parameter, ParameterKeyPath>)
        -> AppShortcutParameterPresentationTitle<Intent, Value, Parameter, ParameterKeyPath> {
        return title
    }

    public static func buildExpression(_ expression: AppShortcutParameterPresentationTitle<Intent, Value, Parameter, ParameterKeyPath>)
        -> AppShortcutParameterPresentationTitle<Intent, Value, Parameter, ParameterKeyPath> {
        return expression
    }
}

public struct AppShortcutParameterPresentationTitle<Intent, Value, Parameter, ParameterKeyPath>
    where Intent: AppIntent, Value: _IntentValue, Value: Sendable,
          Parameter: IntentParameter<Value>, ParameterKeyPath: KeyPath<Intent, Parameter> {
    public let keyPath: ParameterKeyPath?
    public let specific: String
    public let generic: String

    public init(specific: AppShortcutParameterPresentationTitleString<Intent, Value, Parameter, ParameterKeyPath>,
                generic: StaticString, table: StaticString? = nil) {
        self.keyPath = specific.keyPath
        self.specific = specific.text
        self.generic = String(describing: generic)
    }
}

public struct AppShortcutParameterPresentationTitleString<Intent, Value, Parameter, ParameterKeyPath>
    : ExpressibleByStringInterpolation
    where Intent: AppIntent, Value: _IntentValue, Value: Sendable,
          Parameter: IntentParameter<Value>, ParameterKeyPath: KeyPath<Intent, Parameter> {
    public let keyPath: ParameterKeyPath?
    public let text: String

    public init(_ text: String) {
        self.keyPath = nil
        self.text = text
    }

    public init(_ text: String, for keyPath: ParameterKeyPath) {
        self.keyPath = keyPath
        self.text = text
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.text)
    }

    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var text: String { return literal }

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
        }

        public mutating func appendInterpolation(_ subject: ParameterKeyPath) {
            literal += "\\(\(subject))"
        }
    }
}

public protocol RevenantShortcutPhrase {
    var text: String { get }
}

public struct AppShortcutPhrase<Intent>: ExpressibleByStringInterpolation, RevenantShortcutPhrase where Intent: AppIntent {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.text)
    }

    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var text: String { return literal }

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
        }

        public mutating func appendInterpolation(_ token: AppShortcutPhraseToken) {
            literal += token.text
        }
    }
}

public enum AppShortcutPhraseToken{
    case applicationName

    public var text: String { return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "" }

    var ordinal: Int {
        switch self {
        case .applicationName: return 0
        }
    }

    public static func == (a: AppShortcutPhraseToken, b: AppShortcutPhraseToken) -> Bool { return a.ordinal == b.ordinal }

}

public struct NegativeAppShortcutPhrase: ExpressibleByStringInterpolation {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.text)
    }

    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var text: String { return literal }

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
        }

        public mutating func appendInterpolation(_ token: AppShortcutPhraseToken) {
            literal += token.text
        }
    }
}

public struct NegativeAppShortcutPhrases {
    public let phrases: [NegativeAppShortcutPhrase]

    public init(phrases: [NegativeAppShortcutPhrase] = []) {
        self.phrases = phrases
    }
}

public enum ShortcutTileColor{
    case red
    case orange
    case yellow
    case green
    case teal
    case blue
    case purple
    case pink
    case navy
    case lime
    case tangerine
    case grape
    case grayBlue
    case grayBrown
    case grayGreen
    case lightBlue

    var ordinal: Int {
        switch self {
        case .red: return 0
        case .orange: return 1
        case .yellow: return 2
        case .green: return 3
        case .teal: return 4
        case .blue: return 5
        case .purple: return 6
        case .pink: return 7
        case .navy: return 8
        case .lime: return 9
        case .tangerine: return 10
        case .grape: return 11
        case .grayBlue: return 12
        case .grayBrown: return 13
        case .grayGreen: return 14
        case .lightBlue: return 15
        }
    }

    public static func == (a: ShortcutTileColor, b: ShortcutTileColor) -> Bool { return a.ordinal == b.ordinal }

}

public protocol AppShortcutOptionsCollectionProtocol {
    var title: LocalizedStringResource { get }
    var systemImageName: String { get }
    var dynamicOptionsProvider: (any DynamicOptionsProvider)? { get }
}

extension AppShortcutOptionsCollectionProtocol {
    public var title: LocalizedStringResource { return LocalizedStringResource("Options") }
    public var systemImageName: String { return "ellipsis.circle" }
    public var dynamicOptionsProvider: (any DynamicOptionsProvider)? { return nil }
}

public struct AppShortcutOptionsCollection<Provider>: AppShortcutOptionsCollectionProtocol
    where Provider: DynamicOptionsProvider {
    public let title: LocalizedStringResource
    public let systemImageName: String
    public let dynamicOptionsProvider: (any DynamicOptionsProvider)?

    public init(_ provider: Provider, title: LocalizedStringResource, systemImageName: String) {
        self.dynamicOptionsProvider = provider
        self.title = title
        self.systemImageName = systemImageName
    }
}

public protocol AppShortcutOptionsCollectionSpecification: Sendable, Sequence
    where Element == any AppShortcutOptionsCollectionProtocol {}

public typealias AppShortcutOptionsCollectionSpecificationFor<Value: _IntentValue> = [any AppShortcutOptionsCollectionProtocol]

public protocol AppShortcutsProvider: Sendable {
    associatedtype OptionsCollection

    associatedtype ParameterPresentation
    associatedtype Summary
    associatedtype Title

    static var appShortcuts: [AppShortcut] { get }
    static var negativePhrases: NegativeAppShortcutPhrases { get }
    static var shortcutTileColor: ShortcutTileColor { get }
    static func updateAppShortcutParameters()
}

extension AppShortcutsProvider {
    public static var negativePhrases: NegativeAppShortcutPhrases { return NegativeAppShortcutPhrases() }
    public static var shortcutTileColor: ShortcutTileColor { return .blue }

    public static func updateAppShortcutParameters() {
        RevenantShortcutStore.shared.register(appShortcuts)
    }
}

public protocol AppShortcutsContent: Escapable, Copyable {
    var appShortcuts: [AppShortcut] { get }
}

public struct LimitedAvailabilityAppShortcuts: AppShortcutsContent, Copyable, Escapable {
    public var appShortcuts: [AppShortcut]

    public init(_ appShortcuts: [AppShortcut]) {
        self.appShortcuts = appShortcuts
    }
}

@resultBuilder
public enum AppShortcutsBuilder {
    public static func buildBlock() -> [AppShortcut] { return [] }

    public static func buildBlock(_ shortcut: AppShortcut) -> [AppShortcut] { return [shortcut] }

    public static func buildExpression(_ expression: AppShortcut) -> AppShortcut { return expression }

    public static func buildLimitedAvailability(_ shortcut: AppShortcut) -> AppShortcut { return shortcut }

    public static func buildOptional(_ shortcut: AppShortcut?) -> [AppShortcut] { return shortcut.map { [$0] } ?? [] }
}

public final class RevenantShortcutStore {
    public static let shared = RevenantShortcutStore()

    private var shortcuts: [AppShortcut] = []
    private let lock = NSLock()

    public init() {}

    public func register(_ shortcuts: [AppShortcut]) {
        lock.lock()
        defer { lock.unlock() }
        self.shortcuts = shortcuts
    }

    public func appShortcuts() -> [AppShortcut] {
        lock.lock()
        defer { lock.unlock() }
        return shortcuts
    }

    public func phrases() -> [String] {
        return appShortcuts().flatMap { $0.phrases.map { $0.text } }
    }
}
