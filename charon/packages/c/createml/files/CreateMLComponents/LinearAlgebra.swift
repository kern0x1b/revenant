import Accelerate
import Foundation

#if arch(arm64) || arch(x86_64)
typealias LapackInt = Int32
#else
typealias LapackInt = Int
#endif

public struct RowMatrix {
    public var values: [Double]
    public let rows: Int
    public let columns: Int
    public let stride: Int

    public init(rows: Int, columns: Int, stride: Int? = nil) {
        self.rows = rows
        self.columns = columns
        self.stride = stride ?? columns
        self.values = [Double](repeating: 0, count: rows * self.stride)
    }

    public init(_ values: [Double], rows: Int, columns: Int, stride: Int? = nil) {
        precondition(stride ?? columns >= columns, "a matrix's stride is not narrower than its columns")
        precondition(values.count >= rows * (stride ?? columns), "a matrix's storage is narrower than rows x stride")
        self.values = values
        self.rows = rows
        self.columns = columns
        self.stride = stride ?? columns
    }

    public static func zeros(rows: Int, columns: Int) -> RowMatrix {
        RowMatrix(rows: rows, columns: columns)
    }

    public static func identity(_ order: Int) -> RowMatrix {
        var matrix = RowMatrix(rows: order, columns: order)
        for index in 0..<order {
            matrix[0, index] = 1
        }
        return matrix
    }

    public subscript(row: Int, column: Int) -> Double {
        get { values[row * stride + column] }
        set { values[row * stride + column] = newValue }
    }

    public var isSquare: Bool { rows == columns }

    public func row(_ index: Int) -> ArraySlice<Double> {
        values[(index * stride)..<(index * stride + columns)]
    }

    public func contiguousRow(_ index: Int) -> [Double] { Array(row(index)) }

    public func contiguousColumn(_ index: Int) -> [Double] {
        (0..<rows).map { self[$0, index] }
    }

    public func submatrixRows(_ range: Range<Int>) -> RowMatrix {
        let taken = range.count
        var out = RowMatrix(rows: taken, columns: columns)
        for (offset, source) in range.enumerated() {
            for column in 0..<columns {
                out[offset, column] = self[source, column]
            }
        }
        return out
    }

    public func transposed() -> RowMatrix {
        var out = RowMatrix(rows: columns, columns: rows)
        for row in 0..<rows {
            for column in 0..<columns {
                out[column, row] = self[row, column]
            }
        }
        return out
    }

    public func multiplied(by other: RowMatrix) -> RowMatrix {
        precondition(other.rows == columns, "the inner dimensions do not agree: \(rows)x\(columns) times \(other.rows)x\(other.columns)")
        var out = RowMatrix(rows: rows, columns: other.columns)
        guard rows > 0, other.columns > 0 else { return out }
        let alpha = 1.0, beta = 0.0
        let order = CBLAS_ORDER(rawValue: CblasRowMajor.rawValue)
        let noTranspose = CBLAS_TRANSPOSE(rawValue: CblasNoTrans.rawValue)
        values.withUnsafeBufferPointer { left in
            other.values.withUnsafeBufferPointer { right in
                out.values.withUnsafeMutableBufferPointer { product in
                    cblas_dgemm(order, noTranspose, noTranspose,
                                Int32(rows), Int32(other.columns), Int32(columns),
                                alpha, left.baseAddress!, Int32(stride),
                                right.baseAddress!, Int32(other.stride),
                                beta, product.baseAddress!, Int32(out.stride))
                }
            }
        }
        return out
    }

    public func gram() -> RowMatrix {
        guard rows > 0, columns > 0 else { return RowMatrix(rows: columns, columns: columns) }
        guard isSquare else { return transposed().multiplied(by: self) }
        var out = RowMatrix(rows: rows, columns: rows)
        let alpha = 1.0, beta = 0.0
        let order = CBLAS_ORDER(rawValue: CblasRowMajor.rawValue)
        let upper = CBLAS_UPLO(rawValue: CblasUpper.rawValue)
        let noTranspose = CBLAS_TRANSPOSE(rawValue: CblasNoTrans.rawValue)
        values.withUnsafeBufferPointer { left in
            out.values.withUnsafeMutableBufferPointer { product in
                cblas_dsyrk(order, upper, noTranspose, Int32(rows), Int32(rows),
                            alpha, left.baseAddress!, Int32(stride), beta, product.baseAddress!, Int32(out.stride))
            }
        }
        for row in 1..<rows {
            for column in 0..<row {
                out[row, column] = out[column, row]
            }
        }
        return out
    }

