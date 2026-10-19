import Foundation
import CoreData
import FoundationEssentials
import FoundationInternationalization

public final class DefaultStore: DataStore, DataStoreBatching, @unchecked Sendable {
    public typealias Configuration = ModelConfiguration
    public typealias Snapshot = DefaultSnapshot
    public typealias HistoryType = DefaultHistoryTransaction
    public typealias TokenType = DefaultHistoryToken

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

    private static var lastLoadError: Error?

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

    private func migrate(from last: any VersionedSchema.Type, to schema: Schema,
                          plan: any SchemaMigrationPlan.Type) throws {
        let target = Schema(versionedSchema: last)
        guard target != schema else { return }
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
                let container = ModelContainer(self, schema: schema)
                try willMigrate?(ModelContext(container))
                try didMigrate?(ModelContext(container))
            }
        }
    }

    public func entityDescription(for name: String) -> NSEntityDescription {
        coordinator.managedObjectModel.entitiesByName[name]
            ?? NSEntityDescription()
    }

    private var modelTypes: [String: any PersistentModel.Type] = [:]

    func remember<T>(_ type: T.Type, for entityName: String) where T: PersistentModel {
        modelTypes[entityName] = type
    }

    public func modelType(for entityName: String) -> (any PersistentModel.Type)? {
        modelTypes[entityName]
    }

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

public struct UniquenessViolation: Error {
    public let entity: String
    public let constraint: [String]
    public let conflict: NSConstraintConflict
}

extension DefaultStore: HistoryProviding {
    public static var historyType: DefaultHistoryTransaction.Type { DefaultHistoryTransaction.self }

    public func fetchHistory(_ descriptor: HistoryDescriptor<DefaultHistoryTransaction>)
    throws -> [DefaultHistoryTransaction] {
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: NSPersistentHistoryToken())
        if descriptor.fetchLimit > 0 {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "NSPersistentHistoryTransaction")
            fetch.fetchLimit = Int(descriptor.fetchLimit)
            request.fetchRequest = fetch
        }
        let rows = try execute(request)
        var transactions = rows.map { DefaultHistoryTransaction($0) }
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
