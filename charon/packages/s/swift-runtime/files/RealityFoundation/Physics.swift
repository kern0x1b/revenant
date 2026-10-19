// The physics: the components that make an entity a body, the joints that tie two together, and
// the CPU solver that moves them.
//
// The solver is ours, and what it computes is stated rather than implied: gravity is Apple's
// documented (0, -9.81, 0) — the host's own `Scene.__gravity` reads nil, which is the engine
// default and not a per-scene override — a sphere is collided exactly, a box exactly against a
// sphere and by the separating axis test against another box, a capsule as the chain of three
// spheres along its axis, and a convex hull as the box its bounds give until the mesh round
// measures a real hull. The step is semi-implicit Euler: the velocity first, then the position
// from the new velocity, which is the stable order for an explicit integrator.

import simd
import Foundation

// MARK: - The components

/// How a body takes part in the simulation.
public enum PhysicsBodyMode: Hashable {
    /// Never moves, and is of infinite mass: the world the others move against.
    case `static`
    /// Moves only when something moves it.
    case kinematic
    /// Moves under the forces the simulation applies to it.
    case dynamic
}

/// The mass, the inertia and the centre of mass of a body.
public struct PhysicsMassProperties: Equatable {
    /// Mass one, inertia a tenth on each axis, and the centre at the origin. Measured on the
    /// host 2026-09-27: `PhysicsBodyComponent()` and a static body both report mass 1 and
    /// inertia (0.1, 0.1, 0.1).
    public static let `default` = PhysicsMassProperties()

    public var mass: Float
    public var inertia: SIMD3<Float>
    public var centerOfMass: (position: SIMD3<Float>, orientation: simd_quatf)

    public init() {
        mass = 1
        inertia = SIMD3<Float>(x: 0.1, y: 0.1, z: 0.1)
        centerOfMass = (position: .zero, orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
    }

    public init(mass: Float, inertia: SIMD3<Float> = SIMD3<Float>(x: 0.1, y: 0.1, z: 0.1),
                centerOfMass: (position: SIMD3<Float>, orientation: simd_quatf) = (SIMD3<Float>(x: 0, y: 0, z: 0), simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))) {
        self.mass = mass
        self.inertia = inertia
        self.centerOfMass = centerOfMass
    }

    /// The mass a shape of the given density and volume has, and its inertia from the shape.
    @MainActor
    public init(shape: ShapeResource, density: Float) {
        let mass = shape.shape.volume * density
        self.init(mass: mass, inertia: shape.shape.inertia(forMass: mass))
    }

    /// The mass asked for, and the inertia the shape gives at that mass.
    @MainActor
    public init(shape: ShapeResource, mass: Float) {
        self.init(mass: mass, inertia: shape.shape.inertia(forMass: mass))
    }

    public static func == (a: PhysicsMassProperties, b: PhysicsMassProperties) -> Bool {
        a.mass == b.mass && a.inertia == b.inertia && a.centerOfMass.position == b.centerOfMass.position
    }
}

/// How much a surface resists sliding, and how much it bounces. The resource is a reference, as
/// the SDK's is, so that several bodies can share one.
@MainActor
open class PhysicsMaterialResource {
    public static let `default` = PhysicsMaterialResource()

    public var __staticFriction: Float
    public var __dynamicFriction: Float
    public var __restitution: Float

    public init(__staticFriction: Float = 0.5, __dynamicFriction: Float = 0.5, __restitution: Float = 0) {
        self.__staticFriction = __staticFriction
        self.__dynamicFriction = __dynamicFriction
        self.__restitution = __restitution
    }
}

/// The body an entity is: whether it moves, how heavy it is, and what it may not do.
@frozen public struct PhysicsBodyComponent: Component, Equatable {
    public var mode: PhysicsBodyMode
    public var massProperties: PhysicsMassProperties
    public var material: PhysicsMaterialResource?
    /// Whether each axis of the translation is held still.
    public var isTranslationLocked: (x: Bool, y: Bool, z: Bool)
    /// Whether each axis of the rotation is held still.
    public var isRotationLocked: (x: Bool, y: Bool, z: Bool)
    /// Whether a body fast enough to pass through another one is caught anyway.
    public var isContinuousCollisionDetectionEnabled: Bool
    /// What the 18.0 `isAffectedByGravity` and the two dampings are; a body that gravity does
    /// not move is a body the simulation only pushes.
    public var isAffectedByGravity: Bool
    public var linearDamping: Float
    public var angularDamping: Float

