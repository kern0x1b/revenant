// MARK: - Bind targets
//
// What an animation drives: a path into a scene graph, and the kind of value the path names.
//
// Read from the SDK's own interface, `iPhoneOS26.2.sdk/.../RealityFoundation.swiftmodule/
/// arm64e-apple-ios.swiftinterface`: BindPath :498-534, BindTarget :535-660, InternalBindPath :663,
// BindableData :666-668 with its conformances at :669 onwards, and BlendShapeWeightsData :15874.
//
// The paths and the value protocol are data, and they are carried whole. What a *renderer* reads -
// a material's parameters, a blend shape's weight, a billboard factor, a skeletal pose, a joint
// transform, an opacity - is not: this port's view is an SCNView over the SceneKit bridge, and a
// path to a property no renderer here reads is a path to nothing. Those cases are absent rows with
// that reason, not declarations standing in for them.

import simd
import Foundation

/// A path into a scene graph, as a list of parts. `BindPath.Part` is the interface's own enum
/// (:499-534) and the cases this port carries are the ones that name something in the scene graph
/// it has: a scene, an anchor's entity, a named entity, a named parameter, and a transform.
@frozen public struct BindPath: Equatable {
    public enum Part: Equatable {
        /// The scene itself.
        case scene(String)
        /// An entity on the anchor of that name.
        case anchorEntity(String)
        /// The child of the last part with that name.
        case entity(String)
        /// A parameter of whatever the path has reached.
        case parameter(String)
        /// The transform of whatever the path has reached.
        case transform

        // Not carried, and each is an absent row in the registry: jointTransforms, opacity,
        // blendShapeWeights, blendShapeWeightsAtIndex, blendShapeWeightsWithID,
        // billboardBlendFactor, skeletalPose, ikSolver and the material and texture-coordinate
        // parts. They name values that only a renderer reads.
    }

    /// The parts, in order from the scene down.
    public var parts: [Part]

    public init(parts: [Part] = []) { self.parts = parts }
    public init(_ parts: Part...) { self.parts = parts }

    /// The path a builder has accumulated, which is what a target names.
    public var target: BindTarget { .path(self) }
}

/// What an animation drives: a kind of value, or a path to one.
@frozen public enum BindTarget: Equatable {
    /// The transform of the entity this target is bound to.
    case transform
    /// A named parameter of the entity this target is bound to.
    case parameter(String)
    /// A path into the scene graph, which is what every builder here makes.
    case path(BindPath)

    // Not carried, and each is an absent row: `internal(_:)` (the system's own private path, and
    // the interface marks it unavailable on tvOS), jointTransforms, opacity, blendShapeWeights,
    // blendShapeWeightsAtIndex, blendShapeWeightsWithID, billboardBlendFactor and skeletalPose.
    // They name values a renderer reads, and this port has no renderer that reads them.

    /// A path from a scene, which is where every binding starts.
    public struct ScenePath {
        let parts: [BindPath.Part]

        /// The entity on the anchor of that name.
        public func anchorEntity(_ name: String) -> EntityPath {
            EntityPath(parts: parts + [.anchorEntity(name)])
        }

        /// The scene itself.
        public var `self`: BindTarget { .path(BindPath(parts: parts)) }
    }

    /// A path from an entity, and the properties of that entity this port carries.
    public struct EntityPath {
        let parts: [BindPath.Part]

        /// The child entity of that name.
        public func entity(_ name: String) -> EntityPath {
            EntityPath(parts: parts + [.entity(name)])
        }

        /// The entity's transform.
        public var transform: BindTarget { .path(BindPath(parts: parts + [.transform])) }

        /// A named parameter of the entity.
        public func parameter(_ name: String) -> BindTarget {
            .path(BindPath(parts: parts + [.parameter(name)]))
        }

        /// The entity's inverse-kinematics solver, which the IK block in this module carries, so
        /// this path is carried and the ones beside it that name a renderer are not.
        public func ikSolver(_ id: IKComponent.Solver.ID? = nil) -> IkSolverPath {
            IkSolverPath(parts: parts, solver: id)
        }

        /// The entity itself, which is a parameter path with no terminal part.
        public var `self`: BindTarget { .path(BindPath(parts: parts)) }
    }

    /// A path from an inverse-kinematics solver to the target one of its constraints is given.
    public struct IkSolverPath {
        let parts: [BindPath.Part]
        let solver: IKComponent.Solver.ID?

        /// Where the named constraint is asked to put its joint.
        public func constraintTarget(_ constraintName: String) -> BindTarget {
            .path(BindPath(parts: parts + [.parameter("ikSolver.constraintTarget.\(constraintName)")]))
        }

        /// Where the named constraint is asked to look.
        public func constraintLookAtTarget(_ constraintName: String) -> BindTarget {
            .path(BindPath(parts: parts + [.parameter("ikSolver.constraintLookAtTarget.\(constraintName)")]))
        }
    }

    /// The scene of that name, which is where a binding starts.
    public static func scene(_ name: String) -> ScenePath {
        ScenePath(parts: [.scene(name)])
    }
}

/// What a bind target can write into: the value kinds the interface conforms to it, and the list is
/// the interface's - `Float` and `Double` at :669 and :672, `SIMD2` at :675, and the rest along the
/// same lines. The protocol itself is empty (`:667`), so carrying it is carrying the conformances.
public protocol BindableData {}

extension Float: BindableData {}
extension Double: BindableData {}
extension SIMD2: BindableData where Scalar == Float {}
extension SIMD3: BindableData where Scalar == Float {}
extension SIMD4: BindableData where Scalar == Float {}
extension simd_quatf: BindableData {}
extension Transform: BindableData {}

extension Entity {
    /// The target that drives this entity's transform.
    public var bindTarget: BindTarget { .transform }
}
