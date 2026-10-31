import Foundation

#if REVENANT_APPINTENTS_CORESPOTLIGHT
import CoreSpotlight

extension CSSearchableIndex {
    public func indexAppEntities(_ appEntities: [some IndexedEntity], priority: Int = 0) async throws {
        var written = [CSSearchableItem]()
        for entity in appEntities {
            written.append(CSSearchableItem(appEntity: entity, priority: priority))
        }
        guard !written.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            indexSearchableItems(written) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func deleteAppEntities<Entity>(ofType entityType: Entity.Type) async throws where Entity: IndexedEntity {
        let identifiers = RevenantSpotlightIndex.recordedIdentifiers(ofType: RevenantSpotlightIndex.contentType(of: Entity.self))
        try await delete(identifiers: identifiers)
    }

    public func deleteAppEntities<Entity>(identifiedBy identifiers: [Entity.ID],
                                            ofType type: Entity.Type) async throws where Entity: IndexedEntity {
        let wanted: [String] = identifiers.map { $0.entityIdentifierString }
        let recorded = RevenantSpotlightIndex.recordedIdentifiers(ofType: RevenantSpotlightIndex.contentType(of: Entity.self))
        try await delete(identifiers: wanted.filter { recorded.contains($0) })
    }

    private func delete(identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            deleteSearchableItems(withIdentifiers: identifiers) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

extension CSSearchableItem {
    public convenience init(appEntity: some IndexedEntity) {
        self.init(appEntity: appEntity, priority: 0)
    }

    public convenience init<Entity>(appEntity: Entity, priority: Int) where Entity: IndexedEntity {
        let attributes = CSSearchableItemAttributeSet(itemContentType: RevenantSpotlightIndex.contentType(of: Entity.self))
        attributes.associateAppEntity(appEntity, priority: priority)
        self.init(uniqueIdentifier: appEntity.id.entityIdentifierString,
                  domainIdentifier: RevenantSpotlightIndex.domain,
                  attributeSet: attributes)
    }

    public func associateAppEntity(_ appEntity: some IndexedEntity, priority: Int = 0) {
        attributeSet.associateAppEntity(appEntity, priority: priority)
    }
}

extension CSSearchableItemAttributeSet {
    public func associateAppEntity<Entity>(_ appEntity: Entity, priority: Int = 0) where Entity: IndexedEntity {
        title = RevenantLocalized.string(of: appEntity.displayRepresentation.title)
        contentDescription = appEntity.displayRepresentation.subtitle.map { RevenantLocalized.string(of: $0) }
        keywords = appEntity.displayRepresentation.synonyms.map { RevenantLocalized.string(of: $0) }
        setValue(appEntity.id.entityIdentifierString, forKey: RevenantAppEntityIdentifierAttribute)
    }

    public var appEntityIdentifier: String? {
        return value(forKey: RevenantAppEntityIdentifierAttribute) as? String
    }
}

public enum RevenantSpotlightIndex {
    public static var domain: String {
        return Bundle.main.bundleIdentifier ?? "revenant.appintents"
    }

    public static func contentType(of entityType: any Any.Type) -> String {
        return String(describing: entityType)
    }

    public static func identifier<Identifier>(for identifier: Identifier) -> String {
        return String(describing: identifier)
    }

    public static func recordedIdentifiers(ofType contentType: String) -> [String] {
        return RevenantSpotlightStore.records().filter { $0.contentType == contentType }.map { $0.identifier }
    }
}

public struct RevenantSpotlightRecord {
    public let identifier: String
    public let domain: String
    public let contentType: String
    public let appEntityIdentifier: String?

    public init(identifier: String, domain: String, contentType: String, appEntityIdentifier: String?) {
        self.identifier = identifier
        self.domain = domain
        self.contentType = contentType
        self.appEntityIdentifier = appEntityIdentifier
    }
}

public enum RevenantSpotlightStore {
    public static func records() -> [RevenantSpotlightRecord] {
        return RevenantSpotlightJournal.records ?? []
    }
}

public enum RevenantSpotlightJournal {
    public static let root = "/var/mobile/Library/Caches/org.revenant.corespotlight"

    public static let entityIdentifierAttribute = "appEntityIdentifier"

    public static var records: [RevenantSpotlightRecord]? {
        guard FileManager.default.fileExists(atPath: root) else { return nil }
        let paths = (try? FileManager.default.subpathsOfDirectory(atPath: root)) ?? []
        var records = [RevenantSpotlightRecord]()
        for path in paths where path.hasSuffix(".plist") {
            let full = (root as NSString).appendingPathComponent(path)
            guard let data = FileManager.default.contents(atPath: full),
                  let propertyList = try? PropertyListSerialization.propertyList(from: data, options: 0, format: nil),
                  let entries = propertyList as? [String: Any] else { continue }
            for (identifier, entry) in entries {
                guard let archive = entry as? [String: Any] else { continue }
                let attributes = archive["attributeSet"] as? [String: Any]
                records.append(RevenantSpotlightRecord(identifier: identifier,
                                                     domain: archive["domainIdentifier"] as? String
                                                         ?? RevenantSpotlightIndex.domain,
                                                     contentType: attributes?["contentType"] as? String ?? "",
                                                     appEntityIdentifier: attributes?[entityIdentifierAttribute] as? String))
            }
        }
        return records
    }
}

public let RevenantAppEntityIdentifierAttribute = RevenantSpotlightJournal.entityIdentifierAttribute
#endif

@available(iOS 8.0, *)
extension NSUserActivity {
    public var appEntityIdentifier: String? {
        get {
            return userInfo?[RevenantAppEntityIdentifierKey] as? String
        }
        set {
            var info = userInfo ?? [:]
            info[RevenantAppEntityIdentifierKey] = newValue
            userInfo = info
        }
    }
}

public let RevenantAppEntityIdentifierKey = "AppIntentsEntityIdentifier"
