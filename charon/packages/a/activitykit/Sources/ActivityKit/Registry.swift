// The port's own record of the activities an app has registered.
//
// The framework's record is the system's daemon, which is not on these releases. This is where the
// module keeps what an app registered, so that `activities`, the update streams and a later in-process
// read all see the same values. It is per process, as the daemon's is per device: what survives a
// relaunch is the system's own store, and `facts/ActivityKit/Availability.md` says so.

import Foundation

/// What the registry needs of an activity: its name, which is what it keys its record by. Every
/// `Activity<Attributes>` has one, whatever its attributes are.
public protocol CharonRegisteredActivity {
    var id: String { get }
    var charonActivityState: ActivityState { get }
}

/// The activities the app has registered, and what the system did with them.
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
    /// The live activities by identifier. Their type is the caller's, so the table holds `Any` and
    /// each read casts to the type the caller asked about - which is how one registry serves every
    /// `ActivityAttributes` an app has.
    private var live: [String: Any] = [:]
    private let lock = NSLock()

    public init() {}

    /// The activities of one kind that have not ended, in the order they were registered.
    func activities<Attributes>(of type: Attributes.Type) -> [Activity<Attributes>] {
        lock.lock()
        let ids = entries.filter { $0.typeName == String(describing: Attributes.self) && $0.endedAt == nil }
            .map { $0.id }
        lock.unlock()
        return ids.compactMap { live[$0] as? Activity<Attributes> }
    }

    /// Register an activity and keep it, which is what the daemon does with a request it accepts.
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

    /// The record of a push the system delivered, which is the date the end or the update is dated.
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

    /// The token the daemon mints for the app as a whole, which every activity of the app shares.
    /// Only the daemon mints one, and there is none here.
    func pushToStartToken(of type: Any.Type) -> Data? { return nil }
}
