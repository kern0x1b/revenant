import Foundation
import Observation

@attached(member, conformances: Observation.Observable, SwiftData.PersistentModel, Swift.Sendable,
          names: named(_$backingData), named(persistentBackingData), named(schemaMetadata),
          named(init), named(_$observationRegistrar), named(_SwiftDataNoType), named(access),
          named(withMutation))
@attached(memberAttribute)
@attached(extension, conformances: Observation.Observable, SwiftData.PersistentModel, Swift.Sendable)
public macro Model() = #externalMacro(module: "SwiftDataMacros", type: "PersistentModelMacro")

@attached(member, names: named(modelExecutor), named(modelContainer), named(init))
@attached(extension, conformances: SwiftData.ModelActor)
public macro ModelActor() = #externalMacro(module: "SwiftDataMacros", type: "PersistentModelActorMacro")

@attached(peer)
public macro Attribute(_ options: SwiftData.Schema.Attribute.Option...,
                       originalName: Swift.String? = nil,
                       hashModifier: Swift.String? = nil) =
    #externalMacro(module: "SwiftDataMacros", type: "AttributePropertyMacro")

@attached(peer)
public macro Relationship(_ options: SwiftData.Schema.Relationship.Option...,
                          deleteRule: SwiftData.Schema.Relationship.DeleteRule = .nullify,
                          minimumModelCount: Swift.Int? = 0,
                          maximumModelCount: Swift.Int? = 0,
                          originalName: Swift.String? = nil,
                          inverse: Swift.AnyKeyPath? = nil,
                          hashModifier: Swift.String? = nil) =
    #externalMacro(module: "SwiftDataMacros", type: "RelationshipPropertyMacro")

@attached(peer)
public macro Transient() = #externalMacro(module: "SwiftDataMacros", type: "TransientPropertyMacro")

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`))
public macro _PersistedProperty() = #externalMacro(module: "SwiftDataMacros", type: "PersistedPropertyMacro")

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`))
public macro _TransformablePersistedProperty() =
    #externalMacro(module: "SwiftDataMacros", type: "TransformablePersistedPropertyMacro")
