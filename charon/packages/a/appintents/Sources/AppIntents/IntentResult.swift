// What an intent answers with, and what it can refuse with.
//
// The result is a value type the app fills in: a value to hand on, a dialog to say, another intent to
// open, a snippet to show. The `result(...)` overloads are the factories the framework names, and each
// one names the container's own generic arguments, so `some IntentResult` is what an intent's
// `perform()` gives back.

import Foundation

// MARK: - Results

/// What an intent's `perform()` gives back.
public protocol IntentResult: Sendable {
    associatedtype Value: _IntentValue = Never
    associatedtype Snippet = Never
    associatedtype Dialog = Never
    associatedtype OpensAppIntent: AppIntent = Never
    var value: Value? { get }
}

/// A result that hands a value on.
public protocol ReturnsValue<Value>: IntentResult {}

/// A result that opens another app.
public protocol OpensIntent: IntentResult {}

/// A result that says something.
public protocol ProvidesDialog: IntentResult where Dialog == IntentDialog {}

/// A result that shows a view of the app's own.
public protocol ShowsSnippetView: IntentResult where Snippet == _SnippetViewContainer {}

/// A result that shows another intent's snippet.
public protocol ShowsSnippetIntent: IntentResult where Snippet == _SnippetIntentContainer {}

/// The result every `perform()` returns: a value, a dialog, an intent to open, a snippet and the
/// activity it belongs to, each of the five being nothing when the intent returned none.
public struct IntentResultContainer<Value, OpensAppIntent, Snippet, Dialog>: IntentResult, @unchecked Sendable
    where Value: _IntentValue, OpensAppIntent: AppIntent {
    public var value: Value?
    public var dialog: Dialog?
    public var opensIntent: OpensAppIntent?
    public var snippet: Snippet?
    public var activityIdentifier: String?

    public init(value: Value? = nil, opensIntent: OpensAppIntent? = nil, dialog: Dialog? = nil,
                snippet: Snippet? = nil, activityIdentifier: String? = nil) {
        self.value = value
        self.opensIntent = opensIntent
        self.dialog = dialog
        self.snippet = snippet
        self.activityIdentifier = activityIdentifier
    }
}

extension IntentResultContainer: ReturnsValue {}
extension IntentResultContainer: OpensIntent {}
extension IntentResultContainer: ProvidesDialog where Dialog == IntentDialog {}
extension IntentResultContainer: ShowsSnippetView where Snippet == _SnippetViewContainer {}
extension IntentResultContainer: ShowsSnippetIntent where Snippet == _SnippetIntentContainer {}

extension IntentResult {
    public static func result() -> Self where Self == IntentResultContainer<Never, Never, Never, Never> {
        return IntentResultContainer()
    }

    public static func result<Value>(value: Value) -> Self
        where Self == IntentResultContainer<Value, Never, Never, Never>, Value: _IntentValue {
        return IntentResultContainer(value: value)
    }

    public static func result<OpensAppIntent>(opensIntent: OpensAppIntent) -> Self
        where Self == IntentResultContainer<Never, OpensAppIntent, Never, Never>, OpensAppIntent: AppIntent {
        return IntentResultContainer(opensIntent: opensIntent)
    }

    public static func result(opensIntent: some AppIntent) -> Self
        where Self == IntentResultContainer<Never, Never, Never, Never> {
        return IntentResultContainer()
    }

