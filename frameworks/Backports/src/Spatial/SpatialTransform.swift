import Foundation
import simd

@frozen
public struct Rotation3D: Rotatable3D, Rotatable3DProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
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

    public var quaternion: simd_quatd

    public var vector: SIMD4<Double> {
        get { quaternion.vector }
        set { quaternion = simd_quatd(vector: newValue) }
    }

    public init() { self.init(simd_quatd(vector: SIMD4<Double>(0, 0, 0, 1))) }

    public init(_ quaternion: simd_quatd) { self.quaternion = quaternion }

    public init(_ source: SIMD4<Double>) { self.quaternion = simd_quatd(vector: source) }

    public init(angle: Angle2D, axis: RotationAxis3D) {
        let half = angle.radians / 2
        let unit = Vector3D(axis.vector).normalized
        let s = Darwin.sin(half)
        self.quaternion = simd_quatd(vector: SIMD4<Double>(unit.x * s, unit.y * s, unit.z * s, Darwin.cos(half)))
    }

    @available(*, deprecated, renamed: "init(angle:axis:)")
    public init(axis: RotationAxis3D, angle: Angle2D) { self.init(angle: angle, axis: axis) }

    public init(forward: Vector3D, up: Vector3D = Vector3D(x: 0, y: 1, z: 0)) {
        let z = -forward.vector
        let x = simd_cross(up.vector, z)
        let y = simd_cross(z, x)
        self.init(simd_quaternion(simd_double3x3(columns: (x, y, z))))
    }

    public init(forward: Vector3D) { self.init(forward: forward, up: Vector3D(x: 0, y: 1, z: 0)) }

    @available(*, deprecated, renamed: "init(position:target:up:)")
    public init(eye: Point3D, target: Point3D, up: Vector3D = Vector3D(x: 0, y: 1, z: 0)) {
        self.init(forward: target - eye, up: up)
    }

    public init(from: Vector3D, to: Vector3D) {
        self.init(quaternionBetween(from.vector, to.vector))
    }

    public var angle: Angle2D {
        get { Angle2D(radians: simd_angle(quaternion)) }
        set { self = Rotation3D(angle: newValue, axis: axis) }
    }

    public var axis: RotationAxis3D {
        get {
            let found = simd_axis(quaternion)
            let whole = found.x.isFinite && found.y.isFinite && found.z.isFinite
            return RotationAxis3D(whole ? found : simd_double3(repeating: 0))
        }
        set { self = Rotation3D(angle: angle, axis: newValue) }
    }

    public static let identity = Rotation3D()

    public var isIdentity: Bool {
        vector == SIMD4<Double>(0, 0, 0, 1)
    }

    public var inverse: Rotation3D {
        Rotation3D(inverseQuaternion(vector))
    }

    public var isUnit: Bool { abs(simd_length_squared(vector) - 1) < 1e-12 }

    public func rotated(by rotation: Rotation3D) -> Rotation3D { rotation * self }

    public func rotated(by quaternion: simd_quatd) -> Rotation3D { Rotation3D(quaternion) * self }

    public func rotation(to other: Rotation3D) -> Rotation3D {
        other * inverse
    }

    public static func == (lhs: Rotation3D, rhs: Rotation3D) -> Bool {
        lhs.vector == rhs.vector
    }

    public static func * (lhs: Rotation3D, rhs: Rotation3D) -> Rotation3D {
        Rotation3D(quaternionProduct(lhs.vector, rhs.vector))
    }

    public static func *= (lhs: inout Rotation3D, rhs: Rotation3D) { lhs = lhs * rhs }

    public func eulerAngles(order: SPEulerAngleOrder) -> EulerAngles {
        EulerAngles(quaternion: vector, order: order)
    }

    public init(eulerAngles: EulerAngles) { self.init(eulerAngles.quaternion) }

    public var affineTransform: AffineTransform3D { AffineTransform3D(rotation: self) }

    public func applying(_ transform: AffineTransform3D) -> Rotation3D {
        guard let turned = transform.rotation else { return self }
        return turned * self
    }

    public func applying(_ transform: ProjectiveTransform3D) -> Rotation3D {
        guard let turned = transform.rotation else { return .identity }
        return turned * self
    }

    public func applying(_ pose: Pose3D) -> Rotation3D { applying(pose.affineTransform) }
    public func applying(_ scaledPose: ScaledPose3D) -> Rotation3D { self }

    public func unapplying(_ transform: AffineTransform3D) -> Rotation3D {
        applying(transform.inverted() ?? .identity)
    }

    public func unapplying(_ transform: ProjectiveTransform3D) -> Rotation3D {
        applying(transform.inverted() ?? .identity)
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(vector) }

    private enum VectorKeys: String, CodingKey { case vector }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: VectorKeys.self)
        try container.encode(vector, forKey: .vector)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: VectorKeys.self)
        self.init(try container.decode(SIMD4<Double>.self, forKey: .vector))
    }

    public var description: String { "(quaternion: \(quaternion))" }
    public var customMirror: Mirror { Mirror(self, children: ["quaternion": quaternion]) }
}

