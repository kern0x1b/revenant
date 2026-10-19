import Foundation
import CoreData

public final class ModelContainer: Equatable, @unchecked Sendable {
    public let schema: Schema
    public let migrationPlan: (any SchemaMigrationPlan.Type)?
    public var configurations: Set<ModelConfiguration>

    public let store: DefaultStore

    var models: [ObjectIdentifier: any PersistentModel] = [:]

    private var contexts: [ModelContext] = []

    @MainActor public var mainContext: ModelContext {
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

    public func deleteAllData() {
        try? erase()
    }

    public func erase() throws {
        try store.erase()
    }
}
