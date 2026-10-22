import Foundation
import simd

@frozen
public struct Size3D: Primitive3D, Volumetric, Primitive3DProtocol, AdditiveArithmetic, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
    public typealias Scalar = Double
    public typealias AffineTransform = AffineTransform3D
    public typealias ProjectiveTransform = ProjectiveTransform3D
    public typealias Pose = Pose3D
    public typealias Rect = Rect3D
    public typealias Vector = Vector3D
    public typealias Point = Point3D
    public typealias Size = Size3D
    public typealias Rotation = Rotation3D
    public typealias Quaternion = simd_quatd
    public typealias AxisEnumeration = AxisWithFactors

    public var width: Double
    public var height: Double
    public var depth: Double

    public init() { self.init(width: 0, height: 0, depth: 0) }

    public init(width: Double = 0, height: Double = 0, depth: Double = 0) {
        self.width = width
        self.height = height
        self.depth = depth
    }

    public init(_ xyz: simd_double3) { self.init(width: xyz.x, height: xyz.y, depth: xyz.z) }
    public init(_ source: simd_packed_double4) { self.init(width: source.x, height: source.y, depth: source.z) }
    public init(_ point: Point3D) { self.init(width: point.x, height: point.y, depth: point.z) }
    public init(_ xyz: Vector3D) { self.init(width: xyz.x, height: xyz.y, depth: xyz.z) }

    public static let zero = Size3D()
    public static let one = Size3D(width: 1, height: 1, depth: 1)
    public static let infinity = Size3D(width: .infinity, height: .infinity, depth: .infinity)

    public var vector: simd_double3 {
        get { simd_double3(width, height, depth) }
        set { width = newValue.x; height = newValue.y; depth = newValue.z }
    }

    @available(*, deprecated, renamed: "vector")
    public var simd: simd_double3 {
        get { vector }
        set { vector = newValue }
    }

    public var size: Size3D { self }

    public var isZero: Bool { width == 0 && height == 0 && depth == 0 }
    public var isFinite: Bool { width.isFinite && height.isFinite && depth.isFinite }
    public var isNaN: Bool { width.isNaN || height.isNaN || depth.isNaN }

    public static func + (lhs: Size3D, rhs: Size3D) -> Size3D {
        Size3D(lhs.vector + rhs.vector)
    }

    public static func - (lhs: Size3D, rhs: Size3D) -> Size3D {
        Size3D(lhs.vector - rhs.vector)
    }

    public static prefix func - (size: Size3D) -> Size3D {
        Size3D(-size.vector)
    }

    public static func * (lhs: Double, rhs: Size3D) -> Size3D { Size3D(lhs * rhs.vector) }
    public static func * (lhs: Size3D, rhs: Double) -> Size3D { Size3D(lhs.vector * rhs) }
    public static func / (lhs: Size3D, rhs: Double) -> Size3D { Size3D(lhs.vector / rhs) }
    public static func += (lhs: inout Size3D, rhs: Size3D) { lhs = lhs + rhs }
    public static func -= (lhs: inout Size3D, rhs: Size3D) { lhs = lhs - rhs }
    public static func *= (lhs: inout Size3D, rhs: Double) { lhs = lhs * rhs }
    public static func /= (lhs: inout Size3D, rhs: Double) { lhs = lhs / rhs }

    public static func * (lhs: AffineTransform3D, rhs: Size3D) -> Size3D { rhs.applying(lhs) }
    public static func * (lhs: ProjectiveTransform3D, rhs: Size3D) -> Size3D { rhs.applying(lhs) }
    public static func * (lhs: Pose3D, rhs: Size3D) -> Size3D { rhs.applying(lhs) }

    public static func == (lhs: Size3D, rhs: Size3D) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height && lhs.depth == rhs.depth
    }

    public func scaledBy(x: Double = 1, y: Double = 1, z: Double = 1) -> Size3D {
        Size3D(width: width * x, height: height * y, depth: depth * z)
    }

    public mutating func scaleBy(x: Double = 1, y: Double = 1, z: Double = 1) {
        self = scaledBy(x: x, y: y, z: z)
    }

    public func scaled(by scale: Size3D) -> Size3D {
        scaledBy(x: scale.width, y: scale.height, z: scale.depth)
    }

    public mutating func scale(by scale: Size3D) { self = scaled(by: scale) }
    public func uniformlyScaled(by scale: Double) -> Size3D { scaledBy(x: scale, y: scale, z: scale) }
    public mutating func uniformlyScale(by scale: Double) { self = uniformlyScaled(by: scale) }

    public func sheared(_ shear: AxisWithFactors) -> Size3D {
        Size3D(Vector3D(x: width, y: height, z: depth).sheared(shear).vector)
    }

    public mutating func shear(_ shear: AxisWithFactors) { self = sheared(shear) }

    public func rotated(by rotation: Rotation3D) -> Size3D {
        applying(rotation.affineTransform)
    }

    public func rotated(by quaternion: simd_quatd) -> Size3D {
        applying(Rotation3D(quaternion).affineTransform)
    }

    public func rotated(by rotation: Rotation3D, around pivot: Point3D) -> Size3D {
        Rect3D(origin: .zero, size: self).rotated(by: rotation, around: pivot).size
    }

    public func rotated(by quaternion: simd_quatd, around pivot: Point3D) -> Size3D {
        rotated(by: Rotation3D(quaternion), around: pivot)
    }

    public mutating func rotate(by rotation: Rotation3D) { self = rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = rotated(by: quaternion) }

    public func translated(by vector: Vector3D) -> Size3D { self }

    public func rotation(to other: Size3D) -> Rotation3D {
        Vector3D(x: width, y: height, z: depth)
            .rotation(to: Vector3D(x: other.width, y: other.height, z: other.depth))
    }

    @available(*, deprecated, message: "Use the `Vector3D` variant.")
    public func translated(by size: Size3D) -> Size3D { self + size }

    public mutating func translate(by vector: Vector3D) { }
    public mutating func translate(by size: Size3D) { self += size }

    public func applying(_ transform: AffineTransform3D) -> Size3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ transform: ProjectiveTransform3D) -> Size3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ pose: Pose3D) -> Size3D { applying(matrix: pose.matrix) }
    public func applying(_ scaledPose: ScaledPose3D) -> Size3D { applying(matrix: scaledPose.matrix) }

    public func unapplying(_ transform: AffineTransform3D) -> Size3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ transform: ProjectiveTransform3D) -> Size3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ pose: Pose3D) -> Size3D { unapplying(matrix: pose.matrix) }
    public func unapplying(_ scaledPose: ScaledPose3D) -> Size3D { unapplying(matrix: scaledPose.matrix) }

    public mutating func apply(_ transform: AffineTransform3D) { self = applying(transform) }
    public mutating func apply(_ transform: ProjectiveTransform3D) { self = applying(transform) }
    public mutating func apply(_ pose: Pose3D) { self = applying(pose) }
    public mutating func unapply(_ transform: AffineTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ transform: ProjectiveTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ pose: Pose3D) { self = unapplying(pose) }

    func applying(matrix: simd_double4x4) -> Size3D {
        Size3D(first3(simd_mul(matrix, SIMD4<Double>(vector, 0))))
    }

    func unapplying(matrix: simd_double4x4) -> Size3D {
        guard let inverse = invertedMatrix(matrix) else { return self }
        return applying(matrix: inverse)
    }

    public func contains(_ other: Self) -> Bool {
        other.width >= 0 && other.height >= 0 && other.depth >= 0 &&
            other.width <= width && other.height <= height && other.depth <= depth
    }

    public func contains(point: Point3D) -> Bool {
        let p = point.vector
        return p.x >= 0 && p.x <= width && p.y >= 0 && p.y <= height && p.z >= 0 && p.z <= depth
    }

    public func contains(anyOf points: [Point3D]) -> Bool {
        points.contains { contains(point: $0) }
    }

    public func union(_ other: Self) -> Self {
        Size3D(width: max(width, other.width),
                        height: max(height, other.height),
                        depth: max(depth, other.depth))
    }

    public mutating func formUnion(_ other: Self) { self = union(other) }

    public func intersection(_ other: Self) -> Self? {
        let overlap = Size3D(width: min(width, other.width),
                                      height: min(height, other.height),
                                      depth: min(depth, other.depth))
        return overlap != .zero ? overlap : nil
    }

    public mutating func formIntersection(_ other: Self) { self = intersection(other) ?? .zero }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(depth)
    }

    private enum CodingKeys: String, CodingKey { case width, height, depth }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(depth, forKey: .depth)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(width: try container.decode(Double.self, forKey: .width),
                  height: try container.decode(Double.self, forKey: .height),
                  depth: try container.decode(Double.self, forKey: .depth))
    }

    public var description: String { "(width: \(width), height: \(height), depth: \(depth))" }
    public var customMirror: Mirror { Mirror(self, children: ["width": width, "height": height, "depth": depth]) }
}

