// The store: an NSPersistentStoreCoordinator, the model made from a schema, and the history the
// store keeps of what was saved.

import Foundation
import CoreData
import FoundationEssentials
import FoundationInternationalization

public final class DefaultStore: DataStore, DataStoreBatching, @unchecked Sendable {
    public typealias Configuration = ModelConfiguration
    public typealias Snapshot = DefaultSnapshot
    public typealias HistoryType = DefaultHistoryTransaction
    public typealias TokenType = DefaultHistoryToken

    /// A CloudKit container is an NSPersistentContainer, so a store that names a CloudKit
    /// container is that subclass and one that names none is the base class. No release this port
    /// runs on has CloudKit, so nothing mirrors; the class is still what a store of this
    /// configuration is, and its identifier is what the configuration is asked for.
    public let name: String
    public let schema: Schema
    public let configuration: ModelConfiguration
    public let coordinator: NSPersistentStoreCoordinator
    public let container: NSPersistentContainer

    public var identifier: String { name }

    public convenience init(_ configuration: ModelConfiguration,
                            migrationPlan: (any SchemaMigrationPlan.Type)? = nil) throws {
        try self.init(configuration, migrationPlan: migrationPlan, schema: configuration.schema ?? Schema())
    }

    public init(_ configuration: ModelConfiguration, migrationPlan: (any SchemaMigrationPlan.Type)?,
                schema: Schema) throws {
        self.configuration = configuration
        self.schema = schema
        self.name = configuration.name
        let model = try DefaultStore.model(from: schema)
        if configuration.cloudKitContainerIdentifier != nil {
            self.container = NSPersistentCloudKitContainer(name: configuration.name, managedObjectModel: model)
        } else {
            self.container = NSPersistentContainer(name: configuration.name, managedObjectModel: model)
        }
        self.coordinator = container.persistentStoreCoordinator
        let description = NSPersistentStoreDescription(url: configuration.url)
        description.type = configuration.isStoredInMemoryOnly ? NSInMemoryStoreType : NSSQLiteStoreType
        // A store that keeps history says so with the key the release reads, and the history
        // tracking itself is a backport (registry/CoreData/ios11.json); without it the release
        // ignores the option and the store answers every history fetch with nothing.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        try container.loadPersistentStores(completionHandler: { _, error in
            if let error { DefaultStore.lastLoadError = error }
        })
        if let error = DefaultStore.lastLoadError {
            DefaultStore.lastLoadError = nil
            throw error
        }
        if let migrationPlan, let last = migrationPlan.schemas.last {
            try migrate(from: last, to: schema, plan: migrationPlan)
        }
    }

    /// What `loadPersistentStores` hands back, which arrives after the closure has run.
    private static var lastLoadError: Error?

    /// The Core Data model a schema describes: one entity per schema entity, one property per
    /// schema property, and the indexes the schema names. A relationship's far end is filled in
    /// after every entity exists, because Core Data needs both ends to point at something.
    static func model(from schema: Schema) throws -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        var entities = [NSEntityDescription]()
        for schemaEntity in schema.entities {
            let entity = NSEntityDescription()
            entity.name = schemaEntity.name
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
            var properties = [NSPropertyDescription]()
            for property in schemaEntity.storedProperties {
                if let relationship = property as? Schema.Relationship {
                    let description = NSRelationshipDescription()
                    description.name = relationship.name
                    description.deleteRule = DefaultStore.deleteRule(of: relationship.deleteRule)
                    if let minimum = relationship.minimumModelCount { description.minCount = minimum }
                    if let maximum = relationship.maximumModelCount { description.maxCount = maximum }
                    properties.append(description)
                } else if let attribute = property as? Schema.Attribute {
                    properties.append(DefaultStore.attribute(from: attribute))
                }
            }
            entity.properties = properties
            entities.append(entity)
        }
        model.entities = entities
        // The far ends, now that every entity has a description to point at.
        for (index, schemaEntity) in schema.entities.enumerated() {
            for property in schemaEntity.relationships {
                guard let relationship = property as? Schema.Relationship,
                      let description = entities[index].relationshipsByName[relationship.name]
                else { continue }
                description.destinationEntity = entities.first { $0.name == relationship.destination }
                    ?? entities[index]
            }
        }
        for (index, schemaEntity) in schema.entities.enumerated() {
            let indexes = schemaEntity.indices.map { names in
                NSFetchIndexDescription(name: names.joined(separator: "_"),
                                        elements: names.map { name in
                                            guard let property = entities[index].propertiesByName[name]
                                            else { return NSFetchIndexElementDescription(property: NSAttributeDescription(),
                                                                                          collationType: .binary) }
                                            return NSFetchIndexElementDescription(property: property, collationType: .binary)
                                        })
            }
            if !indexes.isEmpty { entities[index].indexes = indexes }
        }
        if model.entities.contains(where: { $0.properties.isEmpty }) {
            throw SwiftDataError.modelValidationFailure
        }
        return model
    }

    /// One schema attribute as a Core Data attribute. The type is the one the Swift value has, by
    /// the table in `AttributeMapping`; a value with no column of its own - a struct, an array, a
    /// `UUID`, a `URL` on a release whose `NSUUIDAttributeType` is iOS 11 and later - is stored as
    /// the transformable Core Data has had since iOS 3.0, which keeps the type.
    static func attribute(from attribute: Schema.Attribute) -> NSAttributeDescription {
        let description = NSAttributeDescription()
        description.name = attribute.name
        description.attributeType = AttributeMapping.coreDataType(of: attribute.valueType,
                                                                  transformable: attribute.isTransformable)
        description.isOptional = attribute.isOptional
        if let defaultValue = attribute.defaultValue { description.defaultValue = StoredValue.store(defaultValue) }
        if let name = attribute.transformerName { description.valueTransformerName = name }
        if attribute.options.contains(.externalStorage) { description.allowsExternalBinaryDataStorage = true }
        return description
    }

    static func deleteRule(of rule: Schema.Relationship.DeleteRule) -> NSDeleteRule {
        switch rule {
        case .noAction: return .noActionDeleteRule
        case .nullify: return .nullifyDeleteRule
        case .cascade: return .cascadeDeleteRule
        case .deny: return .denyDeleteRule
        }
    }

    /// A store that is already at the schema it is opened with has nothing to migrate.
    private func migrate(from last: any VersionedSchema.Type, to schema: Schema,
                          plan: any SchemaMigrationPlan.Type) throws {
        let target = Schema(versionedSchema: last)
        guard target != schema else { return }
        // The release's own -migratePersistentStore:toURL:options:withType:error: takes no
        // mapping model, so the migration this performs is the store's own: a column the new
        // schema adds and the old one lacks is added to the table. A migration that renames a
        // column, or changes a column's type, needs a mapping model and the release has no
        // signature that takes one - which is what `MigrationStage.custom` is for, and why a
        // rename in a plan is written as one. The signature also takes the file a store is
        // migrated to, not a store, so the store is migrated beside itself and put in place.
        if let store = coordinator.persistentStores.first, let url = store.url {
            let moved = url.deletingLastPathComponent()
                .appendingPathComponent(url.lastPathComponent + ".migrating")
            try coordinator.migratePersistentStore(store, to: moved, options: nil, withType: NSSQLiteStoreType)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: moved)
        }
        for stage in plan.stages {
            switch stage {
            case .lightweight:
                break
            case .custom(_, _, let willMigrate, let didMigrate):
                // A custom stage's two closures are handed a context over the store being
                // migrated, so that what they change is what the migration writes.
                let container = ModelContainer(self, schema: schema)
                try willMigrate?(ModelContext(container))
                try didMigrate?(ModelContext(container))
            }
        }
    }

    /// The entity a model type is stored as, in this store's model.
    public func entityDescription(for name: String) -> NSEntityDescription {
        coordinator.managedObjectModel.entitiesByName[name]
            ?? NSEntityDescription()
    }

    /// Which Swift type an entity holds, as far as this store has been told. A model type is
    /// recorded here the first time a row of its entity is read as that model, which is the only
    /// place the type is statically known; the schema holds the entities and this holds the types
    /// the rows of each have been read as.
    private var modelTypes: [String: any PersistentModel.Type] = [:]

    func remember<T>(_ type: T.Type, for entityName: String) where T: PersistentModel {
        modelTypes[entityName] = type
    }

    public func modelType(for entityName: String) -> (any PersistentModel.Type)? {
        modelTypes[entityName]
    }

    // MARK: The DataStore

    public func erase() throws {
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
        try container.loadPersistentStores(completionHandler: { _, error in
            if let error { DefaultStore.lastLoadError = error }
        })
        if let error = DefaultStore.lastLoadError { throw error }
    }

    public func fetch<T>(_ request: DataStoreFetchRequest<T>) throws -> DataStoreFetchResult<T, DefaultSnapshot>
    where T: PersistentModel {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let rows = NSFetchRequest<NSManagedObject>(entityName: Schema.entityName(for: T.self))
        rows.includesPendingChanges = request.descriptor.includePendingChanges
        var snapshots = [DefaultSnapshot]()
        for row in try context.fetch(rows) where !row.objectID.isTemporaryID {
            let backing = CoreDataBacking<T>(for: T.self, object: row, context: context, owner: nil)
            var related = [PersistentIdentifier: any BackingData<T>]()
            snapshots.append(DefaultSnapshot(from: backing, relatedBackingDatas: &related))
        }
        return DataStoreFetchResult(descriptor: request.descriptor, fetchedSnapshots: snapshots)
    }

    public func save(_ request: DataStoreSaveChangesRequest<DefaultSnapshot>) throws
    -> DataStoreSaveChangesResult<DefaultSnapshot> {
        // A context holds the rows; a save of snapshots is a context's own save, which the
        // context does. What a store has to answer is which identities changed.
        var remapped = [PersistentIdentifier: PersistentIdentifier]()
        for snapshot in request.inserted + request.updated where snapshot.persistentIdentifier.id.object == nil {
            remapped[snapshot.persistentIdentifier] = snapshot.persistentIdentifier
        }
        return DataStoreSaveChangesResult(for: identifier, remappedIdentifiers: remapped)
    }

    public func delete<T>(_ request: DataStoreBatchDeleteRequest<T>) throws where T: PersistentModel {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: Schema.entityName(for: T.self))
        let delete = NSBatchDeleteRequest(fetchRequest: fetch)
        delete.resultType = .resultTypeObjectIDs
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.execute(delete)
    }

    /// The uniqueness constraints the schema names, checked against the rows of the store. The
    /// store of the port cannot enforce them - `NSEntityDescription.uniquenessConstraints` is
    /// registered `absent` for iOS 6 - so this is where they are checked, and a duplicate is
    /// refused rather than written.
    func checkUniqueness(in context: ModelContext) throws {
        for schemaEntity in schema.entities where !schemaEntity.uniquenessConstraints.isEmpty {
            for constraint in schemaEntity.uniquenessConstraints {
                let request = NSFetchRequest<NSManagedObject>(entityName: schemaEntity.name)
                request.includesPendingChanges = true
                var seen = [String: NSManagedObject]()
                for row in try context.context.fetch(request) {
                    let key = constraint.map { name in
                        String(describing: row.value(forKey: name) ?? NSNull())
                    }.joined(separator: "\u{1}")
                    if let first = seen[key], first !== row {
                        // A uniqueness constraint the store of the port cannot enforce, broken.
                        // `NSEntityDescription.uniquenessConstraints` is registered `absent` for
                        // iOS 6, and `NSConstraintConflict` is an Objective-C class this module
                        // cannot throw, so the refusal is a Swift error that carries both the
                        // constraint that was broken and Core Data's own value for the conflict.
                        let conflict = NSConstraintConflict(constraint: constraint, database: row,
                                                            databaseSnapshot: nil,
                                                            conflicting: [first, row],
                                                            conflictingSnapshots: [])
                        throw UniquenessViolation(entity: schemaEntity.name, constraint: constraint,
                                                  conflict: conflict)
                    }
                    seen[key] = row
                }
            }
        }
    }
}

