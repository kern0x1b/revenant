import Foundation
import simd

@inlinable
func spatialDefaultTolerance() -> Double {
    defaultTolerance
}

@inlinable
func quaternionProduct(_ lhs: SIMD4<Double>, _ rhs: SIMD4<Double>) -> SIMD4<Double> {
    let (x1, y1, z1, w1) = (lhs.x, lhs.y, lhs.z, lhs.w)
    let (x2, y2, z2, w2) = (rhs.x, rhs.y, rhs.z, rhs.w)
    return SIMD4<Double>(w1 * x2 + x1 * w2 + (y1 * z2 - z1 * y2),
                           w1 * y2 + y1 * w2 + (z1 * x2 - x1 * z2),
                           w1 * z2 + z1 * w2 + (x1 * y2 - y1 * x2),
                           w1 * w2 - (x1 * x2 + y1 * y2 + z1 * z2))
}

@inlinable
func normalizedQuaternion(_ q: SIMD4<Double>) -> SIMD4<Double> {
    let squared = simd_length_squared(q)
    guard squared != 0, squared.isFinite else { return SIMD4<Double>(0, 0, 0, 1) }
    return q / squared.squareRoot()
}

@inlinable
func inverseQuaternion(_ q: SIMD4<Double>) -> SIMD4<Double> {
    let squared = simd_length_squared(q)
    guard squared != 0, squared.isFinite else { return SIMD4<Double>(0, 0, 0, 1) }
    return SIMD4<Double>(-q.x, -q.y, -q.z, q.w) / squared
}

@inlinable
func quaternionBetween(_ from: simd_double3, _ to: simd_double3) -> SIMD4<Double> {
    let a = from / simd_length(from)
    let b = to / simd_length(to)
    let cross = simd_cross(a, b)
    let w = 1 + simd_dot(a, b)
    if simd_length_squared(cross) < 1e-24 && w < 1e-12 {
        var across = simd_cross(a, simd_double3(1, 0, 0))
        if simd_length_squared(across) < 1e-24 {
            across = simd_cross(a, simd_double3(0, 1, 0))
        }
        return SIMD4<Double>(across / simd_length(across), 0)
    }
    let q = SIMD4<Double>(cross, w)
    return q / simd_length(q)
}

@inlinable
func vectorRotated(_ v: simd_double3, by q: SIMD4<Double>) -> simd_double3 {
    let u = SIMD3<Double>(q.y, q.z, q.w)
    let t = 2 * simd_cross(u, v)
    return v + q.w * t + simd_cross(u, t)
}

extension simd_double4x4 {
    func scalingBy(x: Double, y: Double, z: Double) -> simd_double4x4 {
        var m = self
        m.columns.0 = m.columns.0 * x
        m.columns.1 = m.columns.1 * y
        m.columns.2 = m.columns.2 * z
        return m
    }

    func rotatingBy(_ rotation: Rotation3D) -> simd_double4x4 {
        let r = simd_matrix3x3(rotation.quaternion)
        let first = first3(columns.0), second = first3(columns.1), third = first3(columns.2)
        func turned(_ axis: simd_double3) -> simd_double3 {
            first * axis.x + second * axis.y + third * axis.z
        }
        var m = self
        m.columns.0 = SIMD4<Double>(turned(r.columns.0), 0)
        m.columns.1 = SIMD4<Double>(turned(r.columns.1), 0)
        m.columns.2 = SIMD4<Double>(turned(r.columns.2), 0)
        return m
    }

    func translatingBy(_ offset: Vector3D) -> simd_double4x4 {
        var m = self
        m.columns.3 = columns.0 * offset.x + columns.1 * offset.y + columns.2 * offset.z + columns.3
        return m
    }

    func shearing(_ shear: AxisWithFactors) -> simd_double4x4 {
        let c0: simd_double3
        let c1: simd_double3
        let c2: simd_double3
        switch shear {
        case .xAxis(let yFactor, let zFactor):
            c0 = simd_double3(1, yFactor, zFactor)
            c1 = simd_double3(0, 1, 0)
            c2 = simd_double3(0, 0, 1)
        case .yAxis(let xFactor, let zFactor):
            c0 = simd_double3(1, 0, 0)
            c1 = simd_double3(xFactor, 1, zFactor)
            c2 = simd_double3(0, 0, 1)
        case .zAxis(let xFactor, let yFactor):
            c0 = simd_double3(1, 0, 0)
            c1 = simd_double3(0, 1, 0)
            c2 = simd_double3(xFactor, yFactor, 1)
        }
        return simd_mul(self, simd_matrix(SIMD4<Double>(c0, 0), SIMD4<Double>(c1, 0),
                                            SIMD4<Double>(c2, 0), SIMD4<Double>(0, 0, 0, 1)))
    }

