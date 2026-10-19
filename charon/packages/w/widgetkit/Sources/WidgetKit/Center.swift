// The centre: the system service a widget asks to be redrawn, and the record it keeps of what is
// installed.
//
// `WidgetCenter` is a handle on a daemon (`chronod`/`WidgetKitAgent`) that owns the installed
// widgets. iOS 6.1.3 runs no widget host and no daemon, so `reloadTimelines` and `reloadAllTimelines`
// are the port's own redraw of the in-app surface, and `currentConfigurations` answers with the
// configurations the app registered in the port's own store. `facts/WidgetKit/Host.md`.

import Foundation
import AppIntents

/// The system's own record of one installed widget.
public struct WidgetInfo: Hashable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    public typealias ID = String

    /// The name the widget's kind is registered under.
    public let kind: String
    /// The configuration the widget is drawn with, in the form the system keeps.
    public let configuration: String
    /// The family the widget is drawn at on the surface it is installed on.
    public let family: WidgetFamily
    /// The name the system knows this installation by.
    public let id: String

    public init(kind: String, configuration: String, family: WidgetFamily, id: String = UUID().uuidString) {
        self.kind = kind
        self.configuration = configuration
        self.family = family
        self.id = id
    }

    /// The intent the widget's configuration names, when it names an app intent.
    public func widgetConfigurationIntent<Intent>(of type: Intent.Type = Intent.self) -> Intent?
        where Intent: WidgetConfigurationIntent {
        return CharonWidgetRegistry.shared.intent(for: type, kind: kind, configuration: configuration)
    }

    public var description: String { return "\(kind)@\(id)" }
    public var debugDescription: String { return "WidgetInfo(kind: \(kind), family: \(family), id: \(id))" }
}

/// The system's own record of one installed control.
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

    /// The intent the control's configuration names, when it names an app intent.
    public func configurationIntent<Intent>(of type: Intent.Type = Intent.self) -> Intent?
        where Intent: WidgetConfigurationIntent {
        return CharonWidgetRegistry.shared.intent(for: type, kind: kind, configuration: nil)
    }
}

/// The handle a widget has on the system that draws and redraws it.
public final class WidgetCenter {
    public static let shared = WidgetCenter()

    /// The keys the system puts an installation's own values under in a user-info dictionary.
    public struct UserInfoKey {
        public static var kind: String { return "WidgetKind" }
        public static var family: String { return "WidgetFamily" }
        public static var activityID: String { return "WidgetActivityID" }

        public init() {}
    }

    /// The push token the system minted for the widget this process is drawing, which is nothing
    /// where there is no host.
    public var currentPushInfo: WidgetPushInfo? { return CharonWidgetRegistry.shared.currentPushInfo }

    public init() {}

    /// Ask for every installed widget to be redrawn.
    public func reloadAllTimelines() {
        CharonWidgetRegistry.shared.reloadAll()
    }

    /// Ask for the widgets of one kind to be redrawn.
    public func reloadTimelines(ofKind kind: String) {
        CharonWidgetRegistry.shared.reload(kind: kind)
    }

    /// The system's own record of what is installed, the way the system answers it.
    public func currentConfigurations() async throws -> [WidgetInfo] {
        return CharonWidgetRegistry.shared.configurations()
    }

    /// The system's own record of what is installed, in the callback spelling the system uses.
    public func getCurrentConfigurations(_ completion: @escaping @Sendable (Result<[WidgetInfo], any Error>) -> Void) {
        // the callback is the system's own shape; the answer is already in the store, so it is handed
        // over without a run of the caller's async work
        completion(.success(CharonWidgetRegistry.shared.configurations()))
    }

    /// Tell the system the recommendations the widget asked for are no longer right.
    public func invalidateConfigurationRecommendations() {
        CharonWidgetRegistry.shared.invalidateRecommendations()
    }

    /// Tell the system the widget of one kind is no longer worth what it was scored by.
    public func invalidateRelevance(ofKind kind: String) {
        CharonWidgetRegistry.shared.invalidateRelevance(ofKind: kind)
    }
}

/// The handle on the control centre's own service, which is where a control's value is drawn.
public final class ControlCenter {
    public static let shared = ControlCenter()

    private init() {}

    /// The controls the app has installed, which is the port's own record.
    public static func currentControls() -> [ControlInfo] { return CharonWidgetRegistry.shared.controls() }

    /// Ask for every installed control to be redrawn.
    public static func reloadAllControls() { CharonWidgetRegistry.shared.reloadAll() }

    /// Ask for the controls of one kind to be redrawn.
    public static func reloadControls(ofKind kind: String) { CharonWidgetRegistry.shared.reload(kind: kind) }
}
