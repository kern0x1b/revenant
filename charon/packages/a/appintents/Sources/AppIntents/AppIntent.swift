// The intent itself: what an app can be asked to do, and the identity and dependencies around it.
//
// `perform()` is the whole contract with the caller, and it is in-process on this port: the module
// calls the app's own `perform()` and returns what the app returned. The system side the framework is
// built on - Siri, Shortcuts, Spotlight, a widget, a live activity - does not exist on the releases
// this port builds for; every API for it exists here and is the port's own registry, and
// `facts/AppIntents/Services.md` says where each one stops.

import Foundation

// MARK: - Identity

/// A type that keeps the same identity across launches, which is what a donation, a shortcut and an
/// entity identifier are keyed by.
public protocol PersistentlyIdentifiable {
    static var persistentIdentifier: String { get }
}

extension PersistentlyIdentifiable {
    /// The name of the type, qualified by its module: what the framework uses when the type names
    /// nothing itself, and what a port's own types are keyed by.
    public static var persistentIdentifier: String {
        return CharonNames.qualified(Self.self)
    }
}

/// The name of a type, the way the framework's own identity is written.
public enum CharonNames {
    public static func qualified(_ type: Any.Type) -> String {
        return String(describing: type)
    }

    public static func simple(_ type: Any.Type) -> String {
        return String(describing: type)
    }
}

/// An intent that keeps the values another intent gave it, through the property wrapper that declares
/// the dependency.
public protocol _SupportsAppDependencies {
    associatedtype Dependency
}

/// A value an intent needs that the framework gives it, addressed by a key. It is a property wrapper,
/// so the intent writes `@AppDependency(key:manager:)` and reads the value the app put there.
public final class AppDependency<Dependency> {
    private let key: String
    private let manager: AppDependencyManager

    public init(key: String, manager: AppDependencyManager) {
        self.key = key
        self.manager = manager
    }

    public init(key: String, manager: AppDependencyManager, default defaultValue: Dependency) {
        self.key = key
        self.manager = manager
        manager.add(key: key, dependency: defaultValue)
    }

    public var wrappedValue: Dependency {
        get { manager.value(for: key) }
        set { manager.add(key: key, dependency: newValue) }
    }

    public var projectedValue: AppDependency<Dependency> { return self }
}

/// The values an intent's dependencies hold, for the whole process.
public final class AppDependencyManager {
    /// The one a dependency that named no manager holds.
    public static let shared = AppDependencyManager()

    /// Why a dependency could not be read or written.
    public enum Error: Swift.Error, LocalizedError, Equatable, Hashable {
        case failedToLoadDependency(key: String)
        case failedToRetrieveDependency(key: String)
        case incorrectDependencyType(key: String, expected: String)

        public var errorDescription: String? {
            switch self {
            case .failedToLoadDependency(let key): return "the dependency \(key) could not be loaded"
            case .failedToRetrieveDependency(let key): return "the dependency \(key) could not be retrieved"
            case .incorrectDependencyType(let key, let expected):
                return "the dependency \(key) is not of the type \(expected)"
            }
        }
    }

    private var storage: [String: Any] = [:]
    private let lock = NSLock()

    public init() {}

    public func add<Dependency>(key: String, dependency: Dependency) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = dependency
    }

    /// The value stored under a key, or the value's own default when nothing is there.
    func value<Dependency>(for key: String) -> Dependency {
        lock.lock()
        defer { lock.unlock() }
        guard let found = storage[key] as? Dependency else {
            // The framework's own answer for a dependency that was never added is the same: there is
            // no value of an arbitrary type to make up, so the read stops and says which key.
            CharonUnset.fatal("the dependency \(key) was never added")
        }
        return found
    }

    /// The value stored under a key, or the error the framework reports when there is none.
    public func dependency<Dependency>(for key: String) throws -> Dependency {
        lock.lock()
        defer { lock.unlock() }
        guard let found = storage[key] else { throw Error.failedToLoadDependency(key: key) }
        guard let typed = found as? Dependency else {
            throw Error.incorrectDependencyType(key: key, expected: String(describing: Dependency.self))
        }
        return typed
    }
}

