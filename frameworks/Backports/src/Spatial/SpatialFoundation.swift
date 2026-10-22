import Foundation
import simd

@frozen
public enum AxisWithFactors {
    case xAxis(yShearFactor: Double, zShearFactor: Double)
    case yAxis(xShearFactor: Double, zShearFactor: Double)
    case zAxis(xShearFactor: Double, yShearFactor: Double)
}

@frozen
public struct Angle2D: AdditiveArithmetic, Comparable, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
    public typealias Scalar = Double

    public var radians: Double

    public init() { self.radians = 0 }
    public init(radians: Double) { self.radians = radians }
    public init<T: BinaryFloatingPoint>(radians: T) { self.radians = Double(radians) }
    public init(degrees: Double) { self.radians = degrees * Double.pi / 180 }
    public init<T: BinaryFloatingPoint>(degrees: T) { self.radians = Double(degrees) * Double.pi / 180 }

    public static let zero = Angle2D(radians: 0)
    public static func radians(_ radians: Double) -> Angle2D { Angle2D(radians: radians) }
    public static func degrees(_ degrees: Double) -> Angle2D { Angle2D(degrees: degrees) }

    public var degrees: Double { radians * 180 / Double.pi }

    public var normalized: Angle2D {
        var value = radians.truncatingRemainder(dividingBy: 2 * Double.pi)
        if value > Double.pi {
            value -= 2 * Double.pi
        } else if value <= -Double.pi {
            value += 2 * Double.pi
        }
        return Angle2D(radians: value)
    }

    public static func + (lhs: Angle2D, rhs: Angle2D) -> Angle2D { Angle2D(radians: lhs.radians + rhs.radians) }
    public static prefix func + (x: Self) -> Self { Angle2D(radians: x.radians) }
    public static func - (lhs: Angle2D, rhs: Angle2D) -> Angle2D { Angle2D(radians: lhs.radians - rhs.radians) }
    public static prefix func - (angle: Angle2D) -> Angle2D { Angle2D(radians: -angle.radians) }
    public static func += (lhs: inout Angle2D, rhs: Angle2D) { lhs = lhs + rhs }
    public static func -= (lhs: inout Angle2D, rhs: Angle2D) { lhs = lhs - rhs }
    public static func < (lhs: Angle2D, rhs: Angle2D) -> Bool { lhs.radians < rhs.radians }
    public static func == (lhs: Angle2D, rhs: Angle2D) -> Bool { lhs.radians == rhs.radians }

    public static func acos(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.acos(x)) }
    public static func acosh(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.acosh(x)) }
    public static func asin(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.asin(x)) }
    public static func asinh(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.asinh(x)) }
    public static func atan(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.atan(x)) }
    public static func atanh(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.atanh(x)) }
    public static func atan2(y: Double, x: Double) -> Angle2D { Angle2D(radians: Darwin.atan2(y, x)) }

    public func hash(into hasher: inout Hasher) { hasher.combine(radians) }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(radians)
    }

    public init(from decoder: any Decoder) throws {
        self.radians = try decoder.singleValueContainer().decode(Double.self)
    }

    public var description: String { "(radians: \(radians))" }
    public var customMirror: Mirror { Mirror(self, children: ["radians": radians]) }
}

@inlinable
public func cos(_ angle: Angle2D) -> Double { Darwin.cos(angle.radians) }

@inlinable
public func sin(_ angle: Angle2D) -> Double { Darwin.sin(angle.radians) }

@inlinable
public func tan(_ angle: Angle2D) -> Double { Darwin.tan(angle.radians) }

@inlinable
public func cosh(_ angle: Angle2D) -> Double { Darwin.cosh(angle.radians) }

@inlinable
public func sinh(_ angle: Angle2D) -> Double { Darwin.sinh(angle.radians) }

@inlinable
public func tanh(_ angle: Angle2D) -> Double { Darwin.tanh(angle.radians) }