    /// A body of mass one under gravity, nothing locked and no continuous detection. Measured on
    /// the host: `PhysicsBodyComponent()` answers mode .dynamic, mass 1, inertia (0.1, 0.1,
    /// 0.1), no locks, continuous detection off.
    public init() {
        mode = .dynamic
        massProperties = .default
        material = nil
        isTranslationLocked = (false, false, false)
        isRotationLocked = (false, false, false)
        isContinuousCollisionDetectionEnabled = false
        isAffectedByGravity = true
        linearDamping = 0
        angularDamping = 0
    }

    public init(massProperties: PhysicsMassProperties = .default, material: PhysicsMaterialResource? = nil,
                mode: PhysicsBodyMode = .dynamic) {
        self.init()
        self.massProperties = massProperties
        self.material = material
        self.mode = mode
    }

    @MainActor
    public init(shapes: [ShapeResource], density: Float, material: PhysicsMaterialResource? = nil,
                mode: PhysicsBodyMode = .dynamic) {
        self.init(material: material, mode: mode)
        // The mass is the shapes' volume at that density, and the inertia the shapes give.
        var mass: Float = 0
        for shape in shapes { mass += shape.shape.volume * density }
        massProperties = PhysicsMassProperties(mass: mass, inertia: shapes.first?.shape.inertia(forMass: mass) ?? massProperties.inertia)
    }

    @MainActor
    public init(shapes: [ShapeResource], mass: Float, material: PhysicsMaterialResource? = nil,
                mode: PhysicsBodyMode = .dynamic) {
        self.init(material: material, mode: mode)
        massProperties = PhysicsMassProperties(mass: mass, inertia: shapes.first?.shape.inertia(forMass: mass) ?? massProperties.inertia)
    }

    public static func == (a: PhysicsBodyComponent, b: PhysicsBodyComponent) -> Bool {
        a.mode == b.mode && a.massProperties == b.massProperties && a.isTranslationLocked == b.isTranslationLocked
            && a.isRotationLocked == b.isRotationLocked
            && a.isContinuousCollisionDetectionEnabled == b.isContinuousCollisionDetectionEnabled
    }
}

/// How a body is moving now.
@frozen public struct PhysicsMotionComponent: Component, Equatable {
    public var linearVelocity: SIMD3<Float>
    public var angularVelocity: SIMD3<Float>

    public init() {
        linearVelocity = .zero
        angularVelocity = .zero
    }

    public init(linearVelocity: SIMD3<Float> = .zero, angularVelocity: SIMD3<Float> = .zero) {
        self.linearVelocity = linearVelocity
        self.angularVelocity = angularVelocity
    }

    public static func == (a: PhysicsMotionComponent, b: PhysicsMotionComponent) -> Bool {
        a.linearVelocity == b.linearVelocity && a.angularVelocity == b.angularVelocity
    }
}

@MainActor
extension HasPhysicsBody {
    public var physicsBody: PhysicsBodyComponent? {
        get { coreEntity.component(of: PhysicsBodyComponent.self) }
        set {
            if let newValue {
                coreEntity.setComponent(newValue)
            } else {
                coreEntity.removeComponent(of: PhysicsBodyComponent.self)
            }
        }
    }

    /// The shapes the body collides as, which are the entity's own collision shapes.
    public var collisionShapes: [ShapeResource] { collision?.shapes ?? [] }
}

@MainActor
extension HasPhysicsMotion {
    public var physicsMotion: PhysicsMotionComponent? {
        get { coreEntity.component(of: PhysicsMotionComponent.self) }
        set {
            if let newValue {
                coreEntity.setComponent(newValue)
            } else {
                coreEntity.removeComponent(of: PhysicsMotionComponent.self)
            }
        }
    }
}

// MARK: - Joints

/// A point in an entity, which is what a joint ties together.
///
/// The equality is written out rather than synthesised: the `simd_quatf` of an offset is a C
/// struct of a vector, and a hand-written one is the same answer without depending on whether
/// the module in use synthesises `Hashable` for it.
public struct GeometricPin {
    /// The name of the entity the pin is in, and where in it.
    public let name: String
    public let skeletalJointName: String?
    public var offsetPosition: SIMD3<Float>
    public var offsetOrientation: simd_quatf

    public init(named name: String, offsetPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
                offsetOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)) {
        self.init(named: name, skeletalJointName: "", offsetPosition: offsetPosition, offsetOrientation: offsetOrientation)
    }

    public init(named name: String, skeletalJointName: String, offsetPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
                offsetOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)) {
        self.name = name
        self.skeletalJointName = skeletalJointName
        self.offsetPosition = offsetPosition
        self.offsetOrientation = offsetOrientation
    }

    public static func == (a: GeometricPin, b: GeometricPin) -> Bool {
        a.name == b.name && a.skeletalJointName == b.skeletalJointName && a.offsetPosition == b.offsetPosition
            && a.offsetOrientation.vector == b.offsetOrientation.vector
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(skeletalJointName)
        hasher.combine(offsetPosition)
        hasher.combine(offsetOrientation.vector)
    }
}

