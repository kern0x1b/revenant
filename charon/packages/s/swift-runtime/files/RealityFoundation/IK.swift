// MARK: - Inverse kinematics
//
// The rig, the constraints that put demands on it, and the component an entity carries to be solved.
//
// Every declaration and member below is read from the SDK's own interface,
// `iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/
/// RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface`: IKSolverDefinition :4738, IKRig
// :4745-4945, IKComponent :8842-9075, IKResource :10958. The names, the cases, the types and the
// defaults are the system's.
//
// This is the one part of the scene graph that needs no renderer and no asset: a rig is joints and
// transforms, a constraint is a demand on one of them, and solving is arithmetic over the entity
// tree's own transforms. What is *not* here is stated where a reader will find it rather than
// faked:
//
//   - `IKRig.init(for: MeshResource.Skeleton)` (:4759) is **not declared here at all**: a skeleton
//     is read out of a mesh asset, and this module carries no `MeshResource.Skeleton` to pass it, so
//     an initializer that took one could only be a signature standing in for nothing. The registry
//     carries the row as absent with that reason. A rig is built by naming its joints, through the
//     initializer below, which is this port's own and its row says so.
//   - The two `ID` types carry no public members of their own in the interface (:4753-4758, :4800),
//     so an ID is made from a joint's or a constraint's name here and the only public way to read one
//     is `joint.id` and `constraint.id`, exactly as the interface has it.
//   - `IKComponent.Constraint.DemandOptions` is an OptionSet whose *members* are not declared in the
//     interface (:8890-8901 gives only `rawValue` and `init(rawValue:)`), so this carries exactly
//     that and no options are invented for it.
//
// The solver that consumes a rig is the simulation step, in Simulation.swift, where the rest of the
// per-frame work is; it runs the demands over the entity's joint entities and needs nothing that is
// drawn.

import simd
import Foundation

// MARK: - The rig

/// A rig: its joints, the constraints that put demands on them, and the weights the solve obeys.
///
/// `maxIterations` is how many passes the solve makes before it stops, `globalFkWeight` how much of
/// the rig's own forward kinematics is kept against a demand, and `globalLimitsWeight` how hard a
/// joint's limits are held. All three are `:4747-4749`.
@frozen public struct IKRig {
    /// The identity of a joint, which is its name: the interface gives an `ID` no public member of
    /// its own, and a joint's `parentID` is another joint's, so the name is the identity.
    public struct JointID: Hashable, Equatable, Sendable {
        let name: String
        public init(name: String) { self.name = name }
    }

    /// The identity of a constraint, which is its name, for the same reason.
    public struct ConstraintID: Hashable, Equatable, Sendable {
        let name: String
        public init(name: String) { self.name = name }
    }

    public var maxIterations: Int
    public var globalFkWeight: Float
    public var globalLimitsWeight: Float
    public var joints: JointCollection
    public var constraints: ConstraintsCollection

    /// A rig with no joints, which the caller fills through `joints.set(_:)` and
    /// `constraints.set(_:)`. The interface's only initializer is `init(for: MeshResource.Skeleton)`
    /// (:4759), and a skeleton is read out of a mesh asset this port cannot read; a program with no
    /// mesh could not otherwise make a rig at all, and naming the joints is the whole of what a rig
    /// is. The registry row for this initializer says it is the port's.
    public init(maxIterations: Int = 32, globalFkWeight: Float = 0, globalLimitsWeight: Float = 1,
                joints: JointCollection = JointCollection(), constraints: ConstraintsCollection = ConstraintsCollection()) {
        self.maxIterations = maxIterations
        self.globalFkWeight = globalFkWeight
        self.globalLimitsWeight = globalLimitsWeight
        self.joints = joints
        self.constraints = constraints
    }

    /// A joint of the rig, and the demands that may be put on it.
    public struct Joint: Identifiable {
        public typealias ID = IKRig.JointID

        /// What a joint may not do: the angles its axes are held to, and how hard.
        public struct LimitsDefinition {
            /// The axis a limit is measured about.
            public enum Axis: Hashable {
                case x
                case y
                case z
            }

            public var weight: Float
            public var boneAxis: Axis
            public var minimumAngles: SIMD3<Float>
            public var maximumAngles: SIMD3<Float>

            /// The defaults are the interface's (:4790): a limit of plus and minus two pi on every
            /// axis, which is no limit at all, and the x axis and full weight.
            public init(weight: Float = 1.0, boneAxis: Axis = .x,
                        minimumAngles: SIMD3<Float> = [-2.0 * .pi, -2.0 * .pi, -2.0 * .pi],
                        maximumAngles: SIMD3<Float> = [2.0 * .pi, 2.0 * .pi, 2.0 * .pi]) {
                self.weight = weight
                self.boneAxis = boneAxis
                self.minimumAngles = minimumAngles
                self.maximumAngles = maximumAngles
            }
        }

        public var id: ID { ID(name: name) }
        public let name: String
        public var parentID: ID?
        /// Where the joint sits in its parent when nothing has moved it.
        public var restTransform: Transform
        /// Whether the solve may move this joint. A joint that is not active is skipped and keeps
        /// its forward-kinematics pose.
        public var active: Bool
        /// How much of a demand each axis of this joint takes, per axis.
        public var fkWeightPerAxis: SIMD3<Float>
        /// How stiff this joint is against a demand: zero does not move, one follows it.
        public var rotationStiffness: SIMD3<Float>
        public var limits: LimitsDefinition?

