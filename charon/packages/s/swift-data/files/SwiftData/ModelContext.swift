import Foundation
import CoreData
import Observation
import FoundationEssentials
import FoundationInternationalization

public final class ModelContext: Equatable, SendableMetatype {
    public enum NotificationKey: String {
        case queryGeneration
        case invalidatedAllIdentifiers
        case insertedIdentifiers
        case updatedIdentifiers
        case deletedIdentifiers
    }

    public static let willSave = Notification.Name("SwiftDataModelContextWillSave")
    public static let didSave = Notification.Name("SwiftDataModelContextDidSave")

    public let context: NSManagedObjectContext

    public internal(set) var container: ModelContainer!

    public var author: String?
    public var undoManager: UndoManager? {
        get { context.undoManager }
        set { context.undoManager = newValue }
    }
    public var autosaveEnabled: Bool = true
    public var editingState = EditingState()

    public init(_ container: ModelContainer) {
        self.context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.context.persistentStoreCoordinator = container.store.coordinator
        self.container = container
        container.register(self)
        context.modelContext = self
    }

    static func detachedContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        return context
    }

    private var byRow: [ObjectIdentifier: any PersistentModel] = [:]
    private var byIdentifier: [PersistentIdentifier: any PersistentModel] = [:]

    func register<Model: PersistentModel>(_ model: Model, for object: NSManagedObject) {
        byRow[ObjectIdentifier(object)] = model
        if let identifier = model.persistentBackingData.persistentModelID { byIdentifier[identifier] = model }
    }

    func makeModel<T>(_ type: T.Type, forObject object: NSManagedObject) -> T? where T: PersistentModel {
        if let known = byRow[ObjectIdentifier(object)] as? T { return known }
        let backing = CoreDataBacking<T>(for: T.self, object: object, context: context, owner: nil)
        let made = T(backingData: backing)
        register(made, for: object)
        remember(type, for: object.entity.name ?? Schema.entityName(for: T.self))
        return made
    }

    func model(forObject object: NSManagedObject) -> any PersistentModel? {
        if let known = byRow[ObjectIdentifier(object)] { return known }
        guard let name = object.entity.name, let make = factories[name] else { return nil }
        let made = make(object, context)
        byRow[ObjectIdentifier(object)] = made
        return made
    }

    private var factories: [String: (NSManagedObject, NSManagedObjectContext) -> any PersistentModel] = [:]

    private func remember<T: PersistentModel>(_ type: T.Type, for entityName: String) {
        factories[entityName] = { object, context in
            T(backingData: CoreDataBacking<T>(for: T.self, object: object, context: context, owner: nil))
        }
    }

    public var hasChanges: Bool { context.hasChanges }

    public var insertedModelsArray: [any PersistentModel] {
        models(context.insertedObjects)
    }

    public var changedModelsArray: [any PersistentModel] {
        models(context.updatedObjects)
    }

    public var deletedModelsArray: [any PersistentModel] {
        models(context.deletedObjects)
    }

    private func models(_ rows: Set<NSManagedObject>) -> [any PersistentModel] {
        rows.compactMap { byRow[ObjectIdentifier($0)] }
    }

    public func insert<T>(_ model: T) where T: PersistentModel {
        let backing = CoreDataBacking<T>(for: T.self, object: NSManagedObject(
            entity: container.store.entityDescription(for: Schema.entityName(for: T.self)), insertInto: nil),
            context: context, owner: nil)
        let inserted = T(backingData: backing)
        context.insert(backing.object)
        register(inserted, for: backing.object)
    }

    public func delete<T>(_ model: T) where T: PersistentModel {
        if let object = model.backingObject { context.delete(object) }
    }

    public func delete<T>(model: T.Type, where predicate: Predicate<T>? = nil,
                          includeSubclasses: Bool = true) throws where T: PersistentModel {
        var descriptor = FetchDescriptor<T>()
        descriptor.predicate = predicate
        for row in try fetchRows(entityName: Schema.entityName(for: T.self), descriptor: descriptor,
                                 includeSubclasses: includeSubclasses) {
            context.delete(row)
        }
    }

    public func rollback() {
        context.rollback()
        byRow.removeAll()
        byIdentifier.removeAll()
    }

    public func processPendingChanges() {
        context.processPendingChanges()
    }

    public func save() throws {
        guard container.configurations.allSatisfy({ $0.allowsSave }) else {
            throw SwiftDataError.modelValidationFailure
        }
        try container.store.checkUniqueness(in: self)
        NotificationCenter.default.post(name: ModelContext.willSave, object: self)
        try context.save()
        reindex()
        var userInfo: [String: Any] = [:]
        userInfo[NotificationKey.insertedIdentifiers.rawValue] =
            (context.insertedObjects.map { identifier(of: $0) })
        userInfo[NotificationKey.updatedIdentifiers.rawValue] =
            (context.updatedObjects.map { identifier(of: $0) })
        userInfo[NotificationKey.deletedIdentifiers.rawValue] =
            (context.deletedObjects.map { identifier(of: $0) })
        userInfo[NotificationKey.queryGeneration.rawValue] = context.queryGenerationToken
        userInfo[NotificationKey.invalidatedAllIdentifiers.rawValue] = false
        NotificationCenter.default.post(name: ModelContext.didSave, object: self, userInfo: userInfo)
    }

    private func reindex() {
        byRow.removeAll()
        byIdentifier.removeAll()
        for object in context.registeredObjects {
            if let known = byRow[ObjectIdentifier(object)] ?? container.models[ObjectIdentifier(object)] {
                register(known, for: object)
            }
        }
    }

    private func identifier(of object: NSManagedObject) -> PersistentIdentifier {
        PersistentIdentifier(object.objectID, entityName: object.entity.name ?? "")
    }

    public func transaction(block: () throws -> Void) throws {
        var thrown: Error?
        context.performAndWait {
            do { try block() } catch { thrown = error }
        }
        if let thrown { throw thrown }
    }

    func fetchRows<T>(_ type: T.Type, entityName: String, includeSubclasses: Bool = true) throws -> [NSManagedObject]
    where T: PersistentModel {
        try fetchRows(entityName: entityName, descriptor: FetchDescriptor<T>(), includeSubclasses: includeSubclasses)
    }

    func fetchRows<T>(entityName: String, descriptor: FetchDescriptor<T>,
                      includeSubclasses: Bool = true) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.includesPendingChanges = descriptor.includePendingChanges
        if !descriptor.sortBy.isEmpty {
            request.sortDescriptors = descriptor.sortBy.compactMap { sort in
                guard let key = sort.keyPath, let name = key._kvcKeyPathString else { return nil }
                return NSSortDescriptor(key: name, ascending: sort.order == SortOrder.forward)
            }
        }
        if descriptor.predicate == nil {
            if let limit = descriptor.fetchLimit { request.fetchLimit = limit }
            if let offset = descriptor.fetchOffset, offset > 0 { request.fetchOffset = offset }
        }
        if !descriptor.relationshipKeyPathsForPrefetching.isEmpty {
            request.relationshipKeyPathsForPrefetching =
                descriptor.relationshipKeyPathsForPrefetching.map { "\($0)" }
        }
        return try context.fetch(request)
    }

    public func fetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] where T: PersistentModel {
        let rows = try fetchRows(entityName: Schema.entityName(for: T.self), descriptor: descriptor)
        let models = rows.compactMap { makeModel(T.self, forObject: $0) }
        guard let predicate = descriptor.predicate else { return models }
        return try models.filter { try predicate.evaluate($0) }
    }

    public func fetch<T>(_ descriptor: FetchDescriptor<T>, batchSize: Int) throws -> FetchResultsCollection<T>
    where T: PersistentModel {
        var paged = descriptor
        paged.fetchLimit = batchSize
        return FetchResultsCollection(try fetch(paged))
    }

    public func fetchCount<T>(_ descriptor: FetchDescriptor<T>) throws -> Int where T: PersistentModel {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: Schema.entityName(for: T.self))
        request.includesPendingChanges = descriptor.includePendingChanges
        request.resultType = .countResultType
        let result = try context.fetch(request) as? [NSNumber]
        return result?.first?.intValue ?? 0
    }

    public func fetchIdentifiers<T>(_ descriptor: FetchDescriptor<T>) throws -> [PersistentIdentifier]
    where T: PersistentModel {
        let request = NSFetchRequest<NSManagedObjectID>(entityName: Schema.entityName(for: T.self))
        request.includesPendingChanges = descriptor.includePendingChanges
        if let limit = descriptor.fetchLimit { request.fetchLimit = limit }
        if let offset = descriptor.fetchOffset, offset > 0 { request.fetchOffset = offset }
        return try context.fetch(request).map { PersistentIdentifier($0, entityName: Schema.entityName(for: T.self)) }
    }

    public func fetchIdentifiers<T>(_ descriptor: FetchDescriptor<T>, batchSize: Int) throws
    -> FetchResultsCollection<PersistentIdentifier> where T: PersistentModel {
        var paged = descriptor
        paged.fetchLimit = batchSize
        return FetchResultsCollection(try fetchIdentifiers(paged))
    }

    public func enumerate<T>(_ fetch: FetchDescriptor<T>, batchSize: Int = 5000,
                             allowEscapingMutations: Bool = false,
                             block: (T) throws -> Void) throws where T: PersistentModel {
        var page = fetch
        var offset = fetch.fetchOffset ?? 0
        var seen = 0
        while true {
            page.fetchOffset = offset
            page.fetchLimit = batchSize
            let rows = try self.fetch(page)
            if rows.isEmpty { return }
            for row in rows { try block(row) }
            seen += rows.count
            offset += rows.count
            if rows.count < batchSize { return }
            if seen > 0 && !allowEscapingMutations { continue }
        }
    }

    public func fetchHistory(_ descriptor: HistoryDescriptor<DefaultHistoryTransaction>) throws
    -> [DefaultHistoryTransaction] {
        try container.store.fetchHistory(descriptor)
    }

    public func deleteHistory(_ descriptor: HistoryDescriptor<DefaultHistoryTransaction>) throws {
        try container.store.deleteHistory(descriptor)
    }

    public func model(for persistentModelID: PersistentIdentifier) -> any PersistentModel {
        byIdentifier[persistentModelID] ?? UnsavedModel.instance
    }

    public func registeredModel<T>(for persistentModelID: PersistentIdentifier) -> T? where T: PersistentModel {
        byIdentifier[persistentModelID] as? T
    }

    public static func == (lhs: ModelContext, rhs: ModelContext) -> Bool { lhs === rhs }
}

extension NSManagedObjectContext {
    private static var contextStorage: [ObjectIdentifier: ModelContext] = [:]

    var modelContext: ModelContext? {
        get { NSManagedObjectContext.contextStorage[ObjectIdentifier(self)] }
        set { NSManagedObjectContext.contextStorage[ObjectIdentifier(self)] = newValue }
    }
}

@Observable
public final class UnsavedModel: PersistentModel {
    public static let instance = UnsavedModel()
    public init() {}
    public var persistentBackingData: any BackingData<UnsavedModel> =
        CoreDataBacking<UnsavedModel>(for: UnsavedModel.self)
    public init(backingData: any BackingData<UnsavedModel>) {}
    public static var schemaMetadata: [Schema.PropertyMetadata] { [] }
}
