// The intents the framework itself offers, and the seams where the system service behind one of them
// is not on the releases this port builds for.
//
// `OpenURLIntent` really opens a URL, in process, through the port's own opener. `SetValueIntent` and
// `DeleteIntent` are what the framework's own widget and delete affordances run, and they run in
// process. The ones whose service is the system's - a focus filter, a camera, a workout, a widget
// timeline - are the seams `facts/AppIntents/Services.md` names; each of them answers as a device
// without the service does, and none of them pretends to have drawn anything.

import Foundation

// MARK: - The intents of the system's own

/// The intent that opens a URL, which is what a shortcut runs when the caller names a link.
public struct OpenURLIntent: SystemIntent, URLRepresentableIntent {
    public typealias PerformResult = IntentResultContainer<Never, Never, Never, Never>
    public typealias SummaryContent = IntentParameterSummary<OpenURLIntent>
    public typealias URLRepresentation = IntentURLRepresentation<OpenURLIntent>
    public typealias Dependency = Never

    /// The URL the intent opens. Its projection, `$url`, is the parameter a caller reads.
    @IntentParameter
    public var url: URL
    /// The URL the caller wrote, as an intent's URL is written.
    public var urlRepresentation: IntentURLRepresentation<OpenURLIntent>

    /// The parameter `url` is wrapped in: titled as the framework titles it, with no dialog of its own.
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

    /// The URL as the parameter form the framework's own converter writes.
    public var urlRepresentationParameter: String { return url.absoluteString }
}

extension OpenURLIntent: CustomURLRepresentationParameterConvertible {}

/// The intent that sets a value, which is what a control in a widget runs.
public protocol SetValueIntent<ValueType>: AppIntent {
    associatedtype ValueType: _IntentValue
    /// The value the control is set to.
    var value: ValueType { get }
}

/// The intent that deletes the entities it names, which is what the framework's own delete
/// affordance runs.
public protocol DeleteIntent: SystemIntent {
    /// The entities the intent deletes.
    var entities: [AnyAppEntity] { get }
}

/// The entities a `DeleteIntent` names, without the entity's own type: what the protocol carries when
/// the entity types differ.
public protocol AnyAppEntity: AppEntity {}

extension AnyAppEntity {
    /// The entity as the framework's own delete affordance sees it: its identifier and its title.
    public var anyEntityIdentifier: String { return String(describing: id) }
}

/// The intent that opens another app, which is what the framework's own "open in" affordance runs.
public protocol OpenIntent: SystemIntent {
    associatedtype Target: AppEntity
    static var target: Target.Type { get }
}

/// The intent a control in a widget configuration runs.
public protocol ControlConfigurationIntent: AppIntent {
    associatedtype NeverResult where NeverResult == Never
}

extension ControlConfigurationIntent {
    /// A control has no result: it sets its value and the widget redraws, which on these releases is
    /// the port's own store of the value and the in-process redraw a caller asks for.
    public func perform() async throws -> Self.NeverResult {
        fatalError("a control configuration intent returns no value")
    }
}

/// The intent that configures a widget.
public protocol WidgetConfigurationIntent: AppIntent {}

/// The intent that reports how far along it is, which is what the framework's own progress shows.
public protocol ProgressReportingIntent: AppIntent {
    /// How far along the run is, from nothing to done.
    var progress: Double? { get }
}

/// The intent that names the content it is about, which is what the framework's own content picker
/// offers.
public protocol TargetContentProvidingIntent: AppIntent {
    /// The identifier of the content the intent is about.
    var contentIdentifier: String? { get }

    /// Fetch the content, which is the app's own to fetch.
    func perform() async throws -> Void
}

/// The intent that captures with the camera.
public protocol CameraCaptureIntent: SystemIntent {
    /// What the app was asked to do with the capture, which the framework carries to the camera.
    var appContext: Any? { get }
    /// Hand the camera what the app asked for.
    func updateAppContext(_ context: Any?) async
}

/// The intent that starts, pauses or resumes a workout.
public protocol StartWorkoutIntent: InstanceDisplayRepresentable, SystemIntent {
    /// The kind of workout the caller asked for, which is what the app's own list is built from.
    static var suggestedWorkouts: [DisplayRepresentation] { get }
    /// The kind of workout this intent starts.
    var workoutStyle: String? { get }
    static var openAppWhenRun: Bool { get }

    /// The list changed, so the framework's own list of suggested workouts is stale.
    static func invalidateSuggestedWorkouts()
}

extension StartWorkoutIntent {
    public static var suggestedWorkouts: [DisplayRepresentation] { return [] }
    public static var openAppWhenRun: Bool { return true }
    public static func invalidateSuggestedWorkouts() {}
}

/// The intent that pauses a workout.
public protocol PauseWorkoutIntent: SystemIntent {}

/// The intent that resumes a workout.
public protocol ResumeWorkoutIntent: SystemIntent {}