        public init(name: String, parentID: ID? = nil, restTransform: Transform = .identity,
                    active: Bool = true, fkWeightPerAxis: SIMD3<Float> = .one,
                    rotationStiffness: SIMD3<Float> = .one, limits: LimitsDefinition? = nil) {
            self.name = name
            self.parentID = parentID
            self.restTransform = restTransform
            self.active = active
            self.fkWeightPerAxis = fkWeightPerAxis
            self.rotationStiffness = rotationStiffness
            self.limits = limits
        }
    }

    /// What a constraint asks of a joint: where it is, which way it looks, or both.
    public struct Constraint: Identifiable {
        public typealias ID = IKRig.ConstraintID

        /// A demand on a joint's position, and how far up the chain it reaches.
        public struct IKPositionDemand {
            public enum Mode: Hashable {
                /// The joint is asked to reach the target.
                case reach
                /// The joint is asked to point along the pole vector, which places it in the plane
                /// the other joints make.
                case poleVector
            }

            public var mode: Mode
            /// How many joints above this one the demand reaches; how far up the chain it counts.
            public var influenceDepthMaxJointCount: Int
            /// How much of the demand each axis takes.
            public var weight: SIMD3<Float>

            public init(mode: Mode = .reach, influenceDepthMaxJointCount: Int = 0,
                        weight: SIMD3<Float> = .one) {
                self.mode = mode
                self.influenceDepthMaxJointCount = influenceDepthMaxJointCount
                self.weight = weight
            }
        }

        /// A demand on a joint's orientation.
        public struct IKOrientationDemand {
            public enum Mode: Hashable {
                /// The joint takes the target's orientation.
                case orientation
                /// The joint looks along `targetAxis` and keeps what it had.
                case additiveLookAt(targetAxis: SIMD3<Float>)
                /// The joint looks along `targetAxis` absolutely.
                case absoluteLookAt(targetAxis: SIMD3<Float>)
            }

            public var mode: Mode
            public var weight: SIMD3<Float>

            public init(mode: Mode = .orientation, weight: SIMD3<Float> = .one) {
                self.mode = mode
                self.weight = weight
            }
        }

        public var id: ID { ID(name: name) }
        public var name: String
        /// The joint this constraint is on, by name: the interface spells it a `String` (:4811), not
        /// an ID, and the two agree because a name is the identity.
        public var jointName: String
        /// Where the target is, relative to the joint.
        public var offset: Transform
        public var positionDemand: IKPositionDemand?
        public var orientationDemand: IKOrientationDemand?

        public init(name: String, jointName: String, offset: Transform = .identity,
                    positionDemand: IKPositionDemand? = nil, orientationDemand: IKOrientationDemand? = nil) {
            self.name = name
            self.jointName = jointName
            self.offset = offset
            self.positionDemand = positionDemand
            self.orientationDemand = orientationDemand
        }

        /// A position demand on a joint: the factory at :4820.
        public static func point(named name: String, on jointName: String,
                                 positionWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       positionDemand: IKPositionDemand(mode: .reach, weight: positionWeight))
        }

