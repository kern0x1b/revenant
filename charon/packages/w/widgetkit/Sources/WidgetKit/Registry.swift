// The port's own record of the widgets and controls an app has installed, and the redraw a widget
// asks for.
//
// The framework's record is the system's widget daemon; these releases run no widget host and no such
// daemon, so the record is this one: what a widget registered, which is what `currentConfigurations`
// answers and what `reloadTimelines` redraws. The redraw goes to the handler the app installs, which
// is where an in-app widget surface draws. `facts/WidgetKit/Host.md`.

import Foundation
import AppIntents

/// What the app's installed widgets are, and the redraw a widget asks for.
public final class CharonWidgetRegistry {
    public static let shared = CharonWidgetRegistry()

    private var infos: [WidgetInfo] = []
    private var installedControls: [ControlInfo] = []
    private var intents: [String: AnyWidgetConfigurationIntent] = [:]
    private var push: WidgetPushInfo?
    private let lock = NSLock()

    /// The handler that draws the app's own widget surface, which the redraw calls.
    public var redraw: ((String) -> Void)?
    /// The handler that draws the app's own control surface.
    public var redrawControl: ((String) -> Void)?

    public init() {}

    /// The configurations the app registered, in the order it registered them.
    public func configurations() -> [WidgetInfo] {
        lock.lock()
        defer { lock.unlock() }
        return infos
    }

    public func controls() -> [ControlInfo] {
        lock.lock()
        defer { lock.unlock() }
        return installedControls
    }

    public var currentPushInfo: WidgetPushInfo? {
        lock.lock()
        defer { lock.unlock() }
        return push
    }

    /// Register a widget: the kind, the configuration and the family it is drawn at.
    public func register(kind: String, configuration: String, family: WidgetFamily) {
        lock.lock()
        infos.append(WidgetInfo(kind: kind, configuration: configuration, family: family))
        lock.unlock()
    }

    /// Register a control, with the push token the system minted for it.
    public func registerControl(id: String, kind: String, pushInfo: ControlPushInfo?) {
        lock.lock()
        installedControls.append(ControlInfo(id: id, kind: kind, pushInfo: pushInfo))
        lock.unlock()
    }

    /// Remember the intent a widget's configuration names, so `widgetConfigurationIntent(of:)` can hand
    /// the same instance back to the app that registered it.
    public func register<Intent: WidgetConfigurationIntent>(_ intent: Intent, for kind: String,
                                                            configuration: String? = nil) {
        lock.lock()
        intents[CharonWidgetRegistry.key(for: kind, configuration: configuration)] = AnyWidgetConfigurationIntent(intent)
        lock.unlock()
    }

    func intent<Intent: WidgetConfigurationIntent>(for type: Intent.Type, kind: String,
                                                   configuration: String?) -> Intent? {
        lock.lock()
        defer { lock.unlock() }
        return intents[CharonWidgetRegistry.key(for: kind, configuration: configuration)]?.value as? Intent
    }

    /// The system mints a push token for the widget this process draws; a caller that has one installs
    /// it, and with none the framework's own answer is nothing.
    public func setCurrentPushInfo(_ info: WidgetPushInfo?) {
        lock.lock()
        push = info
        lock.unlock()
    }

    public func reloadAll() {
        lock.lock()
        let kinds = Set(infos.map { $0.kind } + installedControls.map { $0.kind })
        lock.unlock()
        for kind in kinds { reload(kind: kind) }
    }

    public func reload(kind: String) {
        redraw?(kind)
        redrawControl?(kind)
    }

    public func invalidateRecommendations() {}

    public func invalidateRelevance(ofKind kind: String) {}

    private static func key(for kind: String, configuration: String?) -> String {
        return "\(kind)#\(configuration ?? "")"
    }
}

/// An intent of any configuration type, held so the registry can hand it back with the caller's own
/// type without knowing what that type is.
struct AnyWidgetConfigurationIntent {
    let value: any WidgetConfigurationIntent

    init<Intent: WidgetConfigurationIntent>(_ intent: Intent) {
        self.value = intent
    }
}
