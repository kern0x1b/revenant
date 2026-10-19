import simd
import Foundation

public protocol Component {
    static var __size: Int { get }
    static func __free(to buffer: UnsafeMutableRawPointer, offset: Int)
    static func __fromCore(_ coreComponent: __ComponentRef) -> Self
    func __toCore(_ coreComponent: __ComponentRef)
    static var __coreComponentType: __ComponentTypeRef { get }
    static func __addIntrospectionData(_ builder: OpaquePointer?)
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

    public static var componentName: String {
        __REComponentRegistry.shared.registration(of: Self.self, size: __size).name
    }
}

extension Component {
    public static func registerComponent() {
        _ = __REComponentRegistry.shared.registration(of: Self.self, size: __size)
    }
}

@frozen public struct Transform: Component, Hashable {
    public static let identity = Transform()

    public var scale: SIMD3<Float> = .one
    public var rotation: simd_quatf = Transform.identityRotation
    public var translation: SIMD3<Float> = .zero

    public static let identityRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    public init() {}

    public init(scale: SIMD3<Float> = SIMD3<Float>(x: 1, y: 1, z: 1),
                rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                translation: SIMD3<Float> = SIMD3<Float>(x: 0, y: 0, z: 0)) {
        self.scale = scale
        self.rotation = rotation
        self.translation = translation
    }

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

    public init(matrix: float4x4) {
        self = Transform.__decompose(matrix)
    }

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

    static func __compose(translation: SIMD3<Float>, rotation: simd_quatf, scale: SIMD3<Float>) -> float4x4 {
        let basis = simd_float3x3(rotation)
        return float4x4(SIMD4<Float>(basis.columns.0 * scale.x, 0),
                        SIMD4<Float>(basis.columns.1 * scale.y, 0),
                        SIMD4<Float>(basis.columns.2 * scale.z, 0),
                        SIMD4<Float>(translation, 1))
    }

    static func __decompose(_ matrix: float4x4) -> Transform {
        let translation = SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
        let scale = SIMD3<Float>(simd_length(matrix.columns.0), simd_length(matrix.columns.1), simd_length(matrix.columns.2))
        let basis = simd_float3x3(columns: (__re3(matrix.columns.0) / scale.x,
                                            __re3(matrix.columns.1) / scale.y,
                                            __re3(matrix.columns.2) / scale.z))
        return Transform(scale: scale, rotation: simd_quatf(basis), translation: translation)
    }

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

@inline(__always)
internal func __re3(_ vector: SIMD4<Float>) -> SIMD3<Float> {
    SIMD3<Float>(vector.x, vector.y, vector.z)
}

extension __REEntity {
    public var transformAsComponent: Transform {
        get { transform }
        set { transform = newValue }
    }
}