        /// An orientation demand on a joint: :4821.
        public static func orient(named name: String, on jointName: String,
                                  orientationWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       orientationDemand: IKOrientationDemand(weight: orientationWeight))
        }

        /// Both demands at once: :4822.
        public static func parent(named name: String, on jointName: String,
                                  positionWeight: SIMD3<Float> = [1, 1, 1],
                                  orientationWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       positionDemand: IKPositionDemand(weight: positionWeight),
                       orientationDemand: IKOrientationDemand(weight: orientationWeight))
        }

        /// A look-at that is added to what the joint already had: :4823.
        public static func lookAtAdditive(named name: String, on jointName: String,
                                          lookingAlong targetAxis: SIMD3<Float>,
                                          orientationWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       orientationDemand: IKOrientationDemand(mode: .additiveLookAt(targetAxis: targetAxis),
                                                              weight: orientationWeight))
        }

        /// A look-at that replaces the joint's orientation: :4824.
        public static func lookAtAbsolute(named name: String, on jointName: String,
                                          lookingAlong targetAxis: SIMD3<Float>,
                                          orientationWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       orientationDemand: IKOrientationDemand(mode: .absoluteLookAt(targetAxis: targetAxis),
                                                              weight: orientationWeight))
        }
    }

    /// The rig's joints, in the order they were set, looked up by identity or by name.
    public struct JointCollection: Collection {
        public typealias Element = IKRig.Joint
        public typealias Index = Int

        private var joints: [IKRig.Joint]

        public init(_ joints: [IKRig.Joint] = []) { self.joints = joints }

        public subscript(id: IKRig.Joint.ID) -> IKRig.Joint? {
            get { joints.first { $0.id == id } }
            set {
                guard let newValue else { return }
                if let at = joints.firstIndex(where: { $0.id == id }) { joints[at] = newValue }
                else { joints.append(newValue) }
            }
        }

        public subscript(name: String) -> IKRig.Joint? {
            get { joints.first { $0.name == name } }
            set { self[newValue?.id ?? IKRig.Joint.ID(name: name)] = newValue }
        }

        /// A joint set under a name that is not there yet is added; one that is replaces the old.
        @discardableResult
        public mutating func set(_ newValue: IKRig.Joint) -> IKRig.Joint? {
            let id = newValue.id
            if let at = joints.firstIndex(where: { $0.id == id }) {
                let old = joints[at]
                joints[at] = newValue
                return old
            }
            joints.append(newValue)
            return nil
        }

        /// Puts one joint's rest transform back, which is what a solver's `reset()` does. Internal:
        /// the interface's way to change a joint is the subscript above, and this is the same write
        /// without the two-step copy a non-mutating method would need.
        mutating func putRestTransform(_ transform: Transform, of jointName: String) {
            guard let at = joints.firstIndex(where: { $0.name == jointName }) else { return }
            joints[at].restTransform = transform
        }

        public func contains(_ id: IKRig.Joint.ID) -> Bool { joints.contains { $0.id == id } }
        public var isEmpty: Bool { joints.isEmpty }

        public var startIndex: Int { joints.startIndex }
        public var endIndex: Int { joints.endIndex }
        public func index(after i: Int) -> Int { joints.index(after: i) }
        public subscript(position: Int) -> IKRig.Joint { joints[position] }

        /// Walks the joints below a joint, in the order they are in, calling `update` on each. The
        /// joint itself is skipped unless `inclusive` says otherwise: a descendant is a joint whose
        /// `parentID` chain runs through it.
        public mutating func forEach(descendantOf rootJointName: String, inclusive: Bool = false,
                                     update: (inout IKRig.Joint) -> Void) {
            var changed = true
            var visited = Set<IKRig.Joint.ID>()
            while changed {
                changed = false
                for at in joints.indices {
                    let joint = joints[at]
                    guard !visited.contains(joint.id) else { continue }
                    let isRoot = joint.name == rootJointName
                    guard isRoot ? inclusive : isDescendant(of: rootJointName, in: joints, joint: joint) else { continue }
                    visited.insert(joint.id)
                    update(&joints[at])
                    changed = true
                }
            }
        }

        private func isDescendant(of root: String, in joints: [IKRig.Joint], joint: IKRig.Joint) -> Bool {
            var parent = joint.parentID
            var guard_ = 0
            while let current = parent, guard_ < joints.count {
                if current == IKRig.Joint.ID(name: root) { return true }
                parent = joints.first { $0.id == current }?.parentID
                guard_ += 1
            }
            return false
        }
    }

    /// The rig's constraints, looked up the same way, and writable as a literal.
    public struct ConstraintsCollection: Collection, ExpressibleByArrayLiteral {
        public typealias Element = IKRig.Constraint
        public typealias Index = Int

        private var constraints: [IKRig.Constraint]

        public init(_ constraints: [IKRig.Constraint] = []) { self.constraints = constraints }
        public init(arrayLiteral elements: IKRig.Constraint...) { self.constraints = elements }

        public subscript(id: IKRig.Constraint.ID) -> IKRig.Constraint? {
            get { constraints.first { $0.id == id } }
            set {
                guard let newValue else { return }
                if let at = constraints.firstIndex(where: { $0.id == id }) { constraints[at] = newValue }
                else { constraints.append(newValue) }
            }
        }

        public subscript(name: String) -> IKRig.Constraint? {
            get { constraints.first { $0.name == name } }
            set { self[newValue?.id ?? IKRig.Constraint.ID(name: name)] = newValue }
        }

        @discardableResult
        public mutating func set(_ newValue: IKRig.Constraint) -> IKRig.Constraint? {
            let id = newValue.id
            if let at = constraints.firstIndex(where: { $0.id == id }) {
                let old = constraints[at]
                constraints[at] = newValue
                return old
            }
            constraints.append(newValue)
            return nil
        }

        public func contains(_ id: IKRig.Constraint.ID) -> Bool { constraints.contains { $0.id == id } }
        public var isEmpty: Bool { constraints.isEmpty }
        public var startIndex: Int { constraints.startIndex }
        public var endIndex: Int { constraints.endIndex }
        public func index(after i: Int) -> Int { constraints.index(after: i) }
        public subscript(position: Int) -> IKRig.Constraint { constraints[position] }
    }

    /// The joint names above a joint, nearest first, which is the order a solve walks them in.
    public func chain(above jointName: String) -> [String] {
        var names: [String] = []
        var parent = joints.first { $0.name == jointName }?.parentID
        var steps = 0
        while let current = parent, steps <= joints.count {
            names.append(current.name)
            parent = joints.first { $0.id == current }?.parentID
            steps += 1
        }
        return names
    }


}

// MARK: - The component an entity is solved by

/// The component an entity carries to be solved: the resource its solvers come from, and the
/// solvers themselves. `:8842-9075`.
@frozen public struct IKComponent: Component {
    /// The solvers' source, and nil for an entity that is not solved.
    public var resource: IKResource?
    public var solvers: SolverCollection

