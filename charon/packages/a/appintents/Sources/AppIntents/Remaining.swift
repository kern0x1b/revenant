import Foundation

@attached(memberAttribute)
@attached(extension, conformances: AppIntents.AppEntity, AppIntents.AssistantSchemaEntity,
          names: named(__assistantSchemaEntity))
public macro AppEntity<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AppEntityMacros")
    where T: AssistantSchemas.Entity

@attached(memberAttribute)
@attached(extension, conformances: AppIntents.AppIntent, AppIntents.AssistantSchemaIntent)
public macro AppIntent<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AppIntentMacros")
    where T: AssistantSchemas.Intent

@attached(memberAttribute)
@attached(extension, conformances: AppIntents.AppEnum, AppIntents.AssistantSchemaEnum)
public macro AppEnum<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AppEnumMacros")
    where T: AssistantSchemas.Enum

@attached(memberAttribute)
@attached(extension, conformances: AppIntents.AppEntity, AppIntents.AssistantSchemaEntity,
          names: named(__assistantSchemaEntity))
public macro AssistantEntity<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AssistantEntityMacros")
    where T: AssistantSchemas.Entity

@attached(memberAttribute)
@attached(extension, conformances: AppIntents.AppIntent, AppIntents.AssistantSchemaIntent)
public macro AssistantIntent<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AssistantIntentMacros")
    where T: AssistantSchemas.Intent

@attached(memberAttribute)
@attached(extension, conformances: AppIntents.AppEnum, AppIntents.AssistantSchemaEnum)
public macro AssistantEnum<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AssistantEnumMacros")
    where T: AssistantSchemas.Enum

@attached(peer)
public macro ComputedProperty(title: String) = #externalMacro(module: "AppIntentsMacros", type: "ComputedPropertyMacro")

@attached(peer)
public macro ComputedProperty(title: String, indexingKey: String)
    = #externalMacro(module: "AppIntentsMacros", type: "ComputedPropertyMacro")

@attached(peer)
public macro ComputedProperty(title: String, customIndexingKey: String)
    = #externalMacro(module: "AppIntentsMacros", type: "ComputedPropertyMacro")

@attached(peer)
public macro ComputedProperty(indexingKey: String)
    = #externalMacro(module: "AppIntentsMacros", type: "ComputedPropertyMacro")

@attached(peer)
public macro ComputedProperty(customIndexingKey: String)
    = #externalMacro(module: "AppIntentsMacros", type: "ComputedPropertyMacro")

@attached(peer)
public macro ComputedProperty()
    = #externalMacro(module: "AppIntentsMacros", type: "ComputedPropertyMacro")

@attached(peer)
public macro DeferredProperty(title: String) = #externalMacro(module: "AppIntentsMacros", type: "DeferredPropertyMacro")

@attached(peer)
public macro DeferredProperty() = #externalMacro(module: "AppIntentsMacros", type: "DeferredPropertyMacro")

@attached(extension, conformances: AppIntents._IntentValueRepresentable, names: arbitrary)
public macro UnionValue() = #externalMacro(module: "AppIntentsMacros", type: "_UnionValueMacro")

public protocol AssistantIntent: AppIntent {}

public protocol AssistantEntity: AppEntity {}

public protocol AssistantEnum: AppEnum {}

public protocol AssistantSchemaIntent: AssistantIntent {
    static var isAssistantOnly: Bool { get }
}

extension AssistantSchemaIntent {
    public static var isAssistantOnly: Bool { return false }

    public static var title: LocalizedStringResource { return CharonAssistantTitle.of(Self.self) }
}

public enum CharonAssistantTitle {
    public static func of(_ type: Any.Type) -> LocalizedStringResource {
        return CharonLocalized.resource(String(describing: type))
    }
}

public protocol AssistantSchemaEntity: AssistantEntity {
    static var isAssistantOnly: Bool { get }
}

extension AssistantSchemaEntity {
    public static var isAssistantOnly: Bool { return false }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: CharonLocalized.resource(String(describing: Self.self)))
    }
}

public protocol AssistantSchemaEnum: AssistantEnum {
    static var isAssistantOnly: Bool { get }
}

extension AssistantSchemaEnum {
    public static var isAssistantOnly: Bool { return false }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: CharonLocalized.resource(String(describing: Self.self)))
    }
}

public protocol _SystemIntentValue: DisplayRepresentable, PersistentlyIdentifiable, _IntentValue, Sendable {}

extension IntentParameterContext {
    public func needsValueError(_ dialog: IntentDialog? = nil) -> AppIntentError {
        return AppIntentError(parameterTitle: title, dialog: dialog, optional: isOptional)
    }

    public func needsDisambiguationError(among itemsToDisambiguate: [Any],
                                         dialog: IntentDialog? = nil) -> AppIntentError {
        return AppIntentError(parameterTitle: title, dialog: dialog, optional: isOptional,
                              disambiguation: itemsToDisambiguate.count)
    }