    public func transposedMultiplied(by vector: [Double]) -> [Double] {
        precondition(vector.count == rows, "the vector is \(vector.count) long, the matrix is \(rows) tall")
        var out = [Double](repeating: 0, count: columns)
        guard rows > 0 else { return out }
        values.withUnsafeBufferPointer { left in
            vector.withUnsafeBufferPointer { right in
                out.withUnsafeMutableBufferPointer { product in
                    cblas_dgemv(CBLAS_ORDER(rawValue: CblasRowMajor.rawValue),
                                CBLAS_TRANSPOSE(rawValue: CblasTrans.rawValue),
                                Int32(rows), Int32(columns),
                                1.0, left.baseAddress!, Int32(stride),
                                right.baseAddress!, 1,
                                0.0, product.baseAddress!, 1)
                }
            }
        }
        return out
    }

    public func multiplied(by vector: [Double]) -> [Double] {
        precondition(vector.count == columns, "the vector is \(vector.count) long, the matrix is \(columns) wide")
        var out = [Double](repeating: 0, count: rows)
        guard rows > 0 else { return out }
        values.withUnsafeBufferPointer { left in
            vector.withUnsafeBufferPointer { right in
                out.withUnsafeMutableBufferPointer { product in
                    cblas_dgemv(CBLAS_ORDER(rawValue: CblasRowMajor.rawValue),
                                CBLAS_TRANSPOSE(rawValue: CblasNoTrans.rawValue),
                                Int32(rows), Int32(columns),
                                1.0, left.baseAddress!, Int32(stride),
                                right.baseAddress!, 1,
                                0.0, product.baseAddress!, 1)
                }
            }
        }
        return out
    }

    public static func dot(_ left: [Double], _ right: [Double]) -> Double {
        precondition(left.count == right.count, "a dot product needs two vectors of one length")
        guard !left.isEmpty else { return 0 }
        return left.withUnsafeBufferPointer { a in
            right.withUnsafeBufferPointer { b in
                cblas_ddot(Int32(a.count), a.baseAddress!, 1, b.baseAddress!, 1)
            }
        }
    }

    public static func sum(_ vector: [Double]) -> Double {
        guard !vector.isEmpty else { return 0 }
        var total = 0.0
        vDSP_sveD(vector, 1, &total, vDSP_Length(vector.count))
        return total
    }

    public static func mean(_ vector: [Double]) -> Double {
        vector.isEmpty ? 0 : sum(vector) / Double(vector.count)
    }

    public static func variance(_ vector: [Double]) -> Double {
        guard vector.count > 1 else { return 0 }
        var average = 0.0
        vDSP_meanvD(vector, 1, &average, vDSP_Length(vector.count))
        var deviations = [Double](repeating: 0, count: vector.count)
        var minusAverage = -average
        vDSP_vsaddD(vector, 1, &minusAverage, &deviations, 1, vDSP_Length(vector.count))
        var total = 0.0
        vDSP_svesqD(deviations, 1, &total, vDSP_Length(vector.count))
        return total / Double(vector.count - 1)
    }

    public static func standardDeviation(_ vector: [Double]) -> Double {
        variance(vector).squareRoot()
    }

