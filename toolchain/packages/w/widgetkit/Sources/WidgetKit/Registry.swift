import Foundation
import AppIntents

public final class RevenantWidgetRegistry {
    public static let shared = RevenantWidgetRegistry()

    private var infos: [WidgetInfo] = []
    private var installedControls: [ControlInfo] = []
    private var intents: [String: AnyWidgetConfigurationIntent] = [:]
    private var push: WidgetPushInfo?
    private let lock = NSLock()

    public var redraw: ((String) -> Void)?
    public var redrawControl: ((String) -> Void)?

    public init() {}

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

    public func register(kind: String, configuration: String, family: WidgetFamily) {
        lock.lock()
        infos.append(WidgetInfo(kind: kind, configuration: configuration, family: family))
        lock.unlock()
    }

    public func registerControl(id: String, kind: String, pushInfo: ControlPushInfo?) {
        lock.lock()
        installedControls.append(ControlInfo(id: id, kind: kind, pushInfo: pushInfo))
        lock.unlock()
    }

    public func register<Intent: WidgetConfigurationIntent>(_ intent: Intent, for kind: String,
                                                            configuration: String? = nil) {
        lock.lock()
        intents[RevenantWidgetRegistry.key(for: kind, configuration: configuration)] = AnyWidgetConfigurationIntent(intent)
        lock.unlock()
    }

    func intent<Intent: WidgetConfigurationIntent>(for type: Intent.Type, kind: String,
                                                   configuration: String?) -> Intent? {
        lock.lock()
        defer { lock.unlock() }
        return intents[RevenantWidgetRegistry.key(for: kind, configuration: configuration)]?.value as? Intent
    }

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

struct AnyWidgetConfigurationIntent {
    let value: any WidgetConfigurationIntent

    init<Intent: WidgetConfigurationIntent>(_ intent: Intent) {
        self.value = intent
    }
}
