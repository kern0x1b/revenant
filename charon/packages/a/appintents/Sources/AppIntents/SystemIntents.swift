import Foundation

public struct OpenURLIntent: SystemIntent, URLRepresentableIntent {
    public typealias PerformResult = IntentResultContainer<Never, Never, Never, Never>
    public typealias SummaryContent = IntentParameterSummary<OpenURLIntent>
    public typealias URLRepresentation = IntentURLRepresentation<OpenURLIntent>
    public typealias Dependency = Never

    @IntentParameter
    public var url: URL
    public var urlRepresentation: IntentURLRepresentation<OpenURLIntent>

    private static func makeURLParameter() -> IntentParameter<URL> {
        return IntentParameter<URL>(title: LocalizedStringResource("URL"), description: nil, requestValueDialog: nil,
                                    inputConnectionBehavior: InputConnectionBehavior.default)
    }

    public init() {
        self._url = OpenURLIntent.makeURLParameter()
        self.url = CharonURL.placeholder
        self.urlRepresentation = IntentURLRepresentation(CharonURL.placeholder)
    }

    public init(_ url: URL) {
        self._url = OpenURLIntent.makeURLParameter()
        self.url = url
        self.urlRepresentation = IntentURLRepresentation(url)
    }

    public init(urlRepresentable: URLRepresentableEntity) {
        self.init(CharonURL.placeholder.appendingPathComponent(urlRepresentable.urlRepresentationParameter))
    }

    public init(urlRepresentable: URLRepresentableEnum) {
        self.init(CharonURL.placeholder.appendingPathComponent(urlRepresentable.urlRepresentationParameter))
    }

    public init(urlRepresentable: some URLRepresentableIntent) {
        self.init(CharonURL.placeholder.appendingPathComponent(
            String(describing: type(of: urlRepresentable))))
    }

    public static var title: LocalizedStringResource { return LocalizedStringResource("Open URL") }
    public static var openAppWhenRun: Bool { return true }

    public static var parameterSummary: SummaryContent { return SummaryContent("Open the URL") }

    public func perform() async throws -> PerformResult {
        CharonURL.open(url)
        return IntentResultContainer()
    }

    public var urlRepresentationParameter: String { return url.absoluteString }
}

extension OpenURLIntent: CustomURLRepresentationParameterConvertible {}

public protocol SetValueIntent<ValueType>: AppIntent {
    associatedtype ValueType: _IntentValue
    var value: ValueType { get }
}

public protocol DeleteIntent: SystemIntent {
    var entities: [AnyAppEntity] { get }
}

public protocol AnyAppEntity: AppEntity {}

extension AnyAppEntity {
    public var anyEntityIdentifier: String { return String(describing: id) }
}

public protocol OpenIntent: SystemIntent {
    associatedtype Target: AppEntity
    static var target: Target.Type { get }
}

public protocol ControlConfigurationIntent: AppIntent {
    associatedtype NeverResult where NeverResult == Never
}

extension ControlConfigurationIntent {
    public func perform() async throws -> Self.NeverResult {
        fatalError("a control configuration intent returns no value")
    }
}

public protocol WidgetConfigurationIntent: AppIntent {}

public protocol ProgressReportingIntent: AppIntent {
    var progress: Double? { get }
}

public protocol TargetContentProvidingIntent: AppIntent {
    var contentIdentifier: String? { get }

    func perform() async throws -> Void
}

public protocol CameraCaptureIntent: SystemIntent {
    var appContext: Any? { get }
    func updateAppContext(_ context: Any?) async
}

public protocol StartWorkoutIntent: InstanceDisplayRepresentable, SystemIntent {
    static var suggestedWorkouts: [DisplayRepresentation] { get }
    var workoutStyle: String? { get }
    static var openAppWhenRun: Bool { get }

    static func invalidateSuggestedWorkouts()
}