    public static func result(dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Never, Never, Never, IntentDialog> {
        return IntentResultContainer(dialog: dialog)
    }

    public static func result<Value, OpensAppIntent>(value: Value, opensIntent: OpensAppIntent) -> Self
        where Self == IntentResultContainer<Value, OpensAppIntent, Never, Never>,
              Value: _IntentValue, OpensAppIntent: AppIntent {
        return IntentResultContainer(value: value, opensIntent: opensIntent)
    }

    public static func result<Value>(value: Value, opensIntent: some AppIntent) -> Self
        where Self == IntentResultContainer<Value, Never, Never, Never>, Value: _IntentValue {
        return IntentResultContainer(value: value)
    }

    public static func result<Value>(value: Value, dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Value, Never, Never, IntentDialog>, Value: _IntentValue {
        return IntentResultContainer(value: value, dialog: dialog)
    }

    public static func result<Value, OpensAppIntent>(value: Value, opensIntent: OpensAppIntent,
                                                     dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Value, OpensAppIntent, Never, IntentDialog>,
              Value: _IntentValue, OpensAppIntent: AppIntent {
        return IntentResultContainer(value: value, opensIntent: opensIntent, dialog: dialog)
    }

    public static func result<Value>(value: Value, opensIntent: some AppIntent, dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Value, Never, Never, IntentDialog>, Value: _IntentValue {
        return IntentResultContainer(value: value, dialog: dialog)
    }

    public static func result<OpensAppIntent>(opensIntent: OpensAppIntent, dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Never, OpensAppIntent, Never, IntentDialog>, OpensAppIntent: AppIntent {
        return IntentResultContainer(opensIntent: opensIntent, dialog: dialog)
    }

    public static func result(opensIntent: some AppIntent, dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Never, Never, Never, IntentDialog> {
        return IntentResultContainer(dialog: dialog)
    }

    public static func result(snippetIntent: some SnippetIntent = EmptySnippetIntent()) -> Self
        where Self == IntentResultContainer<Never, Never, _SnippetIntentContainer, Never> {
        return IntentResultContainer(snippet: _SnippetIntentContainer(intent: snippetIntent))
    }

    public static func result<Value>(value: Value, snippetIntent: some SnippetIntent = EmptySnippetIntent()) -> Self
        where Self == IntentResultContainer<Value, Never, _SnippetIntentContainer, Never>, Value: _IntentValue {
        return IntentResultContainer(value: value, snippet: _SnippetIntentContainer(intent: snippetIntent))
    }

    public static func result<Value>(value: Value, opensIntent: some AppIntent,
                                      snippetIntent: some SnippetIntent = EmptySnippetIntent()) -> Self
        where Self == IntentResultContainer<Value, Never, _SnippetIntentContainer, Never>, Value: _IntentValue {
        return IntentResultContainer(value: value, opensIntent: nil,
                                     snippet: _SnippetIntentContainer(intent: snippetIntent))
    }

    public static func result<Value>(value: Value, opensIntent: some AppIntent, dialog: IntentDialog,
                                      snippetIntent: some SnippetIntent = EmptySnippetIntent()) -> Self
        where Self == IntentResultContainer<Value, Never, _SnippetIntentContainer, IntentDialog>, Value: _IntentValue {
        return IntentResultContainer(value: value, dialog: dialog,
                                     snippet: _SnippetIntentContainer(intent: snippetIntent))
    }

    public static func result<Value>(value: Value, dialog: IntentDialog,
                                      snippetIntent: some SnippetIntent = EmptySnippetIntent()) -> Self
        where Self == IntentResultContainer<Value, Never, _SnippetIntentContainer, IntentDialog>, Value: _IntentValue {
        return IntentResultContainer(value: value, dialog: dialog,
                                     snippet: _SnippetIntentContainer(intent: snippetIntent))
    }

    public static func result(opensIntent: some AppIntent,
                              snippetIntent: some SnippetIntent = EmptySnippetIntent()) -> Self
        where Self == IntentResultContainer<Never, Never, _SnippetIntentContainer, Never> {
        return IntentResultContainer(snippet: _SnippetIntentContainer(intent: snippetIntent))
    }

    public static func result(opensIntent: some AppIntent, dialog: IntentDialog,
                              snippetIntent: some SnippetIntent = EmptySnippetIntent()) -> Self
        where Self == IntentResultContainer<Never, Never, _SnippetIntentContainer, IntentDialog> {
        return IntentResultContainer(dialog: dialog, snippet: _SnippetIntentContainer(intent: snippetIntent))
    }

    public static func result(dialog: IntentDialog, snippetIntent: some SnippetIntent = EmptySnippetIntent()) -> Self
        where Self == IntentResultContainer<Never, Never, _SnippetIntentContainer, IntentDialog> {
        return IntentResultContainer(dialog: dialog, snippet: _SnippetIntentContainer(intent: snippetIntent))
    }

    public static func result<Intent>(actionButtonIntent: Intent) -> Self
        where Self == IntentResultContainer<Never, Never, Never, Never>, Intent: AppIntent {
        return IntentResultContainer()
    }

    public static func result<Intent>(actionButtonIntent: Intent, dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Never, Never, Never, IntentDialog>, Intent: AppIntent {
        return IntentResultContainer(dialog: dialog)
    }

    public static func result<Value, Intent>(value: Value, actionButtonIntent: Intent) -> Self
        where Self == IntentResultContainer<Value, Never, Never, Never>, Value: _IntentValue, Intent: AppIntent {
        return IntentResultContainer(value: value)
    }

    public static func result<Value, Intent>(value: Value, actionButtonIntent: Intent, dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Value, Never, Never, IntentDialog>,
              Value: _IntentValue, Intent: AppIntent {
        return IntentResultContainer(value: value, dialog: dialog)
    }

    public static func result<Intent>(actionButtonIntent: Intent, activityIdentifier: String) -> Self
        where Self == IntentResultContainer<Never, Never, Never, Never>, Intent: AppIntent {
        return IntentResultContainer(activityIdentifier: activityIdentifier)
    }

    public static func result<Intent>(actionButtonIntent: Intent, activityIdentifier: String,
                                      dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Never, Never, Never, IntentDialog>, Intent: AppIntent {
        return IntentResultContainer(dialog: dialog, activityIdentifier: activityIdentifier)
    }

    public static func result<Value, Intent>(value: Value, actionButtonIntent: Intent, activityIdentifier: String) -> Self
        where Self == IntentResultContainer<Value, Never, Never, Never>,
              Value: _IntentValue, Intent: AppIntent {
        return IntentResultContainer(value: value, activityIdentifier: activityIdentifier)
    }

    public static func result<Value, Intent>(value: Value, actionButtonIntent: Intent, activityIdentifier: String,
                                             dialog: IntentDialog) -> Self
        where Self == IntentResultContainer<Value, Never, Never, IntentDialog>,
              Value: _IntentValue, Intent: AppIntent {
        return IntentResultContainer(value: value, dialog: dialog, activityIdentifier: activityIdentifier)
    }
}

/// The view of the app's own that a result shows, added in iOS 26. The framework's own view is a
/// SwiftUI bridge; the release this port builds for has no such bridge, so the container carries the
/// intent that asked for the view and nothing pretends to have drawn it.
public struct _SnippetViewContainer {
    public let intent: any SnippetIntent

    public init(intent: any SnippetIntent) {
        self.intent = intent
    }
}

/// The intent whose snippet a result shows, added in iOS 26.
public struct _SnippetIntentContainer {
    public let intent: any SnippetIntent

    public init(intent: any SnippetIntent) {
        self.intent = intent
    }
}

/// An intent whose result shows a view of the app's own, added in iOS 26.
public protocol SnippetIntent: AppIntent where PerformResult: ShowsSnippetView {
    /// Ask the snippet to load itself again.
    func reload() async
}

/// An intent that shows nothing at all, added in iOS 26: the snippet of an app that has none.
public struct EmptySnippetIntent: SnippetIntent {
    public typealias PerformResult = IntentResultContainer<Never, Never, _SnippetViewContainer, Never>
    public typealias SummaryContent = IntentParameterSummary<EmptySnippetIntent>
    public typealias Dependency = Never

    public init() {}

    public static var title: LocalizedStringResource { return CharonLocalized.resource("Empty") }
    public static var isDiscoverable: Bool { return false }
    public static var parameterSummary: SummaryContent { return SummaryContent("") }

    public func perform() async throws -> PerformResult {
        return IntentResultContainer()
    }

    /// An empty snippet has nothing to load again.
    public func reload() async {}
}

/// The bridge that loads the app's own view of a snippet. The framework's own bridge is a SwiftUI loader;
/// the port has no SwiftUI on these releases, so no conformer is carried here.
public protocol _ViewBridgeLoader: AnyObject, Escapable, Copyable {
    static func loadBridge()
}

// MARK: - Errors

/// Why an intent could not do what it was asked.
public struct AppIntentError: Error {
    /// The error that asks the framework to run the intent again from the beginning.
    public static var restartPerform: AppIntentError { return AppIntentError() }

    /// The action the user has to take before the intent can run.
    public enum UserActionRequired: Error {
        case accountSetup
        case signin
        case confirmation

        /// The text the framework's own error prints, measured against the host for `signin`.
        public var errorDescription: String? {
            switch self {
            case .signin: return AppIntentError.preamble + "You need to be signed in to complete this action"
            default: return nil
            }
        }
    }

    /// A permission the intent needs, which the user has to give.
    public enum PermissionRequired: Error {
        case bluetooth
        case contacts
        case localNetwork
        case location(precise: Bool)
        case photos
        case siri

        /// The text the framework's own error prints, measured against the host for
        /// `location(precise: true)`.
        public var errorDescription: String? {
            switch self {
            case .location(let precise):
                return AppIntentError.preamble + "Please grant " + (precise ? "Precise" : "Approximate") +
                    " Location permission to the app"
            default: return nil
            }
        }
    }

    /// Why the intent could not do what it was asked and asking again would not help.
    public enum Unrecoverable: Error {
        case entityNotFound
        case featureCurrentlyRestricted
        case networkFailure
        case notAllowed
        case partialFailure
        case unknown
        case unsupportedOnDevice

        /// The text the framework's own error prints, measured against the host for the two cases
        /// measured (`unknown`, `notAllowed`); the rest carry their own name until they are measured.
        public var errorDescription: String? {
            switch self {
            case .unknown: return AppIntentError.preamble + "Something went wrong"
            case .notAllowed: return AppIntentError.preamble + "This current action is not allowed"
            default: return nil
            }
        }
    }

    /// What has to happen before the intent runs again, when the error is about one parameter.
    public var localizedStringResource: LocalizedStringResource? { return parameterTitle }

    /// The text the framework's own errors carry, which is what a caller reads in a log. The four
    /// sentences here are the ones measured against the host (`Unrecoverable.unknown` and
    /// `.notAllowed`, `UserActionRequired.signin`, `PermissionRequired.location(precise: true)`); the
    /// rest of the cases carry their own name until they are measured too.
    public static let preamble = "AppIntent encountered the following predefined error: "

    /// The parameter the error is about, when the error is about one.
    public var parameterTitle: LocalizedStringResource?
    /// The dialog the error would have shown, when the caller named one.
    public var dialog: IntentDialog?
    /// Whether the parameter may have no value, which is what says whether asking again would help.
    public var optional: Bool = false
    /// How many values the caller had to choose between.
    public var disambiguationCount: Int = 0

    public init() {}

    public init(parameterTitle: LocalizedStringResource, dialog: IntentDialog?, optional: Bool,
                disambiguation: Int = 0) {
        self.init()
        self.parameterTitle = parameterTitle
        self.dialog = dialog
        self.optional = optional
        self.disambiguationCount = disambiguation
    }

    public static func == (lhs: AppIntentError, rhs: AppIntentError) -> Bool {
        return lhs.parameterTitle == rhs.parameterTitle && lhs.optional == rhs.optional
            && lhs.disambiguationCount == rhs.disambiguationCount
    }
}

extension AppIntentError.UserActionRequired: CustomStringConvertible, LocalizedError {
    public var description: String { return errorDescription ?? "UserActionRequired" }
}

extension AppIntentError.Unrecoverable: CustomStringConvertible, LocalizedError {
    public var description: String { return errorDescription ?? "Unrecoverable" }
}

extension AppIntentError.PermissionRequired: CustomStringConvertible, LocalizedError {
    public var description: String { return errorDescription ?? "PermissionRequired" }
}

extension AppIntentError: CustomStringConvertible {
    public var description: String {
        if let title = parameterTitle { return "AppIntentError: \(CharonLocalized.string(of: title))" }
        return "AppIntent encountered an error."
    }
}

/// The conditions under which a confirmation is worth asking for.
public struct ConfirmationConditions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The framework is not sure the source is the right one, so the user is asked.
    public static let lowConfidenceSource = ConfirmationConditions(rawValue: 1 << 0)
}

/// The name on the button that confirms an action. The names the framework names are the ones it
/// shows in the confirmation; a name of the app's own is a `custom` one, with its own labels.
public struct ConfirmationActionName: Sendable {
    private let value: String

    private init(_ value: String) {
        self.value = value
    }

    /// A name the app writes itself, with the labels its own buttons carry.
    public static func custom(acceptLabel: LocalizedStringResource, acceptAlternatives: [LocalizedStringResource] = [],
                              denyLabel: LocalizedStringResource, denyAlternatives: [LocalizedStringResource] = [],
                              destructive: Bool = false) -> ConfirmationActionName {
        return ConfirmationActionName("custom:\(CharonLocalized.string(of: acceptLabel))|\(CharonLocalized.string(of: denyLabel))|\(destructive)")
    }

    public static var add: ConfirmationActionName { return ConfirmationActionName("add") }
    public static var addData: ConfirmationActionName { return ConfirmationActionName("addData") }
    public static var book: ConfirmationActionName { return ConfirmationActionName("book") }
    public static var buy: ConfirmationActionName { return ConfirmationActionName("buy") }
    public static var call: ConfirmationActionName { return ConfirmationActionName("call") }
    public static var checkIn: ConfirmationActionName { return ConfirmationActionName("checkIn") }
    public static var `continue`: ConfirmationActionName { return ConfirmationActionName("continue") }
    public static var create: ConfirmationActionName { return ConfirmationActionName("create") }
    public static var `do`: ConfirmationActionName { return ConfirmationActionName("do") }
    public static var download: ConfirmationActionName { return ConfirmationActionName("download") }
    public static var filter: ConfirmationActionName { return ConfirmationActionName("filter") }
    public static var find: ConfirmationActionName { return ConfirmationActionName("find") }
    public static var get: ConfirmationActionName { return ConfirmationActionName("get") }
    public static var go: ConfirmationActionName { return ConfirmationActionName("go") }
    public static var log: ConfirmationActionName { return ConfirmationActionName("log") }
    public static var open: ConfirmationActionName { return ConfirmationActionName("open") }
    public static var order: ConfirmationActionName { return ConfirmationActionName("order") }
    public static var pay: ConfirmationActionName { return ConfirmationActionName("pay") }
    public static var play: ConfirmationActionName { return ConfirmationActionName("play") }
    public static var playSound: ConfirmationActionName { return ConfirmationActionName("playSound") }
    public static var post: ConfirmationActionName { return ConfirmationActionName("post") }
    public static var request: ConfirmationActionName { return ConfirmationActionName("request") }
    public static var run: ConfirmationActionName { return ConfirmationActionName("run") }
    public static var search: ConfirmationActionName { return ConfirmationActionName("search") }
    public static var send: ConfirmationActionName { return ConfirmationActionName("send") }
    public static var set: ConfirmationActionName { return ConfirmationActionName("set") }
    public static var share: ConfirmationActionName { return ConfirmationActionName("share") }
    public static var start: ConfirmationActionName { return ConfirmationActionName("start") }
    public static var startNavigation: ConfirmationActionName { return ConfirmationActionName("startNavigation") }
    public static var toggle: ConfirmationActionName { return ConfirmationActionName("toggle") }
    public static var turnOff: ConfirmationActionName { return ConfirmationActionName("turnOff") }
    public static var turnOn: ConfirmationActionName { return ConfirmationActionName("turnOn") }
    public static var view: ConfirmationActionName { return ConfirmationActionName("view") }
}

/// One of the options an intent asks the user to pick from, added in iOS 26.
public struct IntentChoiceOption: Equatable {
    /// How an option is shown.
    public struct Style: Hashable {
        public var rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let `default` = Style(rawValue: 0)
        public static let destructive = Style(rawValue: 1)
        public static let cancel = Style(rawValue: 2)
    }

    public let title: LocalizedStringResource
    public let style: Style

    public init(title: LocalizedStringResource, style: Style = .default) {
        self.title = title
        self.style = style
    }

    public static func == (lhs: IntentChoiceOption, rhs: IntentChoiceOption) -> Bool {
        return lhs.title == rhs.title && lhs.style == rhs.style
    }
}

// MARK: - Dialogs and descriptions

/// What an intent says while it runs, or instead of a value: a line, a line and a supporting one, and
/// from iOS 17.2 the system image shown beside them.
public struct IntentDialog: ExpressibleByStringInterpolation, Sendable {
    // The framework declares no public property here, only the four initialisers below: what a caller
    // has of a dialog is the resource it built and the text it resolves to. These are the module's own
    // storage, and the port's own code is what reads them.
    let full: LocalizedStringResource
    let supporting: LocalizedStringResource?
    /// The system image shown beside the dialog, added in iOS 17.2.
    let systemImageName: String?

    public init(_ string: LocalizedStringResource) {
        self.full = string
        self.supporting = nil
        self.systemImageName = nil
    }

    public init(full: LocalizedStringResource, supporting: LocalizedStringResource) {
        self.full = full
        self.supporting = supporting
        self.systemImageName = nil
    }

    public init(full: LocalizedStringResource, systemImageName: String) {
        self.full = full
        self.supporting = nil
        self.systemImageName = systemImageName
    }

    public init(full: LocalizedStringResource, supporting: LocalizedStringResource, systemImageName: String) {
        self.full = full
        self.supporting = supporting
        self.systemImageName = systemImageName
    }

    public init(stringLiteral value: String) {
        self.init(LocalizedStringResource(stringLiteral: value))
    }

    public init(stringInterpolation: StringInterpolation) {
        self = stringInterpolation.value
    }

    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    /// The interpolation of a dialog: a line with holes, each hole a resource or a value written into
    /// the line.
    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var value: IntentDialog

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
            value = IntentDialog(CharonLocalized.resource(""))
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
            flush()
        }

        public mutating func appendInterpolation(_ resource: LocalizedStringResource) {
            literal += CharonLocalized.string(of: resource)
            flush()
        }

        public mutating func appendInterpolation(_ value: any CustomLocalizedStringResourceConvertible) {
            literal += CharonLocalized.string(of: value.localizedStringResource)
            flush()
        }

        public mutating func appendInterpolation(_ value: String) { appendInterpolation(resource(value)) }
        public mutating func appendInterpolation(_ value: Int) { appendInterpolation(resource(value)) }
        public mutating func appendInterpolation(_ value: Double) { appendInterpolation(resource(value)) }
        public mutating func appendInterpolation<T>(_ value: T) { appendInterpolation(resource(value)) }

        private func resource<T>(_ value: T) -> LocalizedStringResource {
            let text = String(describing: value)
            #if CHARON_APPINTENTS_CARRIES_LOCALIZED_STRING
            return LocalizedStringResource(stringLiteral: text)
            #else
            return CharonLocalized.resource(text, defaultValue: text)
            #endif
        }

        private mutating func flush() {
            #if CHARON_APPINTENTS_CARRIES_LOCALIZED_STRING
            value = IntentDialog(LocalizedStringResource(stringLiteral: literal))
            #else
            value = IntentDialog(CharonLocalized.resource(literal, defaultValue: literal))
            #endif
        }
    }
}

/// What an intent does, in the words the app writes: the description itself, the category it sits in,
/// the words a search finds it by, and from iOS 17 the name of the value it returns.
public struct IntentDescription: ExpressibleByStringLiteral {
    public let descriptionText: String
    public let categoryName: String?
    public let searchKeywords: [String]
    /// The name of the value the intent returns, added in iOS 17.
    public let resultValueName: String?

    public init(_ description: String, categoryName: String? = nil, searchKeywords: [String] = []) {
        self.descriptionText = description
        self.categoryName = categoryName
        self.searchKeywords = searchKeywords
        self.resultValueName = nil
    }

    public init(_ description: String, categoryName: String? = nil, searchKeywords: [String] = [],
                resultValueName: String? = nil) {
        self.descriptionText = description
        self.categoryName = categoryName
        self.searchKeywords = searchKeywords
        self.resultValueName = resultValueName
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String
}

/// Where an intent runs, as the framework sees it: when the run started, and how it may carry on.
public struct IntentSystemContext {
    /// When the run started, which is the port's own clock read at the moment the run began.
    public let preciseTimestamp: Date

    public init(preciseTimestamp: Date = Date()) {
        self.preciseTimestamp = preciseTimestamp
    }

    /// The mode the run is in, added in iOS 26.
    public var currentMode: IntentModes.Current { return CharonForeground.mode }
}
