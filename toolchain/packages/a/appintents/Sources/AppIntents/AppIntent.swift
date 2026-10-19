import Foundation

public protocol PersistentlyIdentifiable {
    static var persistentIdentifier: String { get }
}

extension PersistentlyIdentifiable {
    public static var persistentIdentifier: String {
        return RevenantNames.qualified(Self.self)
    }
}

public enum RevenantNames {
    public static func qualified(_ type: Any.Type) -> String {
        return String(describing: type)
    }

    public static func simple(_ type: Any.Type) -> String {
        return String(describing: type)
    }
}

public protocol _SupportsAppDependencies {
    associatedtype Dependency
}

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

public final class AppDependencyManager {
    public static let shared = AppDependencyManager()

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

    func value<Dependency>(for key: String) -> Dependency {
        lock.lock()
        defer { lock.unlock() }
        guard let found = storage[key] as? Dependency else {
            RevenantUnset.fatal("the dependency \(key) was never added")
        }
        return found
    }

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

public final class IntentProjection<Intent: AppIntent> {
    fileprivate let dependency: IntentParameterDependency<Intent>

    init(dependency: IntentParameterDependency<Intent>) {
        self.dependency = dependency
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Intent, Value>) -> Value.UnwrappedType where Value: _IntentValue {
        guard let value = RevenantIntentStorage.shared.value(for: IntentParameterDependency.name(keyPath)) as? Value.UnwrappedType else {
            RevenantUnset.fatal("a parameter read before the framework filled it in")
        }
        return value
    }
}

public final class RevenantIntentStorage {
    public static let shared = RevenantIntentStorage()

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
        return storage[key] ?? RevenantEmptyValue()
    }
}

public struct RevenantEmptyValue: _IntentValue, Sendable {
    public typealias ValueType = Never
    public typealias UnwrappedType = Never
    public typealias Specification = EmptyResolverSpecification<Never>
    public static var defaultResolverSpecification: Specification { return Specification() }
    public init() {}
}

public protocol AppIntent: PersistentlyIdentifiable, _SupportsAppDependencies, Sendable {
    associatedtype PerformResult: IntentResult
    associatedtype SummaryContent: ParameterSummary
    static var title: LocalizedStringResource { get }
    static var openAppWhenRun: Bool { get }
    static var supportedModes: IntentModes { get }
    static var authenticationPolicy: IntentAuthenticationPolicy { get }
    static var isDiscoverable: Bool { get }
    static var parameterSummary: SummaryContent { get }
    static var description: IntentDescription? { get }
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

    public static var persistentIdentifier: String { return RevenantNames.qualified(Self.self) }

    @discardableResult
    public func donate() async throws -> IntentDonationIdentifier {
        return try await donate(result: try await perform())
    }

    @discardableResult
    public func donate() -> IntentDonationIdentifier {
        return RevenantRun.await { try await self.donate() } ?? IntentDonationIdentifier()
    }

    @discardableResult
    public func donate(result: some IntentResult) async throws -> IntentDonationIdentifier {
        return IntentDonationManager.shared.donate(intent: self, result: result)
    }

    @discardableResult
    public func donate(result: some IntentResult) -> IntentDonationIdentifier {
        return (try? RevenantRun.await { try await self.donate(result: result) }) ?? IntentDonationIdentifier()
    }

    public func callAsFunction(donate donateOnCompletion: Bool = true) async throws -> PerformResult.Value?
        where PerformResult: ReturnsValue {
        let result = try await perform()
        if donateOnCompletion {
            _ = try? await donate(result: result)
        }
        return result.value
    }

    public func callAsFunction(donate donateOnCompletion: Bool = true) async throws where PerformResult: OpensIntent,
                                                                           PerformResult.Value == Never {
        let result = try await perform()
        if donateOnCompletion {
            _ = try? await donate(result: result)
        }
    }

    public func requestConfirmation() async throws {
        try await IntentConfirmationRequest.confirm(IntentConfirmationRequest.Request(app: self))
    }

    public func requestConfirmation(conditions: ConfirmationConditions = [],
                                    actionName: ConfirmationActionName? = nil,
                                    dialog: IntentDialog? = nil) async throws {
        try await IntentConfirmationRequest.confirm(IntentConfirmationRequest.Request(app: self, conditions: conditions,
                                                                                        actionName: actionName, dialog: dialog))
    }

    public func requestConfirmation(conditions: ConfirmationConditions = [],
                                    actionName: ConfirmationActionName? = nil,
                                    dialog: IntentDialog? = nil,
                                    showDialogAsPrompt: Bool = false,
                                    snippetIntent: (any SnippetIntent)? = nil) async throws {
        try await IntentConfirmationRequest.confirm(IntentConfirmationRequest.Request(app: self, conditions: conditions,
                                                                                        actionName: actionName, dialog: dialog,
                                                                                        showDialogAsPrompt: showDialogAsPrompt))
    }

    public func requestConfirmation(output: some IntentResult,
                                    confirmationActionName: ConfirmationActionName? = nil,
                                    showPrompt: Bool = true) async throws -> some IntentResult {
        return output
    }

