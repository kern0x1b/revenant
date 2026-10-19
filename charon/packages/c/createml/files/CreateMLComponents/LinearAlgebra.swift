// LinearAlgebra.swift — the arithmetic the estimators are made of, over the device's own BLAS and
// LAPACK.
//
// There is no matrix code in this package. Every kernel below is a call into the Accelerate of the
// release the program runs on: the armv7 caches from 4.3 up export cblas_dgemm, cblas_dsyrk, dgesv_
// and dpotrf_ (measured over the caches; the names are in the Accelerate band's
// facts/Accelerate/AppleBLAS.md), and `import Accelerate` at the port's deployment target declares
// all four as available from iOS 4.0, so they resolve as ordinary framework imports against the
// device's own dyld shared cache.
//
// What is here is the shape those calls need — a row-major matrix with a leading dimension, the
// transposes CBLAS spells as an enum, and the three tolerances a fit has to report honestly. The
// types are the port's own because the estimators index them by column; the arithmetic is the
// system's.

import Accelerate
import Foundation

/// LAPACK's integer type, as the header spells it for this architecture.
///
/// `clapack.h` picks `long` where a long is 32 bits and `int` otherwise, and Swift spells those
/// `Int` and `Int32` — both 32-bit, because the CLAPACK interface is ILP32 unless the SDK's ILP64
/// switch is defined, and it is not. Naming it once here is what keeps the two architectures' call
/// sites identical; below armv7 the header's `long` is the target's `Int`.
#if arch(arm64) || arch(x86_64)
typealias LapackInt = Int32
#else
typealias LapackInt = Int
#endif

