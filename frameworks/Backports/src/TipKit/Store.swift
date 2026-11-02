import Foundation

extension Tips {
    public struct ConfigurationOption: Sendable {
        public struct CloudKitContainer: Equatable, Sendable {
            public static var automatic: CloudKitContainer { return CloudKitContainer(name: "") }

            let name: String

            private init(name: String) { self.name = name }

            public static func named(_ name: String) -> CloudKitContainer { return CloudKitContainer(name: name) }

            public static func == (a: CloudKitContainer, b: CloudKitContainer) -> Bool { return a.name == b.name }
        }

        public struct DatastoreLocation: Equatable, Sendable {
            public static var applicationDefault: DatastoreLocation {
                return DatastoreLocation(Tips.Store.shared.defaultURL.path)
            }

            let path: String

            private init(_ path: String) { self.path = path }

            public static func groupContainer(identifier: String) -> DatastoreLocation {
                return DatastoreLocation(identifier)
            }

            public static func url(_ url: URL) -> DatastoreLocation { return DatastoreLocation(url.path) }

            public static func == (a: DatastoreLocation, b: DatastoreLocation) -> Bool { return a.path == b.path }
        }

        public struct DisplayFrequency: Equatable, Sendable {
            let seconds: TimeInterval

            private init(_ seconds: TimeInterval) { self.seconds = seconds }

            public static var immediate: DisplayFrequency { return DisplayFrequency(0) }
            public static var hourly: DisplayFrequency { return DisplayFrequency(3600) }
            public static var daily: DisplayFrequency { return DisplayFrequency(86400) }
            public static var weekly: DisplayFrequency { return DisplayFrequency(604800) }
            public static var monthly: DisplayFrequency { return DisplayFrequency(2592000) }

            public static func == (a: DisplayFrequency, b: DisplayFrequency) -> Bool { return a.seconds == b.seconds }
        }

        public static func cloudKitContainer(_ container: CloudKitContainer) -> ConfigurationOption {
            return ConfigurationOption(container)
        }

        public static func datastoreLocation(_ location: DatastoreLocation) -> ConfigurationOption {
            return ConfigurationOption(location)
        }

        public static func displayFrequency(_ frequency: DisplayFrequency) -> ConfigurationOption {
            return ConfigurationOption(frequency)
        }

        let value: Any

        init(_ value: Any) { self.value = value }
    }

    public struct Store {
        public private(set) var donations: [String: [Tips.Event<EmptyDonation>.Donation]] = [:]
        public private(set) var shown: [String: [Date]] = [:]
        public private(set) var invalidated: [String: Tips.InvalidationReason] = [:]
        public var displayFrequency: ConfigurationOption.DisplayFrequency = .immediate
        public var cloudKitContainer: ConfigurationOption.CloudKitContainer?
        public private(set) var configured = false
        public private(set) var kinds: [String: String] = [:]

        public let defaultURL: URL

        public static var shared = Store()

        public init() {
            let support = (NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first
                           ?? NSTemporaryDirectory())
            let folder = (support as NSString).appendingPathComponent("revenant-tipkit")
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            self.defaultURL = URL(fileURLWithPath: folder).appendingPathComponent("tips.plist")
            load()
        }
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

        public func shouldDisplay(_ tip: AnyTip) -> Bool {
            if invalidated[tip.id] != nil { return false }
            if RevenantTipRules.hold(tip.rules, store: self) == false { return false }
            if let last = shown[tip.id]?.last, tip.options.contains(where: { $0 is Tips.IgnoresDisplayFrequency }) == false {
                let elapsed = Date().timeIntervalSince(last)
                if elapsed < displayFrequency.seconds { return false }
            }
            return RevenantTipRules.withinOptions(tip, store: self)
        }

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

        public mutating func resetDatastore() {
            invalidated = [:]
            shown = [:]
            configured = false
            save()
        }

        public func input() -> RevenantRuleInput {
            var all: [Tips.Event<EmptyDonation>.Donation] = []
            for (_, entries) in donations.sorted(by: { $0.key < $1.key }) {
                all.append(contentsOf: entries.sorted { $0.date > $1.date })
            }
            return RevenantRuleInput(donations: all)
        }

        public func move(to url: URL) {}

        public static func values<DonationInfo>(of donation: DonationInfo) -> [String: String] {
            return Store.mirror(donation)
        }

        static func mirror<DonationInfo>(_ donation: DonationInfo) -> [String: String] {
            let mirror = Mirror(reflecting: donation)
            var out: [String: String] = [:]
            for child in mirror.children where child.label != nil {
                out[child.label!] = String(describing: child.value)
            }
            return out
        }

        public mutating func load() {
            guard let data = FileManager.default.contents(atPath: defaultURL.path),
                  let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let entry = propertyList as? [String: Any] else { return }
            invalidated = (entry["invalidated"] as? [String: String] ?? [:]).reduce(into: [:]) {
                $0[$1.key] = Tips.InvalidationReason(rawRevenantValue: $1.value)
            }
        }

        public mutating func save() {
            let entry: [String: Any] = ["invalidated": invalidated.reduce(into: [String: String]()) {
                $0[$1.key] = $1.value.rawRevenantValue
            }]
            guard let data = try? PropertyListSerialization.data(fromPropertyList: entry, format: .xml, options: 0) else {
                return
            }
            try? data.write(to: defaultURL)
        }
    }

    public struct RevenantRuleInput: RuleInput {
        public let donations: [Tips.Event<EmptyDonation>.Donation]
    }
}

extension Tips.InvalidationReason {
    public var rawRevenantValue: String {
        switch self {
        case .actionPerformed: return "actionPerformed"
        case .displayCountExceeded: return "displayCountExceeded"
        case .displayDurationExceeded: return "displayDurationExceeded"
        case .tipClosed: return "tipClosed"
        }
    }

    public init?(rawRevenantValue: String) {
        switch rawRevenantValue {
        case "actionPerformed": self = .actionPerformed
        case "displayCountExceeded": self = .displayCountExceeded
        case "displayDurationExceeded": self = .displayDurationExceeded
        case "tipClosed": self = .tipClosed
        default: return nil
        }
    }
}

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

enum RevenantTipRules {
    static func hold(_ rules: [Tips.Rule], store: Tips.Store) -> Bool {
        guard !rules.isEmpty else { return true }
        let input = store.input()
        return rules.allSatisfy { $0.condition.evaluate(input) }
    }

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
    public static func configure(_ configuration: [ConfigurationOption] = []) throws {
        if Store.shared.configured { throw TipKitError.tipsDatastoreAlreadyConfigured }
        var store = Store.shared
        store.configure(configuration)
        Store.shared = store
    }

    public static func showTipsForTesting(_ tips: [any Tip.Type]) {
        for id in Store.shared.tipIDs(of: tips) { Store.shared.restore(id) }
    }

    public static func hideTipsForTesting(_ tips: [any Tip.Type]) {
        for id in Store.shared.tipIDs(of: tips) { Store.shared.invalidate(id, reason: .tipClosed) }
    }

    public static func hideAllTipsForTesting() {
        Store.shared.invalidateAll()
    }

    public static func resetDatastore() {
        Store.shared.resetDatastore()
    }
}

extension Tips.Store {
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

    public mutating func restore(_ tipID: String) {
        reset(tipID)
    }

    public mutating func restoreAll() {
        for tipID in shown.keys { reset(tipID) }
        for tipID in invalidated.keys { reset(tipID) }
    }

    public mutating func invalidateAll() {
        for tipID in shown.keys { invalidate(tipID, reason: .tipClosed) }
    }
}