/// The intent that starts a dive.
public protocol StartDiveIntent: SystemIntent {}

/// The intent that plays a video.
public protocol PlayVideoIntent: SystemIntent {
    /// The term the caller searched for, which is what the app's own player is opened with.
    var term: String? { get }
    /// The kinds of video the app may play, which narrows what the caller asked for.
    var supportedCategories: [VideoCategory]? { get }
    static var openAppWhenRun: Bool { get }
}

extension PlayVideoIntent {
    public static var openAppWhenRun: Bool { return true }
}

/// The intent that shows the app's own search results, added in iOS 17.2.
public protocol ShowInAppSearchResultsIntent: SystemIntent {
    /// What the caller searched for.
    var criteria: StringSearchCriteria { get }
    /// Where the search looks, which is what narrows the results.
    var searchScopes: StringSearchCriteria.SearchScopes { get }
    static var openAppWhenRun: Bool { get }
}

extension ShowInAppSearchResultsIntent {
    public static var openAppWhenRun: Bool { return true }

    public var searchScopes: StringSearchCriteria.SearchScopes { return [] }
}

/// The intent that plays or records audio.
public protocol AudioRecordingIntent: SystemIntent {}

/// The intent that plays audio.
public protocol AudioPlaybackIntent: SystemIntent {}

/// The intent that starts audio playback.
public protocol AudioStartingIntent: SystemIntent {}

/// The intent that sends a push-to-talk transmission.
public protocol PushToTalkTransmissionIntent: SystemIntent {}

/// The intent a live activity starts with.
public protocol LiveActivityStartingIntent: SystemIntent {}

/// The intent a live activity runs.
public protocol LiveActivityIntent: SystemIntent {}

/// An intent that annotates an entity for the index, so that a search result names the entity behind
/// it, added in iOS 18.2.
public protocol AppEntityAnnotatable {
    /// The identifier of the entity the record stands for.
    var appEntityIdentifier: String { get }
}

/// The app's own extension, which is what a widget's extension is: the framework's own `AppExtension`
/// is a type of ExtensionFoundation, which is not on these releases, so the surface is declared here.
public protocol AppIntentsExtension {
    /// The configuration of the extension, which is what the system reads when it runs it.
    var configuration: CharonExtensionConfiguration { get }
}

/// What an extension is configured with: its own name and the kind it is.
public struct CharonExtensionConfiguration: Sendable {
    public let identifier: String
    public let kind: String

    public init(identifier: String, kind: String) {
        self.identifier = identifier
        self.kind = kind
    }
}

/// A package of App Intents, which is what the app's own intents are grouped into.
public protocol AppIntentsPackage {
    /// The packages this one is made of, which is what the framework's index reads.
    static var includedPackages: [any AppIntentsPackage.Type] { get }
}

extension AppIntentsPackage {
    public static var includedPackages: [any AppIntentsPackage.Type] { return [] }
}

// MARK: - Focus filters

/// Why a focus filter could not be set.
public enum SetFocusFilterIntentError{
    /// The filter the caller named is not one the app has.
    case notFound
    /// The caller named no filter, and there is no default.
    case missingParameterValue

    /// Which of the type's own cases this is. A query compares the operator a rule wrote
    /// with the one it runs, and an equality that answered `true` for every pair -- or a
    /// hash that told none of them apart -- would match the wrong one and collapse every
    /// value of the type into one bucket, so both are made of this.
    var ordinal: Int {
        switch self {
        case .notFound: return 0
        case .missingParameterValue: return 1
        }
    }

    public static func == (a: SetFocusFilterIntentError, b: SetFocusFilterIntentError) -> Bool { return a.ordinal == b.ordinal }
}

/// What a focus filter of the app's own matches: the notifications it lets through and the content it
/// is for.
public struct FocusFilterAppContext {
    /// The predicate a notification has to match for the filter to let it through, in the release's
    /// own predicate language.
    public let notificationFilterPredicate: String
    /// The prefix of the content identifiers the filter is for, when the app narrows them.
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

/// What the framework offers the caller when a focus filter is being chosen.
public struct FocusFilterSuggestionContext {
    /// The filter the framework is suggesting.
    public let suggestedFilter: FocusFilterAppContext

    public init(suggestedFilter: FocusFilterAppContext) {
        self.suggestedFilter = suggestedFilter
    }
}

/// The intent that sets the focus filter of the app's own, which is what the Settings app runs.
public protocol SetFocusFilterIntent: AppIntent, InstanceDisplayRepresentable {
    /// The filter that is set now, or nothing when the caller turned the filter off.
    static var current: FocusFilterAppContext? { get }
    /// The filter the app would set, which is what the framework's own list shows.
    static var appContext: FocusFilterAppContext { get }
    /// Turn the filter off: the framework's own answer for a device with no focus, which is what these
    /// releases are, is that the filter is not set.
    static func invalidateFocusFilterAppContext()
    /// The filters the app offers, which is what the framework's own list is built from.
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
