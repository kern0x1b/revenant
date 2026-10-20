import simd
import Foundation

public struct CollisionGroup: OptionSet, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let `default` = CollisionGroup(rawValue: 1)
    public static let all = CollisionGroup(rawValue: .max)
    public static let sceneUnderstanding = CollisionGroup(rawValue: 1 << 1)
}

public struct CollisionFilter: Equatable {
    public var group: CollisionGroup
    public var mask: CollisionGroup

    public init(group: CollisionGroup, mask: CollisionGroup) {
        self.group = group
        self.mask = mask
    }

    public static let `default` = CollisionFilter(group: .default, mask: .all)
    public static let sensor = CollisionFilter(group: .all, mask: .all)

    public func meets(_ other: CollisionFilter) -> Bool {
        (mask.contains(other.group) || other.mask.contains(group)) && group != .all
    }
}

public enum PhysicsShape {
    case box(halfExtents: SIMD3<Float>)
    case sphere(radius: Float)
    case capsule(radius: Float, halfHeight: Float)
    case convex(points: [SIMD3<Float>])

    public var bounds: BoundingBox {
        switch self {
        case .box(let halfExtents):
            return BoundingBox(min: -halfExtents, max: halfExtents)
        case .sphere(let radius):
            return BoundingBox(min: SIMD3<Float>(repeating: -radius), max: SIMD3<Float>(repeating: radius))
        case .capsule(let radius, let halfHeight):
            return BoundingBox(min: SIMD3<Float>(-radius, -halfHeight, -radius), max: SIMD3<Float>(radius, halfHeight, radius))
        case .convex(let points):
            var box = BoundingBox()
            for point in points { box.extend(with: point) }
            return box
        }
    }

    public var volume: Float {
        switch self {
        case .box(let halfExtents):
            return 8 * halfExtents.x * halfExtents.y * halfExtents.z
        case .sphere(let radius):
            return (4.0 / 3.0) * Float.pi * radius * radius * radius
        case .capsule(let radius, let halfHeight):
            return Float.pi * radius * radius * 2 * halfHeight + (4.0 / 3.0) * Float.pi * radius * radius * radius
        case .convex(let points):
            return ConvexHull.volume(of: points)
        }
    }

    public func inertia(forMass mass: Float) -> SIMD3<Float> {
        switch self {
        case .box(let halfExtents):
            let (a, b, c) = (2 * halfExtents.x, 2 * halfExtents.y, 2 * halfExtents.z)
            return SIMD3<Float>(mass / 12 * (b * b + c * c), mass / 12 * (a * a + c * c), mass / 12 * (a * a + b * b))
        case .sphere(let radius):
            let solid = 0.4 * mass * radius * radius
            return SIMD3<Float>(repeating: solid)
        case .capsule(let radius, _):
            let cylinder = 0.5 * mass * radius * radius
            return SIMD3<Float>(cylinder, cylinder, cylinder)
        case .convex(let points):
            let meanSquare = ConvexHull.meanSquareDistance(from: SIMD3<Float>(repeating: 0), of: points)
            return SIMD3<Float>(repeating: 0.4 * mass * meanSquare)
        }
    }

    public var boxCorners: [SIMD3<Float>] { bounds.corners }
}

@MainActor
open class ShapeResource {
    public let shape: PhysicsShape
    public let offset: simd_quatf
    public let offsetTranslation: SIMD3<Float>

    public init(shape: PhysicsShape, offset: simd_quatf, offsetTranslation: SIMD3<Float>) {
        self.shape = shape
        self.offset = offset
        self.offsetTranslation = offsetTranslation
    }

    public var bounds: BoundingBox { shape.bounds }

    public func offsetBy(rotation: simd_quatf) -> ShapeResource {
        ShapeResource(shape: shape, offset: offset * rotation, offsetTranslation: offsetTranslation)
    }

