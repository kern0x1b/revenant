import Foundation

public protocol CharonRegisteredActivity {
    var id: String { get }
    var charonActivityState: ActivityState { get }
}

public final class CharonActivityRegistry {
    public static let shared = CharonActivityRegistry()

    private struct Entry {
        let id: String
        let typeName: String
        var style: ActivityStyle
        var alert: (configuration: AlertConfiguration, start: Date)?
        var state: ActivityState
        var endedAt: Date?
    }

    private var entries: [Entry] = []
    private var live: [String: Any] = [:]
    private let lock = NSLock()

    public init() {}

    func activities<Attributes>(of type: Attributes.Type) -> [Activity<Attributes>] {
        lock.lock()
        let ids = entries.filter { $0.typeName == String(describing: Attributes.self) && $0.endedAt == nil }
            .map { $0.id }
        lock.unlock()
        return ids.compactMap { live[$0] as? Activity<Attributes> }
    }

    func register<Attributes>(attributes: Attributes,
                             content: ActivityContent<Attributes.ContentState>) throws -> Activity<Attributes>
        where Attributes: ActivityAttributes {
        let activity = Activity<Attributes>(attributes: attributes, state: content.state, id: UUID().uuidString)
        lock.lock()
        entries.append(Entry(id: activity.id, typeName: String(describing: Attributes.self), style: .standard,
                             alert: nil, state: .active, endedAt: nil))
        live[activity.id] = activity
        lock.unlock()
        return activity
    }

    func setStyle(_ style: ActivityStyle, for activity: CharonRegisteredActivity) {
        lock.lock()
        if let index = entries.firstIndex(where: { $0.id == activity.id }) {
            entries[index].style = style
        }
        lock.unlock()
    }

    func setAlert(_ configuration: AlertConfiguration, starting start: Date, for activity: CharonRegisteredActivity) {
        lock.lock()
        if let index = entries.firstIndex(where: { $0.id == activity.id }) {
            entries[index].alert = (configuration, start)
        }
        lock.unlock()
    }

    func didUpdate(activity: CharonRegisteredActivity) {
        lock.lock()
        if let index = entries.firstIndex(where: { $0.id == activity.id }) {
            entries[index].state = activity.charonActivityState
        }
        lock.unlock()
    }

    func didPush(_ activity: CharonRegisteredActivity, at date: Date) {
        lock.lock()
        if let index = entries.firstIndex(where: { $0.id == activity.id }) {
            entries[index].endedAt = entries[index].endedAt ?? date
        }
        lock.unlock()
    }

    func didEnd(activity: CharonRegisteredActivity, dismissalPolicy: ActivityUIDismissalPolicy,
                at date: Date? = nil) {
        lock.lock()
        if let index = entries.firstIndex(where: { $0.id == activity.id }) {
            entries[index].state = .ended
            entries[index].endedAt = date ?? Date()
        }
        lock.unlock()
    }

    func pushToStartToken(of type: Any.Type) -> Data? { return nil }
}
