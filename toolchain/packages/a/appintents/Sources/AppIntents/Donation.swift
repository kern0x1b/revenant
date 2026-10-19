import Foundation

public struct IntentDonationIdentifier: Hashable, Codable, Sendable {
    public let identifier: String
    public let intentType: String
    public let entityIdentifiers: [String]

    public init(identifier: String = UUID().uuidString, intentType: String = "",
                entityIdentifiers: [String] = []) {
        self.identifier = identifier
        self.intentType = intentType
        self.entityIdentifiers = entityIdentifiers
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.intentType = try container.decode(String.self, forKey: .intentType)
        self.entityIdentifiers = try container.decodeIfPresent([String].self, forKey: .entityIdentifiers) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(intentType, forKey: .intentType)
        try container.encode(entityIdentifiers, forKey: .entityIdentifiers)
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case intentType
        case entityIdentifiers
    }

    public static func == (a: IntentDonationIdentifier, b: IntentDonationIdentifier) -> Bool {
        return a.identifier == b.identifier && a.intentType == b.intentType
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(intentType)
    }
}

public struct IntentDonationMatchingPredicate {
    enum Kind {
        case donationIdentifier(IntentDonationIdentifier)
        case entityIdentifier(EntityIdentifier)
        case intentType(String, EntityIdentifier?)
    }

    let kind: Kind

    public static func donationIdentifier(_ identifier: IntentDonationIdentifier) -> IntentDonationMatchingPredicate {
        return IntentDonationMatchingPredicate(kind: .donationIdentifier(identifier))
    }

    public static func entityIdentifier(_ identifier: EntityIdentifier) -> IntentDonationMatchingPredicate {
        return IntentDonationMatchingPredicate(kind: .entityIdentifier(identifier))
    }

    public static func intentType(_ intentType: String,
                                  entityIdentifier: EntityIdentifier? = nil) -> IntentDonationMatchingPredicate {
        return IntentDonationMatchingPredicate(kind: .intentType(intentType, entityIdentifier))
    }
}

public struct IntentDonation: Codable, Sendable {
    public let identifier: IntentDonationIdentifier
    public let timestamp: Date
    public let value: String?

    public init(identifier: IntentDonationIdentifier, timestamp: Date, value: String?) {
        self.identifier = identifier
        self.timestamp = timestamp
        self.value = value
    }
}

public struct IntentDonationManager {
    public static let shared = IntentDonationManager()

    private let store: IntentDonationStore
    private let lock = NSLock()

    public init() {
        store = IntentDonationStore()
    }

    @discardableResult
    public func donate<Intent: AppIntent>(intent: Intent, result: some IntentResult) -> IntentDonationIdentifier {
        let identifier = IntentDonationIdentifier(intentType: Intent.persistentIdentifier)
        let value = RevenantIntentResultText.write(result)
        lock.lock()
        store.add(IntentDonation(identifier: identifier, timestamp: Date(), value: value))
        lock.unlock()
        return identifier
    }

    public func donations() -> [IntentDonation] {
        lock.lock()
        defer { lock.unlock() }
        return store.all()
    }

    public func deleteDonations(matching predicate: IntentDonationMatchingPredicate) {
        lock.lock()
        defer { lock.unlock() }
        switch predicate.kind {
        case .donationIdentifier(let wanted):
            store.remove(where: { $0.identifier == wanted })
        case .entityIdentifier(let wanted):
            store.remove(where: { $0.identifier.entityIdentifiers.contains(wanted.identifier) })
        case .intentType(let intentType, let entity):
            store.remove(where: { donation in
                guard donation.identifier.intentType == intentType else { return false }
                guard let entity = entity else { return true }
                return donation.identifier.entityIdentifiers.contains(entity.identifier)
            })
        }
    }
}

final class IntentDonationStore {
    private let path: String

    init() {
        let support = (NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first ?? NSTemporaryDirectory())
        let folder = (support as NSString).appendingPathComponent("revenant-appintents")
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        path = (folder as NSString).appendingPathComponent("donations.plist")
    }

    func all() -> [IntentDonation] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }
        guard let list = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { entry in
            guard let identifier = entry["identifier"] as? String,
                  let intentType = entry["intentType"] as? String else { return nil }
            return IntentDonation(identifier: IntentDonationIdentifier(identifier: identifier, intentType: intentType),
                                  timestamp: Date(timeIntervalSince1970: entry["timestamp"] as? Double ?? 0),
                                  value: entry["value"] as? String)
        }.sorted { $0.timestamp > $1.timestamp }
    }

    func add(_ donation: IntentDonation) {
        var list = all()
        list.insert(donation, at: 0)
        write(list)
    }

    func remove(where predicate: (IntentDonation) -> Bool) {
        write(all().filter { !predicate($0) })
    }

    private func write(_ list: [IntentDonation]) {
        let entries: [[String: Any]] = list.map { donation in
            return ["identifier": donation.identifier.identifier, "intentType": donation.identifier.intentType,
                    "timestamp": donation.timestamp.timeIntervalSince1970, "value": donation.value ?? ""]
        }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0) else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

