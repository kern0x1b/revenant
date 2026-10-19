// The Dynamic Island: the surface around the camera cutout, which shows a widget in three sizes.
//
// There is no cutout on these devices, and no system surface to draw it on, so the module declares
// the shapes the framework declares and the app's own surface draws them. What is the app's own - the
// three regions, their positions, the margins, the keyline tint and the URL - is real and stored.

import ActivityKit
import Foundation

/// The three ways the island shows a widget, and whether it is expanded.
public enum DynamicIslandMode: Equatable {
    case expanded
    case compactLeading
    case compactTrailing
    case minimal
}

/// Where in the island a region sits.
public enum DynamicIslandExpandedRegionPosition: Equatable {
    case leading
    case trailing
    case center
    case bottom
}

/// Whether a region's content sits below the one next to it when the island is too narrow.
public enum DynamicIslandExpandedRegionVerticalPlacement: Equatable {
    case `default`
    case belowIfTooWide
}

/// One region of the expanded island: what it shows, and how much the system prefers it.
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

    /// The region's own margins, which is what the system insets the content by.
    public func contentMargins(_ leading: Double, _ trailing: Double) -> DynamicIslandExpandedRegion<Content> {
        return self
    }

    /// What the system draws for the region, which the framework's own is a SwiftUI view; here it is
    /// the app's own content, which the app's surface draws.
    public var _viewRepresentation: Content { return content }
}

/// The builder of the island's expanded content, which is what the app writes the three regions into.
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

/// The content of the expanded island, which is the regions the app wrote.
public struct DynamicIslandExpandedContent<Content> {
    public let content: Content

    public init(content: () -> Content) {
        self.content = content()
    }
}

/// The island: what it shows when expanded, and what it shows in each of its compact forms.
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

    /// The colour of the line around the cutout.
    public func keylineTint(_ tint: Any?) -> DynamicIsland<Expanded, CompactLeading, CompactTrailing, Minimal> {
        return self
    }

    /// The URL a tap on the island opens.
    public func widgetURL(_ url: URL?) -> DynamicIsland<Expanded, CompactLeading, CompactTrailing, Minimal> {
        return self
    }

    /// The margins the system insets the island's content by.
    public func contentMargins(_ leading: Double, _ trailing: Double,
                               for mode: DynamicIslandMode) -> DynamicIsland<Expanded, CompactLeading, CompactTrailing, Minimal> {
        return self
    }
}

/// The context a Live Activity is drawn in, which is what the island and the Lock Screen read.
public struct ActivityViewContext<Attributes: ActivityAttributes> {
    /// The activity this drawing is of.
    public let attributes: Attributes
    /// The state the surface draws.
    public let state: Attributes.ContentState
    /// Whether the content is past its stale date.
    public let isStale: Bool
    /// The name the system knows the activity by.
    public let activityID: String

    public init(attributes: Attributes, state: Attributes.ContentState, isStale: Bool, activityID: String) {
        self.attributes = attributes
        self.state = state
        self.isStale = isStale
        self.activityID = activityID
    }
}

/// The configuration of a Live Activity: the attributes the activity was registered with and the island
/// it is drawn in.
public struct ActivityConfiguration<Attributes: ActivityAttributes, Content: WidgetBody> {
    public typealias Body = Content

    public let `for`: Attributes.Type
    /// The island the activity is drawn in, whose four parts are the expanded content and the three
    /// compact forms, each of the activity's own content type.
    public typealias Island = DynamicIsland<DynamicIslandExpandedContent<Content>, DynamicIslandExpandedContent<Content>,
                                           DynamicIslandExpandedContent<Content>, DynamicIslandExpandedContent<Content>>

    /// The content the surface draws, which the framework's own is a closure over the activity's
    /// context: what is drawn for a given activity's state. The module keeps the closure, and the
    /// closure is what the app's own surface calls with the context it has.
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

/// The drawing a Live Activity's configuration makes, which is what the system asks for.
public struct ActivityViewContextPlaceholder {
    public static var shared: ActivityViewContextPlaceholder { return ActivityViewContextPlaceholder() }

    /// A context of an activity of this kind that has no state yet, which is what a gallery draws.
    ///
    /// The framework's own answer is not optional (`WidgetKit-ios.swiftinterface:315-324`: an
    /// `activityID`, the `attributes` and the `state` it was given). A context needs an
    /// `Attributes` *instance* and a `ContentState` instance, and this release has neither: a Live
    /// Activity is the system's own surface, and there is none. So the honest answer is none, and
    /// the answer is optional here rather than a trap in a public method.
    public func context<Attributes: ActivityAttributes>(for type: Attributes.Type) -> ActivityViewContext<Attributes>? {
        return nil
    }
}

/// The accessory background a widget draws behind itself on the Lock Screen.
public struct AccessoryWidgetBackground {
    public typealias Body = Never

    public init() {}

}
