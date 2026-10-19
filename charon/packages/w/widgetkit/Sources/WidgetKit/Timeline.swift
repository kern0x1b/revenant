// The timeline: what a widget shows, when, and how its entries are told apart by relevance.
//
// A widget is a view the system draws on a surface of its own, and a timeline is the list of what it
// shows and when. Neither needs the system to be a value: the entries, the reload policy, the
// relevance and the provider context are the app's own, and the system only asks for them and draws
// the result. iOS 6.1.3 has no widget host at all, so what a widget draws is drawn in the app - the
// module says so in `facts/WidgetKit/Host.md` - and every value here is what the app put in it.

import Foundation

/// One thing a widget shows, at one moment.
public protocol TimelineEntry {
    /// When the entry is for.
    var date: Date { get }
    /// How relevant the entry is against the others, which the system sorts by.
    var relevance: TimelineEntryRelevance? { get }
}

extension TimelineEntry {
    public var relevance: TimelineEntryRelevance? { return nil }
}

/// How relevant an entry is, and for how long.
public struct TimelineEntryRelevance: Codable, Hashable {
    /// The score, from 0 to 1.
    public let score: Double
    /// How long the score holds, which the system waits before asking for a new timeline.
    public let duration: TimeInterval

    public init(score: Double, duration: TimeInterval) {
        // the framework's own clips rather than refuses, and a score of 0 means "no relevance"
        self.score = score < 0 ? 0 : (score > 1 ? 1 : score)
        self.duration = duration
    }
}

/// When the system should come back for a new timeline.
public struct TimelineReloadPolicy: Equatable {
    /// Never: the timeline is drawn once and stays.
    public static var never: TimelineReloadPolicy { return TimelineReloadPolicy(.never) }
    /// At the end of the last entry.
    public static var atEnd: TimelineReloadPolicy { return TimelineReloadPolicy(.atEnd) }
    /// After this many seconds.
    public static func after(_ date: TimeInterval) -> TimelineReloadPolicy { return TimelineReloadPolicy(.after(date)) }

    enum Kind: Equatable {
        case never
        case atEnd
        case after(TimeInterval)
    }

    let kind: Kind

    private init(_ kind: Kind) {
        self.kind = kind
    }
}

/// A list of what a widget shows, and when the system should ask again.
public struct Timeline<EntryType> where EntryType: TimelineEntry {
    /// The entries, in the order the system draws them.
    public let entries: [EntryType]
    /// When the system comes back for a new list.
    public let policy: TimelineReloadPolicy

    public init(entries: [EntryType], policy: TimelineReloadPolicy) {
        self.entries = entries
        self.policy = policy
    }
}

/// What the system tells a provider when it asks for a timeline.
public struct TimelineProviderContext {
    /// The family of surface the widget is drawn on.
    public let family: WidgetFamily
    /// Whether this is a preview rather than a real draw.
    public let isPreview: Bool
    /// The size the surface is drawn at, which is the release's own size in points.
    public let displaySize: CGSizeLike
    /// The variants the system may draw the widget at for this family.
    public let environmentVariants: EnvironmentVariants

    public init(family: WidgetFamily, isPreview: Bool = false, displaySize: CGSizeLike = CGSizeLike(),
                environmentVariants: EnvironmentVariants = EnvironmentVariants()) {
        self.family = family
        self.isPreview = isPreview
        self.displaySize = displaySize
        self.environmentVariants = environmentVariants
    }

    /// A context for a family, with the system's own defaults for everything it does not name.
    public static func of(_ family: WidgetFamily) -> TimelineProviderContext {
        return TimelineProviderContext(family: family)
    }

    /// The variants a widget is drawn at on one family: a light, a dark and an increased-contrast
    /// drawing of the same widget. The system holds them; this release has no store of them, so a
    /// variant asked for by name or by key path is answered with none rather than with a value the
    /// system never produced. The framework's own subscripts are two, both over SwiftUI's
    /// `EnvironmentValues` (`WidgetKit-ios.swiftinterface:1714-1721`); both are answered here with
    /// none, and both take the key path over this type, because that is the one type this module
    /// has.
    public struct EnvironmentVariants {
        public init() {}

        /// The variants at a key path the drawing is reached by, which is the framework's own
        /// `@dynamicMemberLookup` subscript (`WidgetKit-ios.swiftinterface:1714-1716`).
        /// Its answer is the same none, for the same reason, and the key path is taken over this type
        /// as the one below is.
        public subscript<Value>(dynamicMember keyPath: KeyPath<EnvironmentVariants, Value>) -> [Value]? {
            return nil
        }

        /// The drawing at a key path into the widget's own environment.
        ///
        /// The interface takes a key path into `SwiftUI.EnvironmentValues` and answers `[T]?`
        /// (`WidgetKit-ios.swiftinterface:1719`): the values are the *system's* own, so the honest
        /// answer for one this release has no record of is none. The framework's spelling needs
        /// SwiftUI's `EnvironmentValues`, which is another band's, so the key path is taken over
        /// this type and the answer stays optional, as the framework's is.
        public subscript<Value>(keyPath: KeyPath<EnvironmentVariants, Value>) -> Value? {
            return nil
        }
    }
}