@frozen
public struct EulerAngles: Hashable, Codable, Sendable {
    public typealias Scalar = Double
    public typealias Order = SPEulerAngleOrder

    public var angles: simd_double3

    public var order: SPEulerAngleOrder

    public init() { self.init(angles: simd_double3(repeating: 0), order: .xyz) }

    public init(angles: simd_double3, order: SPEulerAngleOrder) {
        self.angles = angles
        self.order = order
    }

    public init(quaternion: SIMD4<Double>, order: SPEulerAngleOrder) {
        let m = simd_matrix3x3(simd_quatd(vector: quaternion))
        if case .zxy = order {
            let cosine = (m.columns.0.y * m.columns.0.y + m.columns.1.y * m.columns.1.y).squareRoot()
            if cosine > 1e-6 {
                let x = Darwin.atan2(-m.columns.2.y, cosine)
                let y = Darwin.atan2(m.columns.2.x, m.columns.2.z)
                let z = Darwin.atan2(m.columns.0.y, m.columns.1.y)
                self.init(angles: simd_double3(x + 0, y + 0, z + 0), order: order)
                return
            }
        }
        let sy = (m.columns.0.x * m.columns.0.x + m.columns.0.y * m.columns.0.y).squareRoot()
        if sy > 1e-6 {
            let x = Darwin.atan2(m.columns.1.z, m.columns.2.z)
            let y = Darwin.atan2(-m.columns.0.z, sy)
            let z = Darwin.atan2(m.columns.0.y, m.columns.0.x)
            self.init(angles: simd_double3(x + 0, y + 0, z + 0), order: order)
        } else {
            let x = Darwin.atan2(-m.columns.2.y, m.columns.1.y)
            self.init(angles: simd_double3(x + 0, Darwin.atan2(-m.columns.0.z, sy) + 0, 0), order: order)
        }
    }

    public init(x: Angle2D, y: Angle2D, z: Angle2D, order: SPEulerAngleOrder) {
        self.init(angles: simd_double3(x.radians, y.radians, z.radians), order: order)
    }

    public init(_ x: Angle2D, _ y: Angle2D, _ z: Angle2D, order: SPEulerAngleOrder) {
        self.init(x: x, y: y, z: z, order: order)
    }

    public var quaternion: simd_quatd {
        simd_quatd(vector: self.vector)
    }

    public var vector: SIMD4<Double> {
        let x = SIMD4<Double>(Darwin.sin(angles.x / 2), 0, 0, Darwin.cos(angles.x / 2))
        let y = SIMD4<Double>(0, Darwin.sin(angles.y / 2), 0, Darwin.cos(angles.y / 2))
        let z = SIMD4<Double>(0, 0, Darwin.sin(angles.z / 2), Darwin.cos(angles.z / 2))
        switch order {
        case .zxy: return quaternionProduct(y, quaternionProduct(x, z))
        default: return quaternionProduct(z, quaternionProduct(y, x))
        }
    }

    public static func == (lhs: EulerAngles, rhs: EulerAngles) -> Bool {
        lhs.angles == rhs.angles && lhs.order == rhs.order
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(angles)
        hasher.combine(order)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(angles, forKey: .angles)
        try container.encode(order.rawValue, forKey: .order)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(angles: try container.decode(simd_double3.self, forKey: .angles),
                  order: SPEulerAngleOrder(try container.decode(UInt32.self, forKey: .order)))
    }

    private enum CodingKeys: String, CodingKey { case angles, order }
}