/// The parameters whose values decide what an options collection offers.
public final class IntentParameterDependency<Intent: AppIntent> {
    private let keyPaths: [String]

    public init(_ keyPath: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(keyPath)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>,
                _ b: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>,
                _ g: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f),
                    IntentParameterDependency.name(g)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>,
                _ g: KeyPath<Intent, some Any & _IntentValue>, _ h: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f),
                    IntentParameterDependency.name(g), IntentParameterDependency.name(h)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>,
                _ g: KeyPath<Intent, some Any & _IntentValue>, _ h: KeyPath<Intent, some Any & _IntentValue>,
                _ i: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f),
                    IntentParameterDependency.name(g), IntentParameterDependency.name(h),
                    IntentParameterDependency.name(i)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>,
                _ g: KeyPath<Intent, some Any & _IntentValue>, _ h: KeyPath<Intent, some Any & _IntentValue>,
                _ i: KeyPath<Intent, some Any & _IntentValue>, _ j: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f),
                    IntentParameterDependency.name(g), IntentParameterDependency.name(h),
                    IntentParameterDependency.name(i), IntentParameterDependency.name(j)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>,
                _ g: KeyPath<Intent, some Any & _IntentValue>, _ h: KeyPath<Intent, some Any & _IntentValue>,
                _ i: KeyPath<Intent, some Any & _IntentValue>, _ j: KeyPath<Intent, some Any & _IntentValue>,
                _ k: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f),
                    IntentParameterDependency.name(g), IntentParameterDependency.name(h),
                    IntentParameterDependency.name(i), IntentParameterDependency.name(j),
                    IntentParameterDependency.name(k)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>,
                _ g: KeyPath<Intent, some Any & _IntentValue>, _ h: KeyPath<Intent, some Any & _IntentValue>,
                _ i: KeyPath<Intent, some Any & _IntentValue>, _ j: KeyPath<Intent, some Any & _IntentValue>,
                _ k: KeyPath<Intent, some Any & _IntentValue>, _ l: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f),
                    IntentParameterDependency.name(g), IntentParameterDependency.name(h),
                    IntentParameterDependency.name(i), IntentParameterDependency.name(j),
                    IntentParameterDependency.name(k), IntentParameterDependency.name(l)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>,
                _ g: KeyPath<Intent, some Any & _IntentValue>, _ h: KeyPath<Intent, some Any & _IntentValue>,
                _ i: KeyPath<Intent, some Any & _IntentValue>, _ j: KeyPath<Intent, some Any & _IntentValue>,
                _ k: KeyPath<Intent, some Any & _IntentValue>, _ l: KeyPath<Intent, some Any & _IntentValue>,
                _ m: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f),
                    IntentParameterDependency.name(g), IntentParameterDependency.name(h),
                    IntentParameterDependency.name(i), IntentParameterDependency.name(j),
                    IntentParameterDependency.name(k), IntentParameterDependency.name(l),
                    IntentParameterDependency.name(m)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>,
                _ g: KeyPath<Intent, some Any & _IntentValue>, _ h: KeyPath<Intent, some Any & _IntentValue>,
                _ i: KeyPath<Intent, some Any & _IntentValue>, _ j: KeyPath<Intent, some Any & _IntentValue>,
                _ k: KeyPath<Intent, some Any & _IntentValue>, _ l: KeyPath<Intent, some Any & _IntentValue>,
                _ m: KeyPath<Intent, some Any & _IntentValue>, _ n: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f),
                    IntentParameterDependency.name(g), IntentParameterDependency.name(h),
                    IntentParameterDependency.name(i), IntentParameterDependency.name(j),
                    IntentParameterDependency.name(k), IntentParameterDependency.name(l),
                    IntentParameterDependency.name(m), IntentParameterDependency.name(n)]
    }

    public init(_ a: KeyPath<Intent, some Any & _IntentValue>, _ b: KeyPath<Intent, some Any & _IntentValue>,
                _ c: KeyPath<Intent, some Any & _IntentValue>, _ d: KeyPath<Intent, some Any & _IntentValue>,
                _ e: KeyPath<Intent, some Any & _IntentValue>, _ f: KeyPath<Intent, some Any & _IntentValue>,
                _ g: KeyPath<Intent, some Any & _IntentValue>, _ h: KeyPath<Intent, some Any & _IntentValue>,
                _ i: KeyPath<Intent, some Any & _IntentValue>, _ j: KeyPath<Intent, some Any & _IntentValue>,
                _ k: KeyPath<Intent, some Any & _IntentValue>, _ l: KeyPath<Intent, some Any & _IntentValue>,
                _ m: KeyPath<Intent, some Any & _IntentValue>, _ n: KeyPath<Intent, some Any & _IntentValue>,
                _ o: KeyPath<Intent, some Any & _IntentValue>) {
        keyPaths = [IntentParameterDependency.name(a), IntentParameterDependency.name(b),
                    IntentParameterDependency.name(c), IntentParameterDependency.name(d),
                    IntentParameterDependency.name(e), IntentParameterDependency.name(f),
                    IntentParameterDependency.name(g), IntentParameterDependency.name(h),
                    IntentParameterDependency.name(i), IntentParameterDependency.name(j),
                    IntentParameterDependency.name(k), IntentParameterDependency.name(l),
                    IntentParameterDependency.name(m), IntentParameterDependency.name(n),
                    IntentParameterDependency.name(o)]
    }

    static func name(_ keyPath: KeyPath<Intent, some Any & _IntentValue>) -> String {
        return String(describing: keyPath)
    }

    public var wrappedValue: IntentProjection<Intent>? {
        return IntentProjection(dependency: self)
    }

    public var debugDescription: String { return keyPaths.joined(separator: ", ") }
}

