// What a widget's configuration says about itself: where it may be drawn, what it is called, and what
// the system should ask the owner before offering it.
//
// These are the framework's own modifiers, each of which answers with the configuration that carries
// it. The values a caller reads back are the app's own, kept where the app's surface can read them.

import Foundation
import ActivityKit
import AppIntents

extension WidgetConfiguration {
    /// The kinds the widget may be drawn at, which is what the system's own gallery asks.
    public func supportedFamilies(_ families: [WidgetFamily]) -> Self { return self }

    /// The kinds a Live Activity of this configuration may be drawn at.
    public func supplementalActivityFamilies(_ families: [ActivityFamily]) -> Self { return self }

    /// The mounting styles the widget is drawn with on this surface.
    public func supportedMountingStyles(_ styles: [WidgetMountingStyle]) -> Self { return self }

    /// The surfaces the widget is not drawn on, and the families it is not drawn at.
    public func disfavoredLocations(_ locations: [WidgetLocation], for families: [WidgetFamily]) -> Self { return self }

    /// What the system calls the widget in its gallery.
    public func configurationDisplayName(_ displayName: String) -> Self { return self }

    /// The kind the widget is recorded under, when the app wants one of its own.
    public func associatedKind(_ kind: String) -> Self { return self }

    /// The description the system's gallery shows under the name.
    public func description(_ description: String) -> Self { return self }

    /// What the system asks the owner before it offers the widget.
    public func promptsForUserConfiguration(_ prompts: [String]) -> Self { return self }

    /// The handler the system calls when the widget's push token changes.
    public func pushHandler(_ handler: WidgetPushHandler) -> WidgetPushHandler { return handler }

    /// Whether the widget draws its own background, which the system may not remove.
    public func containerBackgroundRemovable(_ removable: Bool) -> Self { return self }

    /// The same, in the spelling the system's own modifiers use.
    public func _containerBackgroundRemovable(_ removable: Bool) -> Self { return self }

    /// Whether the widget's own content margins are used, or the system's.
    public func contentMarginsDisabled() -> Self { return self }

    /// The same, in the spelling the system's own modifiers use.
    public func _contentMarginsDisabled() -> Self { return self }

    /// The system's own events for the widget's background URL session, which is what it delivers a
    /// widget's own network results to.
    public func onBackgroundURLSessionEvents(matching identifier: String, _ handler: @escaping () -> Void) -> Self {
        return self
    }
}

extension Widget {
    /// The widgets the app offers, which is where the framework's own gallery entry point reads.
    public static func main() -> [WidgetInfo] { return CharonWidgetRegistry.shared.configurations() }
}

/// The handler a widget's app installs to be told when the push tokens the system mints for its
/// widgets change. A push-to-start widget is woken by a push carrying the token the system gave it,
/// so an app whose token changed has to be told which of its widgets it belongs to.
public protocol WidgetPushHandler {
    init()
    /// The system calls this when the push token of one of the named widgets has changed.
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo])
}

/// The bundle of widgets an app offers, which the framework's own gallery reads.
public enum WidgetBundle {
    /// The widgets the app has registered, which is the port's own record.
    public static func main() -> [WidgetInfo] { return CharonWidgetRegistry.shared.configurations() }
}

/// The family a widget is drawn at, which the system asks the app for and the app names.
public protocol _WidgetFamilyProviding {}

extension WidgetFamily {
    /// The family read from the string a caller wrote, which is the raw value the framework's own
    /// initialiser takes.
    public init?(rawValue: String) { self.init(rawValue: rawValue) }
}

extension ActivityFamily {
    /// The family read from the string a caller wrote.
    public init?(rawValue: String) { self.init(rawValue: rawValue) }
}

/// What a preview of a widget is drawn for, which is the family and the state it draws.
public struct WidgetPreviewContext {
    public let family: WidgetFamily

    public init(family: WidgetFamily) {
        self.family = family
    }

    /// The state a preview draws the widget with, reached by the name the system knows it by.
    public subscript<State>(key: String) -> State? { return nil }
}

/// The two ways a Live Activity is previewed: as its own content, or in the island.
public enum ActivityPreviewViewKind {
    /// The activity's own content, as the Lock Screen draws it.
    public static var content: ActivityPreviewViewKind { return .content(.compact) }
    /// The activity in the Dynamic Island.
    public static var dynamicIsland: ActivityPreviewViewKind { return .dynamicIsland(.compact) }

    enum Base {
        case content
        case dynamicIsland
    }

    /// The state of the island a preview draws, which is how much of it there is room for.
    public enum DynamicIslandPreviewViewState {
        case compact
        case expanded
        case minimal
    }

    case content(DynamicIslandPreviewViewState)
    case dynamicIsland(DynamicIslandPreviewViewState)
}

extension ActivityAttributes {
    /// The context a preview of this activity draws with, which is the app's own attributes and state.
    public func previewContext(_ state: ContentState, isStale: Bool = false,
                              viewKind: ActivityPreviewViewKind = .content) -> ActivityViewContext<Self> {
        return ActivityViewContext(attributes: self, state: state, isStale: isStale, activityID: "")
    }
}

/// A preview of a widget in the app's own gallery, which is what the system would draw.
public struct Preview<Content: WidgetBody> {
    public init(_ title: String, as: WidgetFamily, using widget: () -> Content) {}
    public init(_ title: String, as: WidgetFamily, using widget: @escaping (WidgetPreviewContext) -> Content) {}
    public init<Entry: TimelineEntry>(_ title: String, as: WidgetFamily, timeline: () -> Timeline<Entry>) {}
    public init(_ title: String, as: WidgetFamily, timelineProvider: (TimelineProviderContext) -> Void) {}
}

/// The builder a preview of a Live Activity is written with, which is what the app's own gallery reads.
@resultBuilder
public enum PreviewActivityBuilder<Content> {
    public static func buildPartialBlock(first: Content) -> Content { return first }
    public static func buildPartialBlock(accumulated: Content, next: Content) -> Content { return next }
    public static func buildExpression(_ expression: Content) -> Content { return expression }
    public static func buildArray(_ array: [Content]) -> [Content] { return array }
}

/// The builder a preview of a widget's timeline is written with.
@resultBuilder
public enum PreviewTimelineBuilder<Entry> {
    public static func buildPartialBlock(first: Entry) -> Entry { return first }
    public static func buildPartialBlock(accumulated: Entry, next: Entry) -> Entry { return next }
    public static func buildExpression(_ expression: Entry) -> Entry { return expression }
    public static func buildArray(_ array: [Entry]) -> [Entry] { return array }
}
