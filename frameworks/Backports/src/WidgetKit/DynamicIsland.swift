import ActivityKit
import Foundation

public enum DynamicIslandMode: Equatable {
    case expanded
    case compactLeading
    case compactTrailing
    case minimal
}

public enum DynamicIslandExpandedRegionPosition: Equatable {
    case leading
    case trailing
    case center
    case bottom
}

public enum DynamicIslandExpandedRegionVerticalPlacement: Equatable {
    case `default`
    case belowIfTooWide
}

public struct DynamicIslandExpandedRegion<Content> {
    private let content: Content
    private let priority: Double
    private let position: DynamicIslandExpandedRegionPosition
    private let verticalPlacement: DynamicIslandExpandedRegionVerticalPlacement

    public init(_ content: Content, priority: Double = 0,
                position: DynamicIslandExpandedRegionPosition = .leading,
                verticalPlacement: DynamicIslandExpandedRegionVerticalPlacement = .default) {
        self.content = content
        self.priority = priority
        self.position = position
        self.verticalPlacement = verticalPlacement
    }

    public func contentMargins(_ leading: Double, _ trailing: Double) -> DynamicIslandExpandedRegion<Content> {
        return self
    }

    public var _viewRepresentation: Content { return content }
}

@resultBuilder
public enum DynamicIslandExpandedContentBuilder<Content> {
    public static func buildPartialBlock(first: DynamicIslandExpandedRegion<Content>) -> DynamicIslandExpandedRegion<Content> {
        return first
    }

    public static func buildPartialBlock(accumulated: DynamicIslandExpandedRegion<Content>,
                                         next: DynamicIslandExpandedRegion<Content>) -> DynamicIslandExpandedRegion<Content> {
        return next
    }
}

public struct DynamicIslandExpandedContent<Content> {
    public let content: Content

    public init(content: () -> Content) {
        self.content = content()
    }
}

public struct DynamicIsland<Expanded, CompactLeading, CompactTrailing, Minimal> {
    public let expanded: Expanded
    public let compactLeading: CompactLeading
    public let compactTrailing: CompactTrailing
    public let minimal: Minimal

    private var keylineTintSet = false
    private var widgetURLSet = false
    private var contentMarginsSet = false

    public init(expanded: Expanded, compactLeading: CompactLeading, compactTrailing: CompactTrailing,
                minimal: Minimal) {
        self.expanded = expanded
        self.compactLeading = compactLeading
        self.compactTrailing = compactTrailing
        self.minimal = minimal
    }

    public func keylineTint(_ tint: Any?) -> DynamicIsland<Expanded, CompactLeading, CompactTrailing, Minimal> {
        return self
    }

    public func widgetURL(_ url: URL?) -> DynamicIsland<Expanded, CompactLeading, CompactTrailing, Minimal> {
        return self
    }

    public func contentMargins(_ leading: Double, _ trailing: Double,
                               for mode: DynamicIslandMode) -> DynamicIsland<Expanded, CompactLeading, CompactTrailing, Minimal> {
        return self
    }
}

public struct ActivityViewContext<Attributes: ActivityAttributes> {
    public let attributes: Attributes
    public let state: Attributes.ContentState
    public let isStale: Bool
    public let activityID: String

    public init(attributes: Attributes, state: Attributes.ContentState, isStale: Bool, activityID: String) {
        self.attributes = attributes
        self.state = state
        self.isStale = isStale
        self.activityID = activityID
    }
}

public struct ActivityConfiguration<Attributes: ActivityAttributes, Content: WidgetBody> {
    public typealias Body = Content

    public let `for`: Attributes.Type
    public typealias Island = DynamicIsland<DynamicIslandExpandedContent<Content>, DynamicIslandExpandedContent<Content>,
                                           DynamicIslandExpandedContent<Content>, DynamicIslandExpandedContent<Content>>

    public let content: (ActivityViewContext<Attributes>) -> Content
    public let dynamicIsland: Island

    public init(for attributes: Attributes.Type, content: @escaping (ActivityViewContext<Attributes>) -> Content,
                dynamicIsland: Island) {
        self.for = attributes
        self.content = content
        self.dynamicIsland = dynamicIsland
    }

    public var body: (ActivityViewContext<Attributes>) -> Content { return content }
}

public struct ActivityViewContextPlaceholder {
    public static var shared: ActivityViewContextPlaceholder { return ActivityViewContextPlaceholder() }

    public func context<Attributes: ActivityAttributes>(for type: Attributes.Type) -> ActivityViewContext<Attributes>? {
        return nil
    }
}

public struct AccessoryWidgetBackground: WidgetBody, Sendable {
    public init() {}
}

extension AccessoryWidgetBackground {
    public typealias BodyType = Never
}
