import simd
import Foundation

@frozen public struct IKRig {
    public struct JointID: Hashable, Equatable, Sendable {
        let name: String
        public init(name: String) { self.name = name }
    }

    public struct ConstraintID: Hashable, Equatable, Sendable {
        let name: String
        public init(name: String) { self.name = name }
    }

    public var maxIterations: Int
    public var globalFkWeight: Float
    public var globalLimitsWeight: Float
    public var joints: JointCollection
    public var constraints: ConstraintsCollection

    public init(maxIterations: Int = 32, globalFkWeight: Float = 0, globalLimitsWeight: Float = 1,
                joints: JointCollection = JointCollection(), constraints: ConstraintsCollection = ConstraintsCollection()) {
        self.maxIterations = maxIterations
        self.globalFkWeight = globalFkWeight
        self.globalLimitsWeight = globalLimitsWeight
        self.joints = joints
        self.constraints = constraints
    }

    public struct Joint: Identifiable {
        public typealias ID = IKRig.JointID

        public struct LimitsDefinition {
            public enum Axis: Hashable {
                case x
                case y
                case z
            }

            public var weight: Float
            public var boneAxis: Axis
            public var minimumAngles: SIMD3<Float>
            public var maximumAngles: SIMD3<Float>

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
        public var restTransform: Transform
        public var active: Bool
        public var fkWeightPerAxis: SIMD3<Float>
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

    public struct Constraint: Identifiable {
        public typealias ID = IKRig.ConstraintID

        public struct IKPositionDemand {
            public enum Mode: Hashable {
                case reach
                case poleVector
            }

            public var mode: Mode
            public var influenceDepthMaxJointCount: Int
            public var weight: SIMD3<Float>

            public init(mode: Mode = .reach, influenceDepthMaxJointCount: Int = 0,
                        weight: SIMD3<Float> = .one) {
                self.mode = mode
                self.influenceDepthMaxJointCount = influenceDepthMaxJointCount
                self.weight = weight
            }
        }

        public struct IKOrientationDemand {
            public enum Mode: Hashable {
                case orientation
                case additiveLookAt(targetAxis: SIMD3<Float>)
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
        public var jointName: String
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

        public static func point(named name: String, on jointName: String,
                                 positionWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       positionDemand: IKPositionDemand(mode: .reach, weight: positionWeight))
        }

        public static func orient(named name: String, on jointName: String,
                                  orientationWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       orientationDemand: IKOrientationDemand(weight: orientationWeight))
        }

        public static func parent(named name: String, on jointName: String,
                                  positionWeight: SIMD3<Float> = [1, 1, 1],
                                  orientationWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       positionDemand: IKPositionDemand(weight: positionWeight),
                       orientationDemand: IKOrientationDemand(weight: orientationWeight))
        }

        public static func lookAtAdditive(named name: String, on jointName: String,
                                          lookingAlong targetAxis: SIMD3<Float>,
                                          orientationWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       orientationDemand: IKOrientationDemand(mode: .additiveLookAt(targetAxis: targetAxis),
                                                              weight: orientationWeight))
        }

        public static func lookAtAbsolute(named name: String, on jointName: String,
                                          lookingAlong targetAxis: SIMD3<Float>,
                                          orientationWeight: SIMD3<Float> = [1, 1, 1]) -> Constraint {
            Constraint(name: name, jointName: jointName,
                       orientationDemand: IKOrientationDemand(mode: .absoluteLookAt(targetAxis: targetAxis),
                                                              weight: orientationWeight))
        }
    }

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

@frozen public struct IKComponent: Component {
    public var resource: IKResource?
    public var solvers: SolverCollection

    @MainActor
    public init(resource: IKResource?) {
        self.resource = resource
        self.solvers = resource.map { SolverCollection([Solver(rig: $0.solverDefinitions.first?.rigDefinition ?? IKRig())]) }
            ?? SolverCollection()
    }

    public class Solver: Identifiable {
        public typealias ID = Int

        public var id: ID
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

        public var rigDefinition: IKRig { rig }

        public func reset() {
            for name in rig.joints.map({ $0.name }) {
                rig.joints.putRestTransform(.identity, of: name)
            }
            for at in constraints.indices {
                constraints[at].target = .identity
            }
        }
    }

    public class Joint: Identifiable {
        public typealias ID = IKRig.Joint.ID

        public var name: String { joint.name }
        public var fkWeightPerAxis: SIMD3<Float> { joint.fkWeightPerAxis }
        public var rotationStiffness: SIMD3<Float> { joint.rotationStiffness }

        public var id: IKRig.Joint.ID { joint.id }
        let joint: IKRig.Joint
        init(_ joint: IKRig.Joint) { self.joint = joint }
    }

    public class Constraint: Identifiable {
        public typealias ID = IKRig.Constraint.ID

        public struct DemandOptions: OptionSet, Equatable, Hashable {
            public let rawValue: UInt
            public init(rawValue: UInt) { self.rawValue = rawValue }
        }

        public let id: ID
        public var name: String { constraint.name }
        public var jointID: Joint.ID { Joint.ID(name: constraint.jointName) }
        public var demands: DemandOptions
        public var target: Transform
        public var offset: Transform
        public var lookAtTargetPosition: SIMD3<Float>
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

@frozen public struct IKSolverDefinition: Identifiable {
    public typealias ID = Int
    public let id: ID
    public var rigDefinition: IKRig

