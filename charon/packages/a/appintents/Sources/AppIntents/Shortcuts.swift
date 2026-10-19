// App Shortcuts: the phrases that call an intent without naming it, the tiles they are shown on, and
// the registration the system does with them.
//
// The framework hands the app's shortcuts to a system service (Siri, Shortcuts, Spotlight) that these
// releases do not run, so `AppShortcutsProvider.updateAppShortcutParameters()` keeps the list in the
// port's own store and answers from it; `facts/AppIntents/Services.md` says so. The phrases
// themselves, the tiles and the parameter presentations are the app's own values and are real.

import Foundation

/// A shortcut: an intent, the phrases that call it, the title it is shown with and the system image
/// beside it.
public struct AppShortcut {
    /// The intent the shortcut calls.
    public let intent: any AppIntent
    /// The phrases that call it, in the languages the app wrote them in.
    public let phrases: [any CharonShortcutPhrase]
    /// The title the tile is shown with.
    public let shortTitle: LocalizedStringResource
    /// The system image shown on the tile.
    public let systemImageName: String
    /// How the parameters are shown on the tile, added in iOS 17.
    public let parameterPresentation: AppShortcutParameterPresentationSnapshot

    public init(intent: some AppIntent, phrases: [any CharonShortcutPhrase], shortTitle: LocalizedStringResource,
                systemImageName: String) {
        self.intent = intent
        self.phrases = phrases
        self.shortTitle = shortTitle
        self.systemImageName = systemImageName
        self.parameterPresentation = AppShortcutParameterPresentationSnapshot()
    }

    public init(intent: some AppIntent, phrases: [any CharonShortcutPhrase], shortTitle: LocalizedStringResource,
                systemImageName: String, parameterPresentation: some AppShortcutParameterPresentationProtocol) {
        self.intent = intent
        self.phrases = phrases
        self.shortTitle = shortTitle
        self.systemImageName = systemImageName
        self.parameterPresentation = AppShortcutParameterPresentationSnapshot()
    }
}

/// The parameter presentations of a shortcut, as they are kept in the port's own store: the app's own
/// titles and summaries, read back as the strings it wrote.
public struct AppShortcutParameterPresentationSnapshot {
    public var summaries: [String] = []
    public var titles: [String] = []
    public var options: [String] = []
}

/// The marker of a parameter presentation of a shortcut.
public protocol AppShortcutParameterPresentationProtocol {}

/// How one parameter of a shortcut is shown on its tile.
public struct AppShortcutParameterPresentation<Intent, Value, Parameter, ParameterKeyPath>
    where Intent: AppIntent, Value: _IntentValue, Value: Sendable,
          Parameter: IntentParameter<Value>, ParameterKeyPath: KeyPath<Intent, Parameter> {
    public let keyPath: ParameterKeyPath

    public init(for summary: AppShortcutParameterPresentationSummary<Intent, Value, Parameter, ParameterKeyPath>,
                @AppShortcutParameterPresentationTitleBuilder<Intent, Value, Parameter, ParameterKeyPath>
                _: () -> AppShortcutParameterPresentationTitle<Intent, Value, Parameter, ParameterKeyPath>) {
        guard let keyPath = summary.keyPath else {
            CharonUnset.fatal("a parameter presentation is made for the parameter its summary names")
        }
        self.keyPath = keyPath
    }
}

/// The summary of a shortcut's tile: the words that go with one of its parameters.
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

