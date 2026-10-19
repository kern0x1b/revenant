// What AppIntents adds to the three CoreSpotlight classes, and to a resumed activity.
//
// The three classes are the CoreSpotlight backports' own (`registry/CoreSpotlight/ios9.json`, all
// three `implemented`): the release runs no Spotlight index, and the port keeps the journal itself and
// bridges it to the release's own `SPSpotlightManager`. What AppIntents adds is the association
// between an index entry and the app entity behind it, so that a search result names the entity and a
// caller can find it again.
//
// The classes are marked iOS 9 in the SDK's headers, written `CS_CLASS_AVAILABLE(10_13, 9_0)`. The
// port's CoreSpotlight headers come from the generator (tools/gen/target_availability.lua), which lowers
// the marks of what the CoreSpotlight registry carries as implemented; the package compiles this file
// only when a probe finds the three classes at its deployment (packages/a/appintents/xmake.lua). When it
// does not, this file is left out of the module and the rows it holds read `missing` in the ledger.
// `facts/AppIntents/Spotlight.md`.

import Foundation

#if CHARON_APPINTENTS_CORESPOTLIGHT
import CoreSpotlight

extension CSSearchableIndex {
    /// Write the app's entities into the index, with the priority the caller names. The index is the
    /// port's own: `indexSearchableItems` writes the entry into the store the CoreSpotlight
    /// backports keep, which is what a later search reads.
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

    /// Remove the entries of the app's entities of one type, which is what the framework's own
    /// delete does with the entities the app registered.
    public func deleteAppEntities<Entity>(ofType entityType: Entity.Type) async throws where Entity: IndexedEntity {
        let identifiers = CharonSpotlightIndex.recordedIdentifiers(ofType: CharonSpotlightIndex.contentType(of: Entity.self))
        try await delete(identifiers: identifiers)
    }

    /// Remove the entries the identifiers name, of one type of entity.
    public func deleteAppEntities<Entity>(identifiedBy identifiers: [Entity.ID],
                                            ofType type: Entity.Type) async throws where Entity: IndexedEntity {
        let wanted: [String] = identifiers.map { $0.entityIdentifierString }
        let recorded = CharonSpotlightIndex.recordedIdentifiers(ofType: CharonSpotlightIndex.contentType(of: Entity.self))
        try await delete(identifiers: wanted.filter { recorded.contains($0) })
    }

    /// The one delete both of the framework's own spellings goes through: the index removes the
    /// entries whose identifiers are named, and the store the port keeps is what a later search reads.
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
    /// An index entry that names the app entity behind it, so that a result found by searching can
    /// be given back to the app as that entity.
    public convenience init(appEntity: some IndexedEntity) {
        self.init(appEntity: appEntity, priority: 0)
    }

    /// An index entry that names the app entity behind it, with the priority the caller names.
    public convenience init<Entity>(appEntity: Entity, priority: Int) where Entity: IndexedEntity {
        let attributes = CSSearchableItemAttributeSet(itemContentType: CharonSpotlightIndex.contentType(of: Entity.self))
        attributes.associateAppEntity(appEntity, priority: priority)
        self.init(uniqueIdentifier: appEntity.id.entityIdentifierString,
                  domainIdentifier: CharonSpotlightIndex.domain,
                  attributeSet: attributes)
    }

    /// Name the app entity this entry stands for, which is what a search result carries when it
    /// opens the app that owns it.
    public func associateAppEntity(_ appEntity: some IndexedEntity, priority: Int = 0) {
        attributeSet.associateAppEntity(appEntity, priority: priority)
    }
}

extension CSSearchableItemAttributeSet {
    /// Name the app entity this record stands for, which is what the framework's own search result
    /// reads to open the app that owns it. The content type is the one the port's index reads the
    /// record back by, and the title and description are the entity's own display representation.
    public func associateAppEntity<Entity>(_ appEntity: Entity, priority: Int = 0) where Entity: IndexedEntity {
        // the record's own fields are text, and a display representation holds resources: what the
        // framework shows for a title is what the table has for it, or the default value the app wrote
        title = CharonLocalized.string(of: appEntity.displayRepresentation.title)
        contentDescription = appEntity.displayRepresentation.subtitle.map { CharonLocalized.string(of: $0) }
        keywords = appEntity.displayRepresentation.synonyms.map { CharonLocalized.string(of: $0) }
        setValue(appEntity.id.entityIdentifierString, forKey: CharonAppEntityIdentifierAttribute)
    }

    /// The attribute the record carries its app entity's identifier under, which is the key the
    /// framework's own search result reads it from and the one a later search reads the journal by.
    public var appEntityIdentifier: String? {
        return value(forKey: CharonAppEntityIdentifierAttribute) as? String
    }
}

/// The names the module's own index writes and reads: the content type of an entity, the domain its
/// entries live under, and the identifiers the store holds for one type. They are the strings
/// `CSSearchableItem`'s own initialiser takes, and the store is the one the CoreSpotlight backports
/// keep - with none, a delete removes nothing, which is what an index that holds nothing does.
public enum CharonSpotlightIndex {
    /// The domain every entry of an app entity is written under, which is the app's bundle identifier.
    public static var domain: String {
        return Bundle.main.bundleIdentifier ?? "charon.appintents"
    }