/// The Core Data type a Swift value is stored as. The table is the whole of it, and a type with
/// no row in it is transformable, which is the one type that can hold anything: what the value
/// *is* is kept by the transformer or, with none, by `NSCoding`.
enum AttributeMapping {
    static func coreDataType(of type: any Any.Type, transformable: Bool) -> NSAttributeType {
        typealias Date = Foundation.Date
        typealias Data = Foundation.Data
        typealias Decimal = Foundation.Decimal
        if transformable { return .transformableAttributeType }
        switch type {
        case is String.Type, is Substring.Type: return .stringAttributeType
        case is Int.Type, is Int64.Type, is Int32.Type, is Int16.Type, is Int8.Type: return .integer64AttributeType
        case is UInt.Type, is UInt64.Type, is UInt32.Type, is UInt16.Type, is UInt8.Type: return .integer64AttributeType
        case is Double.Type, is Float.Type: return .doubleAttributeType
        case is Bool.Type: return .booleanAttributeType
        case is Date.Type: return .dateAttributeType
        case is Data.Type: return .binaryDataAttributeType
        case is Decimal.Type: return .decimalAttributeType
        default: return .transformableAttributeType
        }
    }
}

/// A uniqueness constraint the store of the port cannot enforce, broken. `NSEntityDescription.
/// uniquenessConstraints` is registered `absent` for iOS 6, and `NSConstraintConflict` is an
/// Objective-C class this module cannot throw, so the refusal is a Swift error that carries both
/// the constraint that was broken and Core Data's own value for the conflict.
public struct UniquenessViolation: Error {
    public let entity: String
    public let constraint: [String]
    public let conflict: NSConstraintConflict
}