@frozen
public struct Point3D: Primitive3D, Translatable3D, Primitive3DProtocol, ClampableWithinRectProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
    public typealias Scalar = Double
    public typealias AffineTransform = AffineTransform3D
    public typealias ProjectiveTransform = ProjectiveTransform3D
    public typealias Pose = Pose3D
    public typealias Rect = Rect3D
    public typealias Vector = Vector3D
    public typealias Point = Point3D
    public typealias Size = Size3D
    public typealias Rotation = Rotation3D
    public typealias Quaternion = simd_quatd
    public typealias AxisEnumeration = AxisWithFactors

    public var x: Double
    public var y: Double
    public var z: Double

    public init() { self.init(x: 0, y: 0, z: 0) }
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(_ xyz: simd_double3) { self.init(x: xyz.x, y: xyz.y, z: xyz.z) }
    public init(_ source: simd_packed_double4) { self.init(x: source.x, y: source.y, z: source.z) }
    public init(_ vector: Vector3D) { self.init(vector.vector) }
    public init(_ coords: SphericalCoordinates3D) {
        self.init(SphericalCoordinates3D.cartesian(in: coords))
    }
    public init(_ size: Size3D) { self.init(size.vector) }

    public static let zero = Point3D()
    public static let infinity = Point3D(x: .infinity, y: .infinity, z: .infinity)

    public var vector: simd_double3 {
        get { simd_double3(x, y, z) }
        set { x = newValue.x; y = newValue.y; z = newValue.z }
    }

    @available(*, deprecated, renamed: "vector")
    public var simd: simd_double3 {
        get { vector }
        set { vector = newValue }
    }

    @available(*, deprecated, message: "This property is deprecated")
    public var origin: Point3D { self }

    public var isZero: Bool { x == 0 && y == 0 && z == 0 }
    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
    public var isNaN: Bool { x.isNaN || y.isNaN || z.isNaN }

    public func distance(to other: Point3D) -> Double {
        simd_distance(self.vector, other.vector)
    }

    public func rotation(to other: Point3D) -> Rotation3D {
        Vector3D(vector).rotation(to: Vector3D(other.vector))
    }

    public static func - (lhs: Point3D, rhs: Point3D) -> Vector3D {
        Vector3D(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static prefix func - (point: Point3D) -> Point3D {
        Point3D(x: -point.x, y: -point.y, z: -point.z)
    }

    public static func + (lhs: Point3D, rhs: Vector3D) -> Point3D {
        Point3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func += (lhs: inout Point3D, rhs: Vector3D) { lhs = lhs + rhs }
    public static func -= (lhs: inout Point3D, rhs: Vector3D) { lhs = lhs - rhs }

    public func uniformlyScaled(by scale: Double) -> Point3D {
        Point3D(x: x * scale, y: y * scale, z: z * scale)
    }

    public mutating func uniformlyScale(by scale: Double) { self = uniformlyScaled(by: scale) }

    public func translated(by vector: Vector3D) -> Point3D {
        Point3D(x: x + vector.x, y: y + vector.y, z: z + vector.z)
    }

    @available(*, deprecated, message: "Use `Vector3D` variant.")
    public func translated(by size: Size3D) -> Point3D { self + Vector3D(size) }

    public mutating func translate(by vector: Vector3D) { self = translated(by: vector) }
    public mutating func translate(by size: Size3D) { self = translated(by: Vector3D(size)) }

    public func rotated(by rotation: Rotation3D) -> Point3D {
        applying(rotation.affineTransform)
    }

    public func rotated(by quaternion: simd_quatd) -> Point3D {
        applying(Rotation3D(quaternion).affineTransform)
    }

    public func rotated(by rotation: Rotation3D, around pivot: Point3D) -> Point3D {
        Point3D(x: pivot.x + (self - pivot).rotated(by: rotation).x,
                       y: pivot.y + (self - pivot).rotated(by: rotation).y,
                       z: pivot.z + (self - pivot).rotated(by: rotation).z)
    }

    public func rotated(by quaternion: simd_quatd, around pivot: Point3D) -> Point3D {
        rotated(by: Rotation3D(quaternion), around: pivot)
    }

    public mutating func rotate(by rotation: Rotation3D) { self = rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = rotated(by: quaternion) }

    public func applying(_ transform: AffineTransform3D) -> Point3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ transform: ProjectiveTransform3D) -> Point3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ pose: Pose3D) -> Point3D { applying(matrix: pose.matrix) }
    public func applying(_ scaledPose: ScaledPose3D) -> Point3D { applying(matrix: scaledPose.matrix) }

    public func unapplying(_ transform: AffineTransform3D) -> Point3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ transform: ProjectiveTransform3D) -> Point3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ pose: Pose3D) -> Point3D { unapplying(matrix: pose.matrix) }
    public func unapplying(_ scaledPose: ScaledPose3D) -> Point3D { unapplying(matrix: scaledPose.matrix) }

    public mutating func apply(_ transform: AffineTransform3D) { self = applying(transform) }
    public mutating func apply(_ transform: ProjectiveTransform3D) { self = applying(transform) }
    public mutating func apply(_ pose: Pose3D) { self = applying(pose) }
    public mutating func unapply(_ transform: AffineTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ transform: ProjectiveTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ pose: Pose3D) { self = unapplying(pose) }

    func applying(matrix: simd_double4x4) -> Point3D {
        Point3D(first3(simd_mul(matrix, SIMD4<Double>(vector, 1))))
    }

    func unapplying(matrix: simd_double4x4) -> Point3D {
        guard let inverse = invertedMatrix(matrix) else { return self }
        return applying(matrix: inverse)
    }

    public func clamped(to rect: Rect3D) -> Point3D {
        Point3D(x: min(max(x, rect.minX), rect.maxX),
                        y: min(max(y, rect.minY), rect.maxY),
                        z: min(max(z, rect.minZ), rect.maxZ))
    }

    public mutating func clamp(to rect: Rect3D) { self = clamped(to: rect) }

    public static func == (lhs: Point3D, rhs: Point3D) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(z)
    }

    private enum CodingKeys: String, CodingKey { case x, y, z }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try container.decode(Double.self, forKey: .x),
                  y: try container.decode(Double.self, forKey: .y),
                  z: try container.decode(Double.self, forKey: .z))
    }

    public var description: String { "(x: \(x), y: \(y), z: \(z))" }
    public var customMirror: Mirror { Mirror(self, children: ["x": x, "y": y, "z": z]) }
}

