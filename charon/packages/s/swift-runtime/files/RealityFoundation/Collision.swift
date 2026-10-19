// The shapes an entity collides with, the component that gives it them, and the group and
// filter that decide which of two shapes meet.
//
// The shape bounds and the mass properties below are the system's own, measured on the host
// 2026-09-27 (arm64-apple-macos26 against the Command Line Tools' MacOSX26.5 SDK, which
// carries RealityKit): `ShapeResource.generateBox(size: (1, 2, 3)).bounds` is
// `min(-0.5, -1, -1.5) max(0.5, 1, 1.5)`, `generateSphere(radius: 2).bounds` is `±2`, and
// `generateCapsule(height: 4, radius: 1).bounds` is `min(-1, -2, -1) max(1, 2, 1)`.

import simd
import Foundation

// MARK: - CollisionGroup

/// Which shapes a collision test considers, as a set of bits. A shape's filter names the group
/// it is in and the groups it meets.
public struct CollisionGroup: OptionSet, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The group an entity's collision shapes are in unless it says otherwise. Measured on the
    /// host: `CollisionFilter.default.group` is 1.
    public static let `default` = CollisionGroup(rawValue: 1)
    /// Every group.
    public static let all = CollisionGroup(rawValue: .max)
    /// The group of the shapes a scene's understanding of the room occupies.
    public static let sceneUnderstanding = CollisionGroup(rawValue: 1 << 1)
}

// MARK: - CollisionFilter

/// Which shapes meet: the group this one is in, and the groups it collides with.
public struct CollisionFilter: Equatable {
    public var group: CollisionGroup
    public var mask: CollisionGroup

    public init(group: CollisionGroup, mask: CollisionGroup) {
        self.group = group
        self.mask = mask
    }

    /// Group 1, meeting every group. Measured on the host: `.default.group.rawValue` is 1 and
    /// `.default.mask.rawValue` is 4294967295.
    public static let `default` = CollisionFilter(group: .default, mask: .all)
    /// A shape that meets everything and is in no group of its own, which is what a sensor is.
    public static let sensor = CollisionFilter(group: .all, mask: .all)

    /// Whether two filters meet: each one's group is in the other's mask.
    public func meets(_ other: CollisionFilter) -> Bool {
        (mask.contains(other.group) || other.mask.contains(group)) && group != .all
    }
}

// MARK: - The shape geometry

/// The geometry a shape resource carries, in the entity's own coordinates. It is public because
/// `ShapeResource` names it: a caller reads a shape's geometry, and the engine's own does too.
public enum PhysicsShape {
    /// A box centred on the entity, of half extents.
    case box(halfExtents: SIMD3<Float>)
    case sphere(radius: Float)
    /// A capsule along the y axis: a cylinder of half height with a hemisphere at each end.
    case capsule(radius: Float, halfHeight: Float)
    /// The convex hull of points, which is what a mesh collides as.
    case convex(points: [SIMD3<Float>])

    /// The box the shape fits in, which is what a bounds and a ray test need.
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

    /// The volume, which a mass from a density needs.
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

    /// The inertia of a body of the given mass about its centre, as the diagonal of the inertia
    /// tensor. A box's is `m/12` times the sum of the squares of the two extents across from
    /// each axis, which is what the system answers (measured: a 1x1x1 box of density 2, mass 2,
    /// inertia (1/3, 1/3, 1/3); the same box of mass 5, inertia (5/6, 5/6, 5/6)).
    public func inertia(forMass mass: Float) -> SIMD3<Float> {
        switch self {
        case .box(let halfExtents):
            let (a, b, c) = (2 * halfExtents.x, 2 * halfExtents.y, 2 * halfExtents.z)
            return SIMD3<Float>(mass / 12 * (b * b + c * c), mass / 12 * (a * a + c * c), mass / 12 * (a * a + b * b))
        case .sphere(let radius):
            let solid = 0.4 * mass * radius * radius
            return SIMD3<Float>(repeating: solid)
        case .capsule(let radius, _):
            // A cylinder's and a sphere's inertia added, which is what the shape is made of.
            let cylinder = 0.5 * mass * radius * radius
            return SIMD3<Float>(cylinder, cylinder, cylinder)
        case .convex(let points):
            // A body's inertia about a hull of its points: the mean square distance, scaled.
            let meanSquare = ConvexHull.meanSquareDistance(from: SIMD3<Float>(repeating: 0), of: points)
            return SIMD3<Float>(repeating: 0.4 * mass * meanSquare)
        }
    }

    /// The eight corners of the shape's box, in the entity's coordinates, which is what a
    /// ray test and a contact test both need.
    public var boxCorners: [SIMD3<Float>] { bounds.corners }
}

// MARK: - ShapeResource