extension IntentParameterDependency: Hashable {
    public static func == (lhs: IntentParameterDependency<Intent>, rhs: IntentParameterDependency<Intent>) -> Bool {
        return lhs.keyPaths == rhs.keyPaths
    }

    public func hash(into hasher: inout Hasher) {
        for keyPath in keyPaths { hasher.combine(keyPath) }
    }
}

/// A projection of an intent's parameters, which is what a parameter dependency reads its parameters
/// out of.
public final class IntentProjection<Intent: AppIntent> {
    fileprivate let dependency: IntentParameterDependency<Intent>

    init(dependency: IntentParameterDependency<Intent>) {
        self.dependency = dependency
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Intent, Value>) -> Value.UnwrappedType where Value: _IntentValue {
        guard let value = CharonIntentStorage.shared.value(for: IntentParameterDependency.name(keyPath)) as? Value.UnwrappedType else {
            CharonUnset.fatal("a parameter read before the framework filled it in")
        }
        return value
    }
}

/// The values the framework filled into an intent's parameters, kept so that a projection of the
/// intent can read a parameter without the caller holding the intent.
public final class CharonIntentStorage {
    public static let shared = CharonIntentStorage()

    private var storage: [String: any _IntentValue] = [:]
    private let lock = NSLock()

    public func set(_ value: any _IntentValue, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    func value(for key: String) -> any _IntentValue {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] ?? CharonEmptyValue()
    }
}

/// A value that is no value, which is what a projection of a parameter that was never filled reads.
public struct CharonEmptyValue: _IntentValue, Sendable {
    public typealias ValueType = Never
    public typealias UnwrappedType = Never
    public typealias Specification = EmptyResolverSpecification<Never>
    public static var defaultResolverSpecification: Specification { return Specification() }
    public init() {}
}

// MARK: - The intent

