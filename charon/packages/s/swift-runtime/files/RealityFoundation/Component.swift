// The component protocol, its registration, and the three of the four core types.

import simd
import Foundation

// MARK: - Component

/// A type that provides custom data for an entity.
///
/// A component is a value: an entity carries at most one of a type, setting a second of that
/// type replaces the first, and reading one that was never set is nil. The registration
/// (`registerComponent()`) tells the engine what the type is called and how large it is, which
/// is what a scene needs before it can store one.
public protocol Component {
    /// The size in bytes of the component's value, which the engine stores components in a
    /// buffer of.
    static var __size: Int { get }
    /// Releases the value stored at `offset` in `buffer`, for the types whose storage holds
    /// something the value does not own.
    static func __free(to buffer: UnsafeMutableRawPointer, offset: Int)
    /// The value this component stands for in a component reference.
    static func __fromCore(_ coreComponent: __ComponentRef) -> Self
    /// Writes this value into a component reference.
    func __toCore(_ coreComponent: __ComponentRef)
    /// The registration of this component type.
    static var __coreComponentType: __ComponentTypeRef { get }
    /// Adds this type's name to the introspection data a scene hands out.
    static func __addIntrospectionData(_ builder: OpaquePointer?)
    /// The name of the component type, as `registerComponent()` recorded it.
    static var __typeName: String { get }
}

extension Component {
    public static var __size: Int { MemoryLayout<Self>.stride }

    public static func __free(to buffer: UnsafeMutableRawPointer, offset: Int) {}

    public static func __fromCore(_ coreComponent: __ComponentRef) -> Self {
        coreComponent.__as(Self.self)
    }

    public func __toCore(_ coreComponent: __ComponentRef) {
        coreComponent.__write(self)
    }

    public static var __coreComponentType: __ComponentTypeRef {
        __ComponentTypeRef(__REComponentRegistry.shared.registration(of: Self.self, size: __size))
    }

    public static func __addIntrospectionData(_ builder: OpaquePointer?) {}

    public static var __typeName: String { componentName }

    /// The name of this component type, which is what the scene's introspection data and a
    /// serialized scene call it.
    public static var componentName: String {
        __REComponentRegistry.shared.registration(of: Self.self, size: __size).name
    }
}

extension Component {
    /// Registers this component type with the engine.
    ///
    /// Registering a type a second time does nothing: the name and the size of a type do not
    /// change, and the scene that already knows the type keeps the one it has.
    public static func registerComponent() {
        _ = __REComponentRegistry.shared.registration(of: Self.self, size: __size)
    }
}

// MARK: - Transform

/// A translation, a rotation and a scale, which is the transform of every entity.
@frozen public struct Transform: Component, Hashable {
    /// The transform of an entity that has not been moved: no translation, no rotation, no scale.
    public static let identity = Transform()

    public var scale: SIMD3<Float> = .one
    public var rotation: simd_quatf = Transform.identityRotation
    public var translation: SIMD3<Float> = .zero

    /// The rotation of `Transform.identity`, spelled out because the `simd` module this port
    /// builds has no `simd_quatf.identity`.
    public static let identityRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    public init() {}

    public init(scale: SIMD3<Float> = SIMD3<Float>(x: 1, y: 1, z: 1),
                rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                translation: SIMD3<Float> = SIMD3<Float>(x: 0, y: 0, z: 0)) {
        self.scale = scale
        self.rotation = rotation
        self.translation = translation
    }