enum RevenantIntentResultText {
    static func write(_ result: some IntentResult) -> String? {
        if let dialog = result as? IntentResultContainer<Never, Never, Never, IntentDialog> {
            return dialog.dialog.map { RevenantLocalized.string(of: $0.full) }
        }
        return nil
    }
}

public struct IntentPrediction<Intent: AppIntent, T>: IntentPredictionConfiguration, Copyable, Escapable {
    let parameters: T?
    let makeDisplayRepresentation: (() -> DisplayRepresentation)?

    var displayRepresentation: DisplayRepresentation? {
        return makeDisplayRepresentation?()
    }

    public init(displayRepresentation: @escaping () -> DisplayRepresentation) {
        self.parameters = nil
        self.makeDisplayRepresentation = displayRepresentation
    }
}

public struct TupleIntentPrediction<Intent: AppIntent, T>: IntentPredictionConfiguration, Copyable, Escapable {
}

protocol _DisplayedPrediction {
    var displayRepresentation: DisplayRepresentation? { get }
}

extension IntentPrediction {
    public init<V0, P0>(parameters: T, displayRepresentation: @escaping (V0) -> DisplayRepresentation) where Intent: AppIntent, T == KeyPath<Intent, P0>, V0: _IntentValue, V0: Sendable, P0: IntentParameter<V0> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, P0, P1, K0, K1>(parameters: T, displayRepresentation: @escaping (V0, V1) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, P0, P1, P2, K0, K1, K2>(parameters: T, displayRepresentation: @escaping (V0, V1, V2) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, P0, P1, P2, P3, K0, K1, K2, K3>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, P0, P1, P2, P3, P4, K0, K1, K2, K3, K4>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, P0, P1, P2, P3, P4, P5, K0, K1, K2, K3, K4, K5>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, V6, P0, P1, P2, P3, P4, P5, P6, K0, K1, K2, K3, K4, K5, K6>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5, V6) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5, K6), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, V6: _IntentValue, V6: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, P6: IntentParameter<V6>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5>, K6: KeyPath<Intent, P6> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, V6, V7, P0, P1, P2, P3, P4, P5, P6, P7, K0, K1, K2, K3, K4, K5, K6, K7>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5, V6, V7) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5, K6, K7), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, V6: _IntentValue, V6: Sendable, V7: _IntentValue, V7: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, P6: IntentParameter<V6>, P7: IntentParameter<V7>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5>, K6: KeyPath<Intent, P6>, K7: KeyPath<Intent, P7> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, V6, V7, V8, P0, P1, P2, P3, P4, P5, P6, P7, P8, K0, K1, K2, K3, K4, K5, K6, K7, K8>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5, V6, V7, V8) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5, K6, K7, K8), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, V6: _IntentValue, V6: Sendable, V7: _IntentValue, V7: Sendable, V8: _IntentValue, V8: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, P6: IntentParameter<V6>, P7: IntentParameter<V7>, P8: IntentParameter<V8>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5>, K6: KeyPath<Intent, P6>, K7: KeyPath<Intent, P7>, K8: KeyPath<Intent, P8> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, P0, P1, P2, P3, P4, P5, P6, P7, P8, P9, K0, K1, K2, K3, K4, K5, K6, K7, K8, K9>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5, V6, V7, V8, V9) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5, K6, K7, K8, K9), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, V6: _IntentValue, V6: Sendable, V7: _IntentValue, V7: Sendable, V8: _IntentValue, V8: Sendable, V9: _IntentValue, V9: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, P6: IntentParameter<V6>, P7: IntentParameter<V7>, P8: IntentParameter<V8>, P9: IntentParameter<V9>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5>, K6: KeyPath<Intent, P6>, K7: KeyPath<Intent, P7>, K8: KeyPath<Intent, P8>, K9: KeyPath<Intent, P9> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, P0, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, V6: _IntentValue, V6: Sendable, V7: _IntentValue, V7: Sendable, V8: _IntentValue, V8: Sendable, V9: _IntentValue, V9: Sendable, V10: _IntentValue, V10: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, P6: IntentParameter<V6>, P7: IntentParameter<V7>, P8: IntentParameter<V8>, P9: IntentParameter<V9>, P10: IntentParameter<V10>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5>, K6: KeyPath<Intent, P6>, K7: KeyPath<Intent, P7>, K8: KeyPath<Intent, P8>, K9: KeyPath<Intent, P9>, K10: KeyPath<Intent, P10> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, P0, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K11>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K11), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, V6: _IntentValue, V6: Sendable, V7: _IntentValue, V7: Sendable, V8: _IntentValue, V8: Sendable, V9: _IntentValue, V9: Sendable, V10: _IntentValue, V10: Sendable, V11: _IntentValue, V11: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, P6: IntentParameter<V6>, P7: IntentParameter<V7>, P8: IntentParameter<V8>, P9: IntentParameter<V9>, P10: IntentParameter<V10>, P11: IntentParameter<V11>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5>, K6: KeyPath<Intent, P6>, K7: KeyPath<Intent, P7>, K8: KeyPath<Intent, P8>, K9: KeyPath<Intent, P9>, K10: KeyPath<Intent, P10>, K11: KeyPath<Intent, P11> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, P0, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K11, K12>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K11, K12), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, V6: _IntentValue, V6: Sendable, V7: _IntentValue, V7: Sendable, V8: _IntentValue, V8: Sendable, V9: _IntentValue, V9: Sendable, V10: _IntentValue, V10: Sendable, V11: _IntentValue, V11: Sendable, V12: _IntentValue, V12: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, P6: IntentParameter<V6>, P7: IntentParameter<V7>, P8: IntentParameter<V8>, P9: IntentParameter<V9>, P10: IntentParameter<V10>, P11: IntentParameter<V11>, P12: IntentParameter<V12>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5>, K6: KeyPath<Intent, P6>, K7: KeyPath<Intent, P7>, K8: KeyPath<Intent, P8>, K9: KeyPath<Intent, P9>, K10: KeyPath<Intent, P10>, K11: KeyPath<Intent, P11>, K12: KeyPath<Intent, P12> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, P0, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K11, K12, K13>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K11, K12, K13), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, V6: _IntentValue, V6: Sendable, V7: _IntentValue, V7: Sendable, V8: _IntentValue, V8: Sendable, V9: _IntentValue, V9: Sendable, V10: _IntentValue, V10: Sendable, V11: _IntentValue, V11: Sendable, V12: _IntentValue, V12: Sendable, V13: _IntentValue, V13: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, P6: IntentParameter<V6>, P7: IntentParameter<V7>, P8: IntentParameter<V8>, P9: IntentParameter<V9>, P10: IntentParameter<V10>, P11: IntentParameter<V11>, P12: IntentParameter<V12>, P13: IntentParameter<V13>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5>, K6: KeyPath<Intent, P6>, K7: KeyPath<Intent, P7>, K8: KeyPath<Intent, P8>, K9: KeyPath<Intent, P9>, K10: KeyPath<Intent, P10>, K11: KeyPath<Intent, P11>, K12: KeyPath<Intent, P12>, K13: KeyPath<Intent, P13> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }

    public init<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, P0, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K11, K12, K13, K14>(parameters: T, displayRepresentation: @escaping (V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14) -> DisplayRepresentation) where Intent: AppIntent, T == (K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K11, K12, K13, K14), V0: _IntentValue, V0: Sendable, V1: _IntentValue, V1: Sendable, V2: _IntentValue, V2: Sendable, V3: _IntentValue, V3: Sendable, V4: _IntentValue, V4: Sendable, V5: _IntentValue, V5: Sendable, V6: _IntentValue, V6: Sendable, V7: _IntentValue, V7: Sendable, V8: _IntentValue, V8: Sendable, V9: _IntentValue, V9: Sendable, V10: _IntentValue, V10: Sendable, V11: _IntentValue, V11: Sendable, V12: _IntentValue, V12: Sendable, V13: _IntentValue, V13: Sendable, V14: _IntentValue, V14: Sendable, P0: IntentParameter<V0>, P1: IntentParameter<V1>, P2: IntentParameter<V2>, P3: IntentParameter<V3>, P4: IntentParameter<V4>, P5: IntentParameter<V5>, P6: IntentParameter<V6>, P7: IntentParameter<V7>, P8: IntentParameter<V8>, P9: IntentParameter<V9>, P10: IntentParameter<V10>, P11: IntentParameter<V11>, P12: IntentParameter<V12>, P13: IntentParameter<V13>, P14: IntentParameter<V14>, K0: KeyPath<Intent, P0>, K1: KeyPath<Intent, P1>, K2: KeyPath<Intent, P2>, K3: KeyPath<Intent, P3>, K4: KeyPath<Intent, P4>, K5: KeyPath<Intent, P5>, K6: KeyPath<Intent, P6>, K7: KeyPath<Intent, P7>, K8: KeyPath<Intent, P8>, K9: KeyPath<Intent, P9>, K10: KeyPath<Intent, P10>, K11: KeyPath<Intent, P11>, K12: KeyPath<Intent, P12>, K13: KeyPath<Intent, P13>, K14: KeyPath<Intent, P14> {
        self.parameters = parameters
        self.makeDisplayRepresentation = nil
    }
}