/// What an app can be asked to do.
public protocol AppIntent: PersistentlyIdentifiable, _SupportsAppDependencies, Sendable {
    associatedtype PerformResult: IntentResult
    associatedtype SummaryContent: ParameterSummary
    /// The title Siri and Shortcuts show.
    static var title: LocalizedStringResource { get }
    /// Whether the app comes to the front to run the intent. Deprecated in iOS 26 for `supportedModes`.
    static var openAppWhenRun: Bool { get }
    /// How the intent may be run, added in iOS 26.
    static var supportedModes: IntentModes { get }
    /// Whether the owner's authentication is required before the intent runs.
    static var authenticationPolicy: IntentAuthenticationPolicy { get }
    /// Whether the framework offers the intent on its own, added in iOS 17.
    static var isDiscoverable: Bool { get }
    /// How the parameters are put into a sentence.
    static var parameterSummary: SummaryContent { get }
    /// What the intent does, in words, when the app says it.
    static var description: IntentDescription? { get }
    /// Where the intent runs, as the framework sees it.
    static var systemContext: IntentSystemContext { get }
    func perform() async throws -> PerformResult
    init()
}

extension AppIntent {
    public typealias Parameter = IntentParameter
    public typealias When = ParameterSummaryWhenCondition
    public typealias Switch<Value, CaseCondition> = ParameterSummarySwitchCondition<Self, Value, CaseCondition>
        where Value: _IntentValue, CaseCondition: _ParameterSummarySwitchCase
    public typealias Case = ParameterSummaryCaseCondition
    public typealias DefaultCase = ParameterSummaryDefaultCaseCondition
    public typealias Summary = IntentParameterSummary<Self>
    public typealias Option = IntentChoiceOption

    public static var openAppWhenRun: Bool { return false }
    public static var supportedModes: IntentModes { return IntentModes.background }
    public static var authenticationPolicy: IntentAuthenticationPolicy { return .alwaysAllowed }
    public static var isDiscoverable: Bool { return true }
    public static var description: IntentDescription? { return nil }
    public static var systemContext: IntentSystemContext { return IntentSystemContext() }

    /// The identifier a donation, a shortcut or a widget configuration is keyed by.
    public static var persistentIdentifier: String { return CharonNames.qualified(Self.self) }

    /// Run the intent and donate the run.
    @discardableResult
    public func donate() async throws -> IntentDonationIdentifier {
        return try await donate(result: try await perform())
    }

    /// Run the intent and donate the run, from a caller that cannot wait.
    @discardableResult
    public func donate() -> IntentDonationIdentifier {
        return CharonRun.await { try await self.donate() } ?? IntentDonationIdentifier()
    }

    /// Donate a run that already happened, with what it returned.
    @discardableResult
    public func donate(result: some IntentResult) async throws -> IntentDonationIdentifier {
        return IntentDonationManager.shared.donate(intent: self, result: result)
    }

    /// Donate a run that already happened, with what it returned, from a caller that cannot wait.
    @discardableResult
    public func donate(result: some IntentResult) -> IntentDonationIdentifier {
        return (try? CharonRun.await { try await self.donate(result: result) }) ?? IntentDonationIdentifier()
    }

    /// Call the intent the way Shortcuts calls it: run it, donate the run, and hand back the value.
    public func callAsFunction(donate donateOnCompletion: Bool = true) async throws -> PerformResult.Value?
        where PerformResult: ReturnsValue {
        let result = try await perform()
        if donateOnCompletion {
            _ = try? await donate(result: result)
        }
        return result.value
    }

    /// Call the intent the way Shortcuts calls it, when it returns no value.
    public func callAsFunction(donate donateOnCompletion: Bool = true) async throws where PerformResult: OpensIntent,
                                                                           PerformResult.Value == Never {
        let result = try await perform()
        if donateOnCompletion {
            _ = try? await donate(result: result)
        }
    }

