// The context: the place rows are read and written, the thing a view holds, and the place a
// model's identity comes from.
//
// A context owns an NSManagedObjectContext and the table that pairs each of its rows with the
// model that reads it. `registeredObjects` - on the release since iOS 3.0, and what the pilot's
// draft claimed iOS 6 did not have - is what says which rows the context holds, and the table is
// what turns one into a model.

import Foundation
import CoreData
import Observation
import FoundationEssentials
import FoundationInternationalization

public final class ModelContext: Equatable, SendableMetatype {
    /// The keys a save notification carries. Their names are Apple's, read from the host's own
    /// SwiftData by the differential; the values they hold here are the row identifiers this
    /// context saved, which the release's own `NSInsertedObjectIDsKey` and the three beside it do
    /// not carry - those are registered `absent` for iOS 6, whose
    /// `NSManagedObjectContextDidSaveNotification` carries the objects themselves.
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

    /// The container this context reads and writes. Set by `ModelContainer` when the context is
    /// made, and read by a model through its backing data.
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

    /// A context with no container, for a model built by hand and not yet in a store. It has a
    /// context of its own, so a model can be made, read and written before it is inserted.
    static func detachedContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        return context
    }

    // MARK: The rows this context holds

    /// The row each model is stored as, and the model each row is read by. Two tables, because
    /// both directions are asked: a model's identity from a row, and a row from an identifier
    /// that came off the wire.
    private var byRow: [ObjectIdentifier: any PersistentModel] = [:]
    private var byIdentifier: [PersistentIdentifier: any PersistentModel] = [:]

    func register<Model: PersistentModel>(_ model: Model, for object: NSManagedObject) {
        byRow[ObjectIdentifier(object)] = model
        if let identifier = model.persistentBackingData.persistentModelID { byIdentifier[identifier] = model }
    }

    /// The model a row is read by, made now if this context has not made it: a row that arrives
    /// from a fetch has no model until one is asked for, and the same model comes back next time
    /// because the row remembers it. The type is the one this call names, which is what a fetch
    /// of `T` and a relationship of `T.PersistentElement` both have.
    func makeModel<T>(_ type: T.Type, forObject object: NSManagedObject) -> T? where T: PersistentModel {
        if let known = byRow[ObjectIdentifier(object)] as? T { return known }
        let backing = CoreDataBacking<T>(for: T.self, object: object, context: context, owner: nil)
        let made = T(backingData: backing)
        register(made, for: object)
        remember(type, for: object.entity.name ?? Schema.entityName(for: T.self))
        return made
    }

    /// The model a row is read by, for a caller that does not know the type. Which type that is
    /// comes from this table, which is filled the first time a row of that entity is read as a
    /// model of that type - the one place the type is statically known.
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

    // MARK: What changed

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

    // MARK: Reading and writing

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

    /// Every row of the entity, or of the rows a predicate names. The predicate is a
    /// `Foundation.Predicate` the port does not have yet, so this is the unfiltered form and it
    /// deletes by fetching: the batch-delete path of the store, `DataStoreBatching.delete`, is
    /// where a predicate belongs.
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

    /// A save changes every row's identifier that had a temporary one, so the table that pairs
    /// rows with models is rebuilt from the rows the context still holds.
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

    // MARK: Fetching

    /// The rows a fetch of `entityName` names. The request is the store's own, with the
    /// descriptor's limit, offset, pending changes and prefetches; a descriptor's properties to
    /// fetch are the columns the store is asked for.
    func fetchRows<T>(_ type: T.Type, entityName: String, includeSubclasses: Bool = true) throws -> [NSManagedObject]
    where T: PersistentModel {
        try fetchRows(entityName: entityName, descriptor: FetchDescriptor<T>(), includeSubclasses: includeSubclasses)
    }

    /// The rows a fetch names. The store orders them: a `SortDescriptor`'s key path is a
    /// `KeyPath`, and `AnyKeyPath._kvcKeyPathString` is the name `NSSortDescriptor` sorts by, so
    /// the order becomes the store's own ORDER BY rather than a sort of rows already in memory.
    /// A predicate cannot go the other way - the node types of `PredicateExpression` are internal
    /// to swift-foundation and `Predicate.evaluate(_:)` is the only public way to run one - so a
    /// fetch with one reads its rows and filters them here, which is what
    /// `DataStoreError.preferInMemoryFilter` says a store does. The limit and the offset are
    /// therefore counted after the filtering, not by the store.
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

    // MARK: Identity

    // MARK: The history

    /// What the store remembers of what was saved to it, oldest first.
    ///
    /// The store is the one that holds the history - `NSPersistentHistoryChangeRequest` and the
    /// transactions it returns are the backports', registry/CoreData/ios11.json, and the store's
    /// description sets `NSPersistentHistoryTrackingKey` so there is one to read - and the
    /// descriptor's three members are all it has: a predicate, a limit and an order. There is no
    /// token and no date on it, so a fetch is the store's whole history. A reader that wants to
    /// resume from where it was holds the token the transactions carry.
    public func fetchHistory(_ descriptor: HistoryDescriptor<DefaultHistoryTransaction>) throws
    -> [DefaultHistoryTransaction] {
        try container.store.fetchHistory(descriptor)
    }

    /// The history before the newest transaction, gone. A store that keeps everything grows with
    /// every write, and this is how a program says where to stop keeping it.
    public func deleteHistory(_ descriptor: HistoryDescriptor<DefaultHistoryTransaction>) throws {
        try container.store.deleteHistory(descriptor)
    }

    public func model(for persistentModelID: PersistentIdentifier) -> any PersistentModel {
        // What this context holds under that identity. A model is paired with its row the first
        // time that row is read as that model - by a fetch, by `registeredModel`, or by reading a
        // relationship - and an identity this context has never paired a model with names a row
        // or a store that is not here, which is a model with no row.
        byIdentifier[persistentModelID] ?? UnsavedModel.instance
    }

    public func registeredModel<T>(for persistentModelID: PersistentIdentifier) -> T? where T: PersistentModel {
        byIdentifier[persistentModelID] as? T
    }

    public static func == (lhs: ModelContext, rhs: ModelContext) -> Bool { lhs === rhs }
}

extension NSManagedObjectContext {
    /// The SwiftData context a Core Data context belongs to, which is what a model's backing data
    /// asks to find its rows in. A Core Data context has no such back-reference of its own, and
    /// one is what lets a row find the table that pairs it with its model.
    private static var contextStorage: [ObjectIdentifier: ModelContext] = [:]

    var modelContext: ModelContext? {
        get { NSManagedObjectContext.contextStorage[ObjectIdentifier(self)] }
        set { NSManagedObjectContext.contextStorage[ObjectIdentifier(self)] = newValue }
    }
}

/// The model a context answers for an identifier that names no row: a model that is not in this
/// store. Apple's `model(for:)` is not optional, and the only honest answer for an identifier
/// with no row is a model with no row.
@Observable
public final class UnsavedModel: PersistentModel {
    public static let instance = UnsavedModel()
    public init() {}
    public var persistentBackingData: any BackingData<UnsavedModel> =
        CoreDataBacking<UnsavedModel>(for: UnsavedModel.self)
    public init(backingData: any BackingData<UnsavedModel>) {}
    public static var schemaMetadata: [Schema.PropertyMetadata] { [] }
}
