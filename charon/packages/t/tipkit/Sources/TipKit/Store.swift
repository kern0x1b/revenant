// The datastore: what the owner has done, what has been shown, and where the app keeps it.
//
// TipKit's own datastore is a service the system's settings app writes, and its default location is
// inside the app's own container. Here the store is the app's own file: what the app donates is
// written where the app can read it back, and a rule's condition is evaluated over what is in it. That
// is the whole of the behaviour a rule needs, and it is real on every release. `facts/TipKit/Rendering.md`.

import Foundation

extension Tips {
    /// Where the app's tips are configured: how often they may be shown, where their donations are
    /// kept, and which container the app shares them through.
    public struct ConfigurationOption: Sendable {
        /// The container the app shares its tips through, which is the CloudKit account it names.
        public struct CloudKitContainer: Equatable, Sendable {
            /// The app's own container, which is what the framework's own default is.
            public static var automatic: CloudKitContainer { return CloudKitContainer(name: "") }

            let name: String

            private init(name: String) { self.name = name }

            /// The container the app names, which is the one its record type lives in.
            public static func named(_ name: String) -> CloudKitContainer { return CloudKitContainer(name: name) }

            public static func == (a: CloudKitContainer, b: CloudKitContainer) -> Bool { return a.name == b.name }
        }

        /// Where the donations are kept.
        public struct DatastoreLocation: Equatable, Sendable {
            /// Inside the app's own container, which is what the framework's own default is.
            public static var applicationDefault: DatastoreLocation {
                return DatastoreLocation(Tips.Store.shared.defaultURL.path)
            }

            let path: String

            private init(_ path: String) { self.path = path }

            /// The shared container the app names.
            public static func groupContainer(identifier: String) -> DatastoreLocation {
                return DatastoreLocation(identifier)
            }

            /// A file the app names.
            public static func url(_ url: URL) -> DatastoreLocation { return DatastoreLocation(url.path) }

            public static func == (a: DatastoreLocation, b: DatastoreLocation) -> Bool { return a.path == b.path }
        }

        /// How often a tip may be shown.
        public struct DisplayFrequency: Equatable, Sendable {
            let seconds: TimeInterval

            private init(_ seconds: TimeInterval) { self.seconds = seconds }

            /// As often as the app asks.
            public static var immediate: DisplayFrequency { return DisplayFrequency(0) }
            /// Once an hour.
            public static var hourly: DisplayFrequency { return DisplayFrequency(3600) }
            /// Once a day.
            public static var daily: DisplayFrequency { return DisplayFrequency(86400) }
            /// Once a week.
            public static var weekly: DisplayFrequency { return DisplayFrequency(604800) }
            /// Once a month.
            public static var monthly: DisplayFrequency { return DisplayFrequency(2592000) }

            public static func == (a: DisplayFrequency, b: DisplayFrequency) -> Bool { return a.seconds == b.seconds }
        }

        /// The container the app shares its tips through.
        public static func cloudKitContainer(_ container: CloudKitContainer) -> ConfigurationOption {
            return ConfigurationOption(container)
        }

        /// Where the donations are kept.
        public static func datastoreLocation(_ location: DatastoreLocation) -> ConfigurationOption {
            return ConfigurationOption(location)
        }

        /// How often a tip may be shown.
        public static func displayFrequency(_ frequency: DisplayFrequency) -> ConfigurationOption {
            return ConfigurationOption(frequency)
        }

        let value: Any

        init(_ value: Any) { self.value = value }
    }

    /// The datastore, and the configuration the app gave it.
    public struct Store {
        /// What the owner has done, keyed by the event's own name.
        public private(set) var donations: [String: [Tips.Event<EmptyDonation>.Donation]] = [:]
        /// When each tip was last shown.
        public private(set) var shown: [String: [Date]] = [:]
        /// Which tips were taken off the list, and why.
        public private(set) var invalidated: [String: Tips.InvalidationReason] = [:]
        /// How often a tip may be shown.
        public var displayFrequency: ConfigurationOption.DisplayFrequency = .immediate
        /// The container the app shares its tips through, when it named one.
        public var cloudKitContainer: ConfigurationOption.CloudKitContainer?
        /// Whether the app has configured its tips yet, which is what a second `configure` finds.
        public private(set) var configured = false
        /// Which kind of tip each id belongs to, filled in when the datastore is told about a tip.
        public private(set) var kinds: [String: String] = [:]

        /// The file the datastore is kept in, which is the app's own container.
        public let defaultURL: URL

        public static var shared = Store()

