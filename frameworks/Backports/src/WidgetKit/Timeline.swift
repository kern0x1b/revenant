import Foundation

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

public struct SupportedActivityFamiliesEnvironmentKey {
    public typealias Value = Set<ActivityFamily>
    public static var defaultValue: Value { return [ActivityFamily.small, .medium] }
}

public enum ActivityFamily: String, Equatable, CustomStringConvertible {
    case small
    case medium

    public var description: String { return rawValue }
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