    @discardableResult
    public static func solve(_ matrix: inout RowMatrix, rightHandSides b: inout [Double]) -> Int {
        precondition(matrix.isSquare, "the system is \(matrix.rows)x\(matrix.columns), not square")
        precondition(b.count == matrix.rows, "the right-hand side is \(b.count) long, the system has \(matrix.rows) rows")
        guard matrix.rows > 0 else { return 0 }
        var order = LapackInt(matrix.rows), rightSides = LapackInt(1)
        var leading = LapackInt(matrix.stride), rhsLeading = LapackInt(b.count), info = LapackInt(0)
        var pivots = [LapackInt](repeating: 0, count: matrix.rows)
        matrix.values.withUnsafeMutableBufferPointer { a in
            b.withUnsafeMutableBufferPointer { right in
                _ = dgesv_(&order, &rightSides, a.baseAddress!, &leading, &pivots,
                            right.baseAddress!, &rhsLeading, &info)
            }
        }
        return Int(info)
    }

    @discardableResult
    public static func cholesky(_ matrix: inout RowMatrix) -> Int {
        precondition(matrix.isSquare, "the matrix is \(matrix.rows)x\(matrix.columns), not square")
        guard matrix.rows > 0 else { return 0 }
        var info = LapackInt(0)
        var lower = Int8(UInt8(ascii: "L"))
        var order = LapackInt(matrix.rows), leading = LapackInt(matrix.stride)
        matrix.values.withUnsafeMutableBufferPointer { a in
            _ = dpotrf_(&lower, &order, a.baseAddress!, &leading, &info)
        }
        return Int(info)
    }

    private static func triangularSolve(_ upper: RowMatrix, _ right: [Double]) -> [Double]? {
        let n = upper.rows
        guard n == upper.columns, right.count == n else { return nil }
        var x = right
        for row in 0..<n {
            var value = x[row]
            for column in 0..<row {
                value -= upper[column, row] * x[column]
            }
            let diagonal = upper[row, row]
            guard diagonal != 0 else { return nil }
            x[row] = value / diagonal
        }
        for row in Swift.stride(from: n - 1, through: 0, by: -1) {
            var value = x[row]
            for column in row + 1..<n {
                value -= upper[row, column] * x[column]
            }
            let diagonal = upper[row, row]
            guard diagonal != 0 else { return nil }
            x[row] = value / diagonal
        }
        return x
    }

    public static func ridgeLeastSquares(design: RowMatrix, targets: [Double], penalty: Double) -> (solution: [Double], info: Int) {
        precondition(design.rows == targets.count, "the design matrix has \(design.rows) rows, there are \(targets.count) targets")
        guard design.rows > 0, design.columns > 0 else { return ([], 0) }
        var normal = design.gram()
        for index in 0..<design.columns {
            normal[index, index] += penalty
        }
        var right = design.transposedMultiplied(by: targets)
        var factor = normal
        if cholesky(&factor) == 0, let solution = triangularSolve(factor, right) {
            return (solution, 0)
        }
        var lu = normal
        let info = solve(&lu, rightHandSides: &right)
        return (info == 0 ? right : [], info)
    }

    public static func logistic(_ scores: [Double]) -> [Double] {
        guard !scores.isEmpty else { return [] }
        var out = [Double](repeating: 0, count: scores.count)
        let shift = scores.max()!
        var exponentials = [Double](repeating: 0, count: scores.count)
        var minusShift = -shift
        vDSP_vsaddD(scores, 1, &minusShift, &exponentials, 1, vDSP_Length(scores.count))
        for index in 0..<scores.count {
            exponentials[index] = exponentials[index]._exp()
        }
        var total = 0.0
        vDSP_sveD(exponentials, 1, &total, vDSP_Length(scores.count))
        guard total > 0 else { return out }
        vDSP_vsdivD(exponentials, 1, &total, &out, 1, vDSP_Length(scores.count))
        return out
    }

    public static func logisticDerivative(_ x: Double) -> Double {
        let s = 1.0 / (1.0 + (-x)._exp())
        return s * (1.0 - s)
    }

    public static func logitLoss(_ label: Double, _ score: Double) -> Double {
        let margin = label * score
        let magnitude = abs(margin)
        return log1p(exp(magnitude)) - (margin > 0 ? margin : 0)
    }
}

extension Double {
    @inline(__always)
    func _exp() -> Double { Foundation.exp(self) }
}