        public init() {
            let support = (NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first
                           ?? NSTemporaryDirectory())
            let folder = (support as NSString).appendingPathComponent("charon-tipkit")
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            self.defaultURL = URL(fileURLWithPath: folder).appendingPathComponent("tips.plist")
            load()
        }
        /// Where a tip is in its life, which the datastore answers. A tip is off the list either
        /// because the owner took it off, or because its own options say it has been offered as
        /// often as it may be; the reason the framework carries is the one that is recorded, and
        /// the option's own reason when it is the option that ended it.
        public func status(of tip: AnyTip) -> Tips.Status {
            if let reason = invalidated[tip.id] { return .invalidated(reason) }
            if let count = tip.options.compactMap({ $0 as? Tips.MaxDisplayCount }).first,
               shown[tip.id]?.count ?? 0 >= count.count {
                return .invalidated(.displayCountExceeded)
            }
            if let duration = tip.options.compactMap({ $0 as? Tips.MaxDisplayDuration }).first,
               let first = shown[tip.id]?.first, Date().timeIntervalSince(first) >= duration.duration {
                return .invalidated(.displayDurationExceeded)
            }
            return .available
        }

        /// Whether a tip may be shown now: it is not invalidated, its rules hold, and the display
        /// frequency allows it.
        public func shouldDisplay(_ tip: AnyTip) -> Bool {
            if invalidated[tip.id] != nil { return false }
            if CharonTipRules.hold(tip.rules, store: self) == false { return false }
            if let last = shown[tip.id]?.last, tip.options.contains(where: { $0 is Tips.IgnoresDisplayFrequency }) == false {
                let elapsed = Date().timeIntervalSince(last)
                if elapsed < displayFrequency.seconds { return false }
            }
            return CharonTipRules.withinOptions(tip, store: self)
        }

        /// Record that a tip was shown, which is what the popover does when it appears.
        public mutating func recordShown(_ tipID: String) {
            shown[tipID, default: []].append(Date())
            save()
        }

        public mutating func record(id: String, value: [String: String]) {
            donations[id, default: []].append(Tips.Event<EmptyDonation>.Donation(value: value, date: Date()))
            save()
        }

        public mutating func delete(id: String) {
            donations[id] = nil
            save()
        }

        /// The ids of every tip the store has been told about that belongs to one of the given
        /// kinds, which is what the framework's type-taking test helpers filter over.
        public func tipIDs(of kinds: [any Tip.Type]) -> [String] {
            return self.kinds.filter { wanted in kinds.contains { String(describing: $0) == wanted.value } }.keys.sorted()
        }

        public mutating func invalidate(_ tipID: String, of kind: String, reason: Tips.InvalidationReason) {
            kinds[tipID] = kind
            invalidate(tipID, reason: reason)
        }

        public mutating func invalidate(_ tipID: String, reason: Tips.InvalidationReason) {
            invalidated[tipID] = reason
            save()
        }

        public mutating func reset(_ tipID: String) {
            invalidated[tipID] = nil
            shown[tipID] = nil
            save()
        }

        /// Put every tip back in the list, which is what a test starts from.
        public mutating func resetDatastore() {
            invalidated = [:]
            shown = [:]
            configured = false
            save()
        }

        /// The donations of the events, newest first, which is what a rule reads.
        public func input() -> CharonRuleInput {
            var all: [Tips.Event<EmptyDonation>.Donation] = []
            for (_, entries) in donations.sorted(by: { $0.key < $1.key }) {
                all.append(contentsOf: entries.sorted { $0.date > $1.date })
            }
            return CharonRuleInput(donations: all)
        }

        /// Where the datastore reads and writes, which a caller may move.
        public func move(to url: URL) {}

        /// The values one donation carries, written as the strings the store keeps.
        public static func values<DonationInfo>(of donation: DonationInfo) -> [String: String] {
            return Store.mirror(donation)
        }

        /// The values a donation carries, read out of what the app sent it.
        static func mirror<DonationInfo>(_ donation: DonationInfo) -> [String: String] {
            let mirror = Mirror(reflecting: donation)
            var out: [String: String] = [:]
            for child in mirror.children where child.label != nil {
                out[child.label!] = String(describing: child.value)
            }
            return out
        }

        /// Read the store back from the file the app owns.
        public mutating func load() {
            guard let data = FileManager.default.contents(atPath: defaultURL.path),
                  let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let entry = propertyList as? [String: Any] else { return }
            invalidated = (entry["invalidated"] as? [String: String] ?? [:]).reduce(into: [:]) {
                $0[$1.key] = Tips.InvalidationReason(rawCharonValue: $1.value)
            }
        }

        /// Write the store into the file the app owns.
        public mutating func save() {
            let entry: [String: Any] = ["invalidated": invalidated.reduce(into: [String: String]()) {
                $0[$1.key] = $1.value.rawCharonValue
            }]
            guard let data = try? PropertyListSerialization.data(fromPropertyList: entry, format: .xml, options: 0) else {
                return
            }
            try? data.write(to: defaultURL)
        }
    }