extension StartWorkoutIntent {
    public static var suggestedWorkouts: [DisplayRepresentation] { return [] }
    public static var openAppWhenRun: Bool { return true }
    public static func invalidateSuggestedWorkouts() {}
}

public protocol PauseWorkoutIntent: SystemIntent {}

public protocol ResumeWorkoutIntent: SystemIntent {}

public protocol StartDiveIntent: SystemIntent {}

public protocol PlayVideoIntent: SystemIntent {
    var term: String? { get }
    var supportedCategories: [VideoCategory]? { get }
    static var openAppWhenRun: Bool { get }
}

extension PlayVideoIntent {
    public static var openAppWhenRun: Bool { return true }
}

public protocol ShowInAppSearchResultsIntent: SystemIntent {
    var criteria: StringSearchCriteria { get }
    var searchScopes: StringSearchCriteria.SearchScopes { get }
    static var openAppWhenRun: Bool { get }
}

extension ShowInAppSearchResultsIntent {
    public static var openAppWhenRun: Bool { return true }

    public var searchScopes: StringSearchCriteria.SearchScopes { return [] }
}

public protocol AudioRecordingIntent: SystemIntent {}

public protocol AudioPlaybackIntent: SystemIntent {}

public protocol AudioStartingIntent: SystemIntent {}

public protocol PushToTalkTransmissionIntent: SystemIntent {}

public protocol LiveActivityStartingIntent: SystemIntent {}

public protocol LiveActivityIntent: SystemIntent {}

public protocol AppEntityAnnotatable {
    var appEntityIdentifier: String { get }
}

public protocol AppIntentsExtension {
    var configuration: CharonExtensionConfiguration { get }
}

public struct CharonExtensionConfiguration: Sendable {
    public let identifier: String
    public let kind: String

    public init(identifier: String, kind: String) {
        self.identifier = identifier
        self.kind = kind
    }
}

public protocol AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { get }
}

extension AppIntentsPackage {
    public static var includedPackages: [any AppIntentsPackage.Type] { return [] }
}

public enum SetFocusFilterIntentError{
    case notFound
    case missingParameterValue

    var ordinal: Int {
        switch self {
        case .notFound: return 0
        case .missingParameterValue: return 1
        }
    }

    public static func == (a: SetFocusFilterIntentError, b: SetFocusFilterIntentError) -> Bool { return a.ordinal == b.ordinal }
}

public struct FocusFilterAppContext {
    public let notificationFilterPredicate: String
    public let targetContentIdentifierPrefix: String?

    public init(notificationFilterPredicate: String) {
        self.notificationFilterPredicate = notificationFilterPredicate
        self.targetContentIdentifierPrefix = nil
    }

    public init(notificationFilterPredicate: String, targetContentIdentifierPrefix: String?) {
        self.notificationFilterPredicate = notificationFilterPredicate
        self.targetContentIdentifierPrefix = targetContentIdentifierPrefix
    }
}

public struct FocusFilterSuggestionContext {
    public let suggestedFilter: FocusFilterAppContext

    public init(suggestedFilter: FocusFilterAppContext) {
        self.suggestedFilter = suggestedFilter
    }
}

public protocol SetFocusFilterIntent: AppIntent, InstanceDisplayRepresentable {
    static var current: FocusFilterAppContext? { get }
    static var appContext: FocusFilterAppContext { get }
    static func invalidateFocusFilterAppContext()
    static func suggestedFocusFilters(for context: FocusFilterSuggestionContext) -> [FocusFilterAppContext]
}

extension SetFocusFilterIntent {
    public static var current: FocusFilterAppContext? { return nil }
    public static var appContext: FocusFilterAppContext {
        return FocusFilterAppContext(notificationFilterPredicate: "")
    }
    public static func invalidateFocusFilterAppContext() {}
    public static func suggestedFocusFilters(for context: FocusFilterSuggestionContext) -> [FocusFilterAppContext] {
        return []
    }
}
