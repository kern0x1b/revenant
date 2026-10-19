// The versioned schema and the plan that migrates between two of them.

import Foundation

public protocol VersionedSchema: SendableMetatype {
    static var models: [any PersistentModel.Type] { get }
    static var versionIdentifier: Schema.Version { get }
}

public protocol SchemaMigrationPlan: SendableMetatype {
    static var schemas: [any VersionedSchema.Type] { get }
    static var stages: [MigrationStage] { get }
}

public enum MigrationStage: Sendable {
    case lightweight(fromVersion: any VersionedSchema.Type, toVersion: any VersionedSchema.Type)
    case custom(fromVersion: any VersionedSchema.Type, toVersion: any VersionedSchema.Type,
                willMigrate: (@Sendable (ModelContext) throws -> Void)?,
                didMigrate: (@Sendable (ModelContext) throws -> Void)?)
}