    /// The transform of an entity rotated by `pitch` about its x axis, by `yaw` about its y
    /// axis and by `roll` about its z axis, in that order: the rotation is the quaternion
    /// product `qy(yaw) * qx(pitch) * qz(roll)`, whose matrix is `Ry(yaw) * Rx(pitch) * Rz(roll)`.
    ///
    /// Measured, not assumed (2026-09-27, host, arm64-apple-macos14 against the Command Line
    /// Tools' MacOSX26.5 SDK, which carries RealityKit): the system's own answers for
    /// `Transform(pitch: 0.3, yaw: 0.5, roll: 0.7)` is
    /// `SIMD4<Float>(0.21989578, 0.18014587, 0.2937772, 0.91262716)` and for
    /// `(1.1, -0.4, 2.2)` is `SIMD4<Float>(0.08141868, -0.53336304, 0.7917335, 0.28644878)`.
    /// This expression agrees with both to 1e-16, and with the three single-axis cases
    /// (`pi/2` about each axis in turn, the identity). The SDK's header spells the same order
    /// through `simd_quatf(eulerAngles:order: .yxz)`, which is not in the simd module either
    /// SDK carries, so the composition is written out here.
    public init(pitch x: Float = 0, yaw y: Float = 0, roll z: Float = 0) {
        let halfPitch = x / 2, halfYaw = y / 2, halfRoll = z / 2
        let sp = Darwin.sin(halfPitch), cp = Darwin.cos(halfPitch)
        let sy = Darwin.sin(halfYaw), cy = Darwin.cos(halfYaw)
        let sr = Darwin.sin(halfRoll), cr = Darwin.cos(halfRoll)
        self.init(scale: .one,
                  rotation: simd_quatf(ix: cr * cy * sp + sr * cp * sy,
                                       iy: cr * cp * sy - sr * cy * sp,
                                       iz: sr * cp * cy - cr * sy * sp,
                                       r: cr * cp * cy + sr * sy * sp),
                  translation: .zero)
    }

    /// The transform a matrix spells out: its translation, the length of each of its first
    /// three columns as the scale, and the rotation of the basis they leave.
    public init(matrix: float4x4) {
        self = Transform.__decompose(matrix)
    }

    /// The transform as a matrix, translation by rotation by scale.
    public var matrix: float4x4 {
        get { Transform.__compose(translation: translation, rotation: rotation, scale: scale) }
        set {
            let decomposed = Transform.__decompose(newValue)
            scale = decomposed.scale
            rotation = decomposed.rotation
            translation = decomposed.translation
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(scale)
        hasher.combine(rotation.vector)
        hasher.combine(translation)
    }

    public static func == (a: Transform, b: Transform) -> Bool {
        a.scale == b.scale && a.rotation == b.rotation && a.translation == b.translation
    }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }

    // MARK: The matrix form

    /// translation * rotation * scale, column-major: each column of the rotation matrix is
    /// scaled by its own component of `scale`, and the translation is the fourth column.
    static func __compose(translation: SIMD3<Float>, rotation: simd_quatf, scale: SIMD3<Float>) -> float4x4 {
        let basis = simd_float3x3(rotation)
        return float4x4(SIMD4<Float>(basis.columns.0 * scale.x, 0),
                        SIMD4<Float>(basis.columns.1 * scale.y, 0),
                        SIMD4<Float>(basis.columns.2 * scale.z, 0),
                        SIMD4<Float>(translation, 1))
    }

    /// The transform a matrix spells out. A column of length zero leaves the rotation of that
    /// axis undefined; the basis is then read as it stands, which is the same answer a
    /// normalization of a zero vector gives.
    static func __decompose(_ matrix: float4x4) -> Transform {
        let translation = SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
        let scale = SIMD3<Float>(simd_length(matrix.columns.0), simd_length(matrix.columns.1), simd_length(matrix.columns.2))
        let basis = simd_float3x3(columns: (__re3(matrix.columns.0) / scale.x,
                                            __re3(matrix.columns.1) / scale.y,
                                            __re3(matrix.columns.2) / scale.z))
        return Transform(scale: scale, rotation: simd_quatf(basis), translation: translation)
    }

    // MARK: The component's storage

    public var __coreSRT: __SRTRef {
        __SRTRef(scale: scale, rotation: rotation, translation: translation)
    }

    public static func __fromCore(_ coreSRT: __SRTRef) -> Transform {
        coreSRT.__as(Transform.self)
    }

    public static func __fromCore(_ coreComponent: __ComponentRef) -> Transform {
        coreComponent.__as(Transform.self)
    }

    public func __toCore(_ coreComponent: __ComponentRef) {
        coreComponent.__write(self)
    }

}

/// The three components of a four, dropping the fourth.
@inline(__always)
internal func __re3(_ vector: SIMD4<Float>) -> SIMD3<Float> {
    SIMD3<Float>(vector.x, vector.y, vector.z)
}

// Transform is a component of every entity and the scene graph reads it directly, so it is
// both: the value of the node, and the one a `components` subscript finds.
extension __REEntity {
    /// The transform as a `Component` value, so `components[Transform.self]` and
    /// `HasTransform.transform` read and write the same storage.
    public var transformAsComponent: Transform {
        get { transform }
        set { transform = newValue }
    }
}