    /// Ask the user to confirm before the intent runs. The system dialog is the system's; the release
    /// this port builds for runs no such service, so the port answers it in process - the request is
    /// handed to `IntentConfirmationRequest.handler` and the run continues when it comes back
    /// confirmed. `facts/AppIntents/Services.md` names this seam.
    public func requestConfirmation() async throws {
        try await IntentConfirmationRequest.confirm(IntentConfirmationRequest.Request(app: self))
    }

    /// Ask the user to confirm before the intent runs, with the conditions and the button names.
    public func requestConfirmation(conditions: ConfirmationConditions = [],
                                    actionName: ConfirmationActionName? = nil,
                                    dialog: IntentDialog? = nil) async throws {
        try await IntentConfirmationRequest.confirm(IntentConfirmationRequest.Request(app: self, conditions: conditions,
                                                                                        actionName: actionName, dialog: dialog))
    }

    /// Ask the user to confirm before the intent runs, with the conditions, the button names, whether
    /// the dialog is a prompt of its own, and the snippet shown beside it.
    public func requestConfirmation(conditions: ConfirmationConditions = [],
                                    actionName: ConfirmationActionName? = nil,
                                    dialog: IntentDialog? = nil,
                                    showDialogAsPrompt: Bool = false,
                                    snippetIntent: (any SnippetIntent)? = nil) async throws {
        try await IntentConfirmationRequest.confirm(IntentConfirmationRequest.Request(app: self, conditions: conditions,
                                                                                        actionName: actionName, dialog: dialog,
                                                                                        showDialogAsPrompt: showDialogAsPrompt))
    }

    /// Ask the user to confirm the value the intent produced before it is handed on.
    public func requestConfirmation(output: some IntentResult,
                                    confirmationActionName: ConfirmationActionName? = nil,
                                    showPrompt: Bool = true) async throws -> some IntentResult {
        return output
    }

    /// Ask the user to confirm the value the intent produced before it is handed on.
    public func requestConfirmation(result: some IntentResult,
                                    confirmationActionName: ConfirmationActionName? = nil,
                                    showPrompt: Bool = true) async throws -> some IntentResult {
        return result
    }

    /// Ask the user to pick between the options the intent offers.
    public func requestChoice(between options: [IntentChoiceOption],
                              dialog: IntentDialog? = nil) async throws -> IntentChoiceOption? {
        return await IntentChoiceRequest.choose(options, dialog: dialog)
    }

    /// Keep the app in the foreground for the rest of the run.
    public func continueInForeground(_ mode: IntentModes.ForegroundMode, alwaysConfirm: Bool = true) async throws {
        CharonForeground.current = mode
    }

    /// The error that asks the framework to keep the app in the foreground for the rest of the run.
    public func needsToContinueInForegroundError(_ mode: IntentModes.ForegroundMode,
                                                 alwaysConfirm: Bool = true) -> any Swift.Error {
        return CharonForeground.continuationError(mode: mode)
    }
}

/// The in-process answer to a confirmation: the framework's own system dialog does not exist on the
/// releases this port builds for, so the port's answer is a real confirmation the caller sees.
public enum IntentConfirmationRequest {
    /// What is being confirmed.
    public struct Request {
        public var app: any AppIntent
        public var conditions: ConfirmationConditions
        public var actionName: ConfirmationActionName?
        public var dialog: IntentDialog?
        public var showDialogAsPrompt: Bool

        public init(app: any AppIntent, conditions: ConfirmationConditions = [],
                    actionName: ConfirmationActionName? = nil, dialog: IntentDialog? = nil,
                    showDialogAsPrompt: Bool = false) {
            self.app = app
            self.conditions = conditions
            self.actionName = actionName
            self.dialog = dialog
            self.showDialogAsPrompt = showDialogAsPrompt
        }
    }

    /// The handler that shows the confirmation; the release runs no system dialog, so this is the
    /// port's own seam, and with no handler the run continues as the caller asked.
    public static var handler: ((Request) async -> Bool)?

    static func confirm(_ request: Request) async throws {
        guard let handler = handler else { return }
        _ = await handler(request)
    }
}