    public func requestConfirmation(result: some IntentResult,
                                    confirmationActionName: ConfirmationActionName? = nil,
                                    showPrompt: Bool = true) async throws -> some IntentResult {
        return result
    }

    public func requestChoice(between options: [IntentChoiceOption],
                              dialog: IntentDialog? = nil) async throws -> IntentChoiceOption? {
        return await IntentChoiceRequest.choose(options, dialog: dialog)
    }

    public func continueInForeground(_ mode: IntentModes.ForegroundMode, alwaysConfirm: Bool = true) async throws {
        RevenantForeground.current = mode
    }

    public func needsToContinueInForegroundError(_ mode: IntentModes.ForegroundMode,
                                                 alwaysConfirm: Bool = true) -> any Swift.Error {
        return RevenantForeground.continuationError(mode: mode)
    }
}

public enum IntentConfirmationRequest {
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

    public static var handler: ((Request) async -> Bool)?

    static func confirm(_ request: Request) async throws {
        guard let handler = handler else { return }
        _ = await handler(request)
    }
}

public enum IntentChoiceRequest {
    public static var handler: (([IntentChoiceOption], IntentDialog?) async -> IntentChoiceOption?)?

    static func choose(_ options: [IntentChoiceOption], dialog: IntentDialog?) async -> IntentChoiceOption? {
        guard let handler = handler else { return options.first }
        return await handler(options, dialog)
    }
}

public enum RevenantForeground {
    public static var current: IntentModes.ForegroundMode = .immediate

    public static var mode: IntentModes.Current { return RevenantForeground.inForeground ? .foreground : .background }

    public static var inForeground = false

    public struct ContinuationError: Error, CustomStringConvertible {
        public let mode: IntentModes.ForegroundMode
        public var description: String { return "continue in the foreground: \(mode)" }
    }

    public static func continuationError(mode: IntentModes.ForegroundMode) -> ContinuationError {
        return ContinuationError(mode: mode)
    }
}

public enum RevenantRun {
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

public protocol SystemIntent: AppIntent {}

public protocol CustomIntentMigratedAppIntent: AppIntent {
    static var intentClassName: String { get }
}

extension CustomIntentMigratedAppIntent {
    public static var intentClassName: String { return String(describing: Self.self) }
    public static var persistentIdentifier: String { return intentClassName }
}

public protocol DeprecatedAppIntent: AppIntent {
    associatedtype ReplacementIntent: AppIntent
    static var deprecation: IntentDeprecation<ReplacementIntent> { get }
}

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

public protocol UndoableIntent: SystemIntent {
    var undoManager: RevenantUndoManager { get }
}

public typealias RevenantUndoManager = UndoManager

public struct IntentModes: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static var background: IntentModes { return IntentModes(rawValue: 1) }

    public static var foreground: IntentModes { return IntentModes.foreground(.immediate) }

    public static func foreground(_ foregroundMode: ForegroundMode) -> IntentModes {
        return IntentModes(rawValue: 2 | (foregroundMode.rawValue << 8))
    }

    public struct ForegroundMode: Hashable, Sendable {
        let rawValue: Int

        public static var immediate: ForegroundMode { return ForegroundMode(rawValue: 0) }
        public static var deferred: ForegroundMode { return ForegroundMode(rawValue: 1) }
        public static var dynamic: ForegroundMode { return ForegroundMode(rawValue: 2) }
    }

    public struct Current: Hashable, Sendable, CustomDebugStringConvertible {
        let rawValue: Int

        public static var background: Current { return Current(rawValue: 0) }
        public static var foreground: Current { return Current(rawValue: 1) }

        public var canContinueInForeground: Bool { return RevenantForeground.inForeground }

        public var debugDescription: String { return canContinueInForeground ? "foreground" : "background" }
    }
}

extension IntentModes {
    public typealias Element = IntentModes
    public typealias ArrayLiteralElement = IntentModes
    public typealias RawValue = Int
}

public enum IntentAuthenticationPolicy: Sendable {
    case alwaysAllowed
    case requiresAuthentication
    case requiresLocalDeviceAuthentication
}

public enum InputConnectionBehavior: Hashable, Sendable {
    case `default`
    case never
    case connectToPreviousIntentResult
}

public enum IntentModesFlags {
    public static let supported: IntentModes = [.background, IntentModes.foreground(.immediate)]
}

public protocol ForegroundContinuableIntent: AppIntent {
    func requestToContinueInForeground(_ mode: IntentModes.ForegroundMode) async throws -> Bool
    func needsToContinueInForegroundError(_ mode: IntentModes.ForegroundMode) -> any Error
}

extension ForegroundContinuableIntent {
    public func requestToContinueInForeground(_ mode: IntentModes.ForegroundMode) async throws -> Bool {
        try await continueInForeground(mode)
        return true
    }

    public func needsToContinueInForegroundError(_ mode: IntentModes.ForegroundMode) -> any Error {
        return RevenantForeground.continuationError(mode: mode)
    }
}