    func flippingColumn(_ index: Int) -> simd_double4x4 {
        guard index >= 0, index < 3 else { return self }
        let alongX: Double = index == 0 ? -1 : 1
        let alongY: Double = index == 1 ? -1 : 1
        let alongZ: Double = index == 2 ? -1 : 1
        func side(_ column: SIMD4<Double>, _ j: Int) -> SIMD4<Double> {
            let across: Double = j == index ? -1 : 1
            return SIMD4<Double>(column.x * alongX * across, column.y * alongY * across,
                                    column.z * alongZ * across, column.w)
        }
        var m = self
        m.columns.0 = side(columns.0, 0)
        m.columns.1 = side(columns.1, 1)
        m.columns.2 = side(columns.2, 2)
        m.columns.3 = SIMD4<Double>(columns.3.x * alongX, columns.3.y * alongY, columns.3.z * alongZ,
                                       columns.3.w)
        return m
    }

    func isApproximatelyEqual(to other: simd_double4x4, tolerance: Double) -> Bool {
        func close(_ a: SIMD4<Double>, _ b: SIMD4<Double>) -> Bool {
            abs(a.x - b.x) < tolerance && abs(a.y - b.y) < tolerance &&
                abs(a.z - b.z) < tolerance && abs(a.w - b.w) < tolerance
        }
        return close(columns.0, other.columns.0) && close(columns.1, other.columns.1) &&
            close(columns.2, other.columns.2) && close(columns.3, other.columns.3)
    }
}

extension simd_double4x3 {
    func scalingBy(x: Double, y: Double, z: Double) -> simd_double4x3 {
        simd_matrix(columns.0 * x, columns.1 * y, columns.2 * z, columns.3)
    }

    func rotatingBy(_ rotation: Rotation3D) -> simd_double4x3 {
        let r = simd_matrix3x3(rotation.quaternion)
        func turned(_ axis: simd_double3) -> simd_double3 {
            columns.0 * axis.x + columns.1 * axis.y + columns.2 * axis.z
        }
        return simd_matrix(turned(r.columns.0), turned(r.columns.1), turned(r.columns.2), columns.3)
    }

    func translatingBy(_ offset: Vector3D) -> simd_double4x3 {
        simd_matrix(columns.0, columns.1, columns.2,
                    columns.0 * offset.x + columns.1 * offset.y + columns.2 * offset.z + columns.3)
    }

    func shearing(_ shear: AxisWithFactors) -> simd_double4x3 {
        var full = simd_double4x4()
        full.columns.0 = SIMD4<Double>(columns.0, 0)
        full.columns.1 = SIMD4<Double>(columns.1, 0)
        full.columns.2 = SIMD4<Double>(columns.2, 0)
        full.columns.3 = SIMD4<Double>(columns.3, 1)
        let sheared = full.shearing(shear)
        return simd_matrix(first3(sheared.columns.0), first3(sheared.columns.1),
                           first3(sheared.columns.2), first3(sheared.columns.3))
    }

    func flippingColumn(_ index: Int) -> simd_double4x3 {
        guard index >= 0, index < 3 else { return self }
        let alongX: Double = index == 0 ? -1 : 1
        let alongY: Double = index == 1 ? -1 : 1
        let alongZ: Double = index == 2 ? -1 : 1
        func side(_ column: simd_double3, _ j: Int) -> simd_double3 {
            let across: Double = j == index ? -1 : 1
            return simd_double3(column.x * alongX * across, column.y * alongY * across,
                             column.z * alongZ * across)
        }
        return simd_matrix(side(columns.0, 0), side(columns.1, 1), side(columns.2, 2),
                           simd_double3(columns.3.x * alongX, columns.3.y * alongY, columns.3.z * alongZ))
    }