    public func requestValue(_ dialog: IntentDialog? = nil) async throws -> Any {
        throw needsValueError(dialog)
    }

    public func requestDisambiguation(among itemsToDisambiguate: [Any],
                                      dialog: IntentDialog? = nil) async throws -> Any {
        throw needsDisambiguationError(among: itemsToDisambiguate, dialog: dialog)
    }

    public func requestConfirmation(for itemToConfirm: Any, dialog: IntentDialog? = nil) async throws -> Bool {
        return true
    }
}

extension OpenIntent {
    public static var openAppWhenRun: Bool { return true }

    public func perform() async throws -> IntentResultContainer<Never, Never, Never, Never> {
        return IntentResultContainer()
    }
}

extension WidgetConfigurationIntent {
    public func perform() async throws -> IntentResultContainer<Never, Never, Never, Never> {
        return IntentResultContainer()
    }
}

extension URLRepresentableIntent {
    public func perform() async throws -> IntentResultContainer<Never, Never, Never, Never> {
        return IntentResultContainer()
    }
}

extension IntentChoiceOption {
    public static var cancel: IntentChoiceOption {
        return IntentChoiceOption(title: LocalizedStringResource("Cancel"), style: .cancel)
    }
}

extension IntentDonationManager {
    @discardableResult
    public func donate<Intent: AppIntent>(intent: Intent) -> IntentDonationIdentifier {
        return donate(intent: intent, result: CharonIntentResultText.empty)
    }
}

extension CharonIntentResultText {
    static let empty = IntentResultContainer<Never, Never, Never, Never>()
}

extension ForegroundContinuableIntent {
    @discardableResult
    public func requestToContinueInForeground<ResultValue>(_ dialog: IntentDialog? = nil,
                                                           continuation: @MainActor () async throws -> ResultValue = { () }) async throws -> ResultValue
        where ResultValue: Sendable {
        return try await continuation()
    }

    public func needsToContinueInForegroundError(_ dialog: IntentDialog? = nil,
                                                 continuation: (@MainActor () async throws -> Void)? = nil) -> AppIntentError {
        if let continuation { Task { @MainActor in try? await continuation() } }
        return AppIntentError()
    }

    public func needsToContinueInForegroundError(_ dialog: IntentDialog? = nil,
                                                 alwaysConfirm: Bool = true) -> AppIntentError {
        return AppIntentError()
    }
}

extension CharonForeground {
    public struct Continuation {
        public var mayContinue: Bool

        public init(mayContinue: Bool = true) {
            self.mayContinue = mayContinue
        }
    }
}

extension CharonRun {
    public static func awaitBool(_ body: @escaping () async throws -> Bool) -> Bool {
        let finished = DispatchSemaphore(value: 0)
        var answer = false
        Task {
            answer = (try? await body()) ?? false
            finished.signal()
        }
        finished.wait()
        return answer
    }
}

extension String {
    public var urlRepresentationParameter: String { return self }
}

extension Int {
    public var urlRepresentationParameter: Int { return self }
}

extension URL {
    public var urlRepresentationParameter: String { return absoluteString }
}

extension IntentWidgetFamily {
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    public var hashValue: Int { return rawValue.hashValue }
}

extension IntentPaymentMethod.PaymentType {
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    public var hashValue: Int { return rawValue.hashValue }
}

extension IntentPerson.Handle.Label {
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    public var hashValue: Int { return rawValue.hashValue }
}

extension IntentPerson.Handle.Value {
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    public var hashValue: Int { return rawValue.hashValue }
}

extension IntentPerson.Identifier {
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    public var hashValue: Int { return rawValue.hashValue }
}

extension SetFocusFilterIntentError {
    public func hash(into hasher: inout Hasher) { hasher.combine(CharonFocusError.ordinal(self)) }

    public var hashValue: Int { return CharonFocusError.ordinal(self) }
}

public enum CharonFocusError {
    public static func ordinal(_ error: SetFocusFilterIntentError) -> Int {
        switch error {
        case .notFound: return 0
        case .missingParameterValue: return 1
        }
    }
}

extension StringSearchScope {
    public init?(rawValue: String) {
        self.init(rawValue: rawValue)
    }
}

extension VideoCategory {
    public init?(rawValue: String) {
        self.init(rawValue: rawValue)
    }
}

extension Bool {
    public struct IntentDisplayName {
        public static var `true`: LocalizedStringResource { return LocalizedStringResource("Yes") }
        public static var `false`: LocalizedStringResource { return LocalizedStringResource("No") }

        public func name(of value: Bool) -> LocalizedStringResource {
            return value ? IntentDisplayName.true : IntentDisplayName.false
        }
    }

    static var intentDisplayName: IntentDisplayName { return IntentDisplayName() }
}