/// The string a shortcut's parameter summary is written with.
public struct AppShortcutParameterPresentationSummaryString<Intent, Value, Parameter, ParameterKeyPath>
    : ExpressibleByStringInterpolation
    where Intent: AppIntent, Value: _IntentValue, Value: Sendable,
          Parameter: IntentParameter<Value>, ParameterKeyPath: KeyPath<Intent, Parameter> {
    /// The parameter this string is about, when the app named one. A plain string names none, which
    /// is the framework's own reading of a literal summary: it is the text and nothing else.
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

    /// The interpolation of a parameter summary: a sentence with holes, each hole a parameter of the
    /// intent.
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

/// The builder of a parameter's presentation title.
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

/// How a parameter of a shortcut is titled on its tile: one string for the value it has, another for
/// any value.
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

/// The string a parameter's presentation title is written with.
public struct AppShortcutParameterPresentationTitleString<Intent, Value, Parameter, ParameterKeyPath>
    : ExpressibleByStringInterpolation
    where Intent: AppIntent, Value: _IntentValue, Value: Sendable,
          Parameter: IntentParameter<Value>, ParameterKeyPath: KeyPath<Intent, Parameter> {
    /// The parameter this string is about, when the app named one. A plain string names none, which
    /// is the framework's own reading of a literal summary: it is the text and nothing else.
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

    /// The interpolation of a title: a string with holes, each hole a parameter of the intent.
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

/// The marker of a phrase that calls a shortcut, which is what a shortcut's list holds.
public protocol CharonShortcutPhrase {
    var text: String { get }
}

/// A phrase that calls a shortcut, with `\(.applicationName)` for the name of the app.
public struct AppShortcutPhrase<Intent>: ExpressibleByStringInterpolation, CharonShortcutPhrase where Intent: AppIntent {
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

    /// The interpolation of a phrase: a sentence with the app's own name in it.
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

/// What a phrase may name instead of writing it out: the app's own name, which is what the phrase is
/// written around.
public enum AppShortcutPhraseToken{
    /// The name of the app the phrase calls into.
    case applicationName

    /// The text the token stands for, which is the app's own display name.
    public var text: String { return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "" }

    /// Which of the type's own cases this is. A query compares the operator a rule wrote
    /// with the one it runs, and an equality that answered `true` for every pair -- or a
    /// hash that told none of them apart -- would match the wrong one and collapse every
    /// value of the type into one bucket, so both are made of this.
    var ordinal: Int {
        switch self {
        case .applicationName: return 0
        }
    }

    public static func == (a: AppShortcutPhraseToken, b: AppShortcutPhraseToken) -> Bool { return a.ordinal == b.ordinal }

}

/// A phrase that says an intent is *not* what the caller wants, added in iOS 17.
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

/// The phrases that say an intent is not what the caller wants.
public struct NegativeAppShortcutPhrases {
    public let phrases: [NegativeAppShortcutPhrase]

    public init(phrases: [NegativeAppShortcutPhrase] = []) {
        self.phrases = phrases
    }
}

/// The colour a shortcut's tile is shown on, which is the framework's own list of tile colours.
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

    /// Which of the type's own cases this is. A query compares the operator a rule wrote
    /// with the one it runs, and an equality that answered `true` for every pair -- or a
    /// hash that told none of them apart -- would match the wrong one and collapse every
    /// value of the type into one bucket, so both are made of this.
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

/// The options a shortcut's tile offers above its parameters, added in iOS 17.
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

/// A set of options a shortcut's tile offers, filled from a provider.
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

/// The specification of the options a shortcut's tile offers, which the app writes with the builder.
public protocol AppShortcutOptionsCollectionSpecification: Sendable, Sequence
    where Element == any AppShortcutOptionsCollectionProtocol {}

/// The specification of the options a shortcut's tile offers, over the value its options carry: what
/// `AppShortcutsProvider` names as its `OptionsCollection`.
public typealias AppShortcutOptionsCollectionSpecificationFor<Value: _IntentValue> = [any AppShortcutOptionsCollectionProtocol]

/// The app's own shortcuts, declared with the `AppShortcutsBuilder` result builder.
public protocol AppShortcutsProvider: Sendable {
    associatedtype OptionsCollection

    associatedtype ParameterPresentation
    associatedtype Summary
    associatedtype Title

    /// The shortcuts the app offers, and the phrases that call them.
    static var appShortcuts: [AppShortcut] { get }
    /// The phrases that say a shortcut is not what the caller wants, added in iOS 17.
    static var negativePhrases: NegativeAppShortcutPhrases { get }
    /// The colour the tiles are shown on.
    static var shortcutTileColor: ShortcutTileColor { get }
    /// Hand the app's shortcuts to the system, which on these releases is the port's own store.
    static func updateAppShortcutParameters()
}

extension AppShortcutsProvider {
    public static var negativePhrases: NegativeAppShortcutPhrases { return NegativeAppShortcutPhrases() }
    public static var shortcutTileColor: ShortcutTileColor { return .blue }

    /// The framework's own call that hands the shortcuts to the system. The service is not on these
    /// releases, so what it does here is write the list into the port's own store, which is what
    /// `appShortcuts()` reads back.
    public static func updateAppShortcutParameters() {
        CharonShortcutStore.shared.register(appShortcuts)
    }
}

/// The app's shortcuts as a value of its own type, which is what the `AppShortcuts` builder makes.
public protocol AppShortcutsContent: Escapable, Copyable {
    var appShortcuts: [AppShortcut] { get }
}

/// The shortcuts of an app that offers them only on a later release, as the `AppShortcuts` builder makes
/// them. The port has one release, so the value is the shortcuts the app would offer.
public struct LimitedAvailabilityAppShortcuts: AppShortcutsContent, Copyable, Escapable {
    public var appShortcuts: [AppShortcut]

    public init(_ appShortcuts: [AppShortcut]) {
        self.appShortcuts = appShortcuts
    }
}

/// The builder of a list of shortcuts.
@resultBuilder
public enum AppShortcutsBuilder {
    public static func buildBlock() -> [AppShortcut] { return [] }

    public static func buildBlock(_ shortcut: AppShortcut) -> [AppShortcut] { return [shortcut] }

    public static func buildExpression(_ expression: AppShortcut) -> AppShortcut { return expression }

    /// A shortcut of an app that offers one only on a later release: the port has one release, so the
    /// value is the one the app would offer.
    public static func buildLimitedAvailability(_ shortcut: AppShortcut) -> AppShortcut { return shortcut }

    public static func buildOptional(_ shortcut: AppShortcut?) -> [AppShortcut] { return shortcut.map { [$0] } ?? [] }
}

/// The port's own record of the app's shortcuts: the list `updateAppShortcutParameters()` writes and
/// a caller reads back in process, where the framework's own index of shortcuts is a system service.
public final class CharonShortcutStore {
    public static let shared = CharonShortcutStore()

    private var shortcuts: [AppShortcut] = []
    private let lock = NSLock()

    public init() {}

    public func register(_ shortcuts: [AppShortcut]) {
        lock.lock()
        defer { lock.unlock() }
        self.shortcuts = shortcuts
    }

    /// The shortcuts the store holds.
    public func appShortcuts() -> [AppShortcut] {
        lock.lock()
        defer { lock.unlock() }
        return shortcuts
    }

    /// The phrases of the shortcuts the store holds, which is what a caller searching for an intent
    /// by its phrases reads.
    public func phrases() -> [String] {
        return appShortcuts().flatMap { $0.phrases.map { $0.text } }
    }
}