/// A shape an entity collides with: a box, a sphere, a capsule or the hull of some points.
///
/// A shape is a reference: two shapes built the same way are two shapes, which is what the
/// system's own answers (measured: `generateBox(size: (1,1,1)) == generateBox(size: (1,1,1))`
/// is false), and which is why the type is a class.
@MainActor
open class ShapeResource {
    /// The geometry.
    public let shape: PhysicsShape
    /// The rotation the shape is offset by, and the translation with it.
    public let offset: simd_quatf
    public let offsetTranslation: SIMD3<Float>

    public init(shape: PhysicsShape, offset: simd_quatf, offsetTranslation: SIMD3<Float>) {
        self.shape = shape
        self.offset = offset
        self.offsetTranslation = offsetTranslation
    }

    /// The box the shape fits in, in the entity's own coordinates.
    public var bounds: BoundingBox { shape.bounds }

    /// The shape with a rotation applied to it.
    public func offsetBy(rotation: simd_quatf) -> ShapeResource {
        ShapeResource(shape: shape, offset: offset * rotation, offsetTranslation: offsetTranslation)
    }

    /// The shape with a translation applied to it.
    public func offsetBy(translation: SIMD3<Float>) -> ShapeResource {
        ShapeResource(shape: shape, offset: offset, offsetTranslation: offsetTranslation + translation)
    }

    /// The shape with both.
    public func offsetBy(rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                         translation: SIMD3<Float> = SIMD3<Float>()) -> ShapeResource {
        ShapeResource(shape: shape, offset: offset * rotation, offsetTranslation: offsetTranslation + translation)
    }

    /// One shape carrying all the geometry of several, which is what a compound collider is.
    public static func __makeShapeResource(_ shapes: [ShapeResource]) -> ShapeResource {
        var box = BoundingBox()
        for shape in shapes { box.extend(with: shape.shape.bounds.min); box.extend(with: shape.shape.bounds.max) }
        let half = (box.max - box.min) / 2
        return ShapeResource(shape: .box(halfExtents: half), offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                             offsetTranslation: (box.min + box.max) / 2)
    }

    /// A box of the given size, centred on the entity.
    public static func generateBox(size: SIMD3<Float>) -> ShapeResource {
        ShapeResource(shape: .box(halfExtents: size / 2), offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                      offsetTranslation: .zero)
    }

    /// A box of the given size, centred on the entity.
    public static func generateBox(width: Float, height: Float, depth: Float) -> ShapeResource {
        generateBox(size: SIMD3<Float>(width, height, depth))
    }

    /// A sphere of the given radius, centred on the entity.
    public static func generateSphere(radius: Float) -> ShapeResource {
        ShapeResource(shape: .sphere(radius: radius), offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), offsetTranslation: .zero)
    }

    /// A capsule along the entity's y axis: a cylinder of half length `height / 2` with a
    /// hemisphere of `radius` at each end, so the whole shape is `height` tall and `2 * radius`
    /// wide. Measured on the host 2026-09-27: `generateCapsule(height: 4, radius: 1).bounds`
    /// is `min(-1, -2, -1) max(1, 2, 1)`, the full height and not the cylinder's alone.
    public static func generateCapsule(height: Float, radius: Float) -> ShapeResource {
        ShapeResource(shape: .capsule(radius: radius, halfHeight: height / 2),
                      offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), offsetTranslation: .zero)
    }

    /// The hull of some points, which is what a mesh's points collide as.
    public static func generateConvex(from points: [SIMD3<Float>]) -> ShapeResource {
        ShapeResource(shape: .convex(points: ConvexHull.hull(of: points)),
                      offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), offsetTranslation: .zero)
    }
}

extension ShapeResource: Hashable {
    /// Two shapes are the same when they are the same object, which is what the system answers.
    nonisolated public static func == (lhs: ShapeResource, rhs: ShapeResource) -> Bool { lhs === rhs }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

// MARK: - ConvexHull

/// The hull of a set of points, by the gift wrapping of the three extremes: enough for the
/// inertia of a convex collider, and the box a ray test uses. A mesh's own collision shape is
/// its bounding box until the mesh round measures a real hull.
enum ConvexHull {
    /// The points that are the extremes of the set along the three axes, which for a box-shaped
    /// mesh is its eight corners and for anything else its six extremes.
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

// MARK: - CollisionComponent

/// The shapes an entity collides with, and how it collides.
@frozen public struct CollisionComponent: Component, Equatable {
    /// How a collision is answered.
    public enum Mode: Hashable {
        /// The shapes push each other apart, and a collision between them raises the events.
        case `default`
        /// The shapes report a collision and do not push each other apart, which is what a
        /// sensor or a trigger is.
        case trigger
    }

    /// The shapes, in the entity's own coordinates.
    public var shapes: [ShapeResource]
    public var mode: Mode
    /// Which of the shapes meet which.
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
    /// The shapes the entity collides with, and how.
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
    /// The box the node fills, counting its own unit cube and everything below it.
    public var visualBounds: BoundingBox { boundingBox(recursive: true, excludeInactive: false) }
}
