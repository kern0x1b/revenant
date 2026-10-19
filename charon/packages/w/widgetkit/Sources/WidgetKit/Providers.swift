// The provider: what the system asks a widget for, and the configuration that says which provider.
//
// There is no widget host on these releases, so nothing here is drawn by the system; what a widget
// shows is drawn in the app, and the provider is what the app's own in-app draw asks. The four
// providers the framework names - `TimelineProvider`, `AppIntentTimelineProvider`,
// `IntentTimelineProvider` and the control value providers - are declared with the framework's own
// shape, and the module's own caller is what fills them in.

import Foundation
import AppIntents

/// The provider a widget without an intent is asked through.
public protocol TimelineProvider {
    /// The entry the widget shows, which is the provider's own type.
    associatedtype Entry: TimelineEntry
    /// What the system tells the provider when it asks for a timeline.
    typealias Context = TimelineProviderContext

    /// The entry the widget shows before it has any, which is what a gallery and a redraw show.
    func placeholder(in context: Context) -> TimelineEntry

    /// One entry, drawn while the real timeline is being asked for.
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void)

    /// The whole timeline: the entries and when to come back.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>?) -> Void)

    /// What the widget is scored by, which is what the system sorts the widget's widgets by.
    func relevance() -> WidgetRelevance<Entry>
}

extension TimelineProvider {
    public func relevance() -> WidgetRelevance<Entry> { return WidgetRelevance(.automatic) }
}

/// The provider a widget configured by an app intent is asked through.
///
/// A provider of this kind is asked for the timeline *asynchronously*, with the configuration the
/// widget is drawn with passed in, so the system is never kept waiting on a completion handler: the
/// entries a widget of this kind offers the system come from `recommendations()`.
public protocol AppIntentTimelineProvider {
    /// The entry the widget shows, which is the provider's own type.
    associatedtype Entry: TimelineEntry
    /// The configuration the widget is drawn with, which is the app intent itself.
    associatedtype Intent: WidgetConfigurationIntent
    /// What the system tells the provider about the widget it is drawing.
    typealias Context = TimelineProviderContext

    /// The entry shown before the provider has answered, which is the provider's own.
    func placeholder(in context: Context) -> Entry
    /// The one entry the widget shows right now.
    func snapshot(for configuration: Intent, in context: Context) async -> Entry
    /// The entries the widget shows from now on, and when it is asked again.
    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry>
    /// The configurations the system may offer the owner to switch the widget to.
    func recommendations() -> [AppIntentRecommendation<Intent>]
    /// How the system should weigh this widget against the others, which the owner may not change.
    func relevance() async -> WidgetRelevance<Intent>
}

extension AppIntentTimelineProvider {
    /// A provider that names no relevance is weighed automatically, which is the framework's default
    /// for this provider.
    public func relevance() async -> WidgetRelevance<Intent> { return WidgetRelevance(.automatic) }

    /// A provider that names no recommendation has none, which is the framework's default for this
    /// provider.
    public func recommendations() -> [AppIntentRecommendation<Intent>] { return [] }
}

/// The provider a widget configured by an `INIntent` is asked through.
/// The same, with the system telling the provider about the intent instance the widget is configured
/// with: a provider of this kind is asked through its own context, and through a completion handler,
/// because the intent arrives from the system's own store rather than from the app.
public protocol IntentTimelineProvider {
    /// The entry the widget shows, which is the provider's own type.
    associatedtype Entry: TimelineEntry
    /// The intent instance the widget is drawn with, which the configuration holds. The interface
    /// names `Intents.INIntent` here, the Objective-C framework, which is another band's and which
    /// these releases do not have; this one is written in terms of the app intent the port's own
    /// `IntentConfiguration` takes. `facts/WidgetKit/Providers.md` records it.
    associatedtype Intent: AppIntent
    /// What the system tells the provider about the widget it is drawing.
    typealias Context = TimelineProviderContext

    /// The configurations the system may offer the owner to switch the widget to.
    func recommendations() -> [IntentRecommendation<Intent>]
    /// The entry shown before the provider has answered, which is the provider's own.
    func placeholder(in context: Context) -> Entry
    /// The one entry the widget shows right now, which the provider answers through `completion`.
    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void)
    /// The entries the widget shows from now on, and when it is asked again, which the provider
    /// answers through `completion`.
    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void)
    /// How the system should weigh this widget against the others, which the owner may not change.
    func relevance() async -> WidgetRelevance<Intent>
}

extension IntentTimelineProvider {
    /// A provider that names no relevance is weighed automatically, which is the framework's default
    /// for this provider.
    public func relevance() async -> WidgetRelevance<Intent> { return WidgetRelevance(.automatic) }
}

/// The entries a widget offers the system to pick from, which is what a relevance provider returns.
public protocol RelevanceEntriesProvider {
    associatedtype Entry: RelevanceEntry
    /// The entries, scored.
    func relevanceEntries(for context: RelevanceEntriesProviderContext) -> [Entry]
}

/// One entry the system picks a widget's content from.
public protocol RelevanceEntry: Sendable {
    /// How relevant the entry is, which is what the system sorts by.
    var relevance: TimelineEntryRelevance { get }
    /// The date the entry is for.
    var date: Date { get }
}

/// What the system tells a relevance provider when it asks for entries.
public struct RelevanceEntriesProviderContext {
    public let family: WidgetFamily
    public let isPreview: Bool

    public init(family: WidgetFamily, isPreview: Bool = false) {
        self.family = family
        self.isPreview = isPreview
    }
}

/// What a control's value is asked for, which is what a control widget's provider returns.
public protocol ControlValueProvider {
    /// The value the control shows now.
    func currentValue() async throws -> Bool
    /// The value the control shows in a gallery.
    var previewValue: Bool { get }
}

/// The context the system tells an intent-configured widget's provider, which is the family and the
/// preview flag.
public struct IntentTimelineProviderContext {
    public let family: WidgetFamily
    public let isPreview: Bool

    public init(family: WidgetFamily, isPreview: Bool = false) {
        self.family = family
        self.isPreview = isPreview
    }
}

/// The same, for a control configured by an app intent.
public protocol AppIntentControlValueProvider {
    /// The value the control shows now, for the configuration it is drawn with.
    func currentValue(configuration: some WidgetConfigurationIntent) async throws -> Bool
    /// The value the control shows in a gallery, for the configuration it is drawn with.
    func previewValue(configuration: some WidgetConfigurationIntent) async throws -> Bool
}

/// The handler a control's app installs to be told when its push tokens change.
public final class ControlPushHandler {
    public init() {}

    /// The system calls this when the push tokens of the named controls have changed.
    public func pushTokensDidChange(controls: [ControlInfo]) {}
}

/// What a control is told when it is asked for its value: which control it is, and which push token
/// the system minted for it.
public struct ControlPushInfo: Sendable, Hashable {
    public let token: Data

    public init(token: Data) {
        self.token = token
    }
}