extension IntentPrediction: _DisplayedPrediction {}

public protocol IntentPredictionConfiguration: Escapable, Copyable {
    associatedtype Intent
}

public protocol PredictableIntent: AppIntent {
    associatedtype Prediction

    static var predictionConfiguration: Self.Prediction { get }
}

@resultBuilder
public enum IntentPredictionsBuilder {}

extension IntentPredictionsBuilder {
    public static func buildExpression<S>(_ expression: S) -> S where S: IntentPredictionConfiguration { return expression }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration, _ a7: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6, a7] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration, _ a7: any IntentPredictionConfiguration, _ a8: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6, a7, a8] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration, _ a7: any IntentPredictionConfiguration, _ a8: any IntentPredictionConfiguration, _ a9: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6, a7, a8, a9] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration, _ a7: any IntentPredictionConfiguration, _ a8: any IntentPredictionConfiguration, _ a9: any IntentPredictionConfiguration, _ a10: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration, _ a7: any IntentPredictionConfiguration, _ a8: any IntentPredictionConfiguration, _ a9: any IntentPredictionConfiguration, _ a10: any IntentPredictionConfiguration, _ a11: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration, _ a7: any IntentPredictionConfiguration, _ a8: any IntentPredictionConfiguration, _ a9: any IntentPredictionConfiguration, _ a10: any IntentPredictionConfiguration, _ a11: any IntentPredictionConfiguration, _ a12: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration, _ a7: any IntentPredictionConfiguration, _ a8: any IntentPredictionConfiguration, _ a9: any IntentPredictionConfiguration, _ a10: any IntentPredictionConfiguration, _ a11: any IntentPredictionConfiguration, _ a12: any IntentPredictionConfiguration, _ a13: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration, _ a7: any IntentPredictionConfiguration, _ a8: any IntentPredictionConfiguration, _ a9: any IntentPredictionConfiguration, _ a10: any IntentPredictionConfiguration, _ a11: any IntentPredictionConfiguration, _ a12: any IntentPredictionConfiguration, _ a13: any IntentPredictionConfiguration, _ a14: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14] }

    public static func buildBlock(_ a1: any IntentPredictionConfiguration, _ a2: any IntentPredictionConfiguration, _ a3: any IntentPredictionConfiguration, _ a4: any IntentPredictionConfiguration, _ a5: any IntentPredictionConfiguration, _ a6: any IntentPredictionConfiguration, _ a7: any IntentPredictionConfiguration, _ a8: any IntentPredictionConfiguration, _ a9: any IntentPredictionConfiguration, _ a10: any IntentPredictionConfiguration, _ a11: any IntentPredictionConfiguration, _ a12: any IntentPredictionConfiguration, _ a13: any IntentPredictionConfiguration, _ a14: any IntentPredictionConfiguration, _ a15: any IntentPredictionConfiguration) -> [any IntentPredictionConfiguration] { return [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15] }

}

