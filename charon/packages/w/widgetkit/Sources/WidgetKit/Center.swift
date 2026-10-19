import Foundation
import AppIntents

public struct WidgetInfo: Hashable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    public typealias ID = String

    public let kind: String
    public let configuration: String
    public let family: WidgetFamily
    public let id: String

    public init(kind: String, configuration: String, family: WidgetFamily, id: String = UUID().uuidString) {
        self.kind = kind
        self.configuration = configuration
        self.family = family
        self.id = id
    }

    public func widgetConfigurationIntent<Intent>(of type: Intent.Type = Intent.self) -> Intent?
        where Intent: WidgetConfigurationIntent {
        return CharonWidgetRegistry.shared.intent(for: type, kind: kind, configuration: configuration)
    }

    public var description: String { return "\(kind)@\(id)" }
    public var debugDescription: String { return "WidgetInfo(kind: \(kind), family: \(family), id: \(id))" }
}

public struct ControlInfo: Identifiable {
    public typealias ID = String

    public let id: String
    public let kind: String
    public let pushInfo: ControlPushInfo?

    public init(id: String, kind: String, pushInfo: ControlPushInfo? = nil) {
        self.id = id
        self.kind = kind
        self.pushInfo = pushInfo
    }

    public func configurationIntent<Intent>(of type: Intent.Type = Intent.self) -> Intent?
        where Intent: WidgetConfigurationIntent {
        return CharonWidgetRegistry.shared.intent(for: type, kind: kind, configuration: nil)
    }
}

public final class WidgetCenter {
    public static let shared = WidgetCenter()

    public struct UserInfoKey {
        public static var kind: String { return "WidgetKind" }
        public static var family: String { return "WidgetFamily" }
        public static var activityID: String { return "WidgetActivityID" }

        public init() {}
    }

    public var currentPushInfo: WidgetPushInfo? { return CharonWidgetRegistry.shared.currentPushInfo }

    public init() {}

    public func reloadAllTimelines() {
        CharonWidgetRegistry.shared.reloadAll()
    }

    public func reloadTimelines(ofKind kind: String) {
        CharonWidgetRegistry.shared.reload(kind: kind)
    }

    public func currentConfigurations() async throws -> [WidgetInfo] {
        return CharonWidgetRegistry.shared.configurations()
    }

    public func getCurrentConfigurations(_ completion: @escaping @Sendable (Result<[WidgetInfo], any Error>) -> Void) {
        completion(.success(CharonWidgetRegistry.shared.configurations()))
    }

    public func invalidateConfigurationRecommendations() {
        CharonWidgetRegistry.shared.invalidateRecommendations()
    }

    public func invalidateRelevance(ofKind kind: String) {
        CharonWidgetRegistry.shared.invalidateRelevance(ofKind: kind)
    }
}

public final class ControlCenter {
    public static let shared = ControlCenter()

    private init() {}

    public static func currentControls() -> [ControlInfo] { return CharonWidgetRegistry.shared.controls() }

    public static func reloadAllControls() { CharonWidgetRegistry.shared.reloadAll() }

    public static func reloadControls(ofKind kind: String) { CharonWidgetRegistry.shared.reload(kind: kind) }
}