    public init(id: ID, rig: IKRig) {
        self.id = id
        self.rigDefinition = rig
    }
}

@MainActor
public class IKResource: Resource {
    private var definitions: [IKSolverDefinition]

    public var solverDefinitions: [IKSolverDefinition] { definitions }

    public convenience init(rig: IKRig) throws {
        guard !rig.joints.isEmpty else { throw IKResourceError.emptyRig }
        self.init(definitions: [IKSolverDefinition(id: 0, rig: rig)])
    }

    init(definitions: [IKSolverDefinition]) {
        self.definitions = definitions
    }
}

public enum IKResourceError: Error {
    case emptyRig
}

extension Entity {
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
                for at in 1..<max(chain.count, 1) {
                    let joint = chain[at]
                    guard joint.active else { continue }
                    let toTarget = target - joint.worldPosition
                    let toEnd = chain[0].worldPosition - joint.worldPosition
                    guard simd_length(toTarget) > 1e-6, simd_length(toEnd) > 1e-6 else { continue }
                    let reached = __IKRotation(aligning: simd_normalize(toEnd), to: simd_normalize(toTarget))
                    let weights = joint.fkWeightPerAxis * joint.rotationStiffness * (1 - rig.globalFkWeight)
                    guard simd_length(weights) > 1e-6 else { continue }
                    var turn = reached
                    if let limits = joint.limits {
                        let axis: SIMD3<Float> = limits.boneAxis == .x ? SIMD3<Float>(1, 0, 0)
                            : (limits.boneAxis == .y ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1))
                        let index = limits.boneAxis == .x ? 0 : (limits.boneAxis == .y ? 1 : 2)
                        let strength = min(max(limits.weight * rig.globalLimitsWeight, 0), 1)
                        turn = __IKClamp(reached, axis: axis, minimum: limits.minimumAngles[index],
                                         maximum: limits.maximumAngles[index], strength: strength)
                    }
                    let frame = joint.worldOrientation
                    let local = frame.inverse * turn * frame
                    chain[at].turn(by: frame * __IKScaled(local, by: weights) * frame.inverse)
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

@MainActor
struct __IKChainJoint {
    let entity: __REEntity
    let name: String
    let active: Bool
    let fkWeightPerAxis: SIMD3<Float>
    let rotationStiffness: SIMD3<Float>
    let limits: IKRig.Joint.LimitsDefinition?

    var worldPosition: SIMD3<Float> { simd_make_float3(entity.transformMatrixInHierarchy.columns.3) }
    var worldOrientation: simd_quatf {
        let m = entity.transformMatrixInHierarchy
        return simd_quatf(float3x3(columns: (simd_make_float3(m.columns.0),
                                              simd_make_float3(m.columns.1),
                                              simd_make_float3(m.columns.2))))
    }
    var orientation: simd_quatf { entity.transform.rotation }

    mutating func turn(by rotation: simd_quatf) {
        entity.transform.rotation = __IKOrientation(rotation, in: orientation)
    }

    var worldOrientationNow: simd_quatf { __IKParentFrame(of: entity) * entity.transform.rotation }

    mutating func setWorldOrientation(_ world: simd_quatf) {
        entity.transform.rotation = __IKParentFrame(of: entity).inverse * world
    }
}

@MainActor
func __IKChain(rig: IKRig, jointName: String, depth: Int, in node: __REEntity) -> [__IKChainJoint] {
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

func __IKRotation(aligning from: SIMD3<Float>, to target: SIMD3<Float>) -> simd_quatf {
    let dot = simd_dot(from, target)
    if dot > 1 - 1e-6 { return simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)) }
    if dot < -1 + 1e-6 { return simd_quatf(angle: .pi, axis: simd_normalize(simd_cross(from, SIMD3<Float>(0, 1, 0)))) }
    let axis = simd_normalize(simd_cross(from, target))
    return simd_quatf(angle: acos(min(max(dot, -1), 1)), axis: axis)
}

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

@MainActor
func __IKParentFrame(of entity: __REEntity) -> simd_quatf {
    guard let parent = entity.parent else { return simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)) }
    let m = parent.transformMatrixInHierarchy
    return simd_quatf(float3x3(columns: (simd_make_float3(m.columns.0), simd_make_float3(m.columns.1),
                                          simd_make_float3(m.columns.2))))
}

func __IKTwistAngle(of rotation: simd_quatf, about axis: SIMD3<Float>) -> Float {
    2 * atan2(simd_dot(rotation.imag, simd_normalize(axis)), rotation.real)
}

func __IKClamp(_ rotation: simd_quatf, axis: SIMD3<Float>, minimum: Float, maximum: Float, strength: Float) -> simd_quatf {
    let a = simd_normalize(axis)
    let angle = __IKTwistAngle(of: rotation, about: a)
    guard strength > 0 else { return rotation }
    let held = min(max(angle, minimum), maximum)
    let amount = angle + (held - angle) * strength
    guard amount != angle else { return rotation }
    let original = simd_quatf(angle: angle, axis: a)
    let clamp = simd_quatf(angle: amount, axis: a)
    return (rotation * original.inverse) * clamp
}

func __IKOrientation(_ rotation: simd_quatf, in orientation: simd_quatf) -> simd_quatf {
    orientation * rotation
}