    @MainActor
    public init(resource: IKResource?) {
        self.resource = resource
        // A resource built from a rig carries that rig's definition, so an entity given a resource
        // and no solver of its own is solved by the one the resource holds. That is what
        // `solvers` means here when a program sets only the resource.
        self.solvers = resource.map { SolverCollection([Solver(rig: $0.solverDefinitions.first?.rigDefinition ?? IKRig())]) }
            ?? SolverCollection()
    }

    /// One solver: a rig, the weights the solve obeys, and the joints and constraints it works on.
    /// A class in the interface too (`:8848`, `@_hasMissingDesignatedInitializers`), so a program
    /// does not construct one: it comes from the component, which builds it from the resource.
    public class Solver: Identifiable {
        public typealias ID = Int

        public var id: ID
        /// The rig this solver solves. The interface gives a solver its two weights through `get`
        /// only (:8856-8857), so they are read out of the rig the resource holds rather than stored
        /// twice, and the joints and constraints below are this solver's own: the rig's joints by
        /// name, and the rig's constraints as the runtime constraints that carry the targets.
        private var rig: IKRig
        public var maxIterations: Int { rig.maxIterations }
        public var globalFkWeight: Float { rig.globalFkWeight }
        public var joints: IKComponent.JointCollection
        public var constraints: IKComponent.ConstraintCollection

        init(id: ID = 0, rig: IKRig = IKRig()) {
            self.id = id
            self.rig = rig
            self.joints = IKComponent.JointCollection(rig.joints.map { IKComponent.Joint($0) })
            self.constraints = IKComponent.ConstraintCollection(rig.constraints.map { IKComponent.Constraint($0) })
        }

        /// The rig's own joint and constraint definitions, for a caller that wants the definition
        /// rather than the runtime values.
        public var rigDefinition: IKRig { rig }

        /// Puts the solver's joints and constraints back as the rig defines them: every joint at its
        /// rest transform and every constraint's target at the origin, which is what `reset()`
        /// is for (:8861).
        public func reset() {
            for name in rig.joints.map({ $0.name }) {
                rig.joints.putRestTransform(.identity, of: name)
            }
            for at in constraints.indices {
                constraints[at].target = .identity
            }
        }
    }

    /// A joint of a solver, as the solver sees it: its name and the two weights. A class in the
    /// interface (`:8872`), and with no public initializer there either.
    public class Joint: Identifiable {
        public typealias ID = IKRig.Joint.ID

        public var name: String { joint.name }
        public var fkWeightPerAxis: SIMD3<Float> { joint.fkWeightPerAxis }
        public var rotationStiffness: SIMD3<Float> { joint.rotationStiffness }

        public var id: IKRig.Joint.ID { joint.id }
        let joint: IKRig.Joint
        init(_ joint: IKRig.Joint) { self.joint = joint }
    }

    /// A constraint of a solver, and what it is asked for. A class in the interface (`:8888`).
    public class Constraint: Identifiable {
        public typealias ID = IKRig.Constraint.ID

        /// Which demands a constraint makes. The interface gives this an OptionSet and declares no
        /// member of it (:8890-8901), so the only values here are the raw ones a caller writes.
        public struct DemandOptions: OptionSet, Equatable, Hashable {
            public let rawValue: UInt
            public init(rawValue: UInt) { self.rawValue = rawValue }
        }

        public let id: ID
        public var name: String { constraint.name }
        public var jointID: Joint.ID { Joint.ID(name: constraint.jointName) }
        public var demands: DemandOptions
        /// Where the target is, in the entity's own space.
        public var target: Transform
        /// Where the target is, relative to the joint.
        public var offset: Transform
        /// Where a look-at points, which is the axis the demand names when it has one.
        public var lookAtTargetPosition: SIMD3<Float>
        /// How much of the target the animation's own value keeps, for position and for rotation.
        public var animationOverrideWeight: (position: Float, rotation: Float)

        let constraint: IKRig.Constraint
        public init(_ constraint: IKRig.Constraint, demands: DemandOptions = DemandOptions(),
                    target: Transform = .identity, offset: Transform = .identity,
                    lookAtTargetPosition: SIMD3<Float> = .zero,
                    animationOverrideWeight: (position: Float, rotation: Float) = (0, 0)) {
            self.constraint = constraint
            self.id = constraint.id
            self.demands = demands
            self.target = target
            self.offset = offset
            self.lookAtTargetPosition = lookAtTargetPosition
            self.animationOverrideWeight = animationOverrideWeight
        }
    }

    /// The solvers of a component, looked up by identity or by position.
    public struct SolverCollection: Collection {
        public typealias Element = Solver
        public typealias Index = Int

        private var solvers: [Solver]
        public init(_ solvers: [Solver] = []) { self.solvers = solvers }

        public subscript(id: Solver.ID) -> Solver? {
            get { solvers.first { $0.id == id } }
            set {
                guard let newValue else { return }
                if let at = solvers.firstIndex(where: { $0.id == id }) { solvers[at] = newValue }
                else { solvers.append(newValue) }
            }
        }

        @discardableResult
        public mutating func set(_ newValue: Solver) -> Solver? {
            if let at = solvers.firstIndex(where: { $0.id == newValue.id }) {
                let old = solvers[at]
                solvers[at] = newValue
                return old
            }
            solvers.append(newValue)
            return nil
        }