@frozen
public struct AffineTransform3D: Transform3DProtocol, Shearable3D, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
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

    public var matrix: simd_double4x3

    public init() { self.matrix = AffineTransform3D.identityMatrix }

    public init(_ matrix: simd_double4x3) { self.matrix = matrix }

    public init(matrix: simd_double4x3) { self.matrix = matrix }

    public init?(_ matrix: simd_double4x4) { self.init(truncating: matrix) }

    public init?(matrix: simd_double4x4) { self.init(truncating: matrix) }

    public init?(projectiveTransform transform: ProjectiveTransform3D) {
        self.init(truncating: transform.matrix)
    }

    public init(truncating matrix: simd_double4x4) {
        self.matrix = simd_matrix(first3(matrix.columns.0), first3(matrix.columns.1),
                                    first3(matrix.columns.2), first3(matrix.columns.3))
    }

    public init(truncating transform: ProjectiveTransform3D) { self.init(truncating: transform.matrix) }

    public init(scale: Size3D) { self.matrix = AffineTransform3D.identityMatrix.scalingBy(x: scale.width, y: scale.height, z: scale.depth) }
    public init(rotation: Rotation3D) { self.matrix = AffineTransform3D.identityMatrix.rotatingBy(rotation) }
    public init(translation offset: Vector3D) { self.matrix = AffineTransform3D.identityMatrix.translatingBy(offset) }
    public init(shear: AxisWithFactors) { self.matrix = AffineTransform3D.identityMatrix.shearing(shear) }

    public init(scale: Size3D = Size3D(width: 1, height: 1, depth: 1), rotation: Rotation3D, translation: Vector3D) {
        self.matrix = AffineTransform3D.identityMatrix.scalingBy(x: scale.width, y: scale.height, z: scale.depth).rotatingBy(rotation).translatingBy(translation)
    }

    public init(pose: Pose3D) { self.matrix = pose.matrix4x3 }
    public init(scaledPose: ScaledPose3D) { self.matrix = scaledPose.matrix4x3 }

    @available(*, deprecated, renamed: "init(offset:)", message: "Use `Vector3D` variant.")
    public init(translation: Size3D) { self.init(translation: Vector3D(translation)) }

    public static let identity = AffineTransform3D()

    static var identityMatrix: simd_double4x3 {
        simd_matrix(simd_double3(1, 0, 0), simd_double3(0, 1, 0), simd_double3(0, 0, 1), simd_double3(0, 0, 0))
    }

    public var columns: (Vector3D, Vector3D, Vector3D, Vector3D) {
        get { (Vector3D(matrix.columns.0), Vector3D(matrix.columns.1),
                Vector3D(matrix.columns.2), Vector3D(matrix.columns.3)) }
        set { matrix = simd_matrix(newValue.0.vector, newValue.1.vector, newValue.2.vector, newValue.3.vector) }
    }

    public var matrix3x3: simd_double3x3 {
        simd_double3x3(columns: (matrix.columns.0, matrix.columns.1, matrix.columns.2))
    }

    public var matrix4x4: simd_double4x4 {
        var full = simd_double4x4()
        full.columns.0 = SIMD4<Double>(matrix.columns.0, 0)
        full.columns.1 = SIMD4<Double>(matrix.columns.1, 0)
        full.columns.2 = SIMD4<Double>(matrix.columns.2, 0)
        full.columns.3 = SIMD4<Double>(matrix.columns.3, 1)
        return full
    }

    public var translation: Vector3D {
        get { Vector3D(matrix.columns.3) }
        set { matrix.columns.3 = simd_double3(newValue.vector) }
    }

    public var offset: Vector3D {
        get { translation }
        set { translation = newValue }
    }

    public var isIdentity: Bool {
        matrix.columns.0 == Self.identityMatrix.columns.0 && matrix.columns.1 == Self.identityMatrix.columns.1 &&
            matrix.columns.2 == Self.identityMatrix.columns.2 && matrix.columns.3 == Self.identityMatrix.columns.3
    }

    public var isTranslation: Bool { matrix3x3.isIdentity }

    public var isInvertible: Bool { simd_determinant(matrix3x3) != 0 }

    public var isRectilinear: Bool {
        let rotation = simd_quaternion(matrix3x3)
        let turn: Double = simd_angle(rotation)
        let angle = abs(Darwin.remainder(turn, Double.pi / 2))
        return angle < spatialDefaultTolerance()
    }

    public var isUniform: Bool {
        let size = scale
        return isRectilinear && size.width == size.height && size.height == size.depth
    }

    public func isUniform(overDimensions: Dimension3DSet) -> Bool {
        let size = scale
        var uniform = isRectilinear
        if overDimensions.contains(.x) { uniform = uniform && size.width == 1 }
        if overDimensions.contains(.y) { uniform = uniform && size.height == 1 }
        if overDimensions.contains(.z) { uniform = uniform && size.depth == 1 }
        return uniform
    }

    public var scale: Size3D {
        let m = matrix3x3
        let sign: Double = simd_determinant(m) >= 0 ? 1 : -1
        return Size3D(width: simd_length(m.columns.0) * sign,
                              height: simd_length(m.columns.1) * sign,
                              depth: simd_length(m.columns.2) * sign)
    }

    public var rotation: Rotation3D? {
        var m = matrix3x3
        let s = scale.vector
        guard s.x != 0, s.y != 0, s.z != 0 else { return nil }
        m.columns.0 = m.columns.0 / s.x
        m.columns.1 = m.columns.1 / s.y
        m.columns.2 = m.columns.2 / s.z
        m.columns.1 = m.columns.1 - simd_project(m.columns.1, m.columns.0)
        m.columns.2 = m.columns.2 - simd_project(m.columns.2, m.columns.0) - simd_project(m.columns.2, m.columns.1)
        m.columns.0 = simd_normalize(m.columns.0)
        m.columns.1 = simd_normalize(m.columns.1)
        m.columns.2 = simd_normalize(m.columns.2)
        let q = simd_quaternion(m)
        let v = q.vector
        guard v.x.isFinite && v.y.isFinite && v.z.isFinite && v.w.isFinite else { return nil }
        return Rotation3D(simd_normalize(q))
    }

    public var inverse: AffineTransform3D? { inverted() }

    public func inverted() -> AffineTransform3D? {
        guard let full = invertedMatrix(matrix4x4) else { return nil }
        return AffineTransform3D(simd_matrix(first3(full.columns.0), first3(full.columns.1),
                                                      first3(full.columns.2), first3(full.columns.3)))
    }

    public func concatenating(_ other: AffineTransform3D) -> AffineTransform3D {
        let product = simd_mul(matrix4x4, other.matrix4x4)
        return AffineTransform3D(simd_matrix(first3(product.columns.0), first3(product.columns.1),
                                                       first3(product.columns.2), first3(product.columns.3)))
    }

    public static func * (lhs: AffineTransform3D, rhs: AffineTransform3D) -> AffineTransform3D {
        lhs.concatenating(rhs)
    }

    public static func *= (lhs: inout AffineTransform3D, rhs: AffineTransform3D) { lhs = lhs * rhs }

    public static func == (lhs: AffineTransform3D, rhs: AffineTransform3D) -> Bool {
        lhs.matrix.isApproximatelyEqual(to: rhs.matrix, tolerance: 0)
    }

    public func isApproximatelyEqual(to other: AffineTransform3D, tolerance: Double) -> Bool {
        matrix4x4.isApproximatelyEqual(to: other.matrix4x4, tolerance: tolerance)
    }

    public func changeBasis(from: AffineTransform3D = .identity, to: AffineTransform3D = .identity) -> AffineTransform3D? {
        guard let fromInverse = from.inverted() else { return nil }
        return to.concatenating(self).concatenating(fromInverse)
    }

    public func scaledBy(x: Double = 1, y: Double = 1, z: Double = 1) -> AffineTransform3D {
        AffineTransform3D(matrix: matrix.scalingBy(x: x, y: y, z: z))
    }

    public mutating func scaleBy(x: Double = 1, y: Double = 1, z: Double = 1) { self = scaledBy(x: x, y: y, z: z) }
    public func scaled(by scale: Size3D) -> AffineTransform3D { scaledBy(x: scale.width, y: scale.height, z: scale.depth) }
    public mutating func scale(by scale: Size3D) { self = scaled(by: scale) }
    public func uniformlyScaled(by scale: Double) -> AffineTransform3D { scaledBy(x: scale, y: scale, z: scale) }
    public mutating func uniformlyScale(by scale: Double) { self = uniformlyScaled(by: scale) }

    public func sheared(_ shear: AxisWithFactors) -> AffineTransform3D {
        AffineTransform3D(matrix: matrix.shearing(shear))
    }

    public mutating func shear(_ shear: AxisWithFactors) { self = sheared(shear) }

    public func translated(by offset: Vector3D) -> AffineTransform3D {
        AffineTransform3D(matrix: matrix.translatingBy(offset))
    }

    @available(*, deprecated, renamed: "translated(by:)", message: "Use `Vector3D` variant.")
    public func translated(by size: Size3D) -> AffineTransform3D { self + Vector3D(size) }

    public mutating func translate(by vector: Vector3D) { self = translated(by: vector) }
    public mutating func translate(by size: Size3D) { self = translated(by: Vector3D(size)) }

    public static func + (lhs: AffineTransform3D, rhs: Vector3D) -> AffineTransform3D { lhs.translated(by: rhs) }

    public func rotated(by rotation: Rotation3D) -> AffineTransform3D {
        AffineTransform3D(matrix: matrix.rotatingBy(rotation))
    }

    public func rotated(by quaternion: simd_quatd) -> AffineTransform3D {
        rotated(by: Rotation3D(quaternion))
    }

    public func rotation(to other: AffineTransform3D) -> Rotation3D {
        guard let mine = rotation, let theirs = other.rotation else { return .identity }
        return theirs * mine.inverse
    }

    public mutating func rotate(by rotation: Rotation3D) { self = rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = rotated(by: quaternion) }

    public func flipped(along axis: Axis3D) -> AffineTransform3D {
        guard let index = indexOfFlip(axis) else { return self }
        return AffineTransform3D(matrix: matrix.flippingColumn(index))
    }

    public mutating func flip(along axis: Axis3D) { self = flipped(along: axis) }

    private static func index(of axis: Axis3D) -> Int? { indexOfFlip(axis) }

    public func hash(into hasher: inout Hasher) { hasher.combine(matrix.columns.0)
        hasher.combine(matrix.columns.1)
        hasher.combine(matrix.columns.2)
        hasher.combine(matrix.columns.3) }

    private enum ColumnKeys: String, CodingKey { case column0, column1, column2, column3 }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: ColumnKeys.self)
        try container.encode(matrix.columns.0, forKey: .column0)
        try container.encode(matrix.columns.1, forKey: .column1)
        try container.encode(matrix.columns.2, forKey: .column2)
        try container.encode(matrix.columns.3, forKey: .column3)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: ColumnKeys.self)
        self.matrix = simd_matrix(try container.decode(simd_double3.self, forKey: .column0),
                                  try container.decode(simd_double3.self, forKey: .column1),
                                  try container.decode(simd_double3.self, forKey: .column2),
                                  try container.decode(simd_double3.self, forKey: .column3))
    }

    public var description: String { "(matrix: \(matrix))" }
    public var customMirror: Mirror { Mirror(self, children: ["matrix": matrix]) }
}