    /// The content type of a type of entity, which is the name of the type.
    public static func contentType(of entityType: any Any.Type) -> String {
        return String(describing: entityType)
    }

    /// The identifier an entity's own identifier is written as in an index entry.
    public static func identifier<Identifier>(for identifier: Identifier) -> String {
        return String(describing: identifier)
    }

    /// The identifiers the store holds for one content type, which is what a delete of every entity
    /// of that type needs. A record with no identifier of its own is not one this module wrote, and
    /// a delete of it is not this module's business.
    public static func recordedIdentifiers(ofType contentType: String) -> [String] {
        return CharonSpotlightStore.records().filter { $0.contentType == contentType }.map { $0.identifier }
    }
}

/// One record of the store the CoreSpotlight backports keep: what was indexed, and for which app
/// entity. It is the journal's own plist entry, read through the files the backports wrote, so the
/// AppIntents side names no private class and no private selector.
public struct CharonSpotlightRecord {
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

/// Reading the store the CoreSpotlight backports keep.
public enum CharonSpotlightStore {
    /// The records the store holds, or none when the program carries no CoreSpotlight backports:
    /// there is no index then, and a delete of it removes nothing.
    public static func records() -> [CharonSpotlightRecord] {
        return CharonSpotlightJournal.records ?? []
    }
}

/// The journal the CoreSpotlight backports keep: one directory per indexing application under
/// `/var/mobile/Library/Caches/org.charon.corespotlight` (their `CharonSpotlightStore.h` names the
/// root), each directory holding plists whose `entries` map an identifier to a keyed archive of a
/// `CSSearchableItem`. Reading it is the AppIntents side's own business, over the files the backports
/// wrote.
public enum CharonSpotlightJournal {
    /// The root the CoreSpotlight backports keep their store under, from their own header.
    public static let root = "/var/mobile/Library/Caches/org.charon.corespotlight"

    /// The attribute a record carries its app entity's identifier under, which is the key the
    /// framework's own search result reads it from.
    public static let entityIdentifierAttribute = "appEntityIdentifier"

    /// Every record the store holds, or nothing when the store is not there: with no CoreSpotlight
    /// backports there is no index, and a delete of one removes nothing.
    public static var records: [CharonSpotlightRecord]? {
        guard FileManager.default.fileExists(atPath: root) else { return nil }
        let paths = (try? FileManager.default.subpathsOfDirectory(atPath: root)) ?? []
        var records = [CharonSpotlightRecord]()
        for path in paths where path.hasSuffix(".plist") {
            let full = (root as NSString).appendingPathComponent(path)
            guard let data = FileManager.default.contents(atPath: full),
                  let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let entries = propertyList as? [String: Any] else { continue }
            for (identifier, entry) in entries {
                guard let archive = entry as? [String: Any] else { continue }
                let attributes = archive["attributeSet"] as? [String: Any]
                records.append(CharonSpotlightRecord(identifier: identifier,
                                                     domain: archive["domainIdentifier"] as? String
                                                         ?? CharonSpotlightIndex.domain,
                                                     contentType: attributes?["contentType"] as? String ?? "",
                                                     appEntityIdentifier: attributes?[entityIdentifierAttribute] as? String))
            }
        }
        return records
    }
}

/// The attribute the module writes an entity's identifier under, which is the journal's own key.
public let CharonAppEntityIdentifierAttribute = CharonSpotlightJournal.entityIdentifierAttribute
#endif

// MARK: - A resumed activity

#if CHARON_APPINTENTS_PORT_HEADERS
/// What an activity carries into an app: the intent it is for, and the entity it is about.
///
/// `NSUserActivity` arrived in iOS 8 and the Foundation backports carry it, so an activity is a real
/// object on this release. The two members here are the framework's own AppIntents extension on it,
/// and they are compiled only where the runtime the module is built against hands over the port's
/// headers - with a runtime built without the backports there is no `NSUserActivity` on the release at
/// all, and the rows read `missing` rather than being declared against a class that is not there.
@available(iOS 8.0, *)
extension NSUserActivity {
    // `NSUserActivity.intent` is iOS 12. The lifted headers do not carry it (measured: the module's
    // typecheck reads `cannot find 'intent' in scope` against them), so the member is compiled only
    // where a runtime carries the property, and is left out of the module otherwise.
#if CHARON_APPINTENTS_NSUSERACTIVITY_INTENT
    /// The widget configuration this activity configures, read back from the activity's own intent.
    public func widgetConfigurationIntent<Intent>(of intentType: Intent.Type = Intent.self) -> Intent?
        where Intent: WidgetConfigurationIntent {
        return intent as? Intent
    }
#endif

    /// The app entity this activity is about, which is what a widget hands the app it opens.
    public var appEntityIdentifier: String? {
        return userInfo?[CharonAppEntityIdentifierKey] as? String
    }
}

/// The key an activity's entity identifier is carried under, which is the framework's own
/// `NSUserActivity` user-info key for it.
public let CharonAppEntityIdentifierKey = "AppIntentsEntityIdentifier"
#endif