extension GeometricPin: Hashable {}

/// What every joint has: the two pins it ties together, whether the joined bodies also collide
/// with each other, and whether the joint is in force.
public protocol PhysicsJoint: Equatable {
    var pin0: GeometricPin { get set }
    var pin1: GeometricPin { get set }
    var checksForInternalCollisions: Bool { get }
    var isActive: Bool { get }
}

/// A joint that holds its two pins in the same place and the same orientation.
public struct PhysicsFixedJoint: PhysicsJoint {
    public var pin0: GeometricPin
    public var pin1: GeometricPin
    public let checksForInternalCollisions: Bool
    public var isActive: Bool

    public init(pin0: GeometricPin, pin1: GeometricPin) {
        self.pin0 = pin0
        self.pin1 = pin1
        checksForInternalCollisions = false
        isActive = true
    }

    public static func == (a: PhysicsFixedJoint, b: PhysicsFixedJoint) -> Bool {
        a.pin0 == b.pin0 && a.pin1 == b.pin1 && a.checksForInternalCollisions == b.checksForInternalCollisions
            && a.isActive == b.isActive
    }
}

/// A joint that holds its two pins a distance apart, and no closer.
public struct PhysicsDistanceJoint: PhysicsJoint {
    public var pin0: GeometricPin
    public var pin1: GeometricPin
    public let checksForInternalCollisions: Bool
    public var isActive: Bool
    /// The distance the joint holds, and the range it allows.
    public var distance: Float
    public var distanceRange: ClosedRange<Float>?

    public init(pin0: GeometricPin, pin1: GeometricPin, distance: Float = 0,
                distanceRange: ClosedRange<Float>? = nil) {
        self.pin0 = pin0
        self.pin1 = pin1
        self.distance = distance
        self.distanceRange = distanceRange
        checksForInternalCollisions = false
        isActive = true
    }

    public static func == (a: PhysicsDistanceJoint, b: PhysicsDistanceJoint) -> Bool {
        a.pin0 == b.pin0 && a.pin1 == b.pin1 && a.distance == b.distance && a.isActive == b.isActive
    }
}

/// The joints an entity holds.
public struct PhysicsJoints: MutableCollection, RangeReplaceableCollection, ExpressibleByArrayLiteral {
    private var storage: [any PhysicsJoint]

    public init() { storage = [] }
    public init(arrayLiteral elements: (any PhysicsJoint)...) { storage = elements }

    public var startIndex: Int { storage.startIndex }
    public var endIndex: Int { storage.endIndex }
    public func index(after i: Int) -> Int { i + 1 }
    public subscript(position: Int) -> (any PhysicsJoint) {
        get { storage[position] }
        set { storage[position] = newValue }
    }
    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C) where C.Element == (any PhysicsJoint) {
        storage.replaceSubrange(subrange, with: newElements)
    }
    public mutating func append(_ newElement: (any PhysicsJoint)) { storage.append(newElement) }
    public mutating func removeAll() { storage.removeAll() }
}

/// Two joints are equal when they are the same value of the same type, which is what a joint's
/// own `==` answers.
func __reJointsEqual(_ a: any PhysicsJoint, _ b: any PhysicsJoint) -> Bool {
    if let left = a as? PhysicsFixedJoint, let right = b as? PhysicsFixedJoint { return left == right }
    if let left = a as? PhysicsDistanceJoint, let right = b as? PhysicsDistanceJoint { return left == right }
    return false
}

extension PhysicsJoints: Equatable {
    public static func == (a: PhysicsJoints, b: PhysicsJoints) -> Bool {
        a.storage.count == b.storage.count && zip(a.storage, b.storage).allSatisfy { a, b in a as AnyObject === (b as AnyObject) || __reJointsEqual(a, b) }
    }
}

/// The joints an entity holds, which the solver applies.
@frozen public struct PhysicsJointsComponent: Component, Equatable {
    public var joints: PhysicsJoints

    public init() { joints = PhysicsJoints() }

    public static func == (a: PhysicsJointsComponent, b: PhysicsJointsComponent) -> Bool { a.joints == b.joints }
}

@MainActor
extension HasPhysics {
    public var physicsJoints: PhysicsJointsComponent? {
        get { coreEntity.component(of: PhysicsJointsComponent.self) }
        set {
            if let newValue {
                coreEntity.setComponent(newValue)
            } else {
                coreEntity.removeComponent(of: PhysicsJointsComponent.self)
            }
        }
    }
}