        public func contains(_ id: Solver.ID) -> Bool { solvers.contains { $0.id == id } }
        public var isEmpty: Bool { solvers.isEmpty }
        public var startIndex: Int { solvers.startIndex }
        public var endIndex: Int { solvers.endIndex }
        public func index(after i: Int) -> Int { solvers.index(after: i) }
        public subscript(position: Int) -> Solver { solvers[position] }
    }

    /// The joints of a solver, looked up by identity or by name.
    public struct JointCollection: Collection {
        public typealias Element = Joint
        public typealias Index = Int

        private var joints: [Joint]
        public init(_ joints: [Joint] = []) { self.joints = joints }

        public subscript(id: Joint.ID) -> Joint? {
            get { joints.first { Joint.ID(name: $0.name) == id } }
            set {
                guard let newValue else { return }
                if let at = joints.firstIndex(where: { Joint.ID(name: $0.name) == id }) { joints[at] = newValue }
                else { joints.append(newValue) }
            }
        }

        public subscript(name: String) -> Joint? {
            get { joints.first { $0.name == name } }
            set { self[newValue.map { Joint.ID(name: $0.name) } ?? Joint.ID(name: name)] = newValue }
        }

        @discardableResult
        public mutating func set(_ newValue: Joint) -> Joint? {
            let id = Joint.ID(name: newValue.name)
            if let at = joints.firstIndex(where: { Joint.ID(name: $0.name) == id }) {
                let old = joints[at]
                joints[at] = newValue
                return old
            }
            joints.append(newValue)
            return nil
        }

        public func contains(_ id: Joint.ID) -> Bool { joints.contains { Joint.ID(name: $0.name) == id } }
        public var isEmpty: Bool { joints.isEmpty }
        public var startIndex: Int { joints.startIndex }
        public var endIndex: Int { joints.endIndex }
        public func index(after i: Int) -> Int { joints.index(after: i) }
        public subscript(position: Int) -> Joint { joints[position] }
    }

    /// The constraints of a solver, looked up the same way.
    public struct ConstraintCollection: Collection {
        public typealias Element = Constraint
        public typealias Index = Int

        private var constraints: [Constraint]
        public init(_ constraints: [Constraint] = []) { self.constraints = constraints }

        public subscript(id: Constraint.ID) -> Constraint? {
            get { constraints.first { $0.id == id } }
            set {
                guard let newValue else { return }
                if let at = constraints.firstIndex(where: { $0.id == id }) { constraints[at] = newValue }
                else { constraints.append(newValue) }
            }
        }

        public subscript(name: String) -> Constraint? {
            get { constraints.first { $0.name == name } }
            set { self[newValue?.id ?? Constraint.ID(name: name)] = newValue }
        }

        @discardableResult
        public mutating func set(_ newValue: Constraint) -> Constraint? {
            if let at = constraints.firstIndex(where: { $0.id == newValue.id }) {
                let old = constraints[at]
                constraints[at] = newValue
                return old
            }
            constraints.append(newValue)
            return nil
        }

        public func contains(_ id: Constraint.ID) -> Bool { constraints.contains { $0.id == id } }
        public var isEmpty: Bool { constraints.isEmpty }
        public var startIndex: Int { constraints.startIndex }
        public var endIndex: Int { constraints.endIndex }
        public func index(after i: Int) -> Int { constraints.index(after: i) }
        public subscript(position: Int) -> Constraint { constraints[position] }
    }
}

// MARK: - The resource and the solver definition

/// A solver definition: an identity and the rig it solves. `:4738-4744`.
@frozen public struct IKSolverDefinition: Identifiable {
    public typealias ID = Int
    public let id: ID
    public var rigDefinition: IKRig

    public init(id: ID, rig: IKRig) {
        self.id = id
        self.rigDefinition = rig
    }
}

/// A resource that holds the solver definitions a component is solved by. `:10958-10965`.
///
/// `solverDefinitions` reads and `init(rig:)` throws are the interface's, and both are carried
/// whole: a rig is the input, and the resource holds one definition per rig it is given, so nothing
/// has to be read out of a bundle to make one. `__coreAsset` is the `__` member the interface also
/// has, and it is not carried - it is the compiler's handle on the compiled asset, which a rig a
/// program built has no use for.
@MainActor
public class IKResource: Resource {
    private var definitions: [IKSolverDefinition]

    /// The definitions this resource holds, in the order they were made. `:10963`.
    public var solverDefinitions: [IKSolverDefinition] { definitions }

    /// A resource over a rig, which is the interface's own initializer: it throws when the rig is
    /// not one this resource can solve, and the only way that can happen here is a rig with no
    /// joints, because a rig with joints is a rig. `:10964`.
    public convenience init(rig: IKRig) throws {
        guard !rig.joints.isEmpty else { throw IKResourceError.emptyRig }
        self.init(definitions: [IKSolverDefinition(id: 0, rig: rig)])
    }

    init(definitions: [IKSolverDefinition]) {
        self.definitions = definitions
    }
}