@frozen
public struct ProjectiveTransform3D: Transform3DProtocol, Shearable3D, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
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

    public var matrix: simd_double4x4

    public init() { self.matrix = ProjectiveTransform3D.identityMatrix }

    public init(_ matrix: simd_double4x4) { self.matrix = matrix }
    public init(matrix: simd_double4x4) { self.matrix = matrix }

    public init(scale: Size3D) { self.matrix = ProjectiveTransform3D.identityMatrix.scalingBy(x: scale.width, y: scale.height, z: scale.depth) }
    public init(rotation: Rotation3D) { self.matrix = ProjectiveTransform3D.identityMatrix.rotatingBy(rotation) }
    public init(translation offset: Vector3D) { self.matrix = ProjectiveTransform3D.identityMatrix.translatingBy(offset) }
    public init(shear: AxisWithFactors) { self.matrix = ProjectiveTransform3D.identityMatrix.shearing(shear) }

    public init(scale: Size3D = Size3D(width: 1, height: 1, depth: 1), rotation: Rotation3D, translation: Vector3D) {
        self.matrix = ProjectiveTransform3D.identityMatrix.scalingBy(x: scale.width, y: scale.height, z: scale.depth).rotatingBy(rotation).translatingBy(translation)
    }

    public init(pose: Pose3D) { self.matrix = pose.matrix }
    public init(scaledPose: ScaledPose3D) { self.matrix = scaledPose.matrix }

    @available(*, deprecated, renamed: "init(offset:)", message: "Use `Vector3D` variant.")
    public init(translation: Size3D) { self.init(translation: Vector3D(translation)) }

    public static let identity = ProjectiveTransform3D()

    static var identityMatrix: simd_double4x4 {
        var m = simd_double4x4()
        m.columns.0 = SIMD4<Double>(1, 0, 0, 0)
        m.columns.1 = SIMD4<Double>(0, 1, 0, 0)
        m.columns.2 = SIMD4<Double>(0, 0, 1, 0)
        m.columns.3 = SIMD4<Double>(0, 0, 0, 1)
        return m
    }

    public var matrix3x3: simd_double3x3 {
        simd_double3x3(columns: (first3(matrix.columns.0), first3(matrix.columns.1), first3(matrix.columns.2)))
    }

    public var matrix4x4: simd_double4x4 { matrix }

    public var translation: Vector3D {
        get { Vector3D(matrix.columns.3) }
        set { matrix.columns.3 = SIMD4<Double>(newValue.vector, matrix.columns.3.w) }
    }

    public var offset: Vector3D {
        get { translation }
        set { translation = newValue }
    }

    public var scaleComponent: Size3D {
        Size3D(width: Vector3D(matrix3x3.columns.0).length,
                        height: Vector3D(matrix3x3.columns.1).length,
                        depth: Vector3D(matrix3x3.columns.2).length)
    }

    public var isIdentity: Bool {
        matrix.isApproximatelyEqual(to: ProjectiveTransform3D.identityMatrix, tolerance: 0) &&
            matrix.columns.3.w == 1
    }
    public var isTranslation: Bool { matrix3x3.isIdentity && matrix.columns.3.w == 1 }
    public var isInvertible: Bool { invertedMatrix(matrix) != nil }

    public var isRectilinear: Bool {
        let rotation = simd_quaternion(matrix3x3)
        let turn: Double = simd_angle(rotation)
        let angle = abs(Darwin.remainder(turn, Double.pi / 2))
        return angle < spatialDefaultTolerance()
    }

    public var isUniform: Bool {
        let size = scale
        return isRectilinear && size.width == size.height && size.height == size.depth
    }

    public func isUniform(overDimensions: Dimension3DSet) -> Bool {
        let size = scale
        var uniform = isRectilinear
        if overDimensions.contains(.x) { uniform = uniform && size.width == 1 }
        if overDimensions.contains(.y) { uniform = uniform && size.height == 1 }
        if overDimensions.contains(.z) { uniform = uniform && size.depth == 1 }
        return uniform
    }

    public var scale: Size3D {
        let m = matrix3x3
        let sign: Double = simd_determinant(m) >= 0 ? 1 : -1
        return Size3D(width: simd_length(m.columns.0) * sign,
                              height: simd_length(m.columns.1) * sign,
                              depth: simd_length(m.columns.2) * sign)
    }

    public var rotation: Rotation3D? {
        AffineTransform3D(truncating: matrix).rotation
    }

    public var inverse: ProjectiveTransform3D? { inverted() }

    public func inverted() -> ProjectiveTransform3D? {
        invertedMatrix(matrix).map { ProjectiveTransform3D($0) }
    }

    public func concatenating(_ other: ProjectiveTransform3D) -> ProjectiveTransform3D {
        ProjectiveTransform3D(simd_mul(matrix, other.matrix))
    }

    public static func * (lhs: ProjectiveTransform3D, rhs: ProjectiveTransform3D) -> ProjectiveTransform3D {
        lhs.concatenating(rhs)
    }

    public static func *= (lhs: inout ProjectiveTransform3D, rhs: ProjectiveTransform3D) { lhs = lhs * rhs }

    public static func == (lhs: ProjectiveTransform3D, rhs: ProjectiveTransform3D) -> Bool {
        lhs.matrix.isApproximatelyEqual(to: rhs.matrix, tolerance: 0)
    }

    public func isApproximatelyEqual(to other: ProjectiveTransform3D, tolerance: Double) -> Bool {
        simd_almost_equal_elements(matrix, other.matrix, tolerance)
    }

    public func scaledBy(x: Double = 1, y: Double = 1, z: Double = 1) -> ProjectiveTransform3D {
        ProjectiveTransform3D(matrix: matrix.scalingBy(x: x, y: y, z: z))
    }

    public mutating func scaleBy(x: Double = 1, y: Double = 1, z: Double = 1) { self = scaledBy(x: x, y: y, z: z) }
    public func scaled(by scale: Size3D) -> ProjectiveTransform3D { scaledBy(x: scale.width, y: scale.height, z: scale.depth) }
    public mutating func scale(by scale: Size3D) { self = scaled(by: scale) }
    public func uniformlyScaled(by scale: Double) -> ProjectiveTransform3D { scaledBy(x: scale, y: scale, z: scale) }
    public mutating func uniformlyScale(by scale: Double) { self = uniformlyScaled(by: scale) }

    public func sheared(_ shear: AxisWithFactors) -> ProjectiveTransform3D {
        ProjectiveTransform3D(matrix: matrix.shearing(shear))
    }

    public mutating func shear(_ shear: AxisWithFactors) { self = sheared(shear) }

    public func translated(by offset: Vector3D) -> ProjectiveTransform3D {
        ProjectiveTransform3D(matrix: matrix.translatingBy(offset))
    }

    @available(*, deprecated, renamed: "translated(by:)", message: "Use `Vector3D` variant.")
    public func translated(by size: Size3D) -> ProjectiveTransform3D { self + Vector3D(size) }

    public mutating func translate(by vector: Vector3D) { self = translated(by: vector) }
    public mutating func translate(by size: Size3D) { self = translated(by: Vector3D(size)) }

    public static func + (lhs: ProjectiveTransform3D, rhs: Vector3D) -> ProjectiveTransform3D { lhs.translated(by: rhs) }

    public func rotated(by rotation: Rotation3D) -> ProjectiveTransform3D {
        ProjectiveTransform3D(matrix: matrix.rotatingBy(rotation))
    }

    public func rotated(by quaternion: simd_quatd) -> ProjectiveTransform3D {
        rotated(by: Rotation3D(quaternion))
    }

    public mutating func rotate(by rotation: Rotation3D) { self = rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = rotated(by: quaternion) }

    public func flipped(along axis: Axis3D) -> ProjectiveTransform3D {
        guard let index = indexOfFlip(axis) else { return self }
        return ProjectiveTransform3D(matrix: matrix.flippingColumn(index))
    }

    public mutating func flip(along axis: Axis3D) { self = flipped(along: axis) }

    public func hash(into hasher: inout Hasher) { hasher.combine(matrix.columns.0)
        hasher.combine(matrix.columns.1)
        hasher.combine(matrix.columns.2)
        hasher.combine(matrix.columns.3) }

    private enum ColumnKeys: String, CodingKey { case column0, column1, column2, column3 }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: ColumnKeys.self)
        try container.encode(matrix.columns.0, forKey: .column0)
        try container.encode(matrix.columns.1, forKey: .column1)
        try container.encode(matrix.columns.2, forKey: .column2)
        try container.encode(matrix.columns.3, forKey: .column3)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: ColumnKeys.self)
        self.matrix = simd_matrix(try container.decode(SIMD4<Double>.self, forKey: .column0),
                                  try container.decode(SIMD4<Double>.self, forKey: .column1),
                                  try container.decode(SIMD4<Double>.self, forKey: .column2),
                                  try container.decode(SIMD4<Double>.self, forKey: .column3))
    }

    public var description: String { "(matrix: \(matrix))" }
    public var customMirror: Mirror { Mirror(self, children: ["matrix": matrix]) }
}

