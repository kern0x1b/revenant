import simd

public protocol SpatialTypeProtocol<Scalar>: Decodable, Encodable, Equatable {
    associatedtype Scalar: Numeric where Scalar == Self.AffineTransform.Scalar,
                                       Self.AffineTransform.Scalar == Self.Point.Scalar,
                                       Self.Point.Scalar == Self.Pose.Scalar,
                                       Self.Pose.Scalar == Self.ProjectiveTransform.Scalar,
                                       Self.ProjectiveTransform.Scalar == Self.Rect.Scalar,
                                       Self.Rect.Scalar == Self.Rotation.Scalar,
                                       Self.Rotation.Scalar == Self.Size.Scalar,
                                       Self.Size.Scalar == Self.Vector.Scalar
    associatedtype AffineTransform: Transform3DProtocol
    associatedtype ProjectiveTransform: Transform3DProtocol
    associatedtype Pose: Rotatable3DProtocol, Translatable3DProtocol
    associatedtype Rect: Primitive3DProtocol
    associatedtype Vector: Primitive3DProtocol
    associatedtype Point: Primitive3DProtocol
    associatedtype Size: Primitive3DProtocol
    associatedtype Rotation: Rotatable3DProtocol
    associatedtype Quaternion
    associatedtype AxisEnumeration
}

public protocol Rotatable3DProtocol<Scalar>: SpatialTypeProtocol {
    func rotation(to other: Self) -> Self.Rotation
    func rotated(by rotation: Self.Rotation) -> Self
    func rotated(by quaternion: Self.Quaternion) -> Self
    mutating func rotate(by rotation: Self.Rotation)
    mutating func rotate(by quaternion: Self.Quaternion)
}

extension Rotatable3DProtocol {
    public mutating func rotate(by rotation: Self.Rotation) { self = self.rotated(by: rotation) }
    public mutating func rotate(by quaternion: Self.Quaternion) { self = self.rotated(by: quaternion) }
}

public protocol Translatable3DProtocol<Scalar>: SpatialTypeProtocol {
    func translated(by vector: Self.Vector) -> Self
    mutating func translate(by vector: Self.Vector)
}

extension Translatable3DProtocol {
    public mutating func translate(by vector: Self.Vector) { self = self.translated(by: vector) }
}

public protocol Scalable3DProtocol<Scalar>: SpatialTypeProtocol {
    var scale: Self.Size { get }
    func scaledBy(x: Self.Scalar, y: Self.Scalar, z: Self.Scalar) -> Self
    func scaled(by scale: Self.Size) -> Self
    func uniformlyScaled(by scale: Self.Scalar) -> Self
    mutating func scaleBy(x: Self.Scalar, y: Self.Scalar, z: Self.Scalar)
    mutating func scale(by scale: Self.Size)
    mutating func uniformlyScale(by scale: Self.Scalar)
}

public protocol Shearable3DProtocol<Scalar>: SpatialTypeProtocol {
    func sheared(_ shear: Self.AxisEnumeration) -> Self
    mutating func shear(_ shear: Self.AxisEnumeration)
}

public protocol Transform3DProtocol: SpatialTypeProtocol {
    init(shear: Self.AxisEnumeration)
    init(scale: Self.Size)
    init(rotation: Self.Rotation)
    init(translation: Self.Vector)
    init(scale: Self.Size, rotation: Self.Rotation, translation: Self.Vector)

    var isIdentity: Bool { get }
    static var identity: Self { get }
    var isTranslation: Bool { get }
    var isUniform: Bool { get }
    func isUniform(overDimensions: Dimension3DSet) -> Bool
    var isRectilinear: Bool { get }

    func concatenating(_ transform: Self) -> Self
    var inverse: Self? { get }
    func inverted() -> Self?
    func isApproximatelyEqual(to other: Self, tolerance: Self.Scalar) -> Bool

    var translation: Self.Vector { get set }
    var rotation: Self.Rotation? { get }

    mutating func flip(along axis: Axis3D)
    func flipped(along axis: Axis3D) -> Self
}

public protocol Primitive3DProtocol<Scalar>: Rotatable3DProtocol {
    static var zero: Self { get }
    static var infinity: Self { get }
    var isZero: Bool { get }
    var isFinite: Bool { get }
    var isNaN: Bool { get }

    func applying(_ transform: Self.AffineTransform) -> Self
    func applying(_ transform: Self.ProjectiveTransform) -> Self
    func applying(_ pose: Self.Pose) -> Self
    mutating func apply(_ transform: Self.AffineTransform)
    mutating func apply(_ transform: Self.ProjectiveTransform)
    mutating func apply(_ pose: Self.Pose)

    func unapplying(_ transform: Self.AffineTransform) -> Self
    mutating func unapply(_ transform: Self.AffineTransform)
    func unapplying(_ transform: Self.ProjectiveTransform) -> Self
    func unapplying(_ pose: Self.Pose) -> Self
    mutating func unapply(_ transform: Self.ProjectiveTransform)
    mutating func unapply(_ pose: Self.Pose)
}

public protocol VolumetricProtocol<Scalar>: SpatialTypeProtocol {
    var size: Self.Size { get }
    func contains(_ other: Self) -> Bool
    func contains(point: Self.Point) -> Bool
    func union(_ other: Self) -> Self
    func intersection(_ other: Self) -> Self?
    mutating func formIntersection(_ other: Self)
    mutating func formUnion(_ other: Self)
    func contains(anyOf points: [Self.Point]) -> Bool
}

public protocol ClampableWithinRectProtocol<Scalar>: SpatialTypeProtocol {
    func clamped(to rect: Self.Rect) -> Self
    mutating func clamp(to rect: Self.Rect)
}

public protocol ProjectiveTransformable3D {
    func applying(_ transform: ProjectiveTransform3D) -> Self
}