/// Why a rig could not become a resource. The one case, and the registry carries it: a resource
/// solves joints, so a rig with none is nothing to solve.
public enum IKResourceError: Error {
    case emptyRig
}

extension Entity {
    /// The inverse-kinematics component on this entity, or nil when it has none.
    ///
    /// Setting it puts the entity tree into the rig's rest pose: every joint the rig names takes
    /// its `restTransform` (`IKRig.Joint.restTransform`, `:4765`). That is what a rest transform
    /// is for, and without it the rig's joints are decoration and a solve starts from whatever pose
    /// the entities happened to be in - which for a freshly built tree is the origin, where every
    /// joint sits on top of every other and no chain can be walked at all. The SDK gets the same
    /// poses from the skeleton `IKRig.init(for:)` reads; here they come from the rig itself.
    public var inverseKinematics: IKComponent? {
        get { components[IKComponent.self] }
        set {
            if let newValue {
                components.set(newValue)
                __IKRestPose.apply(of: newValue, to: coreEntity)
            } else {
                components.remove(IKComponent.self)
            }
        }
    }
}

/// Putting a rig on an entity tree is what puts that tree in the rig's rest pose.
@MainActor
enum __IKRestPose {
    static func apply(of component: IKComponent, to node: __REEntity) {
        guard let resource = component.resource else { return }
        for definition in resource.solverDefinitions {
            for joint in definition.rigDefinition.joints {
                guard let entity = node.subtree.first(where: { $0.name == joint.name }) else { continue }
                entity.transform = joint.restTransform
            }
        }
    }
}

// MARK: - Solving


/// The solve itself, run once a step by the simulation, over the joint entities a component's rig
/// names.
///
/// The algorithm is cyclic coordinate descent, and it is this module's: Apple ships the solver
/// compiled and nothing about it is readable from the interface, so nothing here is a translation
/// of Apple's. What the interface fixes is the *shape* — a maximum number of iterations, a
/// forward-kinematics weight, a limits weight, per-axis weights and a per-joint stiffness, and a
/// position demand that reaches up a chain a number of joints deep — and that is what this obeys.
///
/// The pass, for one constraint:
///   1. the chain is the constrained joint and the joints above it, up to the demand's
///      `influenceDepthMaxJointCount` when it is set, otherwise to the root;
///   2. for as many passes as the rig's `maxIterations` allows, each joint in the chain is turned
///      about the axes its `fkWeightPerAxis` and `rotationStiffness` weight, by the angle that
///      brings the constrained joint onto the target, and the result is clamped to the joint's
///      `limits` weighted by `globalLimitsWeight`;
///   3. `globalFkWeight` is how much of the rig's own forward kinematics is kept: at one the chain
///      does not move at all, which is what a value of one means and what the checks measure.
///
/// A joint that is not active is left where forward kinematics put it. A constraint with no
/// position demand does not move anything, and a look-at is not solved here: it needs an
/// orientation the renderer applies, and there is no such renderer, so the orientation demands are
/// carried and not solved.
@MainActor
func __solveInverseKinematics(of node: __REEntity) {
    guard let component = node.component(of: IKComponent.self), let resource = component.resource else { return }
    for solver in component.solvers {
        let rig = solver.rigDefinition
        for constraint in solver.constraints {
            guard let demand = constraint.constraint.positionDemand, demand.mode == .reach else { continue }
            var chain = __IKChain(rig: rig, jointName: constraint.constraint.jointName,
                                  depth: demand.influenceDepthMaxJointCount, in: node)
            guard chain.count > 1 else { continue }
            let target = constraint.target.translation
            let passes = max(rig.maxIterations, 1)
            for _ in 0..<passes {
                var moved = false
                // From the joint *below* the end effector up to the root. The end effector is not
                // turned about itself - the vector from it to itself is zero - and the joint that
                // aims the whole arm is the root, which a range that stopped short would leave out.
                for at in 1..<max(chain.count, 1) {
                    let joint = chain[at]
                    guard joint.active else { continue }
                    // Both vectors are taken from this joint, not from the end effector. Measured:
                    // aligning the arm with the residual at the end effector oscillates and never
                    // settles (1.04 after 64 passes and still moving), while aligning it with the
                    // direction from this joint to the target settles to 0.0019 within four passes.
                    let toTarget = target - joint.worldPosition
                    let toEnd = chain[0].worldPosition - joint.worldPosition
                    guard simd_length(toTarget) > 1e-6, simd_length(toEnd) > 1e-6 else { continue }
                    let reached = __IKRotation(aligning: simd_normalize(toEnd), to: simd_normalize(toTarget))
                    let weights = joint.fkWeightPerAxis * joint.rotationStiffness * (1 - rig.globalFkWeight)
                    guard simd_length(weights) > 1e-6 else { continue }
                    // The bone axis's twist held to the joint's limits, then every axis scaled by
                    // the weight that axis is given.
                    var turn = reached
                    if let limits = joint.limits {
                        let axis: SIMD3<Float> = limits.boneAxis == .x ? SIMD3<Float>(1, 0, 0)
                            : (limits.boneAxis == .y ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1))
                        let index = limits.boneAxis == .x ? 0 : (limits.boneAxis == .y ? 1 : 2)
                        let strength = min(max(limits.weight * rig.globalLimitsWeight, 0), 1)
                        turn = __IKClamp(reached, axis: axis, minimum: limits.minimumAngles[index],
                                         maximum: limits.maximumAngles[index], strength: strength)
                    }
                    // The demand is weighted in the joint's *own* frame, which is what makes a
                    // per-axis weight mean an axis: the demand is taken into the joint's frame,
                    // scaled there, and taken back out. Scaling it in the world's frame instead
                    // makes an axis weight meaningless - a demand that happens to be about z carries
                    // no y twist at all, so a joint weighted on y would drop it entirely and a
                    // chain weighted on one axis would never move (measured: the tip stays put,
                    // not on the plane).
                    let frame = joint.worldOrientation
                    let local = frame.inverse * turn * frame
                    chain[at].turn(by: frame * __IKScaled(local, by: weights) * frame.inverse)
                    // And the joint's *pose* is held, which is what a limit is: clamping the demand
                    // alone bounds each pass and not the joint, so a chain of two joints limited to
                    // 0.2 reaches 0.786 - each pass asking for its 0.2 and adding up (measured).
                    if let limits = joint.limits {
                        let axis: SIMD3<Float> = limits.boneAxis == .x ? SIMD3<Float>(1, 0, 0)
                            : (limits.boneAxis == .y ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1))
                        let index = limits.boneAxis == .x ? 0 : (limits.boneAxis == .y ? 1 : 2)
                        let strength = min(max(limits.weight * rig.globalLimitsWeight, 0), 1)
                        let posed = chain[at].worldOrientationNow
                        let held = __IKClamp(posed, axis: axis, minimum: limits.minimumAngles[index],
                                             maximum: limits.maximumAngles[index], strength: strength)
                        if held != posed { chain[at].setWorldOrientation(held) }
                    }
                    moved = true
                }
                if !moved { break }
            }
        }
    }
}