@frozen
public struct Pose3D: Rotatable3D, Translatable3D, Rotatable3DProtocol, Translatable3DProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
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

    public var position: Point3D
    public var rotation: Rotation3D

    public init() { self.init(position: .zero, rotation: .identity) }

    public init(position: Point3D = .zero, rotation: Rotation3D) {
        self.position = position
        self.rotation = rotation
    }

    public init(position: simd_double3 = .zero, rotation: simd_quatd) {
        self.init(position: Point3D(position), rotation: Rotation3D(rotation))
    }

    public init(position: Point3D, target: Point3D,
                up: Vector3D = Vector3D(x: 0, y: 1, z: 0)) {
        self.init(position: position, rotation: Rotation3D(forward: target - position, up: up))
    }

    public init(forward: Vector3D, up: Vector3D) {
        self.init(position: .zero, rotation: Rotation3D(forward: forward, up: up))
    }

    public init?(transform: AffineTransform3D) {
        guard let rotation = transform.rotation else { return nil }
        self.init(position: Point3D(transform.translation), rotation: rotation)
    }

    public init?(transform: ProjectiveTransform3D) {
        guard let rotation = transform.rotation else { return nil }
        self.init(position: Point3D(transform.translation), rotation: rotation)
    }

    public init?(_ matrix: simd_double4x4) {
        guard let pose = Pose3D(transform: AffineTransform3D(truncating: matrix)) else { return nil }
        self = pose
    }

    public init?(matrix: simd_double4x4) { self.init(matrix) }

    public static let identity = Pose3D()

    public var isIdentity: Bool { position.isZero && rotation == .identity }

    public var matrix: simd_double4x4 { affineTransform.matrix4x4 }

    var matrix4x3: simd_double4x3 { affineTransform.matrix }

    var affineTransform: AffineTransform3D {
        var transform = AffineTransform3D(rotation: rotation)
        transform.translation = Vector3D(position)
        return transform
    }

    public var inverse: Pose3D {
        let negated = Point3D(x: -position.x, y: -position.y, z: -position.z)
        return Pose3D(position: negated.rotated(by: rotation.inverse), rotation: rotation.inverse)
    }

    public func concatenated(with other: Pose3D) -> Pose3D {
        Pose3D(position: position + Vector3D(other.position.rotated(by: rotation)),
                     rotation: rotation * other.rotation)
    }

    public func concatenated(with other: ScaledPose3D) -> ScaledPose3D {
        ScaledPose3D(pose: self).concatenated(with: other)
    }

    public func concatenating(_ transform: Pose3D) -> Pose3D { concatenated(with: transform) }
    public func concatenating(_ transform: ScaledPose3D) -> ScaledPose3D { concatenated(with: transform) }

    public static func * (lhs: Pose3D, rhs: Pose3D) -> Pose3D { lhs.concatenated(with: rhs) }
    public static func *= (lhs: inout Pose3D, rhs: Pose3D) { lhs = lhs * rhs }

    public func applying(_ transform: ProjectiveTransform3D) -> Pose3D {
        Pose3D(position: position.applying(transform), rotation: rotation.applying(transform))
    }

    public func applying(_ transform: AffineTransform3D) -> Pose3D {
        Pose3D(position: position.applying(transform), rotation: rotation.applying(transform))
    }

    public func unapplying(_ transform: AffineTransform3D) -> Pose3D {
        Pose3D(position: position.unapplying(transform), rotation: rotation.unapplying(transform))
    }

    public func isApproximatelyEqual(to other: Pose3D, tolerance: Double) -> Bool {
        position.isApproximatelyEqual(to: other.position, tolerance: tolerance) &&
            rotation.isApproximatelyEqual(to: other.rotation, tolerance: tolerance)
    }

    public func translated(by offset: Vector3D) -> Pose3D {
        Pose3D(position: position + offset, rotation: rotation)
    }

    @available(*, deprecated, message: "Use the `Vector3D` variant.")
    public func translated(by size: Size3D) -> Pose3D { self + Vector3D(size) }

    public mutating func translate(by vector: Vector3D) { self = translated(by: vector) }
    public mutating func translate(by size: Size3D) { self = translated(by: Vector3D(size)) }

    public static func + (lhs: Pose3D, rhs: Vector3D) -> Pose3D { lhs.translated(by: rhs) }

    public func rotated(by rotation: Rotation3D) -> Pose3D {
        Pose3D(position: position, rotation: self.rotation * rotation)
    }

    public func rotated(by quaternion: simd_quatd) -> Pose3D { rotated(by: Rotation3D(quaternion)) }

    public func rotation(to other: Pose3D) -> Rotation3D {
        position.rotation(to: other.position)
    }

    public mutating func rotate(by rotation: Rotation3D) { self = rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = rotated(by: quaternion) }

    public static func == (lhs: Pose3D, rhs: Pose3D) -> Bool {
        lhs.position == rhs.position && lhs.rotation == rhs.rotation
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(position)
        hasher.combine(rotation)
    }

    private enum CodingKeys: String, CodingKey { case position, rotation }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(rotation, forKey: .rotation)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(position: try container.decode(Point3D.self, forKey: .position),
                  rotation: try container.decode(Rotation3D.self, forKey: .rotation))
    }

    public var description: String { "(position: \(position), rotation: \(rotation))" }
    public var customMirror: Mirror { Mirror(self, children: ["position": position, "rotation": rotation]) }
}

