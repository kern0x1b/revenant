// The store's own types, iOS 18: a store that is not Core Data can be written against these, and
// the Core Data one answers them.

import Foundation
import Observation
import FoundationEssentials

// This port's Foundation overlay and swift-foundation's FoundationEssentials both declare
// `UUID` and `Date`, and a file that imports both cannot say which it means. FoundationEssentials
// is the one that will be the port's Foundation once charon@swift-foundation is in the store, and
// it is the one whose values a store's rows are written as, so it is named at every use below.

public typealias DataStoreSnapshotValue = Codable & Sendable

public protocol DataStoreConfiguration: Hashable {
    associatedtype Store: DataStore where Self == Self.Store.Configuration
    var name: String { get }
    var schema: Schema? { get set }
    func validate() throws
}

public protocol DataStore: AnyObject {
    associatedtype Configuration: DataStoreConfiguration where Self == Self.Configuration.Store
    associatedtype Snapshot: DataStoreSnapshot

    var identifier: String { get }
    var schema: Schema { get }
    var configuration: Self.Configuration { get }

    init(_ configuration: Self.Configuration, migrationPlan: (any SchemaMigrationPlan.Type)?) throws

    func erase() throws
    func fetch<T>(_ request: DataStoreFetchRequest<T>) throws -> DataStoreFetchResult<T, Self.Snapshot>
    where T: PersistentModel
    func save(_ request: DataStoreSaveChangesRequest<Self.Snapshot>) throws
        -> DataStoreSaveChangesResult<Self.Snapshot>
    func initializeState(for editingState: EditingState)
    func invalidateState(for editingState: EditingState)
}

extension DataStore {
    /// How many rows a fetch names. The answer comes from the fetch itself, so it is not a second
    /// kind of question: the store reads the same request with a count result type.
    public func fetchCount<T>(_ request: DataStoreFetchRequest<T>) throws -> Int where T: PersistentModel {
        try fetch(request).fetchedSnapshots.count
    }

    /// Which rows a fetch names, without reading their values.
    public func fetchIdentifiers<T>(_ request: DataStoreFetchRequest<T>) throws -> [PersistentIdentifier]
    where T: PersistentModel {
        try fetch(request).fetchedSnapshots.map { $0.persistentIdentifier }
    }

    public func erase() throws {}

    public func initializeState(for editingState: EditingState) {}

    public func invalidateState(for editingState: EditingState) {}

    public func cachedSnapshots(for persistentIdentifiers: [PersistentIdentifier],
                                editingState: EditingState) throws -> [PersistentIdentifier: Self.Snapshot] {
        // The rows whose values the store already holds, out of the ones it is asked for. A store
        // that keeps a cache of its own answers this itself; the default asks the store, and what
        // it holds is what its own last fetch read.
        let result = try fetch(DataStoreFetchRequest(editingState: editingState,
                                                      descriptor: FetchDescriptor<SnapshotModel>()))
        var cached = [PersistentIdentifier: Self.Snapshot](minimumCapacity: persistentIdentifiers.count)
        for snapshot in result.fetchedSnapshots where persistentIdentifiers.contains(snapshot.persistentIdentifier) {
            cached[snapshot.persistentIdentifier] = snapshot
        }
        return cached
    }
}

/// The model type the default `cachedSnapshots` fetches with: a store with no cache of its own
/// has no entity of its own to name, and this names none.
@Observable
public final class SnapshotModel: PersistentModel {
    public static let instance = SnapshotModel()
    public init() {}
    public init(backingData: any BackingData<SnapshotModel>) {}
    public var persistentBackingData: any BackingData<SnapshotModel> =
        CoreDataBacking<SnapshotModel>(for: SnapshotModel.self)
    public static var schemaMetadata: [Schema.PropertyMetadata] { [] }
}

public protocol DataStoreBatching: DataStore {
    func delete<T>(_ request: DataStoreBatchDeleteRequest<T>) throws where T: PersistentModel
}

public protocol DataStoreSnapshot: Decodable, Encodable, Sendable {
    var persistentIdentifier: PersistentIdentifier { get }
    init<Model>(from backingData: any BackingData<Model>,
                relatedBackingDatas: inout [PersistentIdentifier: any BackingData<Model>]) where Model: PersistentModel
    func copy(persistentIdentifier: PersistentIdentifier,
              remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier]?) -> Self
}

extension DataStoreSnapshot {
    /// A copy under a new identity. The identifiers of the rows this snapshot's relationships
    /// point at are remapped through `remappedIdentifiers`, which is what a store does after a
    /// save that gave rows new identities.
    public func copy(persistentIdentifier: PersistentIdentifier,
                     remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier]? = [:]) -> Self {
        copy(persistentIdentifier: persistentIdentifier, remappedIdentifiers: remappedIdentifiers ?? [:])
    }
}

/// What one editing state is: who made the changes of a save, and which state they belong to.
public struct EditingState: Identifiable, Sendable {
    public typealias ID = FoundationEssentials.UUID

    public let id: FoundationEssentials.UUID
    public var author: String?

    public init(id: FoundationEssentials.UUID = FoundationEssentials.UUID(), author: String? = nil) {
        self.id = id
        self.author = author
    }
}

