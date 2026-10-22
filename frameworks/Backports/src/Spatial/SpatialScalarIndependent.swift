import Foundation
import simd

@frozen
public struct Axis3D: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let x = Axis3D(0x0001)
    public static let y = Axis3D(0x0002)
    public static let z = Axis3D(0x0004)
}

@frozen
public struct Dimension3DSet: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let x = Dimension3DSet(rawValue: 1 << 0)
    public static let y = Dimension3DSet(rawValue: 1 << 1)
    public static let z = Dimension3DSet(rawValue: 1 << 2)
    public static let all: Dimension3DSet = [.x, .y, .z]
}

public let defaultTolerance = Double.ulpOfOne.squareRoot()

public let defaultToleranceFloat = Float.ulpOfOne.squareRoot()

@frozen
public struct SPEulerAngleOrder: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let xyz = SPEulerAngleOrder(0x0001)
    public static let zxy = SPEulerAngleOrder(0x0002)
}

public protocol Primitive3D: Decodable, Encodable, Equatable {
    static var zero: Self { get }
    static var infinity: Self { get }
    var isZero: Bool { get }
    var isFinite: Bool { get }
    var isNaN: Bool { get }

    func applying(_ transform: AffineTransform3D) -> Self
    func applying(_ transform: ProjectiveTransform3D) -> Self
    func applying(_ pose: Pose3D) -> Self
    mutating func apply(_ transform: AffineTransform3D)
    mutating func apply(_ transform: ProjectiveTransform3D)
    mutating func apply(_ pose: Pose3D)
    func unapplying(_ transform: AffineTransform3D) -> Self
    mutating func unapply(_ transform: AffineTransform3D)
    func unapplying(_ transform: ProjectiveTransform3D) -> Self
    mutating func unapply(_ transform: ProjectiveTransform3D)
    func unapplying(_ pose: Pose3D) -> Self
    mutating func unapply(_ pose: Pose3D)

    func translated(by vector: Vector3D) -> Self
    func rotated(by rotation: Rotation3D) -> Self
    func rotated(by quaternion: simd_quatd) -> Self
    func rotation(to other: Self) -> Rotation3D
}

public protocol Translatable3D {
    func translated(by vector: Vector3D) -> Self
    mutating func translate(by vector: Vector3D)
}

public protocol Scalable3D {
    var scale: Size3D { get }
    func scaledBy(x: Double, y: Double, z: Double) -> Self
    func scaled(by scale: Size3D) -> Self
    func uniformlyScaled(by scale: Double) -> Self
    mutating func scaleBy(x: Double, y: Double, z: Double)
    mutating func scale(by scale: Size3D)
    mutating func uniformlyScale(by scale: Double)
}

extension Scalable3D {
    public mutating func scaleBy(x: Double = 1, y: Double = 1, z: Double = 1) { self = scaledBy(x: x, y: y, z: z) }
    public mutating func scale(by scale: Size3D) { self = scaled(by: scale) }
    public mutating func uniformlyScale(by scale: Double) { self = uniformlyScaled(by: scale) }
}

public protocol Rotatable3D {
    func rotated(by rotation: Rotation3D) -> Self
    func rotated(by quaternion: simd_quatd) -> Self
    mutating func rotate(by rotation: Rotation3D)
    mutating func rotate(by quaternion: simd_quatd)
}

extension Rotatable3D {
    public mutating func rotate(by rotation: Rotation3D) { self = self.rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = self.rotated(by: quaternion) }
}

public protocol Shearable3D {
    func sheared(_ shear: AxisWithFactors) -> Self
    mutating func shear(_ shear: AxisWithFactors)
}

extension Shearable3D {
    public mutating func shear(_ shear: AxisWithFactors) { self = self.sheared(shear) }
}

public protocol Volumetric {
    var size: Size3D { get }
    func contains(_ other: Self) -> Bool
    func contains(point: Point3D) -> Bool
    func contains(anyOf points: [Point3D]) -> Bool
    func union(_ other: Self) -> Self
    mutating func formUnion(_ other: Self)
    func intersection(_ other: Self) -> Self?
    mutating func formIntersection(_ other: Self)
}

public protocol ClampableWithinRect {
    func clamped(to rect: Rect3D) -> Self
    mutating func clamp(to rect: Rect3D)
}

extension ClampableWithinRect {
    public mutating func clamp(to rect: Rect3D) { self = self.clamped(to: rect) }
}