@frozen
public struct Rect3D: Primitive3D, Translatable3D, Volumetric, Primitive3DProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
    public typealias Scalar = Double
    public typealias AffineTransform = AffineTransform3D
    public typealias ProjectiveTransform = ProjectiveTransform3D
    public typealias Pose = Pose3D
    public typealias Rect = Rect3D
    public typealias Vector = Vector3D
    public typealias Point = Point3D
    public typealias Size = Size3D
    public typealias Rotation = Rotation3D
    public typealias Quaternion = simd_quatd
    public typealias AxisEnumeration = AxisWithFactors

    public var origin: Point3D
    public var size: Size3D

    public init() { self.init(origin: Point3D.zero, size: Size3D.zero) }

    public init(origin: Point3D, size: Size3D) {
        self.origin = origin
        self.size = size
    }

    public init(origin: Vector3D = .zero, size: Vector3D) {
        self.init(origin: Point3D(origin), size: Size3D(size))
    }

    public init(origin: simd_double3 = .zero, size: simd_double3) {
        self.init(origin: Point3D(origin), size: Size3D(size))
    }

    public init(center: Point3D, size: Size3D) {
        self.init(origin: Point3D(x: center.x - size.width / 2,
                                            y: center.y - size.height / 2,
                                            z: center.z - size.depth / 2), size: size)
    }

    public init(center: Vector3D = .zero, size: Vector3D) {
        self.init(center: Point3D(center), size: Size3D(size))
    }

    public init(center: simd_double3 = .zero, size: simd_double3) {
        self.init(center: Point3D(center), size: Size3D(size))
    }

    public init(points: [Point3D]) {
        guard let first = points.first else {
            self.init(origin: Point3D.zero, size: Size3D.zero)
            return
        }
        var low = first.vector
        var high = first.vector
        for point in points.dropFirst() {
            low = simd_min(low, point.vector)
            high = simd_max(high, point.vector)
        }
        self.init(origin: Point3D(low), size: Size3D(high - low))
    }

    public static let zero = Rect3D()
    public static let infinity = Rect3D(origin: Point3D.infinity, size: Size3D.infinity)

    public var isZero: Bool { origin.isZero && size.isZero }
    public var isFinite: Bool { origin.isFinite && size.isFinite }
    public var isNaN: Bool { origin.isNaN || size.isNaN }

    public var isEmpty: Bool {
        let edges = [size.width, size.height, size.depth]
        return edges.filter { $0 == 0 }.count >= 2
    }

    public var min: Point3D {
        Point3D(origin.vector + simd_min(simd_double3(repeating: 0), size.vector))
    }

    public var max: Point3D {
        Point3D(origin.vector + simd_max(simd_double3(repeating: 0), size.vector))
    }

    public var minX: Double { min.x }
    public var minY: Double { min.y }
    public var minZ: Double { min.z }
    public var maxX: Double { max.x }
    public var maxY: Double { max.y }
    public var maxZ: Double { max.z }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }
    public var midZ: Double { origin.z + size.depth / 2 }

    public var center: Point3D {
        Point3D(origin.vector + size.vector / 2)
    }

    public var standardized: Rect3D {
        Rect3D(origin: min, size: Size3D(simd_abs(size.vector)))
    }

    public var integral: Rect3D {
        let standardized = self.standardized
        let origin = floor3(standardized.min.vector)
        return Rect3D(origin: Point3D(origin),
                                size: Size3D(ceil3(standardized.max.vector) - origin))
    }

    public var cornerPoints: [Point3D] {
        let corner = origin.vector
        let w = size.width
        let h = size.height
        let d = size.depth
        return [
            Point3D(corner),
            Point3D(corner + simd_double3(0, h, 0)),
            Point3D(corner + simd_double3(w, h, 0)),
            Point3D(corner + simd_double3(w, 0, 0)),
            Point3D(corner + simd_double3(0, 0, d)),
            Point3D(corner + simd_double3(0, h, d)),
            Point3D(corner + simd_double3(w, h, d)),
            Point3D(corner + simd_double3(w, 0, d)),
        ]
    }

    public static func == (lhs: Rect3D, rhs: Rect3D) -> Bool {
        lhs.origin == rhs.origin && lhs.size == rhs.size
    }

    public static func * (lhs: AffineTransform3D, rhs: Rect3D) -> Rect3D { rhs.applying(lhs) }
    public static func * (lhs: ProjectiveTransform3D, rhs: Rect3D) -> Rect3D { rhs.applying(lhs) }
    public static func * (lhs: Pose3D, rhs: Rect3D) -> Rect3D { rhs.applying(lhs) }

    public func scaledBy(x: Double = 1, y: Double = 1, z: Double = 1) -> Rect3D {
        let moved = Vector3D(origin.vector).scaledBy(x: x, y: y, z: z)
        return Rect3D(origin: Point3D(moved), size: size.scaledBy(x: x, y: y, z: z))
    }

    public mutating func scaleBy(x: Double = 1, y: Double = 1, z: Double = 1) {
        self = scaledBy(x: x, y: y, z: z)
    }

    public func scaled(by scale: Size3D) -> Rect3D { scaledBy(x: scale.width, y: scale.height, z: scale.depth) }
    public mutating func scale(by scale: Size3D) { self = scaled(by: scale) }
    public func uniformlyScaled(by scale: Double) -> Rect3D { scaledBy(x: scale, y: scale, z: scale) }
    public mutating func uniformlyScale(by scale: Double) { self = uniformlyScaled(by: scale) }

    public func sheared(_ shear: AxisWithFactors) -> Rect3D {
        applying(shearMatrix(for: shear))
    }

    public mutating func shear(_ shear: AxisWithFactors) { self = sheared(shear) }

    public func translated(by vector: Vector3D) -> Rect3D {
        Rect3D(origin: origin + vector, size: size)
    }

    @available(*, deprecated, message: "Use the `Vector3D` variant.")
    public func translated(by size: Size3D) -> Rect3D {
        Rect3D(origin: origin, size: self.size + size)
    }

    public mutating func translate(by vector: Vector3D) { self = translated(by: vector) }
    public mutating func translate(by size: Size3D) { self.size += size }

    public func rotated(by rotation: Rotation3D) -> Rect3D { applying(rotation.affineTransform) }
    public func rotated(by quaternion: simd_quatd) -> Rect3D { applying(Rotation3D(quaternion).affineTransform) }

    public func rotated(by rotation: Rotation3D, around pivot: Point3D) -> Rect3D {
        let corner = Point3D(x: origin.x - pivot.x, y: origin.y - pivot.y, z: origin.z - pivot.z)
        let turned = Rect3D(origin: Point3D(corner.vector).rotated(by: rotation), size: self.size)
        return Rect3D(origin: Point3D(x: turned.origin.x + pivot.x,
                                                           y: turned.origin.y + pivot.y,
                                                           z: turned.origin.z + pivot.z),
                            size: turned.size)
    }

    public func rotated(by quaternion: simd_quatd, around pivot: Point3D) -> Rect3D {
        rotated(by: Rotation3D(quaternion), around: pivot)
    }

    public mutating func rotate(by rotation: Rotation3D) { self = rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = rotated(by: quaternion) }

    public func rotation(to other: Rect3D) -> Rotation3D {
        origin.rotation(to: other.origin)
    }

    public func applying(_ transform: AffineTransform3D) -> Rect3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ transform: ProjectiveTransform3D) -> Rect3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ pose: Pose3D) -> Rect3D { applying(matrix: pose.matrix) }
    public func applying(_ scaledPose: ScaledPose3D) -> Rect3D { applying(matrix: scaledPose.matrix) }

    public func unapplying(_ transform: AffineTransform3D) -> Rect3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ transform: ProjectiveTransform3D) -> Rect3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ pose: Pose3D) -> Rect3D { unapplying(matrix: pose.matrix) }
    public func unapplying(_ scaledPose: ScaledPose3D) -> Rect3D { unapplying(matrix: scaledPose.matrix) }

    public mutating func apply(_ transform: AffineTransform3D) { self = applying(transform) }
    public mutating func apply(_ transform: ProjectiveTransform3D) { self = applying(transform) }
    public mutating func apply(_ pose: Pose3D) { self = applying(pose) }
    public mutating func unapply(_ transform: AffineTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ transform: ProjectiveTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ pose: Pose3D) { self = unapplying(pose) }

    func applying(matrix: simd_double4x4) -> Rect3D {
        Rect3D(points: cornerPoints.map { Point3D(first3(simd_mul(matrix, SIMD4<Double>($0.vector, 1)))) })
    }

    func unapplying(matrix: simd_double4x4) -> Rect3D {
        let three = simd_double3x3(columns: (first3(matrix.columns.0), first3(matrix.columns.1), first3(matrix.columns.2)))
        guard AffineTransform3D(matrix: simd_matrix(three.columns.0, three.columns.1,
                                                            three.columns.2, first3(matrix.columns.3))).isRectilinear,
              let inverse = invertedMatrix(matrix) else { return self }
        return applying(matrix: inverse)
    }

    private func shearMatrix(for shear: AxisWithFactors) -> AffineTransform3D {
        AffineTransform3D(shear: shear)
    }

    public func contains(_ other: Self) -> Bool {
        let low = min.vector
        let high = max.vector
        let otherLow = other.min.vector
        let otherHigh = other.max.vector
        return low.x <= otherLow.x && low.y <= otherLow.y && low.z <= otherLow.z &&
            high.x >= otherHigh.x && high.y >= otherHigh.y && high.z >= otherHigh.z
    }

    public func contains(point: Point3D) -> Bool {
        let low = min.vector
        let high = max.vector
        let p = point.vector
        return low.x <= p.x && low.y <= p.y && low.z <= p.z &&
            high.x >= p.x && high.y >= p.y && high.z >= p.z
    }

    public func contains(anyOf points: [Point3D]) -> Bool {
        points.contains { contains(point: $0) }
    }

    public func union(_ other: Self) -> Self {
        let left = standardized
        let right = other.standardized
        let origin = simd_min(left.origin.vector, right.origin.vector)
        return Rect3D(origin: Point3D(origin),
                              size: Size3D(simd_max(left.max.vector, right.max.vector) - origin))
    }

    public mutating func formUnion(_ other: Self) { self = union(other) }

    public func intersection(_ other: Self) -> Self? {
        let left = standardized
        let right = other.standardized
        let origin = simd_max(left.origin.vector, right.origin.vector)
        let size = simd_min(left.max.vector, right.max.vector) - origin
        guard simd_reduce_min(size) >= 0 else { return nil }
        return Rect3D(origin: Point3D(origin), size: Size3D(size))
    }

    public mutating func formIntersection(_ other: Self) { self = intersection(other) ?? .zero }

    public func intersects(_ other: Self) -> Bool {
        intersection(other) != nil
    }

    public func inset(by dXYZ: Size3D) -> Rect3D {
        let rect = standardized
        let inset = dXYZ.vector
        return Rect3D(origin: Point3D(rect.origin.vector + inset),
                              size: Size3D(rect.size.vector - 2 * inset))
    }

    public mutating func formInset(by dXYZ: Size3D) { self = inset(by: dXYZ) }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }

    private enum CodingKeys: String, CodingKey { case origin, size }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin, forKey: .origin)
        try container.encode(size, forKey: .size)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(origin: try container.decode(Point3D.self, forKey: .origin),
                  size: try container.decode(Size3D.self, forKey: .size))
    }

    public var description: String {
        "(origin: \(origin), size: \(size))"
    }

    public var customMirror: Mirror {
        Mirror(self, children: ["origin": origin, "size": size])
    }
}