    /// The rule's input: every donation the app has sent, newest first.
    public struct CharonRuleInput: RuleInput {
        public let donations: [Tips.Event<EmptyDonation>.Donation]
    }
}

extension Tips.InvalidationReason {
    /// The value the datastore writes, which is the case's own name.
    public var rawCharonValue: String {
        switch self {
        case .actionPerformed: return "actionPerformed"
        case .displayCountExceeded: return "displayCountExceeded"
        case .displayDurationExceeded: return "displayDurationExceeded"
        case .tipClosed: return "tipClosed"
        }
    }

    /// The value read back out of the datastore.
    public init?(rawCharonValue: String) {
        switch rawCharonValue {
        case "actionPerformed": self = .actionPerformed
        case "displayCountExceeded": self = .displayCountExceeded
        case "displayDurationExceeded": self = .displayDurationExceeded
        case "tipClosed": self = .tipClosed
        default: return nil
        }
    }
}

/// The stream of a tip's status, which the datastore answers with the one value it holds.
extension Tips {
    static func statusStream(for id: String) -> AsyncStream<Tips.Status> {
        let status: Tips.Status
        if let reason = Store.shared.invalidated[id] { status = .invalidated(reason) } else { status = .available }
        return AsyncStream { continuation in
            continuation.yield(status)
            continuation.finish()
        }
    }
}

/// Reading a tip's rules, and its options, over the store.
enum CharonTipRules {
    /// Whether every rule of a tip holds. A tip with no rules is shown when its options allow.
    static func hold(_ rules: [Tips.Rule], store: Tips.Store) -> Bool {
        guard !rules.isEmpty else { return true }
        let input = store.input()
        return rules.allSatisfy { $0.condition.evaluate(input) }
    }

    /// Whether a tip's options let it be shown again: the count and the duration it was given.
    static func withinOptions(_ tip: AnyTip, store: Tips.Store) -> Bool {
        let shown = store.shown[tip.id] ?? []
        for option in tip.options {
            if let count = option as? Tips.MaxDisplayCount, shown.count >= count.count { return false }
            if let duration = option as? Tips.MaxDisplayDuration,
               let first = shown.first, Date().timeIntervalSince(first) >= duration.duration { return false }
        }
        return true
    }
}

extension Tips {
    /// The app's own configuration of its tips, which the datastore answers with from then on.
    ///
    /// The datastore is one file in the app's own container, so the app configures it once: a second
    /// call would drop the configuration the first one set, and throws
    /// `TipKitError.tipsDatastoreAlreadyConfigured` instead.
    public static func configure(_ configuration: [ConfigurationOption] = []) throws {
        if Store.shared.configured { throw TipKitError.tipsDatastoreAlreadyConfigured }
        var store = Store.shared
        store.configure(configuration)
        Store.shared = store
    }

    /// Put the given tips back in the list, which is what a test starts from.
    /// The framework takes *types* (`TipKit-ios.swiftinterface:1003`), so a test writes
    /// `showTipsForTesting([MyTip.self])` and every tip of that kind comes back, not the one instance
    /// the caller happened to hold.
    public static func showTipsForTesting(_ tips: [any Tip.Type]) {
        for id in Store.shared.tipIDs(of: tips) { Store.shared.restore(id) }
    }

    /// Take every tip of the given kinds off the list, which is what a test walks through.
    public static func hideTipsForTesting(_ tips: [any Tip.Type]) {
        for id in Store.shared.tipIDs(of: tips) { Store.shared.invalidate(id, reason: .tipClosed) }
    }

    /// Take every tip the app has registered off the list.
    public static func hideAllTipsForTesting() {
        Store.shared.invalidateAll()
    }

    /// Put everything the datastore holds back as it was, which is what a test ends with.
    public static func resetDatastore() {
        Store.shared.resetDatastore()
    }
}

extension Tips.Store {
    /// What the app's configuration says, applied to the store.
    public mutating func configure(_ options: [Tips.ConfigurationOption]) {
        for option in options {
            if let frequency = option.value as? Tips.ConfigurationOption.DisplayFrequency {
                displayFrequency = frequency
            } else if let container = option.value as? Tips.ConfigurationOption.CloudKitContainer {
                cloudKitContainer = container
            }
        }
        configured = true
    }

    /// Put one tip back in the list.
    public mutating func restore(_ tipID: String) {
        reset(tipID)
    }

    /// Put every tip back in the list.
    public mutating func restoreAll() {
        for tipID in shown.keys { reset(tipID) }
        for tipID in invalidated.keys { reset(tipID) }
    }

    /// Take every tip off the list.
    public mutating func invalidateAll() {
        for tipID in shown.keys { invalidate(tipID, reason: .tipClosed) }
    }
}