@frozen
public struct ScaledPose3D: Rotatable3D, Translatable3D, Rotatable3DProtocol, Translatable3DProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable {
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

    public var position: Point3D
    public var rotation: Rotation3D
    public var scale: Double

    public init() { self.init(position: .zero, rotation: .identity, scale: 1) }

    public init(position: Point3D, rotation: Rotation3D, scale: Double = 1) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    public init(position: simd_double3 = .zero, rotation: simd_quatd, scale: Double = 1) {
        self.init(position: Point3D(position), rotation: Rotation3D(rotation), scale: scale)
    }

    public init(pose: Pose3D) {
        self.init(position: pose.position, rotation: pose.rotation, scale: 1)
    }

    public init(_ pose: Pose3D) { self.init(pose: pose) }

    public init?(transform: ProjectiveTransform3D) {
        guard let rotation = transform.rotation else { return nil }
        self.init(position: Point3D(transform.translation), rotation: rotation,
                  scale: transform.scale.width)
    }

    public init?(transform: simd_double4x4) {
        self.init(transform: ProjectiveTransform3D(transform))
    }

    public static let identity = ScaledPose3D()

    public var isIdentity: Bool { position.isZero && rotation == .identity && scale == 1 }

    public var pose: Pose3D { Pose3D(position: position, rotation: rotation) }

