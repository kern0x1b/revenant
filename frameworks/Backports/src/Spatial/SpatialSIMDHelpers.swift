import Foundation
import simd

extension simd_float3x3 {
    var isIdentity: Bool {
        columns.0 == SIMD3<Float>(1, 0, 0) && columns.1 == SIMD3<Float>(0, 1, 0) && columns.2 == SIMD3<Float>(0, 0, 1)
    }
}

extension simd_double3x3 {
    var isIdentity: Bool {
        columns.0 == SIMD3<Double>(1, 0, 0) && columns.1 == SIMD3<Double>(0, 1, 0) && columns.2 == SIMD3<Double>(0, 0, 1)
    }
}

extension simd_float3 {
    func isApproximatelyEqual(to other: simd_float3, tolerance: Float) -> Bool {
        abs(x - other.x) < tolerance && abs(y - other.y) < tolerance && abs(z - other.z) < tolerance
    }
}

extension simd_float4x3 {
    func isApproximatelyEqual(to other: simd_float4x3, tolerance: Float) -> Bool {
        columns.0.isApproximatelyEqual(to: other.columns.0, tolerance: tolerance) &&
            columns.1.isApproximatelyEqual(to: other.columns.1, tolerance: tolerance) &&
            columns.2.isApproximatelyEqual(to: other.columns.2, tolerance: tolerance) &&
            columns.3.isApproximatelyEqual(to: other.columns.3, tolerance: tolerance)
    }
}

extension simd_double4x3 {
    func isApproximatelyEqual(to other: simd_double4x3, tolerance: Double) -> Bool {
        columns.0.isApproximatelyEqual(to: other.columns.0, tolerance: tolerance) &&
            columns.1.isApproximatelyEqual(to: other.columns.1, tolerance: tolerance) &&
            columns.2.isApproximatelyEqual(to: other.columns.2, tolerance: tolerance) &&
            columns.3.isApproximatelyEqual(to: other.columns.3, tolerance: tolerance)
    }
}

@inlinable
func identity3x3(_ element: Float) -> simd_float3x3 {
    simd_float3x3(columns: (SIMD3<Float>(element, 0, 0), SIMD3<Float>(0, element, 0), SIMD3<Float>(0, 0, element)))
}

@inlinable
func identity3x3(_ element: Double) -> simd_double3x3 {
    simd_double3x3(columns: (SIMD3<Double>(element, 0, 0), SIMD3<Double>(0, element, 0), SIMD3<Double>(0, 0, element)))
}

func indexOfFlip(_ axis: Axis3D) -> Int? {
    switch axis {
    case .x: return 0
    case .y: return 1
    case .z: return 2
    default: return nil
    }
}

@inlinable
func first3(_ v: simd_double4) -> simd_double3 { simd_double3(v.x, v.y, v.z) }

@inlinable
func first3(_ v: simd_float4) -> simd_float3 { simd_float3(v.x, v.y, v.z) }

@inlinable
func floor3(_ v: simd_double3) -> simd_double3 { simd_double3(Darwin.floor(v.x), Darwin.floor(v.y), Darwin.floor(v.z)) }

@inlinable
func floor3(_ v: simd_float3) -> simd_float3 { simd_float3(Darwin.floorf(v.x), Darwin.floorf(v.y), Darwin.floorf(v.z)) }

@inlinable
func ceil3(_ v: simd_double3) -> simd_double3 { simd_double3(Darwin.ceil(v.x), Darwin.ceil(v.y), Darwin.ceil(v.z)) }

@inlinable
func ceil3(_ v: simd_float3) -> simd_float3 { simd_float3(Darwin.ceilf(v.x), Darwin.ceilf(v.y), Darwin.ceilf(v.z)) }
