import simd
import Foundation

public enum PhysicsBodyMode: Hashable {
    case `static`
    case kinematic
    case dynamic
}

public struct PhysicsMassProperties: Equatable {
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

    @MainActor
    public init(shape: ShapeResource, density: Float) {
        let mass = shape.shape.volume * density
        self.init(mass: mass, inertia: shape.shape.inertia(forMass: mass))
    }

    @MainActor
    public init(shape: ShapeResource, mass: Float) {
        self.init(mass: mass, inertia: shape.shape.inertia(forMass: mass))
    }

    public static func == (a: PhysicsMassProperties, b: PhysicsMassProperties) -> Bool {
        a.mass == b.mass && a.inertia == b.inertia && a.centerOfMass.position == b.centerOfMass.position
    }
}

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

@frozen public struct PhysicsBodyComponent: Component, Equatable {
    public var mode: PhysicsBodyMode
    public var massProperties: PhysicsMassProperties
    public var material: PhysicsMaterialResource?
    public var isTranslationLocked: (x: Bool, y: Bool, z: Bool)
    public var isRotationLocked: (x: Bool, y: Bool, z: Bool)
    public var isContinuousCollisionDetectionEnabled: Bool
    public var isAffectedByGravity: Bool
    public var linearDamping: Float
    public var angularDamping: Float

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

public struct GeometricPin {
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

public protocol PhysicsJoint: Equatable {
    var pin0: GeometricPin { get set }
    var pin1: GeometricPin { get set }
    var checksForInternalCollisions: Bool { get }
    var isActive: Bool { get }
}

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

public struct PhysicsDistanceJoint: PhysicsJoint {
    public var pin0: GeometricPin
    public var pin1: GeometricPin
    public let checksForInternalCollisions: Bool
    public var isActive: Bool
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