public struct DataStoreFetchRequest<T>: Sendable where T: PersistentModel {
    public let editingState: EditingState
    public let descriptor: FetchDescriptor<T>

    public init(editingState: EditingState, descriptor: FetchDescriptor<T>) {
        self.editingState = editingState
        self.descriptor = descriptor
    }
}

public struct DataStoreFetchResult<ModelType, SnapshotType>: Sendable
where ModelType: PersistentModel, SnapshotType: DataStoreSnapshot {
    public let descriptor: FetchDescriptor<ModelType>
    public let fetchedSnapshots: [SnapshotType]
    public let relatedSnapshots: [PersistentIdentifier: SnapshotType]

    public init(descriptor: FetchDescriptor<ModelType>, fetchedSnapshots: [SnapshotType],
                relatedSnapshots: [PersistentIdentifier: SnapshotType] = [:]) {
        self.descriptor = descriptor
        self.fetchedSnapshots = fetchedSnapshots
        self.relatedSnapshots = relatedSnapshots
    }
}

public struct DataStoreSaveChangesRequest<SnapshotType>: Sendable where SnapshotType: DataStoreSnapshot {
    public let inserted: [SnapshotType]
    public let updated: [SnapshotType]
    public let deleted: [SnapshotType]
    public let editingState: EditingState

    public init(inserted: [SnapshotType] = [], updated: [SnapshotType] = [], deleted: [SnapshotType] = [],
                editingState: EditingState = EditingState()) {
        self.inserted = inserted
        self.updated = updated
        self.deleted = deleted
        self.editingState = editingState
    }
}

public final class DataStoreSaveChangesResult<T>: Sendable where T: DataStoreSnapshot {
    public let remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier]
    public let storeIdentifier: String
    public let snapshotsToReregister: [PersistentIdentifier: T]

    public init(for storeIdentifier: String, remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier] = [:],
                snapshotsToReregister: [PersistentIdentifier: T] = [:]) {
        self.remappedIdentifiers = remappedIdentifiers
        self.storeIdentifier = storeIdentifier
        self.snapshotsToReregister = snapshotsToReregister
    }
}

/// A batch delete: the rows of an entity the predicate names, of the store's own. A store turns
/// the predicate into an `NSPredicate` where it can - `DataStoreError.preferInMemoryFilter` when
/// it cannot, which is the signal to fetch and delete rather than to hand the predicate over.
public struct DataStoreBatchDeleteRequest<T>: Sendable where T: PersistentModel {
    public let editingState: EditingState
    public var includeSubclasses: Bool
    public var predicate: Predicate<T>?

    public init(predicate: Predicate<T>? = nil, editingState: EditingState = EditingState(),
                includeSubclasses: Bool = true) {
        self.predicate = predicate
        self.editingState = editingState
        self.includeSubclasses = includeSubclasses
    }
}

/// The snapshot of one row: its identity, and the value of each property, under the name of the
/// property. This is what a store's fetch returns and what its save takes.
public struct DefaultSnapshot: DataStoreSnapshot {
    public let persistentIdentifier: PersistentIdentifier
    /// A property's value as `JSONEncoder` can carry it: this package's own record of a row.
    /// Internal, because Apple's snapshot exposes no such collection and a public one would be a
    /// name the interface does not declare.
    let values: [String: PropertyValue]

    init(persistentIdentifier: PersistentIdentifier, values: [String: PropertyValue]) {
        self.persistentIdentifier = persistentIdentifier
        self.values = values
    }

    public init<Model>(from backingData: any BackingData<Model>,
                       relatedBackingDatas: inout [PersistentIdentifier: any BackingData<Model>])
    where Model: PersistentModel {
        self.persistentIdentifier = backingData.persistentModelID ?? .unregistered
        var values = [String: PropertyValue]()
        for entry in Model.schemaMetadata {
            // A property the store holds is written down under its own name, with the value the
            // model's metadata says it starts as; the rows a relationship points at are left to
            // the store, which is what `relatedBackingDatas` is for.
            values[entry.name] = PropertyValue(entry.defaultValue)
        }
        for (_, related) in relatedBackingDatas {
            // A related row is named by its own identity; what it holds is the store's business,
            // and it is fetched with the row that points at it.
            guard let model = related.metadata as? String else { continue }
            values[model] = PropertyValue(nil)
        }
        self.values = values
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DataStoreSnapshotCodingKey.self)
        self.persistentIdentifier = try container.decode(PersistentIdentifier.self, forKey: .persistentIdentifier)
        var values = [String: PropertyValue]()
        for key in container.allKeys {
            if case .modeledProperty(let name) = key {
                values[name] = try container.decode(PropertyValue.self, forKey: key)
            }
        }
        self.values = values
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DataStoreSnapshotCodingKey.self)
        try container.encode(persistentIdentifier, forKey: .persistentIdentifier)
        for (name, value) in values {
            try container.encode(value, forKey: .modeledProperty(name))
        }
    }

    public func copy(persistentIdentifier: PersistentIdentifier,
                     remappedIdentifiers: [PersistentIdentifier: PersistentIdentifier]? = [:]) -> DefaultSnapshot {
        DefaultSnapshot(persistentIdentifier: persistentIdentifier, values: values)
    }
}