    public func offsetBy(translation: SIMD3<Float>) -> ShapeResource {
        ShapeResource(shape: shape, offset: offset, offsetTranslation: offsetTranslation + translation)
    }

    public func offsetBy(rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                         translation: SIMD3<Float> = SIMD3<Float>()) -> ShapeResource {
        ShapeResource(shape: shape, offset: offset * rotation, offsetTranslation: offsetTranslation + translation)
    }

    public static func __makeShapeResource(_ shapes: [ShapeResource]) -> ShapeResource {
        var box = BoundingBox()
        for shape in shapes { box.extend(with: shape.shape.bounds.min); box.extend(with: shape.shape.bounds.max) }
        let half = (box.max - box.min) / 2
        return ShapeResource(shape: .box(halfExtents: half), offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                             offsetTranslation: (box.min + box.max) / 2)
    }

    public static func generateBox(size: SIMD3<Float>) -> ShapeResource {
        ShapeResource(shape: .box(halfExtents: size / 2), offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                      offsetTranslation: .zero)
    }

    public static func generateBox(width: Float, height: Float, depth: Float) -> ShapeResource {
        generateBox(size: SIMD3<Float>(width, height, depth))
    }

    public static func generateSphere(radius: Float) -> ShapeResource {
        ShapeResource(shape: .sphere(radius: radius), offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), offsetTranslation: .zero)
    }

    public static func generateCapsule(height: Float, radius: Float) -> ShapeResource {
        ShapeResource(shape: .capsule(radius: radius, halfHeight: height / 2),
                      offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), offsetTranslation: .zero)
    }

    public static func generateConvex(from points: [SIMD3<Float>]) -> ShapeResource {
        ShapeResource(shape: .convex(points: ConvexHull.hull(of: points)),
                      offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), offsetTranslation: .zero)
    }
}

extension ShapeResource: Hashable {
    nonisolated public static func == (lhs: ShapeResource, rhs: ShapeResource) -> Bool { lhs === rhs }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

enum ConvexHull {
    static func hull(of points: [SIMD3<Float>]) -> [SIMD3<Float>] {
        guard !points.isEmpty else { return [] }
        var box = BoundingBox()
        for point in points { box.extend(with: point) }
        return box.corners
    }

    static func volume(of points: [SIMD3<Float>]) -> Float {
        let box = BoundingBox()
        var made = box
        for point in points { made.extend(with: point) }
        let extents = made.extents
        return extents.x * extents.y * extents.z
    }

    static func meanSquareDistance(from centre: SIMD3<Float>, of points: [SIMD3<Float>]) -> Float {
        guard !points.isEmpty else { return 0 }
        var total: Float = 0
        for point in points { total += simd_length_squared(point - centre) }
        return total / Float(points.count)
    }
}

@frozen public struct CollisionComponent: Component, Equatable {
    public enum Mode: Hashable {
        case `default`
        case trigger
    }

    public var shapes: [ShapeResource]
    public var mode: Mode
    public var filter: CollisionFilter

    public init(shapes: [ShapeResource], mode: Mode = .default, filter: CollisionFilter = .default) {
        self.shapes = shapes
        self.mode = mode
        self.filter = filter
    }

    public static func == (a: CollisionComponent, b: CollisionComponent) -> Bool {
        a.mode == b.mode && a.filter == b.filter && a.shapes.count == b.shapes.count
            && zip(a.shapes, b.shapes).allSatisfy { $0 === $1 }
    }
}

@MainActor
extension HasCollision {
    public var collision: CollisionComponent? {
        get { coreEntity.component(of: CollisionComponent.self) }
        set {
            if let newValue {
                coreEntity.setComponent(newValue)
            } else {
                coreEntity.removeComponent(of: CollisionComponent.self)
            }
        }
    }
}

@MainActor
extension __REEntity {
    public var visualBounds: BoundingBox { boundingBox(recursive: true, excludeInactive: false) }
}