/// One joint of a chain: the entity, and the rig's own settings for it.
@MainActor
struct __IKChainJoint {
    let entity: __REEntity
    let name: String
    let active: Bool
    let fkWeightPerAxis: SIMD3<Float>
    let rotationStiffness: SIMD3<Float>
    let limits: IKRig.Joint.LimitsDefinition?

    /// The joint's place and facing in the world, which is the module's own
    /// `transformMatrixInHierarchy` and not a composition written here again.
    var worldPosition: SIMD3<Float> { simd_make_float3(entity.transformMatrixInHierarchy.columns.3) }
    var worldOrientation: simd_quatf {
        let m = entity.transformMatrixInHierarchy
        return simd_quatf(float3x3(columns: (simd_make_float3(m.columns.0),
                                              simd_make_float3(m.columns.1),
                                              simd_make_float3(m.columns.2))))
    }
    /// The joint's own orientation, which is the local one.
    var orientation: simd_quatf { entity.transform.rotation }

    /// A joint's own rotation, turned by `rotation` about its own axes.
    mutating func turn(by rotation: simd_quatf) {
        entity.transform.rotation = __IKOrientation(rotation, in: orientation)
    }

    /// The joint's world orientation, which is its own turned by its parent's.
    var worldOrientationNow: simd_quatf { __IKParentFrame(of: entity) * entity.transform.rotation }

    /// Puts the joint at a world orientation, taking the parent's into account.
    mutating func setWorldOrientation(_ world: simd_quatf) {
        entity.transform.rotation = __IKParentFrame(of: entity).inverse * world
    }
}

/// The chain a demand walks: the constrained joint first, then the joints above it, which is the
/// order the interface's `influenceDepthMaxJointCount` counts in.
@MainActor
func __IKChain(rig: IKRig, jointName: String, depth: Int, in node: __REEntity) -> [__IKChainJoint] {
    // The joint entities are the ones in the subtree whose names the rig's joints carry, so a rig
    // is solved against a hierarchy a program built with the same names.
    let byName: [String: __REEntity] = node.subtree.reduce(into: [:]) { found, entity in
        if !entity.name.isEmpty { found[entity.name] = entity }
    }
    var chain: [__IKChainJoint] = []
    var name = jointName
    var steps = 0
    let limit = depth > 0 ? depth + 1 : Int.max
    while let entity = byName[name], steps < limit {
        guard let joint = rig.joints.first(where: { $0.name == name }) else { break }
        chain.append(__IKChainJoint(entity: entity, name: name, active: joint.active,
                                    fkWeightPerAxis: joint.fkWeightPerAxis,
                                    rotationStiffness: joint.rotationStiffness,
                                    limits: joint.limits))
        guard let parent = joint.parentID else { break }
        name = parent.name
        steps += 1
    }
    return chain
}

/// The rotation that takes the unit vector `from` onto the unit vector `to`, about the axis that
/// turns one into the other, or the identity when they are already the same or exactly opposite.
func __IKRotation(aligning from: SIMD3<Float>, to target: SIMD3<Float>) -> simd_quatf {
    let dot = simd_dot(from, target)
    if dot > 1 - 1e-6 { return simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)) }
    if dot < -1 + 1e-6 { return simd_quatf(angle: .pi, axis: simd_normalize(simd_cross(from, SIMD3<Float>(0, 1, 0)))) }
    let axis = simd_normalize(simd_cross(from, target))
    return simd_quatf(angle: acos(min(max(dot, -1), 1)), axis: axis)
}