// MARK: - The history
//
// A history is what the store remembers of what was saved to it, over the backports'
// NSPersistentHistory*: NSPersistentHistoryChangeRequest, NSPersistentHistoryToken,
// NSPersistentHistoryTransaction, NSPersistentHistoryChange, NSPersistentHistoryResult,
// NSPersistentHistoryTrackingKey, NSPersistentHistoryTokenKey,
// -[NSPersistentStoreCoordinator currentPersistentHistoryTokenFromStores:] and
// NSManagedObjectContext.transactionAuthor, all `implemented` with `minimum: 6.0` in
// registry/CoreData/ios11.json. A store that sets NSPersistentHistoryTrackingKey keeps them, and
// this store's on_install sets it, so there is something below to read.
//
// What a descriptor can ask for is what its three members are: a predicate, a limit and an order.
// There is no token and no date on it, so a fetch is the store's whole history, newest last, and a
// delete is everything before the newest transaction. A reader that wants to resume from where it
// was holds the token itself - `DefaultHistoryToken.tokenValue` carries the transaction number per
// store - and this is stated here because the interface says the same thing and nothing more.

extension DefaultStore: HistoryProviding {
    public static var historyType: DefaultHistoryTransaction.Type { DefaultHistoryTransaction.self }

    public func fetchHistory(_ descriptor: HistoryDescriptor<DefaultHistoryTransaction>)
    throws -> [DefaultHistoryTransaction] {
        // The release declares fetchHistoryAfterDate:, AfterToken: and AfterTransaction:, and the
        // importer gives all three the SAME name, `fetchHistory(after:)`, so the overload is chosen
        // by the argument's type and a nil literal picks none of them. A token that holds nothing
        // is the whole history, and a descriptor has no token on it to say otherwise, so that is
        // the spelling.
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: NSPersistentHistoryToken())
        if descriptor.fetchLimit > 0 {
            // The release's transaction is not an NSFetchRequestResult, so the fetch is untyped and
            // the limit is the fetch's own.
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "NSPersistentHistoryTransaction")
            fetch.fetchLimit = Int(descriptor.fetchLimit)
            request.fetchRequest = fetch
        }
        let rows = try execute(request)
        var transactions = rows.map { DefaultHistoryTransaction($0) }
        // The predicate is compiled by the compiler and answers a transaction's own values, and the
        // store cannot be told about it, so it is run here. That is what
        // `DataStoreError.preferInMemoryFilter` documents.
        if let predicate = descriptor.predicate {
            transactions = try transactions.filter { try predicate.evaluate($0) }
        }
        if !descriptor.sortBy.isEmpty {
            transactions.sort { lhs, rhs in
                for sort in descriptor.sortBy {
                    guard let key = sort.keyPath, let name = key._kvcKeyPathString,
                          let order = DefaultHistoryTransaction.sortValue(of: name, lhs, rhs) else { continue }
                    if order != .orderedSame {
                        return sort.order == SortOrder.forward ? order == .orderedAscending
                                                              : order == .orderedDescending
                    }
                }
                return false
            }
        }
        return transactions
    }

    public func deleteHistory(_ descriptor: HistoryDescriptor<DefaultHistoryTransaction>) throws {
        let request = NSPersistentHistoryChangeRequest.deleteHistory(before: NSPersistentHistoryToken())
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.execute(request)
        _ = descriptor
    }

    private func execute(_ request: NSPersistentHistoryChangeRequest) throws -> [NSPersistentHistoryTransaction] {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let result = try context.execute(request) as? NSPersistentHistoryResult
        return (result?.result as? [NSPersistentHistoryTransaction]) ?? []
    }
}