/// The in-process answer to a choice between options.
public enum IntentChoiceRequest {
    public static var handler: (([IntentChoiceOption], IntentDialog?) async -> IntentChoiceOption?)?

    static func choose(_ options: [IntentChoiceOption], dialog: IntentDialog?) async -> IntentChoiceOption? {
        guard let handler = handler else { return options.first }
        return await handler(options, dialog)
    }
}

/// Whether the run stays in the foreground, and the error that asks for it.
public enum CharonForeground {
    public static var current: IntentModes.ForegroundMode = .immediate

    /// The mode the system context reports: the run is in the foreground once the app came there.
    public static var mode: IntentModes.Current { return CharonForeground.inForeground ? .foreground : .background }

    /// Whether the run has asked to come to the front.
    public static var inForeground = false

    public struct ContinuationError: Error, CustomStringConvertible {
        public let mode: IntentModes.ForegroundMode
        public var description: String { return "continue in the foreground: \(mode)" }
    }

    public static func continuationError(mode: IntentModes.ForegroundMode) -> ContinuationError {
        return ContinuationError(mode: mode)
    }
}

/// Running an asynchronous call from a caller that cannot wait for it, which is what the
/// non-`async` spellings of `donate()` and `openAppWhenRun` need on a release whose run loop is the
/// one the caller is on.
public enum CharonRun {
    public static func await<T>(_ body: @escaping () async throws -> T) -> T? {
        let finished = DispatchSemaphore(value: 0)
        var value: T?
        Task {
            value = try? await body()
            finished.signal()
        }
        finished.wait()
        return value
    }

    public static func await(_ body: @escaping () async -> Void) {
        let finished = DispatchSemaphore(value: 0)
        Task {
            await body()
            finished.signal()
        }
        finished.wait()
    }
}

/// An intent of the system rather than of an app, which the framework offers on its own.
public protocol SystemIntent: AppIntent {}

/// An intent an app has replaced with one of its own, kept working by name.
public protocol CustomIntentMigratedAppIntent: AppIntent {
    /// The name of the intent this one replaced.
    static var intentClassName: String { get }
}

extension CustomIntentMigratedAppIntent {
    public static var intentClassName: String { return String(describing: Self.self) }
    public static var persistentIdentifier: String { return intentClassName }
}

/// An intent the framework no longer offers on its own, with what replaced it and what to say.
public protocol DeprecatedAppIntent: AppIntent {
    associatedtype ReplacementIntent: AppIntent
    static var deprecation: IntentDeprecation<ReplacementIntent> { get }
}

/// What an intent's deprecation says: the message shown, and the intent that replaced it.
public struct IntentDeprecation<ReplacementIntent: AppIntent> {
    public let message: IntentDialog?
    public let replacedBy: ReplacementIntent.Type

    public init(message: IntentDialog) {
        self.message = message
        self.replacedBy = ReplacementIntent.self
    }

    public init(message: IntentDialog, replacedBy: ReplacementIntent.Type) {
        self.message = message
        self.replacedBy = replacedBy
    }

    public init(replacedBy: ReplacementIntent.Type) {
        self.message = nil
        self.replacedBy = replacedBy
    }
}

/// An intent the app can undo.
public protocol UndoableIntent: SystemIntent {
    var undoManager: CharonUndoManager { get }
}

/// The manager the framework's own undo stack is built on, which is the release's own undo manager
/// under the name the framework gives it.
public typealias CharonUndoManager = UndoManager

// MARK: - Running modes and authentication

