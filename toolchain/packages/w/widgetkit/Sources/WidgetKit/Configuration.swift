import Foundation
import ActivityKit
import AppIntents

extension WidgetConfiguration {
    public func supportedFamilies(_ families: [WidgetFamily]) -> Self { return self }

    public func supplementalActivityFamilies(_ families: [ActivityFamily]) -> Self { return self }

    public func supportedMountingStyles(_ styles: [WidgetMountingStyle]) -> Self { return self }

    public func disfavoredLocations(_ locations: [WidgetLocation], for families: [WidgetFamily]) -> Self { return self }

    public func configurationDisplayName(_ displayName: String) -> Self { return self }

    public func associatedKind(_ kind: String) -> Self { return self }

    public func description(_ description: String) -> Self { return self }

    public func promptsForUserConfiguration(_ prompts: [String]) -> Self { return self }

    public func pushHandler(_ handler: WidgetPushHandler) -> WidgetPushHandler { return handler }

    public func containerBackgroundRemovable(_ removable: Bool) -> Self { return self }

    public func _containerBackgroundRemovable(_ removable: Bool) -> Self { return self }

    public func contentMarginsDisabled() -> Self { return self }

    public func _contentMarginsDisabled() -> Self { return self }

    public func onBackgroundURLSessionEvents(matching identifier: String, _ handler: @escaping () -> Void) -> Self {
        return self
    }
}

extension Widget {
    public static func main() -> [WidgetInfo] { return RevenantWidgetRegistry.shared.configurations() }
}

public protocol WidgetPushHandler {
    init()
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo])
}

public enum WidgetBundle {
    public static func main() -> [WidgetInfo] { return RevenantWidgetRegistry.shared.configurations() }
}

public protocol _WidgetFamilyProviding {}

extension WidgetFamily {
    public init?(rawValue: String) { self.init(rawValue: rawValue) }
}

extension ActivityFamily {
    public init?(rawValue: String) { self.init(rawValue: rawValue) }
}

public struct WidgetPreviewContext {
    public let family: WidgetFamily

    public init(family: WidgetFamily) {
        self.family = family
    }

    public subscript<State>(key: String) -> State? { return nil }
}

public enum ActivityPreviewViewKind {
    public static var content: ActivityPreviewViewKind { return .content(.compact) }
    public static var dynamicIsland: ActivityPreviewViewKind { return .dynamicIsland(.compact) }

    enum Base {
        case content
        case dynamicIsland
    }

    public enum DynamicIslandPreviewViewState {
        case compact
        case expanded
        case minimal
    }

    case content(DynamicIslandPreviewViewState)
    case dynamicIsland(DynamicIslandPreviewViewState)
}

extension ActivityAttributes {
    public func previewContext(_ state: ContentState, isStale: Bool = false,
                              viewKind: ActivityPreviewViewKind = .content) -> ActivityViewContext<Self> {
        return ActivityViewContext(attributes: self, state: state, isStale: isStale, activityID: "")
    }
}

public struct Preview<Content: WidgetBody> {
    public init(_ title: String, as: WidgetFamily, using widget: () -> Content) {}
    public init(_ title: String, as: WidgetFamily, using widget: @escaping (WidgetPreviewContext) -> Content) {}
    public init<Entry: TimelineEntry>(_ title: String, as: WidgetFamily, timeline: () -> Timeline<Entry>) {}
    public init(_ title: String, as: WidgetFamily, timelineProvider: (TimelineProviderContext) -> Void) {}
}

@resultBuilder
public enum PreviewActivityBuilder<Content> {
    public static func buildPartialBlock(first: Content) -> Content { return first }
    public static func buildPartialBlock(accumulated: Content, next: Content) -> Content { return next }
    public static func buildExpression(_ expression: Content) -> Content { return expression }
    public static func buildArray(_ array: [Content]) -> [Content] { return array }
}

@resultBuilder
public enum PreviewTimelineBuilder<Entry> {
    public static func buildPartialBlock(first: Entry) -> Entry { return first }
    public static func buildPartialBlock(accumulated: Entry, next: Entry) -> Entry { return next }
    public static func buildExpression(_ expression: Entry) -> Entry { return expression }
    public static func buildArray(_ array: [Entry]) -> [Entry] { return array }
}