extension DefaultHistoryTransaction {
    /// One of the backports' transactions, read. The release declares `transactionNumber`, which is
    /// a transaction's identity: it is its place in the store's history, it is comparable, and it
    /// is what a token points at.
    init(_ transaction: NSPersistentHistoryTransaction) {
        let number = transaction.transactionNumber
        let when = StoredValue.cast(transaction.timestamp, to: Foundation.Date.self)
            ?? Foundation.Date(timeIntervalSince1970: 0)
        self.timestamp = StoredValue.cast(when, to: Date.self) ?? Date(timeIntervalSince1970: 0)
        self.transactionIdentifier = number
        self.storeIdentifier = transaction.storeID
        self.bundleIdentifier = transaction.bundleID
        self.processIdentifier = transaction.processID
        self.author = transaction.author
        self.token = DefaultHistoryToken(tokenValue: [transaction.storeID: number])
        self.changes = (transaction.changes ?? []).map { DefaultHistoryChange($0, in: number) }
    }

    /// A named property of a transaction, for a sort key path. A history transaction's own
    /// properties are the ones the release declares, and a key path naming another is not one of
    /// them, so it answers nil and the sort leaves that key alone rather than sorting by something
    /// nobody named.
    static func sortValue(of name: String, _ lhs: DefaultHistoryTransaction,
                          _ rhs: DefaultHistoryTransaction) -> Foundation.ComparisonResult? {
        switch name {
        case "timestamp", "date":
            if lhs.timestamp == rhs.timestamp { return .orderedSame }
            return lhs.timestamp < rhs.timestamp ? .orderedAscending : .orderedDescending
        case "transactionIdentifier":
            if lhs.transactionIdentifier == rhs.transactionIdentifier { return .orderedSame }
            return lhs.transactionIdentifier < rhs.transactionIdentifier ? .orderedAscending : .orderedDescending
        case "author":
            let left = lhs.author ?? "", right = rhs.author ?? ""
            if left == right { return .orderedSame }
            return left < right ? .orderedAscending : .orderedDescending
        case "storeIdentifier", "storeId":
            if lhs.storeIdentifier == rhs.storeIdentifier { return .orderedSame }
            return lhs.storeIdentifier < rhs.storeIdentifier ? .orderedAscending : .orderedDescending
        default:
            return nil
        }
    }
}

