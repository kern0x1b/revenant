# SceneKit on iOS 6: particle systems and the Swift module

iOS 6 has no SceneKit. The backport (`frameworks/Backports/src/SceneKit`) is a set of Objective-C classes with the SDK's
names, and a Swift module of the same name for the parts of SceneKit that the SDK has only in Swift.

## SCNParticleSystem

`SCNParticleSystem` carries the SDK's whole data model, so a program that configures a system compiles at armv7 iOS 6.0 and
the values read back as written: the intensity and its variation (`particleIntensity`, `particleIntensityVariation`),
birth direction and location, damping, collision, charge, mass, friction, bounce, the image sequence properties,
`local`, `writesToDepthBuffer`, `blackPassEnabled`, `fresnelExponent`, the idle and emission durations and their variations,
the spawned systems, `colliderNodes`, `handleEvent:forProperties:withBlock:`, the modifier add and remove calls,
`reset` and `+particleSystemNamed:inDirectory:`. The five enumerations (`SCNParticleBirthDirection`,
`SCNParticleBirthLocation`, `SCNParticleEvent`, `SCNParticleImageSequenceAnimationMode`, `SCNParticleModifierStage`) are
lowered with it. Coding and copying carry the new properties.

Limit: the backport's renderer does not draw particles. A system attached to a node keeps its configuration and draws
nothing. The members are in `frameworks/Backports/tools/lowered-members.txt`.

## The Swift module

`SceneKit.swift` is the Swift side that the SDK's overlay gives: `SCNVector3` and `SCNVector4` initialisers without labels
from `Float`, `CGFloat`, `Double`, `Int` and SIMD vectors, the conversions to SIMD, the `SCNMatrix4` and `simd` matrix
initialisers, `SCNGeometryElement(indices:primitiveType:)`, the `SCNGeometrySource` array initialisers, the
`boundingBox` and `boundingSphere` tuples of `SCNBoundingVolume`, `SCNSceneSource.entryWithIdentifier(_:withClass:)` and the
bridging of the three value types to `NSValue`. It is a Swift module named like the SDK framework, so it is built with
`-import-underlying-module` and its sources do not import it.

A consumer builds the `SceneKit` target of the `Swift` component and passes its module folder with `-I`, as it does for
`IOSurface` and `UniformTypeIdentifiers` (see `docs/explanation/backports/lowered-implemented-names.md`).

## Checked

`frameworks/Backports/tests/framework_overlay_test.lua` builds the module for armv7 iOS 6.0, typechecks
`frameworks/Backports/tests/SceneKit/overlay.swift` (the lines of Telegram's `PremiumStarComponent.swift` that use
`SCNVector3` with and without labels and from `Float` and `CGFloat`, and the particle intensity properties), and checks that
the same file fails without the module. Not backported: `simdPosition` and the other simd accessors of `SCNNode`
(iOS 11), which Telegram does not use.

Not measured on a device: any drawing. The classes are checked at the compiler and, for the data model, on the host.