@frozen
public struct Vector3D: Primitive3D, Rotatable3D, Primitive3DProtocol, AdditiveArithmetic, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
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

    public init(x: Double = 0, y: Double = 0, z: Double = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(_ vector: simd_double3) {
        self.x = vector.x
        self.y = vector.y
        self.z = vector.z
    }

    public init(_ source: simd_packed_double4) { self.init(x: source.x, y: source.y, z: source.z) }
    public init(_ size: Size3D) { self.init(size.vector) }
    public init(_ point: Point3D) { self.init(x: point.x, y: point.y, z: point.z) }
    public init(_ axis: RotationAxis3D) { self.init(axis.vector) }
    public init(_ coords: SphericalCoordinates3D) { self.init(SphericalCoordinates3D.cartesian(in: coords)) }
    public init(_ pose: Pose3D) { self.init(pose.position.vector) }
    public init(_ scale: ScaledPose3D) { self.init(x: scale.scale, y: scale.scale, z: scale.scale) }

    var vector: simd_double3 {
        get { simd_double3(x, y, z) }
        set { x = newValue.x; y = newValue.y; z = newValue.z }
    }

    public static let zero = Vector3D()
    public static let infinity = Vector3D(x: .infinity, y: .infinity, z: .infinity)
    public static let right = Vector3D(x: 1, y: 0, z: 0)
    public static let up = Vector3D(x: 0, y: 1, z: 0)
    public static let forward = Vector3D(x: 0, y: 0, z: 1)

    public var isZero: Bool { x == 0 && y == 0 && z == 0 }
    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
    public var isNaN: Bool { x.isNaN || y.isNaN || z.isNaN }

    public var lengthSquared: Double { simd_length_squared(vector) }
    public var length: Double { simd_length(vector) }
    public var normalized: Vector3D { Vector3D(simd_normalize(vector)) }

    public mutating func normalize() { self = normalized }

    public func dot(_ other: Vector3D) -> Double { simd_dot(vector, other.vector) }
    public func cross(_ other: Vector3D) -> Vector3D { Vector3D(simd_cross(vector, other.vector)) }

    public func projected(_ other: Vector3D) -> Vector3D {
        Vector3D(simd_project(vector, other.vector))
    }
    public func reflected(_ normal: Vector3D) -> Vector3D { self - normal * (2 * self.dot(normal)) }

    public func scaledBy(x: Double = 1, y: Double = 1, z: Double = 1) -> Vector3D {
        Vector3D(x: self.x * x, y: self.y * y, z: self.z * z)
    }

    public func scaled(by size: Size3D) -> Vector3D { scaledBy(x: size.width, y: size.height, z: size.depth) }
    public func uniformlyScaled(by scale: Double) -> Vector3D { scaledBy(x: scale, y: scale, z: scale) }

    public func sheared(_ shear: AxisWithFactors) -> Vector3D {
        switch shear {
        case .xAxis(let yFactor, let zFactor): return Vector3D(x: x, y: y + x * yFactor, z: z + x * zFactor)
        case .yAxis(let xFactor, let zFactor): return Vector3D(x: x + y * xFactor, y: y, z: z + y * zFactor)
        case .zAxis(let xFactor, let yFactor): return Vector3D(x: x + z * xFactor, y: y + z * yFactor, z: z)
        }
    }

    public mutating func shear(_ shear: AxisWithFactors) { self = sheared(shear) }

    public func translated(by vector: Vector3D) -> Vector3D { self }

    public func rotated(by rotation: Rotation3D) -> Vector3D { applying(rotation.affineTransform) }
    public func rotated(by quaternion: simd_quatd) -> Vector3D { applying(Rotation3D(quaternion).affineTransform) }
    public func rotation(to other: Vector3D) -> Rotation3D { Rotation3D(from: self, to: other) }

    public func applying(_ transform: AffineTransform3D) -> Vector3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ transform: ProjectiveTransform3D) -> Vector3D { applying(matrix: transform.matrix4x4) }
    public func applying(_ pose: Pose3D) -> Vector3D { applying(matrix: pose.matrix) }
    public func applying(_ scaledPose: ScaledPose3D) -> Vector3D { applying(matrix: scaledPose.matrix) }

    public func unapplying(_ transform: AffineTransform3D) -> Vector3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ transform: ProjectiveTransform3D) -> Vector3D { unapplying(matrix: transform.matrix4x4) }
    public func unapplying(_ pose: Pose3D) -> Vector3D { unapplying(matrix: pose.matrix) }
    public func unapplying(_ scaledPose: ScaledPose3D) -> Vector3D { unapplying(matrix: scaledPose.matrix) }

    public mutating func apply(_ transform: AffineTransform3D) { self = applying(transform) }
    public mutating func apply(_ transform: ProjectiveTransform3D) { self = applying(transform) }
    public mutating func apply(_ pose: Pose3D) { self = applying(pose) }
    public mutating func unapply(_ transform: AffineTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ transform: ProjectiveTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ pose: Pose3D) { self = unapplying(pose) }

    func applying(matrix: simd_double4x4) -> Vector3D {
        Vector3D(first3(simd_mul(matrix, SIMD4<Double>(vector, 0))))
    }

    func unapplying(matrix: simd_double4x4) -> Vector3D {
        guard let inverse = invertedMatrix(matrix) else { return self }
        return applying(matrix: inverse)
    }

    public static func + (lhs: Vector3D, rhs: Vector3D) -> Vector3D {
        Vector3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func - (lhs: Vector3D, rhs: Vector3D) -> Vector3D {
        Vector3D(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static func * (lhs: Vector3D, rhs: Double) -> Vector3D {
        Vector3D(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    public static func * (lhs: Double, rhs: Vector3D) -> Vector3D { rhs * lhs }
    public static func * (lhs: Vector3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x * rhs.x, y: lhs.y * rhs.y, z: lhs.z * rhs.z)
    }
    public static func * (lhs: Point3D, rhs: Vector3D) -> Point3D {
        Point3D(x: lhs.x * rhs.x, y: lhs.y * rhs.y, z: lhs.z * rhs.z)
    }
    public static func * (lhs: Vector3D, rhs: Size3D) -> Size3D {
        Size3D(width: lhs.x * rhs.width, height: lhs.y * rhs.height, depth: lhs.z * rhs.depth)
    }
    public static func * (lhs: Size3D, rhs: Vector3D) -> Size3D {
        Size3D(width: lhs.width * rhs.x, height: lhs.height * rhs.y, depth: lhs.depth * rhs.z)
    }
    public static func * (lhs: Vector3D, rhs: AffineTransform3D) -> Vector3D { lhs.applying(rhs) }
    public static func * (lhs: Vector3D, rhs: ProjectiveTransform3D) -> Vector3D { lhs.applying(rhs) }
    public static func * (lhs: Vector3D, rhs: Pose3D) -> Vector3D { lhs * rhs.affineTransform }

    public static func / (lhs: Vector3D, rhs: Double) -> Vector3D {
        Vector3D(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }

    public static prefix func - (vector: Vector3D) -> Vector3D {
        Vector3D(x: -vector.x, y: -vector.y, z: -vector.z)
    }

    public static func += (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs + rhs }
    public static func -= (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs - rhs }
    public static func *= (lhs: inout Vector3D, rhs: Double) { lhs = lhs * rhs }
    public static func /= (lhs: inout Vector3D, rhs: Double) { lhs = lhs / rhs }

    public static func == (lhs: Vector3D, rhs: Vector3D) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }

    public static func + (lhs: Vector3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func + (lhs: Size3D, rhs: Vector3D) -> Size3D {
        Size3D(width: lhs.width + rhs.x, height: lhs.height + rhs.y, depth: lhs.depth + rhs.z)
    }

    public static func + (lhs: Vector3D, rhs: Size3D) -> Size3D {
        Size3D(width: lhs.x + rhs.width, height: lhs.y + rhs.height, depth: lhs.z + rhs.depth)
    }
    public static func - (lhs: Point3D, rhs: Vector3D) -> Point3D {
        Point3D(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static func - (lhs: Vector3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static func - (lhs: Size3D, rhs: Vector3D) -> Size3D {
        Size3D(width: lhs.width - rhs.x, height: lhs.height - rhs.y, depth: lhs.depth - rhs.z)
    }

    public static func - (lhs: Vector3D, rhs: Size3D) -> Size3D {
        Size3D(width: lhs.x - rhs.width, height: lhs.y - rhs.height, depth: lhs.z - rhs.depth)
    }

    public static func lerp(from: Vector3D, to: Vector3D, t: Vector3D) -> Vector3D {
        Vector3D(x: from.x + (to.x - from.x) * t.x,
                          y: from.y + (to.y - from.y) * t.y,
                          z: from.z + (to.z - from.z) * t.z)
    }

    public static func smoothstep(edge0: Vector3D, edge1: Vector3D, x: Vector3D) -> Vector3D {
        func one(_ low: Double, _ high: Double, _ value: Double) -> Double {
            guard low != high else { return value < low ? 0 : 1 }
            let t = min(max((value - low) / (high - low), 0), 1)
            return t * t * (3 - 2 * t)
        }
        return Vector3D(x: one(edge0.x, edge1.x, x.x),
                                 y: one(edge0.y, edge1.y, x.y),
                                 z: one(edge0.z, edge1.z, x.z))
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
public struct RotationAxis3D: Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
    public typealias Scalar = Double
    public typealias Vector = Vector3D

    public var x: Double
    public var y: Double
    public var z: Double

    public init() { self.init(x: 0, y: 0, z: 0) }
    public init(x: Double = 0, y: Double = 0, z: Double = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init<T: BinaryFloatingPoint>(x: T, y: T, z: T) { self.init(x: Double(x), y: Double(y), z: Double(z)) }
    public init(_ xyz: Vector3D) { self.init(x: xyz.x, y: xyz.y, z: xyz.z) }
    public init(_ xyz: simd_double3) { self.init(x: xyz.x, y: xyz.y, z: xyz.z) }
    public init(_ source: simd_packed_double4) { self.init(x: source.x, y: source.y, z: source.z) }
    public init(vector: simd_double3) { self.init(x: vector.x, y: vector.y, z: vector.z) }

    public var vector: simd_double3 {
        get { simd_double3(x, y, z) }
        set { x = newValue.x; y = newValue.y; z = newValue.z }
    }

    @available(*, deprecated, renamed: "vector")
    public var simd: simd_double3 {
        get { vector }
        set { vector = newValue }
    }

    public var isZero: Bool { x == 0 && y == 0 && z == 0 }

    public static let zero = RotationAxis3D()
    public static let x = RotationAxis3D(x: 1, y: 0, z: 0)
    public static let y = RotationAxis3D(x: 0, y: 1, z: 0)
    public static let z = RotationAxis3D(x: 0, y: 0, z: 1)
    public static let xy = RotationAxis3D(x: 1, y: 1, z: 0)
    public static let yz = RotationAxis3D(x: 0, y: 1, z: 1)
    public static let xz = RotationAxis3D(x: 1, y: 0, z: 1)
    public static let xyz = RotationAxis3D(x: 1, y: 1, z: 1)

    public static func == (lhs: RotationAxis3D, rhs: RotationAxis3D) -> Bool {
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
public struct SphericalCoordinates3D: Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
    public typealias Scalar = Double

    public var radius: Double
    public var inclination: Angle2D
    public var azimuth: Angle2D

    public init() { self.init(radius: 0, inclination: Angle2D(radians: 0), azimuth: Angle2D(radians: 0)) }
    public init(radius: Double, inclination: Angle2D, azimuth: Angle2D) {
        self.radius = radius
        self.inclination = inclination
        self.azimuth = azimuth
    }

    public init(x: Double, y: Double, z: Double) { self.init(cartesian: simd_double3(x, y, z)) }
    public init(_ vector: simd_double3) { self.init(cartesian: vector) }
    public init(_ point: Point3D) { self.init(cartesian: point.vector) }
    public init(_ vector: Vector3D) { self.init(cartesian: vector.vector) }
    public init(_ source: simd_packed_double4) { self.init(vector: simd_double3(source.x, source.y, source.z)) }

    public init(vector: simd_double3) {
        self.radius = vector.x
        self.inclination = Angle2D(radians: vector.y)
        self.azimuth = Angle2D(radians: vector.z)
    }

    public var vector: simd_double3 {
        get { simd_double3(radius, inclination.radians, azimuth.radians) }
        set {
            radius = newValue.x
            inclination = Angle2D(radians: newValue.y)
            azimuth = Angle2D(radians: newValue.z)
        }
    }

    private init(cartesian: simd_double3) {
        let radius = simd_length(cartesian)
        self.radius = radius
        let inclination = Darwin.asin(cartesian.y / radius)
        self.inclination = Angle2D(radians: inclination.isNaN ? 0 : inclination)
        let azimuth = Darwin.atan(cartesian.x / cartesian.z)
        self.azimuth = Angle2D(radians: azimuth.isNaN ? 0 : azimuth)
    }

    static func cartesian(in coords: SphericalCoordinates3D) -> simd_double3 {
        let cosInclination = Darwin.cos(coords.inclination.radians)
        return simd_double3(coords.radius * cosInclination * Darwin.sin(coords.azimuth.radians),
                          coords.radius * Darwin.sin(coords.inclination.radians),
                          coords.radius * cosInclination * Darwin.cos(coords.azimuth.radians))
    }

    public static func == (lhs: SphericalCoordinates3D, rhs: SphericalCoordinates3D) -> Bool {
        lhs.radius == rhs.radius && lhs.inclination == rhs.inclination && lhs.azimuth == rhs.azimuth
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(radius)
        hasher.combine(inclination.radians)
        hasher.combine(azimuth.radians)
    }

    private enum CodingKeys: String, CodingKey { case radius, inclination, azimuth }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(radius, forKey: .radius)
        try container.encode(inclination.radians, forKey: .inclination)
        try container.encode(azimuth.radians, forKey: .azimuth)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(radius: try container.decode(Double.self, forKey: .radius),
                  inclination: Angle2D(radians: try container.decode(Double.self, forKey: .inclination)),
                  azimuth: Angle2D(radians: try container.decode(Double.self, forKey: .azimuth)))
    }

    public var description: String { "(radius: \(radius), inclination: \(inclination), azimuth: \(azimuth))" }
    public var customMirror: Mirror { Mirror(self, children: ["radius": radius, "inclination": inclination, "azimuth": azimuth]) }
}
