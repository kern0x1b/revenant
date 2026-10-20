import Foundation

public struct TimelineEntryRelevance: Codable, Hashable {
    public var score: Float
    public var duration: TimeInterval

    public init(score: Float, duration: TimeInterval) {
        self.score = score
        self.duration = duration
    }
}

public protocol TimelineEntry {
    var date: Date { get }
    var relevance: TimelineEntryRelevance? { get }
}

extension TimelineEntry {
    public var relevance: TimelineEntryRelevance? { nil }
}

public struct Timeline<EntryType: TimelineEntry> {
    public var entries: [EntryType]
    public var policy: TimelineReloadPolicy

    public init(entries: [EntryType], policy: TimelineReloadPolicy) {
        self.entries = entries
        self.policy = policy
    }
}

public struct TimelineReloadPolicy: Equatable {
    private enum Kind: Equatable {
        case atEnd
        case never
        case after(Date)
    }

    private let kind: Kind

    private init(_ kind: Kind) {
        self.kind = kind
    }

    public static var atEnd: TimelineReloadPolicy { TimelineReloadPolicy(.atEnd) }
    public static var never: TimelineReloadPolicy { TimelineReloadPolicy(.never) }

    public static func after(_ date: Date) -> TimelineReloadPolicy {
        TimelineReloadPolicy(.after(date))
    }
}

public struct WidgetRenderingMode: Equatable, CustomStringConvertible {
    private let name: String

    private init(_ name: String) {
        self.name = name
    }

    public static let fullColor = WidgetRenderingMode("fullColor")
    public static let accented = WidgetRenderingMode("accented")
    public static let vibrant = WidgetRenderingMode("vibrant")

    public var description: String { name }
}

public struct WidgetAccentedRenderingMode: Hashable {
    private enum Mode: Hashable {
        case accented
        case desaturated
        case accentedDesaturated
        case fullColor
    }

    private let mode: Mode

    private init(_ mode: Mode) {
        self.mode = mode
    }

    public static let accented = WidgetAccentedRenderingMode(.accented)
    public static let desaturated = WidgetAccentedRenderingMode(.desaturated)
    public static let accentedDesaturated = WidgetAccentedRenderingMode(.accentedDesaturated)
    public static let fullColor = WidgetAccentedRenderingMode(.fullColor)
}

public enum WidgetFamily: Int, Sendable {
    case systemSmall = 0
    case systemMedium = 1
    case systemLarge = 2
    case systemExtraLarge = 3
    case systemExtraLargePortrait = 4
    case accessoryCorner = 5
    case accessoryCircular = 6
    case accessoryRectangular = 7
    case accessoryInline = 8
}

extension WidgetFamily: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .systemSmall: return "systemSmall"
        case .systemMedium: return "systemMedium"
        case .systemLarge: return "systemLarge"
        case .systemExtraLarge: return "systemExtraLarge"
        case .systemExtraLargePortrait: return "systemExtraLargePortrait"
        case .accessoryCorner: return "accessoryCorner"
        case .accessoryCircular: return "accessoryCircular"
        case .accessoryRectangular: return "accessoryRectangular"
        case .accessoryInline: return "accessoryInline"
        }
    }

    public var debugDescription: String { description }
}

public struct LevelOfDetail: Equatable {
    private let name: String

    private init(_ name: String) {
        self.name = name
    }

    public static let `default` = LevelOfDetail("default")
    public static let simplified = LevelOfDetail("simplified")
}

public struct WidgetMountingStyle: Hashable, Sendable {
    private enum Style: Hashable {
        case elevated
        case recessed
    }

    private let style: Style

    private init(_ style: Style) {
        self.style = style
    }

    public static let elevated = WidgetMountingStyle(.elevated)
    public static let recessed = WidgetMountingStyle(.recessed)
}

public struct WidgetLocation: Hashable, Sendable {
    private enum Place: Hashable {
        case homeScreen
        case lockScreen
        case standBy
        case iPhoneWidgetsOnMac
        case watchFace
        case smartStack
        case carPlay
    }

    private let place: Place

    private init(_ place: Place) {
        self.place = place
    }

    public static let homeScreen = WidgetLocation(.homeScreen)
    public static let lockScreen = WidgetLocation(.lockScreen)
    public static let standBy = WidgetLocation(.standBy)
    public static let iPhoneWidgetsOnMac = WidgetLocation(.iPhoneWidgetsOnMac)
    public static let watchFace = WidgetLocation(.watchFace)
    public static let smartStack = WidgetLocation(.smartStack)
    public static let carPlay = WidgetLocation(.carPlay)
}
