import CoreGraphics
import Foundation
import simd

public typealias SCNFloat = Float

extension SCNVector3 {
    public init(_ x: Float, _ y: Float, _ z: Float) {
        self.init(x: x, y: y, z: z)
    }

    public init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) {
        self.init(x: Float(x), y: Float(y), z: Float(z))
    }

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.init(x: Float(x), y: Float(y), z: Float(z))
    }

    public init(_ x: Int, _ y: Int, _ z: Int) {
        self.init(x: Float(x), y: Float(y), z: Float(z))
    }

    public init(_ v: SIMD3<Float>) {
        self.init(x: v.x, y: v.y, z: v.z)
    }

    public init(_ v: SIMD3<Double>) {
        self.init(x: Float(v.x), y: Float(v.y), z: Float(v.z))
    }
}

extension SIMD3 where Scalar == Float {
    public init(_ v: SCNVector3) {
        self.init(v.x, v.y, v.z)
    }
}

extension SIMD3 where Scalar == Double {
    public init(_ v: SCNVector3) {
        self.init(Double(v.x), Double(v.y), Double(v.z))
    }
}

extension SCNVector4 {
    public init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.init(x: x, y: y, z: z, w: w)
    }

    public init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ w: CGFloat) {
        self.init(x: Float(x), y: Float(y), z: Float(z), w: Float(w))
    }

    public init(_ x: Double, _ y: Double, _ z: Double, _ w: Double) {
        self.init(x: Float(x), y: Float(y), z: Float(z), w: Float(w))
    }

    public init(_ x: Int, _ y: Int, _ z: Int, _ w: Int) {
        self.init(x: Float(x), y: Float(y), z: Float(z), w: Float(w))
    }

    public init(_ v: SIMD4<Float>) {
        self.init(x: v.x, y: v.y, z: v.z, w: v.w)
    }

    public init(_ v: SIMD4<Double>) {
        self.init(x: Float(v.x), y: Float(v.y), z: Float(v.z), w: Float(v.w))
    }
}

extension SIMD4 where Scalar == Float {
    public init(_ v: SCNVector4) {
        self.init(v.x, v.y, v.z, v.w)
    }
}

extension SIMD4 where Scalar == Double {
    public init(_ v: SCNVector4) {
        self.init(Double(v.x), Double(v.y), Double(v.z), Double(v.w))
    }
}

extension SCNMatrix4 {
    public init(_ m: float4x4) {
        self.init(m11: m[0][0], m12: m[0][1], m13: m[0][2], m14: m[0][3],
                  m21: m[1][0], m22: m[1][1], m23: m[1][2], m24: m[1][3],
                  m31: m[2][0], m32: m[2][1], m33: m[2][2], m34: m[2][3],
                  m41: m[3][0], m42: m[3][1], m43: m[3][2], m44: m[3][3])
    }

    public init(_ m: double4x4) {
        self.init(m11: Float(m[0][0]), m12: Float(m[0][1]), m13: Float(m[0][2]), m14: Float(m[0][3]),
                  m21: Float(m[1][0]), m22: Float(m[1][1]), m23: Float(m[1][2]), m24: Float(m[1][3]),
                  m31: Float(m[2][0]), m32: Float(m[2][1]), m33: Float(m[2][2]), m34: Float(m[2][3]),
                  m41: Float(m[3][0]), m42: Float(m[3][1]), m43: Float(m[3][2]), m44: Float(m[3][3]))
    }
}

extension simd_float4x4 {
    public init(_ m: SCNMatrix4) {
        self.init(columns: (SIMD4<Float>(m.m11, m.m12, m.m13, m.m14),
                            SIMD4<Float>(m.m21, m.m22, m.m23, m.m24),
                            SIMD4<Float>(m.m31, m.m32, m.m33, m.m34),
                            SIMD4<Float>(m.m41, m.m42, m.m43, m.m44)))
    }
}

extension simd_double4x4 {
    public init(_ m: SCNMatrix4) {
        self.init(columns: (SIMD4<Double>(Double(m.m11), Double(m.m12), Double(m.m13), Double(m.m14)),
                            SIMD4<Double>(Double(m.m21), Double(m.m22), Double(m.m23), Double(m.m24)),
                            SIMD4<Double>(Double(m.m31), Double(m.m32), Double(m.m33), Double(m.m34)),
                            SIMD4<Double>(Double(m.m41), Double(m.m42), Double(m.m43), Double(m.m44))))
    }
}