/// One of the backports' changes, read. The release's `NSPersistentHistoryChangeType` is three
/// cases, and a change is an insert, an update or a delete; a delete carries a tombstone, which is
/// what a reader still sees of the row it held.
func DefaultHistoryChange(_ change: NSPersistentHistoryChange,
                           in transaction: Int64) -> HistoryChange {
    let identifier = PersistentIdentifier(change.changedObjectID,
                                          entityName: change.changedObjectID.entity.name ?? "")
    switch change.changeType {
    case .insert:
        return .insert(DefaultHistoryInsert<SnapshotModel>(changeIdentifier: transaction,
                                            transactionIdentifier: transaction,
                                            changedPersistentIdentifier: identifier))
    case .update:
        return .update(DefaultHistoryUpdate<SnapshotModel>(changeIdentifier: transaction,
                                            transactionIdentifier: transaction,
                                            changedPersistentIdentifier: identifier,
                                            updatedAttributes: []))
    default:
        return .delete(DefaultHistoryDelete<SnapshotModel>(changeIdentifier: transaction,
                                            transactionIdentifier: transaction,
                                            changedPersistentIdentifier: identifier,
                                            tombstone: HistoryTombstone(values: (change.tombstone ?? [:])
                                                .map { (String(describing: $0.key), $0.value) })))
    }
}