    public var matrix: simd_double4x4 { affineTransform.matrix4x4 }

    var matrix4x3: simd_double4x3 { affineTransform.matrix }

    var affineTransform: AffineTransform3D {
        var transform = AffineTransform3D(scale: Size3D(width: scale, height: scale, depth: scale),
                                                  rotation: rotation, translation: .zero)
        transform.translation = Vector3D(position)
        return transform
    }

    public var inverse: ScaledPose3D {
        ScaledPose3D(position: position.rotated(by: rotation.inverse).uniformlyScaled(by: -1 / scale),
                              rotation: rotation.inverse,
                              scale: 1 / scale)
    }

    public func concatenated(with other: ScaledPose3D) -> ScaledPose3D {
        ScaledPose3D(position: position + Vector3D(other.position.rotated(by: rotation).uniformlyScaled(by: scale)),
                              rotation: rotation * other.rotation,
                              scale: scale * other.scale)
    }

    public func concatenating(_ transform: ScaledPose3D) -> ScaledPose3D { concatenated(with: transform) }

    public static func * (lhs: ScaledPose3D, rhs: ScaledPose3D) -> ScaledPose3D {
        lhs.concatenated(with: rhs)
    }

    public static func *= (lhs: inout ScaledPose3D, rhs: ScaledPose3D) { lhs = lhs * rhs }

