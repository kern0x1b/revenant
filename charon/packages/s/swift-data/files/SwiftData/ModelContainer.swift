// The container: a schema, the stores a configuration opened, and the context a program holds.

import Foundation
import CoreData

public final class ModelContainer: Equatable, @unchecked Sendable {
    public let schema: Schema
    public let migrationPlan: (any SchemaMigrationPlan.Type)?
    public var configurations: Set<ModelConfiguration>

    /// The store, which is the Core Data one for every configuration: a `ModelConfiguration` is a
    /// `DataStoreConfiguration` whose `Store` is `DefaultStore`, so a container's store and its
    /// configuration are the same objects.
    public let store: DefaultStore

    /// The models this container has made, by the row they are stored as. A model is made over a
    /// row and the row is what remembers it, so a save that changes a row's identity can find
    /// the model again.
    var models: [ObjectIdentifier: any PersistentModel] = [:]

    private var contexts: [ModelContext] = []

    @MainActor public var mainContext: ModelContext {
        // The first context made is the main one, and a container has one main context for as
        // long as it lives, the way Apple's does: `mainContext` is a property, not a new context
        // per read.
        if let made = contexts.first { return made }
        let made = ModelContext(self)
        return made
    }

    public convenience init(for givenSchema: Schema, migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
                            configurations: ModelConfiguration...) throws {
        try self.init(for: givenSchema, migrationPlan: migrationPlan, configurations: configurations)
    }

    public convenience init(for forTypes: any PersistentModel.Type..., migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
                            configurations: ModelConfiguration...) throws {
        try self.init(for: Schema(forTypes), migrationPlan: migrationPlan, configurations: configurations)
    }

    public init(for givenSchema: Schema, migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
                configurations: [ModelConfiguration]) throws {
        let configs = configurations.isEmpty ? [ModelConfiguration(schema: givenSchema)] : configurations
        var seen = Set<String>()
        for configuration in configs where !seen.insert(configuration.url.path).inserted {
            throw SwiftDataError.duplicateConfiguration
        }
        for configuration in configs { try configuration.validate() }
        let schema = configs.compactMap { $0.schema }.first ?? givenSchema
        self.schema = schema
        self.migrationPlan = migrationPlan
        self.configurations = Set(configs)
        self.store = try DefaultStore(configs[0], migrationPlan: migrationPlan, schema: schema)
    }

    public convenience init(for forTypes: any PersistentModel.Type..., configurations: any DataStoreConfiguration...) throws {
        try self.init(for: Schema(forTypes), configurations: configurations)
    }

    public convenience init(for givenSchema: Schema, configurations: [any DataStoreConfiguration]) throws {
        try self.init(for: givenSchema, migrationPlan: nil,
                      configurations: configurations.compactMap { $0 as? ModelConfiguration })
    }

    internal init(_ store: DefaultStore, schema: Schema) {
        self.schema = schema
        self.migrationPlan = nil
        self.configurations = [store.configuration]
        self.store = store
    }

    func register(_ context: ModelContext) {
        if !contexts.contains(where: { $0 === context }) { contexts.append(context) }
    }

    public static func == (lhs: ModelContainer, rhs: ModelContainer) -> Bool { lhs === rhs }

    /// Everything the stores hold, gone. Deprecated in Apple's own name of it, and it says so:
    /// `erase` is what a program should call, and this is here so that a program written against
    /// the old name still runs.
    public func deleteAllData() {
        try? erase()
    }

    public func erase() throws {
        try store.erase()
    }
}