extension SCNGeometryElement {
    public convenience init<IndexType: FixedWidthInteger>(indices: [IndexType], primitiveType: SCNGeometryPrimitiveType) {
        let indexCount = indices.count
        let primitiveCount: Int
        switch primitiveType {
        case .triangles:
            primitiveCount = indexCount / 3
        case .triangleStrip:
            primitiveCount = indexCount - 2
        case .line:
            primitiveCount = indexCount / 2
        case .point:
            primitiveCount = indexCount
        case .polygon:
            preconditionFailure("A polygon has a different number of indices per primitive")
        @unknown default:
            preconditionFailure("Unexpected primitive type")
        }
        let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        self.init(data: data, primitiveType: primitiveType, primitiveCount: primitiveCount, bytesPerIndex: MemoryLayout<IndexType>.stride)
    }
}

extension SCNGeometrySource {
    @nonobjc public convenience init(vertices: [SCNVector3]) {
        self.init(__vertices: vertices, count: vertices.count)
    }

    @nonobjc public convenience init(normals: [SCNVector3]) {
        self.init(__normals: normals, count: normals.count)
    }

    @nonobjc public convenience init(textureCoordinates: [CGPoint]) {
        self.init(__textureCoordinates: textureCoordinates, count: textureCoordinates.count)
    }
}

extension SCNBoundingVolume {
    public var boundingBox: (min: SCNVector3, max: SCNVector3) {
        get {
            var minimum = SCNVector3Zero
            var maximum = SCNVector3Zero
            __getBoundingBoxMin(&minimum, max: &maximum)
            return (min: minimum, max: maximum)
        }
        set {
            var minimum = newValue.min
            var maximum = newValue.max
            __setBoundingBoxMin(&minimum, max: &maximum)
        }
    }

    public var boundingSphere: (center: SCNVector3, radius: Float) {
        var center = SCNVector3Zero
        var radius = CGFloat(0)
        __getBoundingSphereCenter(&center, radius: &radius)
        return (center: center, radius: Float(radius))
    }
}

extension SCNSceneSource {
    public func entryWithIdentifier<T: AnyObject>(_ uid: String, withClass entryClass: T.Type) -> T? {
        return __entry(withIdentifier: uid, with: entryClass) as! T?
    }
}

extension SCNVector3: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue {
        return NSValue(scnVector3: self)
    }

    public static func _forceBridgeFromObjectiveC(_ source: NSValue, result: inout SCNVector3?) {
        result = source.scnVector3Value
    }

    public static func _conditionallyBridgeFromObjectiveC(_ source: NSValue, result: inout SCNVector3?) -> Bool {
        guard strcmp(source.objCType, NSValue(scnVector3: SCNVector3()).objCType) == 0 else {
            result = nil
            return false
        }
        result = source.scnVector3Value
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSValue?) -> SCNVector3 {
        var result: SCNVector3?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}

extension SCNVector4: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue {
        return NSValue(scnVector4: self)
    }

    public static func _forceBridgeFromObjectiveC(_ source: NSValue, result: inout SCNVector4?) {
        result = source.scnVector4Value
    }

    public static func _conditionallyBridgeFromObjectiveC(_ source: NSValue, result: inout SCNVector4?) -> Bool {
        guard strcmp(source.objCType, NSValue(scnVector4: SCNVector4()).objCType) == 0 else {
            result = nil
            return false
        }
        result = source.scnVector4Value
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSValue?) -> SCNVector4 {
        var result: SCNVector4?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}

extension SCNMatrix4: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue {
        return NSValue(scnMatrix4: self)
    }

    public static func _forceBridgeFromObjectiveC(_ source: NSValue, result: inout SCNMatrix4?) {
        result = source.scnMatrix4Value
    }

    public static func _conditionallyBridgeFromObjectiveC(_ source: NSValue, result: inout SCNMatrix4?) -> Bool {
        guard strcmp(source.objCType, NSValue(scnMatrix4: SCNMatrix4()).objCType) == 0 else {
            result = nil
            return false
        }
        result = source.scnMatrix4Value
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSValue?) -> SCNMatrix4 {
        var result: SCNMatrix4?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}