/// A row-major matrix: `rows` rows of `columns` `Double`s, `stride` apart.
///
/// The stride is separate from the count because every BLAS call here takes a leading dimension, and
/// because a sub-matrix of a wider one is a matrix with a bigger stride and fewer columns.
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

    /// A contiguous copy of a row, which is what BLAS wants as an `lda` of the row's own count.
    public func contiguousRow(_ index: Int) -> [Double] { Array(row(index)) }

    public func contiguousColumn(_ index: Int) -> [Double] {
        (0..<rows).map { self[$0, index] }
    }

    /// Rows `range` as one matrix, dropping the stride: a sub-matrix handed to BLAS cannot carry a
    /// leading dimension larger than its own width without saying so, and saying so is the caller's
    /// business.
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

    /// `self * other`, by the system's own GEMM.
    ///
    /// Both operands are handed over as they are: BLAS takes a leading dimension, so a wide stride
    /// costs a copy here and nowhere else.
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

    /// `transpose(self) * self`: the Gram matrix of a design matrix, which is what every
    /// least-squares fit and every ridge term is built from, and which is `columns x columns` for a
    /// design of any height.
    ///
    /// It is *not* the same shape as the operand — a design of forty rows and three features has a
    /// three-by-three Gram matrix — so this is a square-matrix shortcut and not a precondition. A
    /// square operand goes through the system's own SYRK, which computes the half the GEMM would
    /// compute twice; anything else goes through the general product. The port's own arithmetic here
    /// was once written with a `precondition(isSquare)`, which refused the shape a least-squares fit
    /// actually asks for; the host differential is what found it, on a four-row one-column design.
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
        // SYRK filled the upper triangle. The rest is its mirror, which is what a system that returns
        // a symmetric matrix hands back.
        for row in 1..<rows {
            for column in 0..<row {
                out[row, column] = out[column, row]
            }
        }
        return out
    }

    /// `transpose(self) * vector`.
    /// `transpose(self) * vector`, which is `columns` long and so takes a vector as long as this
    /// matrix is *tall* — the rows, not the columns. A design of forty rows and three features is
    /// multiplied on the left by a forty-long vector of targets and answers three, and a precondition
    /// on the columns here would refuse exactly the call a least-squares fit is made of.
    public func transposedMultiplied(by vector: [Double]) -> [Double] {
        precondition(vector.count == rows, "the vector is \(vector.count) long, the matrix is \(rows) tall")
        // The answer is `columns` long, not `rows`: a four-row one-column design multiplied by a
        // four-long vector of targets answers one number. Allocating `rows` here handed the ridge
        // fit a four-long right-hand side to a one-by-one system, which is what the host
        // differential's precondition named.
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

    /// `self * vector`.
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

    /// The sum of the squares of a vector, by the system's own dot product.
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
        // The sum of the squared deviations, not the one-pass form of it: svesq of (x - mean) is
        // stable where (svesq(x) - n·mean²) is not, and the difference is the whole reason a fit
        // over columns of very different magnitudes does not answer a negative variance.
        var deviations = [Double](repeating: 0, count: vector.count)
        var minusAverage = -average
        vDSP_vsaddD(vector, 1, &minusAverage, &deviations, 1, vDSP_Length(vector.count))
        var total = 0.0
        vDSP_svesqD(deviations, 1, &total, vDSP_Length(vector.count))
        return total / Double(vector.count - 1)
    }

    /// The unbiased standard deviation.
    public static func standardDeviation(_ vector: [Double]) -> Double {
        variance(vector).squareRoot()
    }

    /// `A * x = b` solved in place, by the system's own LAPACK: LU with partial pivoting, then the
    /// triangular solves. `info` is LAPACK's own, and is passed back rather than swallowed — a
    /// singular system is a fact about the caller's design matrix, not a reason to answer a zero.
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

    /// A Cholesky factor of a symmetric positive definite matrix, by the system's own LAPACK.
    /// `info > 0` means the leading minor of that order is not positive definite — the caller has a
    /// rank-deficient design matrix, and has to say so.
    ///
    /// The factor lands in this matrix's **upper** triangle, and the reason is worth stating because
    /// it is silent when it is wrong: **LAPACK is column-major and `RowMatrix` is row-major.**
    /// Handing LAPACK a row-major buffer asks it for the *transpose* of what is in it, and for a
    /// symmetric matrix the transpose is the same matrix — so the numbers come out right while the
    /// triangle is the other one in memory. LAPACK's `L[i][j]`, `i > j`, is at buffer index
    /// `i + n*j`, which in this matrix's row-major numbering is the cell `[j][i]`: the upper
    /// triangle. A factor read from the lower one is a plausible wrong number and not a failure.
    ///
    /// Every other call here is CBLAS, which is told the order in `CblasRowMajor` and is unaffected.
    /// The LU solve is the only other LAPACK call, and its *result* is unaffected for the same
    /// reason — the normal matrix is symmetric, so solving its transpose solves it.
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

    /// The solution of `L L' x = b` from the factor `cholesky` wrote, by the two substitutions the
    /// system is made of — the forward one first, then the backward one, because the second cannot
    /// start until the first has finished.
    ///
    /// `L` is read through the upper triangle `cholesky` filled: its diagonal is the same cell either
    /// way, its strictly-lower `L[i][j]` is `upper[j][i]`, and its strictly-upper is zero. Written
    /// that way rather than as a matrix rebuilt from the triangle, because a copy is one more place
    /// for the transposition to go wrong.
    private static func triangularSolve(_ upper: RowMatrix, _ right: [Double]) -> [Double]? {
        let n = upper.rows
        guard n == upper.columns, right.count == n else { return nil }
        var x = right
        // Forward: L y = b.
        for row in 0..<n {
            var value = x[row]
            for column in 0..<row {
                value -= upper[column, row] * x[column]
            }
            let diagonal = upper[row, row]
            guard diagonal != 0 else { return nil }
            x[row] = value / diagonal
        }
        // Backward: L' x = y.
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

    /// The least-squares solution of `A x = b` in the ridge form every fit here uses: the normal
    /// equations with `penalty` added to the diagonal, factored by Cholesky and solved through the
    /// two triangular systems.
    ///
    /// The normal equations rather than a QR, and the reason is the ridge term: it is a diagonal, so
    /// `A'A + penalty*I` is symmetric and — for a positive penalty — positive definite, which is
    /// exactly the case the system's own `dpotrf_` factors. The cost is the squaring of the
    /// condition number; the answer this returns is the one the ridge estimator's own objective is
    /// the minimum of, and a ridge fit is defined by that objective and not by the route taken to it.
    ///
    /// With a penalty of zero the normal matrix is only positive definite when the design has full
    /// column rank, and a Cholesky factor of a rank-deficient matrix reports it rather than
    /// answering — so the factor's own `info` is what decides the route, and a matrix it refuses goes
    /// to the LU solve, which reports singularity the same way. The two agree wherever both exist,
    /// which is everywhere the factor succeeds; the fallback is for the case the factor is defined
    /// to refuse and not for a second opinion.
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
        // The factor refused it, so the normal matrix is not positive definite: a rank-deficient
        // design and no penalty to make it so. The LU solve is the system's answer for that, and it
        // reports singularity through its own `info` rather than returning a plausible number.
        var lu = normal
        let info = solve(&lu, rightHandSides: &right)
        return (info == 0 ? right : [], info)
    }

    /// The softmax of a vector, subtracting the maximum first: the shift is what keeps `exp` from
    /// overflowing on the scores of a confident classifier, and it cancels in the division.
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

    /// The derivative of the logistic function at `x`, which the Newton step of a logistic fit needs
    /// and which is `s(1-s)` for a probability `s`.
    public static func logisticDerivative(_ x: Double) -> Double {
        let s = 1.0 / (1.0 + (-x)._exp())
        return s * (1.0 - s)
    }

    /// The log-likelihood of one observation of a binary logistic model.
    public static func logitLoss(_ label: Double, _ score: Double) -> Double {
        // log(1 + exp(-|y|)) + max(0, -y * score), the form that is finite for both signs of a large
        // score: a plain max(0, label*score) - log(1+exp(label*score)) overflows exp for a confident
        // wrong answer and answers -inf where the loss is merely large.
        let margin = label * score
        let magnitude = abs(margin)
        return log1p(exp(magnitude)) - (margin > 0 ? margin : 0)
    }
}

extension Double {
    /// `exp` under the name the release's own maths uses, so the read of a loss says which function
    /// it is. libm's `exp` is what both spell.
    @inline(__always)
    func _exp() -> Double { Foundation.exp(self) }
}