    var asFourByFour: simd_double4x4 {
        var full = simd_double4x4()
        full.columns.0 = SIMD4<Double>(columns.0, 0)
        full.columns.1 = SIMD4<Double>(columns.1, 0)
        full.columns.2 = SIMD4<Double>(columns.2, 0)
        full.columns.3 = SIMD4<Double>(columns.3, 1)
        return full
    }
}

func invertedMatrix(_ matrix: simd_double4x4) -> simd_double4x4? {
    var work: [Double] = []
    work.reserveCapacity(32)
    let source = [matrix.columns.0, matrix.columns.1, matrix.columns.2, matrix.columns.3]
    for row in 0..<4 {
        for column in 0..<4 {
            work.append(source[column][row])
        }
    }
    for row in 0..<4 {
        for column in 0..<4 {
            work.append(row == column ? 1 : 0)
        }
    }
    assert(work.count == 32, "the working copy is the matrix and the identity, sixteen entries each")

    for step in 0..<4 {
        var pivotRow = step
        var pivotValue = work[step * 4 + step]
        for row in (step + 1)..<4 {
            let candidate = work[row * 4 + step]
            if abs(candidate) > abs(pivotValue) {
                pivotValue = candidate
                pivotRow = row
            }
        }
        guard pivotValue != 0, pivotValue.isFinite else { return nil }
        if pivotRow != step {
            for offset in 0..<4 {
                work.swapAt(step * 4 + offset, pivotRow * 4 + offset)
                work.swapAt(16 + step * 4 + offset, 16 + pivotRow * 4 + offset)
            }
        }

        for offset in 0..<4 {
            work[step * 4 + offset] /= pivotValue
            work[16 + step * 4 + offset] /= pivotValue
        }
        for row in 0..<4 where row != step {
            let factor = work[row * 4 + step]
            guard factor != 0 else { continue }
            for offset in 0..<4 {
                work[row * 4 + offset] -= factor * work[step * 4 + offset]
                work[16 + row * 4 + offset] -= factor * work[16 + step * 4 + offset]
            }
        }
    }

    var out = simd_double4x4()
    out.columns.0 = SIMD4<Double>(work[16], work[20], work[24], work[28])
    out.columns.1 = SIMD4<Double>(work[17], work[21], work[25], work[29])
    out.columns.2 = SIMD4<Double>(work[18], work[22], work[26], work[30])
    out.columns.3 = SIMD4<Double>(work[19], work[23], work[27], work[31])
    return out
}

@inlinable
func invertedMatrix3x3(_ m: simd_double3x3) -> simd_double3x3? {
    let determinant = simd_determinant(m)
    guard determinant != 0, determinant.isFinite else { return nil }
    let a = m.columns.0.x, b = m.columns.1.x, c = m.columns.2.x
    let d = m.columns.0.y, e = m.columns.1.y, f = m.columns.2.y
    let g = m.columns.0.z, h = m.columns.1.z, i = m.columns.2.z
    return simd_double3x3(columns: (
        simd_double3(e * i - f * h, c * h - b * i, b * f - c * e) / determinant,
        simd_double3(f * g - d * i, a * i - c * g, c * d - a * f) / determinant,
        simd_double3(d * h - e * g, b * g - a * h, a * e - b * d) / determinant))
}

extension simd_double3 {
    func isApproximatelyEqual(to other: simd_double3, tolerance: Double) -> Bool {
        abs(x - other.x) < tolerance && abs(y - other.y) < tolerance && abs(z - other.z) < tolerance
    }
}

extension SIMD4<Double> {
    func isApproximatelyEqual(to other: SIMD4<Double>, tolerance: Double) -> Bool {
        abs(x - other.x) < tolerance && abs(y - other.y) < tolerance &&
            abs(z - other.z) < tolerance && abs(w - other.w) < tolerance
    }
}

extension Rotation3D {
    func isApproximatelyEqual(to other: Rotation3D, tolerance: Double) -> Bool {
        vector.isApproximatelyEqual(to: other.vector, tolerance: tolerance)
    }
}

extension Point3D {
    func isApproximatelyEqual(to other: Point3D, tolerance: Double) -> Bool {
        vector.isApproximatelyEqual(to: other.vector, tolerance: tolerance)
    }
}