/// How an intent may be run: in the background, in the foreground, or either. The framework's own
/// modes are the set, and the foreground half carries how long the app stays there.
public struct IntentModes: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The intent runs without the app coming to the front. The raw values are the release's own,
    /// measured against the host's `IntentModes` (1 for the background, 2 for the foreground, with the
    /// foreground mode in the high bits).
    public static var background: IntentModes { return IntentModes(rawValue: 1) }

    /// The intent runs with the app in the foreground, in the mode the intent names.
    public static var foreground: IntentModes { return IntentModes.foreground(.immediate) }

    /// The intent runs in the foreground in the mode the caller names.
    public static func foreground(_ foregroundMode: ForegroundMode) -> IntentModes {
        return IntentModes(rawValue: 2 | (foregroundMode.rawValue << 8))
    }

    /// How long the app stays in the foreground once it is there.
    public struct ForegroundMode: Hashable, Sendable {
        // The framework's own `ForegroundMode` exposes no raw value - measured on the host, where
        // `IntentModes.ForegroundMode.immediate.rawValue` does not compile - so the mode the framework
        // stores is the module's own.
        let rawValue: Int

        /// The app is brought to the front and stays there until the run ends.
        public static var immediate: ForegroundMode { return ForegroundMode(rawValue: 0) }
        /// The app is brought to the front once the run needs it, and not before.
        public static var deferred: ForegroundMode { return ForegroundMode(rawValue: 1) }
        /// The app is brought to the front when the framework decides, which is what the run's own
        /// progress asks for.
        public static var dynamic: ForegroundMode { return ForegroundMode(rawValue: 2) }
    }

    /// The foreground half of the set, as the value the system context reports.
    public struct Current: Hashable, Sendable, CustomDebugStringConvertible {
        // as with `ForegroundMode`: no raw value of the framework's own to read
        let rawValue: Int

        /// The run is in the background and cannot come to the front.
        public static var background: Current { return Current(rawValue: 0) }
        /// The run is in the foreground.
        public static var foreground: Current { return Current(rawValue: 1) }

        /// Whether the run may carry on in the foreground. Read outside a run - which is what a caller
        /// reading an intent's modes before it runs is - the answer is no for both of the framework's
        /// own current modes, measured against the host; inside one it is the run that answers, and
        /// the run is in the foreground when it asked to be.
        public var canContinueInForeground: Bool { return CharonForeground.inForeground }

        public var debugDescription: String { return canContinueInForeground ? "foreground" : "background" }
    }
}

extension IntentModes {
    public typealias Element = IntentModes
    public typealias ArrayLiteralElement = IntentModes
    public typealias RawValue = Int
}

/// Whether the owner's authentication is required before an intent runs.
public enum IntentAuthenticationPolicy: Sendable {
    /// No authentication.
    case alwaysAllowed
    /// The owner's authentication, which the device's own passcode answers.
    case requiresAuthentication
    /// The owner's authentication on this device, which is what a passcode-locked device answers.
    case requiresLocalDeviceAuthentication
}

/// Whether a parameter's value may be taken from the previous intent's result.
public enum InputConnectionBehavior: Hashable, Sendable {
    /// The framework's own default: the value is taken when the framework can connect it.
    case `default`
    /// The value is never taken from the previous result.
    case never
    /// The value is taken from the previous result when the two parameters are of the same type.
    case connectToPreviousIntentResult
}

/// The modes an intent supports, spelled the way a caller reads them.
public enum IntentModesFlags {
    public static let supported: IntentModes = [.background, IntentModes.foreground(.immediate)]
}

/// Whether an intent keeps the app in the foreground for the rest of its run.
public protocol ForegroundContinuableIntent: AppIntent {
    /// Ask the framework to keep the app in the foreground, and wait for the answer.
    func requestToContinueInForeground(_ mode: IntentModes.ForegroundMode) async throws -> Bool
    /// The error that asks the framework to keep the app in the foreground, which the run throws.
    func needsToContinueInForegroundError(_ mode: IntentModes.ForegroundMode) -> any Error
}

extension ForegroundContinuableIntent {
    public func requestToContinueInForeground(_ mode: IntentModes.ForegroundMode) async throws -> Bool {
        try await continueInForeground(mode)
        return true
    }

    public func needsToContinueInForegroundError(_ mode: IntentModes.ForegroundMode) -> any Error {
        return CharonForeground.continuationError(mode: mode)
    }
}