public struct RelevantIntent {
    public enum WidgetKind: Hashable {
        case accessoryCircular
        case accessoryCorner
        case accessoryInline
        case accessoryRectangular
        case systemLarge
        case systemMedium
        case systemSmall
    }

    public let intent: any IntentPredictionConfiguration
    public let relevance: Double
    public let widgetKind: WidgetKind

    public init(_ intent: any IntentPredictionConfiguration, widgetKind: WidgetKind, relevance: Double) {
        self.intent = intent
        self.widgetKind = widgetKind
        self.relevance = relevance
    }

    public var debugDescription: String { return "relevant: \(relevance)" }
}

public final class RelevantIntentManager {
    public static let shared = RelevantIntentManager()

    private let store = RelevantIntentStore()
    private let lock = NSLock()

    public init() {}

    public func updateRelevantIntents(_ intents: [RelevantIntent]) {
        lock.lock()
        defer { lock.unlock() }
        store.write(intents)
    }

    public func relevantIntents() -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return store.read()
    }
}

final class RelevantIntentStore {
    private let path: String

    init() {
        let support = (NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first ?? NSTemporaryDirectory())
        let folder = (support as NSString).appendingPathComponent("revenant-appintents")
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        path = (folder as NSString).appendingPathComponent("relevant-intents.plist")
    }

    func write(_ intents: [RelevantIntent]) {
        let entries: [[String: Any]] = intents.map { intent in
            return ["relevance": intent.relevance, "widgetKind": String(describing: intent.widgetKind),
                    "displayName": (intent.intent as? _DisplayedPrediction)?.displayRepresentation.map { RevenantLocalized.string(of: $0.title) } ?? ""]
        }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0) else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    func read() -> [[String: Any]] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]]) ?? []
    }
}
