// The macros, as Apple's interface declares them.
//
// Each is a declaration and nothing else: `#externalMacro` names a plugin and a type in it, and
// the compiler loads that plugin only when a macro is *used*. So the six names a program writes -
// `@Model`, `@Attribute`, `@Relationship`, `@Transient`, `@ModelActor`, `@_PersistedProperty` and
// `@_TransformablePersistedProperty` - are here and compile without any plugin on the machine, and
// what a program that uses them needs is `SwiftDataMacros`, the host executable that expands them.
//
// The `@attached` lines are Apple's own, copied out of
// SwiftData.swiftmodule/arm64e-apple-ios.swiftinterface in the 26.2 SDK:
//
//   @attached(member, conformances: Observation.Observable, SwiftData.PersistentModel, Swift.Sendable,
//             names: named(_$backingData), named(persistentBackingData), named(schemaMetadata),
//             named(init), named(_$observationRegistrar), named(_SwiftDataNoType), named(access),
//             named(withMutation))
//   @attached(memberAttribute)
//   @attached(extension, conformances: Observation.Observable, SwiftData.PersistentModel, Swift.Sendable)
//   public macro Model() = #externalMacro(module: "SwiftDataMacros", type: "PersistentModelMacro")
//
// A declaration with the wrong roles is worse than none: the roles decide which extension points
// the expansion is handed, so they are Apple's and not this file's opinion.

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
