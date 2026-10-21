import Foundation
import AppIntents

public protocol TimelineProvider {
    associatedtype Entry: TimelineEntry
    typealias Context = TimelineProviderContext

    func placeholder(in context: Context) -> TimelineEntry

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void)

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>?) -> Void)

    func relevance() -> WidgetRelevance<Entry>
}

extension TimelineProvider {
    public func relevance() -> WidgetRelevance<Entry> { return WidgetRelevance(.automatic) }
}

public protocol AppIntentTimelineProvider {
    associatedtype Entry: TimelineEntry
    associatedtype Intent: WidgetConfigurationIntent
    typealias Context = TimelineProviderContext

    func placeholder(in context: Context) -> Entry
    func snapshot(for configuration: Intent, in context: Context) async -> Entry
    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry>
    func recommendations() -> [AppIntentRecommendation<Intent>]
    func relevance() async -> WidgetRelevance<Intent>
}

extension AppIntentTimelineProvider {
    public func relevance() async -> WidgetRelevance<Intent> { return WidgetRelevance(.automatic) }

    public func recommendations() -> [AppIntentRecommendation<Intent>] { return [] }
}

public protocol IntentTimelineProvider {
    associatedtype Entry: TimelineEntry
    associatedtype Intent: AppIntent
    typealias Context = TimelineProviderContext

    func recommendations() -> [IntentRecommendation<Intent>]
    func placeholder(in context: Context) -> Entry
    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void)
    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void)
    func relevance() async -> WidgetRelevance<Intent>
}

extension IntentTimelineProvider {
    public func relevance() async -> WidgetRelevance<Intent> { return WidgetRelevance(.automatic) }
}

public protocol RelevanceEntriesProvider {
    associatedtype Entry: RelevanceEntry
    func relevanceEntries(for context: RelevanceEntriesProviderContext) -> [Entry]
}

public protocol RelevanceEntry: Sendable {
    var relevance: TimelineEntryRelevance { get }
    var date: Date { get }
}

public struct RelevanceEntriesProviderContext {
    public let family: WidgetFamily
    public let isPreview: Bool

    public init(family: WidgetFamily, isPreview: Bool = false) {
        self.family = family
        self.isPreview = isPreview
    }
}

public protocol ControlValueProvider {
    func currentValue() async throws -> Bool
    var previewValue: Bool { get }
}

public struct IntentTimelineProviderContext {
    public let family: WidgetFamily
    public let isPreview: Bool

    public init(family: WidgetFamily, isPreview: Bool = false) {
        self.family = family
        self.isPreview = isPreview
    }
}

public protocol AppIntentControlValueProvider {
    func currentValue(configuration: some WidgetConfigurationIntent) async throws -> Bool
    func previewValue(configuration: some WidgetConfigurationIntent) async throws -> Bool
}

public final class ControlPushHandler {
    public init() {}

    public func pushTokensDidChange(controls: [ControlInfo]) {}
}

public struct ControlPushInfo: Sendable, Hashable {
    public let token: Data

    public init(token: Data) {
        self.token = token
    }
}
