import Foundation

public protocol TimelineEntry {
    var date: Date { get }
    var relevance: TimelineEntryRelevance? { get }
}

extension TimelineEntry {
    public var relevance: TimelineEntryRelevance? { return nil }
}

public struct TimelineEntryRelevance: Codable, Hashable {
    public let score: Double
    public let duration: TimeInterval

    public init(score: Double, duration: TimeInterval) {
        self.score = score < 0 ? 0 : (score > 1 ? 1 : score)
        self.duration = duration
    }
}

public struct TimelineReloadPolicy: Equatable {
    public static var never: TimelineReloadPolicy { return TimelineReloadPolicy(.never) }
    public static var atEnd: TimelineReloadPolicy { return TimelineReloadPolicy(.atEnd) }
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

public struct Timeline<EntryType> where EntryType: TimelineEntry {
    public let entries: [EntryType]
    public let policy: TimelineReloadPolicy

    public init(entries: [EntryType], policy: TimelineReloadPolicy) {
        self.entries = entries
        self.policy = policy
    }
}

public struct TimelineProviderContext {
    public let family: WidgetFamily
    public let isPreview: Bool
    public let displaySize: CGSizeLike
    public let environmentVariants: EnvironmentVariants

    public init(family: WidgetFamily, isPreview: Bool = false, displaySize: CGSizeLike = CGSizeLike(),
                environmentVariants: EnvironmentVariants = EnvironmentVariants()) {
        self.family = family
        self.isPreview = isPreview
        self.displaySize = displaySize
        self.environmentVariants = environmentVariants
    }

    public static func of(_ family: WidgetFamily) -> TimelineProviderContext {
        return TimelineProviderContext(family: family)
    }

    public struct EnvironmentVariants {
        public init() {}

        public subscript<Value>(dynamicMember keyPath: KeyPath<EnvironmentVariants, Value>) -> [Value]? {
            return nil
        }

        public subscript<Value>(keyPath: KeyPath<EnvironmentVariants, Value>) -> Value? {
            return nil
        }
    }
}

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

public enum WidgetMountingStyle: Sendable, Hashable {
    case elevated
    case recessed
}

public enum WidgetAccentedRenderingMode: Hashable {
    case fullColor
    case accented
    case accentedDesaturated
    case desaturated
}

public struct SupportedActivityFamiliesEnvironmentKey {
    public typealias Value = Set<ActivityFamily>
    public static var defaultValue: Value { return [ActivityFamily.small, .medium] }
}

public enum ActivityFamily: String, Equatable, CustomStringConvertible {
    case small
    case medium

    public var description: String { return rawValue }
}

public enum WidgetRenderingMode: Equatable, CustomStringConvertible {
    case fullColor
    case accented
    case vibrant

    public var description: String { return String(describing: self) }
}

public enum LevelOfDetail: Equatable {
    case simplified
    case `default`
}

public struct WidgetRelevanceGroup: Hashable, Sendable {
    private let name: String?

    private init(_ name: String?) {
        self.name = name
    }

    public static func named(_ name: String) -> WidgetRelevanceGroup { return WidgetRelevanceGroup(name) }

    public static var automatic: WidgetRelevanceGroup { return WidgetRelevanceGroup(nil) }

    public static var ungrouped: WidgetRelevanceGroup { return WidgetRelevanceGroup("ungrouped") }
}

public struct WidgetRelevance<Configuration> {
    public let group: WidgetRelevanceGroup
    public let context: Context?
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

public struct WidgetTexture: Sendable, Hashable {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}

public struct WidgetPushInfo: Sendable {
    public let token: Data

    public init(token: Data) {
        self.token = token
    }
}