@frozen
public struct Ray3D: Primitive3D, Primitive3DProtocol, Translatable3DProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
    public typealias Scalar = Double
    public typealias AffineTransform = AffineTransform3D
    public typealias ProjectiveTransform = ProjectiveTransform3D
    public typealias Pose = Pose3D
    public typealias Rect = Rect3D
    public typealias Vector = Vector3D
    public typealias Point = Point3D
    public typealias Size = Size3D
    public typealias Rotation = Rotation3D
    public typealias Quaternion = simd_quatd
    public typealias AxisEnumeration = AxisWithFactors

    public var origin: Point3D
    public var direction: Vector3D

    public init() { self.init(origin: .zero, direction: .zero) }

    public init(origin: Point3D = .zero, direction: Vector3D) {
        self.origin = origin
        let length = direction.length
        self.direction = length.isFinite && length > 0 ? direction.normalized : direction
    }

    public init(origin: simd_double3 = .zero, direction: simd_double3) {
        self.init(origin: Point3D(origin), direction: Vector3D(direction))
    }

    public static let zero = Ray3D()
    public static let infinity = Ray3D(origin: .infinity, direction: .infinity)

    public var isZero: Bool { origin.isZero && direction.isZero }
    public var isFinite: Bool { origin.isFinite && direction.isFinite }
    public var isNaN: Bool { origin.isNaN || direction.isNaN }

    public static func == (lhs: Ray3D, rhs: Ray3D) -> Bool {
        lhs.origin == rhs.origin && lhs.direction == rhs.direction
    }

    public static func * (lhs: Pose3D, rhs: Ray3D) -> Ray3D { rhs.applying(lhs) }

    public func translated(by vector: Vector3D) -> Ray3D {
        Ray3D(origin: origin + vector, direction: direction)
    }

    @available(*, deprecated, message: "Use the `Vector3D` variant.")
    public func translated(by size: Size3D) -> Ray3D { self.translated(by: Vector3D(size)) }

    public mutating func translate(by vector: Vector3D) { self = translated(by: vector) }
    public mutating func translate(by size: Size3D) { self = translated(by: Vector3D(size)) }

    public func rotated(by rotation: Rotation3D) -> Ray3D { applying(rotation.affineTransform) }
    public func rotated(by quaternion: simd_quatd) -> Ray3D { applying(Rotation3D(quaternion).affineTransform) }

    public func rotated(by rotation: Rotation3D, around pivot: Point3D) -> Ray3D {
        let turned = (origin - pivot).rotated(by: rotation)
        return Ray3D(origin: Point3D(x: pivot.x + turned.x, y: pivot.y + turned.y,
                                                     z: pivot.z + turned.z),
                             direction: direction.rotated(by: rotation))
    }

    public func rotated(by quaternion: simd_quatd, around pivot: Point3D) -> Ray3D {
        rotated(by: Rotation3D(quaternion), around: pivot)
    }

    public func rotation(to other: Ray3D) -> Rotation3D {
        direction.rotation(to: other.direction)
    }

    public mutating func rotate(by rotation: Rotation3D) { self = rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = rotated(by: quaternion) }

    public func applying(_ transform: AffineTransform3D) -> Ray3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ transform: ProjectiveTransform3D) -> Ray3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ pose: Pose3D) -> Ray3D { applying(matrix: pose.matrix) }
    public func applying(_ scaledPose: ScaledPose3D) -> Ray3D { applying(matrix: scaledPose.matrix) }

    public func unapplying(_ transform: AffineTransform3D) -> Ray3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ transform: ProjectiveTransform3D) -> Ray3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ pose: Pose3D) -> Ray3D { unapplying(matrix: pose.matrix) }
    public func unapplying(_ scaledPose: ScaledPose3D) -> Ray3D { unapplying(matrix: scaledPose.matrix) }

    public mutating func apply(_ transform: AffineTransform3D) { self = applying(transform) }
    public mutating func apply(_ transform: ProjectiveTransform3D) { self = applying(transform) }
    public mutating func apply(_ pose: Pose3D) { self = applying(pose) }
    public mutating func unapply(_ transform: AffineTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ transform: ProjectiveTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ pose: Pose3D) { self = unapplying(pose) }

    func applying(matrix: simd_double4x4) -> Ray3D {
        Ray3D(
            origin: Point3D(first3(simd_mul(matrix, SIMD4<Double>(origin.vector, 1)))),
            direction: Vector3D(first3(simd_mul(matrix, SIMD4<Double>(direction.vector, 0)))))
    }

    func unapplying(matrix: simd_double4x4) -> Ray3D {
        guard let inverse = invertedMatrix(matrix) else { return self }
        return applying(matrix: inverse)
    }

    public func intersects(_ rect: Rect3D) -> Bool {
        let inverseDirection = simd_double3(repeating: 1) / direction.vector
        let low = rect.min.vector
        let high = rect.max.vector
        let near = inverseDirection.x < 0 ? high : low
        let far = inverseDirection.x < 0 ? low : high
        let origin = self.origin.vector
        let tx0 = (near.x - origin.x) * inverseDirection.x
        let tx1 = (far.x - origin.x) * inverseDirection.x
        let ny = inverseDirection.y < 0 ? high : low
        let fy = inverseDirection.y < 0 ? low : high
        let ty0 = (ny.y - origin.y) * inverseDirection.y
        let ty1 = (fy.y - origin.y) * inverseDirection.y
        let nz = inverseDirection.z < 0 ? high : low
        let fz = inverseDirection.z < 0 ? low : high
        let tz0 = (nz.z - origin.z) * inverseDirection.z
        let tz1 = (fz.z - origin.z) * inverseDirection.z
        let tmin = max(max(min(tx0, tx1), min(ty0, ty1)), min(tz0, tz1))
        let tmax = min(min(max(tx0, tx1), max(ty0, ty1)), max(tz0, tz1))
        return tmax >= tmin
    }

    public func intersects(sphereOrigin: Point3D, sphereRadius: Double) -> Bool {
        let x = origin.vector - sphereOrigin.vector
        let y = 4 * simd_dot(direction.vector, direction.vector)
        let z = 2 * simd_dot(x, direction.vector)
        let w = simd_dot(x, x) - sphereRadius * sphereRadius
        return (z * z - y * w) > 0
    }

    public func contains(_ point: Point3D) -> Bool {
        Vector3D(point.vector - origin.vector).rotated(by: Rotation3D(from: direction, to: Vector3D.forward)) == .zero
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(direction)
    }

    private enum CodingKeys: String, CodingKey { case origin, direction }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin, forKey: .origin)
        try container.encode(direction, forKey: .direction)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(origin: try container.decode(Point3D.self, forKey: .origin),
                  direction: try container.decode(Vector3D.self, forKey: .direction))
    }

    public var description: String {
        "(origin: \(origin), direction: \(direction))"
    }

    public var customMirror: Mirror {
        Mirror(self, children: ["origin": origin, "direction": direction])
    }
}