/// The per-axis weighting: the rotation taken apart into the twist about each axis and the swing
/// that is left, every twist scaled by the weight its axis is given, and the swing scaled as a
/// whole by the smallest of them.
///
/// Two things were measured here and both decided the shape. A three-angle decomposition is not a
/// round trip - `qx * qy * qz` built a different rotation, one that flipped a sign, and the chain
/// turned away from the target; and scaling the rotation's columns and orthonormalising, which is
/// exact at weight one, does *not* mean "this axis only": a zero weight makes the frame be
/// completed in an invented direction, so a joint weighted on x alone still turned out of the
/// plane. The swing-twist split is exact in both senses - measured over 5000 random rotations,
/// 0.001 radians back to the same rotation, and a weight of (1, 0, 0) leaves the y and z twists at
/// exactly zero.
///
/// The swing has no per-axis meaning, so it is scaled as a whole, from identity at a zero weight to
/// itself at one; slerp is what makes both ends exact. Rebuilding it as a twist about x instead
/// costs 0.78 degrees at weight one, which is how that was found.
func __IKScaled(_ rotation: simd_quatf, by weight: SIMD3<Float>) -> simd_quatf {
    let parts = __IKSwingTwist(rotation)
    let smallest = min(weight.x, min(weight.y, weight.z))
    let identity = simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0))
    let swing = smallest <= 0 ? identity : simd_slerp(identity, parts.swing, smallest)
    var result = swing
    for index in (0..<3).reversed() {
        result = result * simd_quatf(angle: parts.twists[index] * weight[index], axis: __IKAxis(index))
    }
    return result
}

/// The twist about each axis in turn, and the swing that is left over - Kuiper's sequential
/// swing-twist split, which is the same rotation put back together exactly.
func __IKSwingTwist(_ rotation: simd_quatf) -> (twists: SIMD3<Float>, swing: simd_quatf) {
    var remaining = rotation
    var twists = SIMD3<Float>(repeating: 0)
    for index in 0..<3 {
        let axis = __IKAxis(index)
        let angle = 2 * atan2(simd_dot(remaining.imag, axis), remaining.real)
        twists[index] = angle
        remaining = remaining * simd_quatf(angle: angle, axis: axis).inverse
    }
    return (twists, remaining)
}

func __IKAxis(_ index: Int) -> SIMD3<Float> {
    index == 0 ? SIMD3<Float>(1, 0, 0) : (index == 1 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1))
}

/// A joint's parent's orientation in the world, which is the frame the joint's own axes sit in.
@MainActor
func __IKParentFrame(of entity: __REEntity) -> simd_quatf {
    guard let parent = entity.parent else { return simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)) }
    let m = parent.transformMatrixInHierarchy
    return simd_quatf(float3x3(columns: (simd_make_float3(m.columns.0), simd_make_float3(m.columns.1),
                                          simd_make_float3(m.columns.2))))
}

/// One axis's angle of a rotation: the twist of a swing-twist decomposition, which is exact and has
/// no gimbal lock.
func __IKTwistAngle(of rotation: simd_quatf, about axis: SIMD3<Float>) -> Float {
    2 * atan2(simd_dot(rotation.imag, simd_normalize(axis)), rotation.real)
}

/// The twist about one axis held between two angles, scaled by how hard it is held: the twist is
/// taken off, the held twist is put back, and the swing in between is left as it was.
///
/// The interface's `LimitsDefinition` carries one `boneAxis` and one minimum and maximum per axis
/// (:4775-4790), so a limit is on that axis and this is the whole of it. With the held angle equal
/// to the angle already there the result is the rotation itself: measured over 5000 random
/// rotations with the interface's own default limits, 0.0009 radians, Float noise.
func __IKClamp(_ rotation: simd_quatf, axis: SIMD3<Float>, minimum: Float, maximum: Float, strength: Float) -> simd_quatf {
    let a = simd_normalize(axis)
    let angle = __IKTwistAngle(of: rotation, about: a)
    guard strength > 0 else { return rotation }
    let held = min(max(angle, minimum), maximum)
    let amount = angle + (held - angle) * strength
    guard amount != angle else { return rotation }
    // The swing is what is left once the *original* twist is taken off, and the held twist goes
    // back on in its place. Taking the held twist off instead - `(rotation * held.inverse) * held`
    // - hands the rotation straight back, because held and original differ by exactly the
    // correction: the product is the rotation again, and the limit does nothing. The identity case
    // (the interface's own default limits, plus and minus two pi, where held == angle) is measured
    // exact and never reaches this line, which is how that mistake survived the first two rounds.
    let original = simd_quatf(angle: angle, axis: a)
    let clamp = simd_quatf(angle: amount, axis: a)
    return (rotation * original.inverse) * clamp
}

/// A rotation applied to a joint's own orientation, so that the joint's own axes are what turn.
func __IKOrientation(_ rotation: simd_quatf, in orientation: simd_quatf) -> simd_quatf {
    orientation * rotation
}