    public func applying(_ transform: ProjectiveTransform3D) -> ScaledPose3D {
        let matrix = simd_mul(matrix, transform.matrix)
        guard let pose = ScaledPose3D(transform: ProjectiveTransform3D(matrix)) else { return self }
        return pose
    }

    public func applying(_ transform: AffineTransform3D) -> ScaledPose3D {
        applying(ProjectiveTransform3D(transform.matrix4x4))
    }

    public func unapplying(_ transform: AffineTransform3D) -> ScaledPose3D {
        applying(transform.inverted() ?? .identity)
    }

    public func isApproximatelyEqual(to other: ScaledPose3D, tolerance: Double) -> Bool {
        pose.isApproximatelyEqual(to: other.pose, tolerance: tolerance) &&
            (scale - other.scale) * (scale - other.scale) < tolerance * tolerance
    }

    public func translated(by offset: Vector3D) -> ScaledPose3D {
        ScaledPose3D(position: position + offset, rotation: rotation, scale: scale)
    }

    @available(*, deprecated, message: "Use the `Vector3D` variant.")
    public func translated(by size: Size3D) -> ScaledPose3D { self + Vector3D(size) }

    public mutating func translate(by vector: Vector3D) { self = translated(by: vector) }
    public mutating func translate(by size: Size3D) { self = translated(by: Vector3D(size)) }

    public static func + (lhs: ScaledPose3D, rhs: Vector3D) -> ScaledPose3D { lhs.translated(by: rhs) }

    public func rotated(by rotation: Rotation3D) -> ScaledPose3D {
        ScaledPose3D(position: position.rotated(by: rotation), rotation: self.rotation * rotation, scale: scale)
    }

    public func rotated(by quaternion: simd_quatd) -> ScaledPose3D { rotated(by: Rotation3D(quaternion)) }

    public func rotation(to other: ScaledPose3D) -> Rotation3D {
        position.rotation(to: other.position)
    }

    public mutating func rotate(by rotation: Rotation3D) { self = rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = rotated(by: quaternion) }

    public static func == (lhs: ScaledPose3D, rhs: ScaledPose3D) -> Bool {
        lhs.position == rhs.position && lhs.rotation == rhs.rotation && lhs.scale == rhs.scale
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(position)
        hasher.combine(rotation)
        hasher.combine(scale)
    }

    private enum CodingKeys: String, CodingKey { case position, rotation, scale }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(scale, forKey: .scale)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(position: try container.decode(Point3D.self, forKey: .position),
                  rotation: try container.decode(Rotation3D.self, forKey: .rotation),
                  scale: try container.decode(Double.self, forKey: .scale))
    }

    public var description: String { "(position: \(position), rotation: \(rotation), scale: \(scale))" }
    public var customMirror: Mirror { Mirror(self, children: ["position": position, "rotation": rotation, "scale": scale]) }
}