/// A size in points, which is what the system measures a widget's surface in.
public struct CGSizeLike: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init() {
        self.width = 0
        self.height = 0
    }

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// The surface a widget is drawn on, which is what the family names.
public enum WidgetFamily: String, Hashable, Sendable, CustomStringConvertible {
    case systemSmall
    case systemMedium
    case systemLarge
    case systemExtraLarge
    case systemExtraLargePortrait
    case accessoryCircular
    case accessoryCorner
    case accessoryInline
    case accessoryRectangular

    public var description: String { return rawValue }

    public var debugDescription: String { return "WidgetFamily(\(rawValue))" }
}

/// Where a widget is shown, which is what a relevance group and a configuration are told.
public struct WidgetLocation: Sendable, Hashable {
    private let name: String

    private init(_ name: String) {
        self.name = name
    }

    public static var homeScreen: WidgetLocation { return WidgetLocation("homeScreen") }
    public static var lockScreen: WidgetLocation { return WidgetLocation("lockScreen") }
    public static var smartStack: WidgetLocation { return WidgetLocation("smartStack") }
    public static var controlCenter: WidgetLocation { return WidgetLocation("controlCenter") }
    public static var standBy: WidgetLocation { return WidgetLocation("standBy") }
    public static var carPlay: WidgetLocation { return WidgetLocation("carPlay") }
    public static var watchFace: WidgetLocation { return WidgetLocation("watchFace") }
    public static var iPhoneWidgetsOnMac: WidgetLocation { return WidgetLocation("iPhoneWidgetsOnMac") }
}

/// How a widget is mounted on the surface it is drawn on, which is what the system's own drawing
/// asks for.
public enum WidgetMountingStyle: Sendable, Hashable {
    case elevated
    case recessed
}

/// Whether the widget's colours are drawn from its own or from the system's accent.
public enum WidgetAccentedRenderingMode: Hashable {
    case fullColor
    case accented
    case accentedDesaturated
    case desaturated
}

/// The families a widget supports, which the system reads out of the environment.
public struct SupportedActivityFamiliesEnvironmentKey {
    public typealias Value = Set<ActivityFamily>
    public static var defaultValue: Value { return [ActivityFamily.small, .medium] }
}

/// The family of a Live Activity's surface, which is what `ActivityViewContext` is told.
public enum ActivityFamily: String, Equatable, CustomStringConvertible {
    case small
    case medium

    public var description: String { return rawValue }
}

/// How a widget is drawn when the system's own accent is over it.
public enum WidgetRenderingMode: Equatable, CustomStringConvertible {
    case fullColor
    case accented
    case vibrant

    public var description: String { return String(describing: self) }
}

/// How much of a widget's content the surface has room for.
public enum LevelOfDetail: Equatable {
    case simplified
    case `default`
}

/// A relevance group, which is what a widget is scored within.
public struct WidgetRelevanceGroup: Hashable, Sendable {
    private let name: String?

    private init(_ name: String?) {
        self.name = name
    }

    /// A group the app names, which is what the system scores the widget within.
    public static func named(_ name: String) -> WidgetRelevanceGroup { return WidgetRelevanceGroup(name) }

    /// The system's own group, which is the widget's family.
    public static var automatic: WidgetRelevanceGroup { return WidgetRelevanceGroup(nil) }

    /// No group at all, which is what a widget is scored in when it names none.
    public static var ungrouped: WidgetRelevanceGroup { return WidgetRelevanceGroup("ungrouped") }
}

/// What a widget is scored by, which is a group and the context it is scored in.
public struct WidgetRelevance<Configuration> {
    public let group: WidgetRelevanceGroup
    public let context: Context?
    /// The context a relevance is scored in: the configuration the widget is drawn with.
    public typealias Context = Configuration

    public init(_ group: WidgetRelevanceGroup) {
        self.group = group
        self.context = nil
    }

    public init(group: WidgetRelevanceGroup) {
        self.group = group
        self.context = nil
    }

    public init(context: Configuration) {
        self.group = .automatic
        self.context = context
    }

    public init(configuration: Configuration, context: Configuration) {
        self.group = .automatic
        self.context = context
    }

    public init(configuration: Configuration, group: WidgetRelevanceGroup) {
        self.group = group
        self.context = configuration
    }
}

/// The relevance a widget asks the system to score it by, over a configuration.
public struct WidgetRelevanceAttribute<Configuration> {
    public let relevance: WidgetRelevance<Configuration>

    public init(context: Configuration) {
        self.relevance = WidgetRelevance(context: context)
    }

    public init(group: WidgetRelevanceGroup) {
        self.relevance = WidgetRelevance(group: group)
    }

    public init(configuration: Configuration, group: WidgetRelevanceGroup) {
        self.relevance = WidgetRelevance(configuration: configuration, group: group)
    }

    public init(configuration: Configuration, context: Configuration) {
        self.relevance = WidgetRelevance(configuration: configuration, context: context)
    }
}

/// A texture the system has for a widget, which is what a large widget is drawn from.
public struct WidgetTexture: Sendable, Hashable {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}

/// The push token the system mints for a widget, which is what a push-to-start widget is woken by.
public struct WidgetPushInfo: Sendable {
    public let token: Data

    public init(token: Data) {
        self.token = token
    }
}
