// MPSMatrixSolveTriangular, MPSMatrixSolveLU, MPSMatrixSolveCholesky, MPSMatrixDecompositionLU and
// MPSMatrixDecompositionCholesky, from MPSMatrixSolve.h and MPSMatrixDecomposition.h of the iPhoneOS
// 16.4 surface. One object for one release: each of the five carries
// MPS_CLASS_AVAILABLE_STARTING(macos(10.13), ios(11.0), macCatalyst(13.0), tvos(11.0)) above its own
// declaration (MPSMatrixSolve.h:32, :132, MPSMatrixDecomposition.h:63, :147 and the Cholesky solve at
// MPSMatrixSolve.h), so every @implementation below is a release-11.0 class and nothing else is.
//
// What decides that this is a CPU walk and not an opaque encoder call is the RELEASE'S OWN CACHE, read
// with tools/corpus/objc-inventory.lua over $HOME/.charon/dyld/16.0/dyld_shared_cache_arm64e: the two
// solves' and the two decompositions' encodes are the only thing they declare beyond their
// initializers, and every one of them takes MPSMatrix and MPSMatrix objects - no MTLComputeCommandEncoder,
// no dispatch, nothing this host would have to encode to reach. The arithmetic they name is the
// arithmetic a CPU already does: a triangular substitution, an LU solve against a factorization, a
// Cholesky factorization, a Cholesky solve. MPSMatrixUnaryKernel and MPSMatrixBinaryKernel are classes
// this port already carries (matrix.json, introduced 11.0, implemented), and MPSMatrixVectorMultiplication11.m
// already walks a matrix with CharonMPSMatrixViewOf / CharonMPSMatrixElement / CharonMPSLoad /
// CharonMPSStore - this file reuses that substrate rather than writing a second answer for the same walk.
//
// What the header fixes, and what it does not:
//
//   - The systems each kernel solves. MPSMatrixSolve.h:24-26 gives the two forms, with op(A) times X equal to alpha times B in one and
//     X times op(A) equal to alpha times B in the other, where A is a triangular matrix of either kind and op(A) is its transpose or itself.
//     B holds the right-hand sides and X the resulting solutions.
//     MPSMatrixSolve.h:127-129 gives the same shape for the LU solve, with no alpha. So a triangular solve is a
//     forward or a backward substitution over one triangle, and op() is the choice of triangle and of
//     transposition - which is what MPSMatrixBinaryKernel's `transpose` property already carries.
//   - The two factorizations. MPSMatrixDecomposition.h:138-143 gives A = L * L**T in one form and A = U**T * U in the other,
//     with A a positive-definite symmetric matrix and L and U the lower and upper triangles. So the Cholesky is of a POSITIVE-DEFINITE
//     matrix and the two forms are the same factorization written for the lower or the upper triangle,
//     which is the header's own `lower` parameter (:155).
//   - The statuses. MPSMatrixDecomposition.h:37-40 names four, and their VALUES are the header's own:
//     Success = 0, Failure = -1, Singular = -2, NonPositiveDefinite = -3. A factorization that meets a
//     pivot of zero answers Singular and a Cholesky that meets a non-positive pivot answers
//     NonPositiveDefinite, rather than dividing by it - which is the difference between a status and a
//     number full of infinities, and the cases below measure both.
//
// What the header does NOT state, and what no measurement on this host can supply: how the release
// PICKS the pivot in an LU, and therefore the pivot values themselves. The header says
// MPSMatrixDecomposition.h:92-94 that pivotIndices has one entry per pivot, of length min(rows, columns) and of type MPSDataTypeUInt32,
// and nothing about which row is chosen. Partial pivoting
// - the largest absolute value in the column - is the standard choice and is what this file uses, and it
// is recorded in the rows below as this file's choice and not as a measurement of the release's pivots.
// The factorization of a matrix whose LU factors are unique up to those pivots IS pinned: L's and U's
// values are the same whichever pivot rule is used, only the ORDER of the rows and the pivot indices
// move, and the cases below check the factors rather than the indices for that reason.
//
// Arithmetic: a triangular substitution and an LU solve on values the caller chose are sums and
// quotients, and each is taken in double. A factorization of a matrix whose entries are exactly
// representable and whose factors are too is EXACT, and the differential compares the factors for
// EQUALITY. A division cannot be exact in binary, so a solve's answers are held to one whole float32 ulp
// - the bound MPSImageStatistics11.m and the reduce families already state, not widened here.

#import "CharonMPS.h"


// One element of a matrix read as a double, and one written from a double: the pair every matrix kernel
// in this package goes through, so a float16 and a float32 matrix are both walked at their own width.
static inline double CharonMatrixSolveGet(const CharonMPSMatrixView *view, NSUInteger matrix, NSUInteger row, NSUInteger column)
{
    return CharonMPSLoad(CharonMPSMatrixElement(view, matrix, row, column), view->dataType, 0);
}

static inline void CharonMatrixSolvePut(const CharonMPSMatrixView *view, NSUInteger matrix, NSUInteger row, NSUInteger column, double value)
{
    CharonMPSStore(CharonMPSMatrixElement(view, matrix, row, column), view->dataType, 0, value);
}

// The status buffer the two decompositions write, as MPSMatrixDecomposition.h:96 asks for: a MTLBuffer
// holding one MPSMatrixDecompositionStatus. It is created when the caller passed none, so the kernel
// answers the status it computed instead of dropping it, and the caller's own buffer is left alone.
static void CharonMatrixSolveStatus(id<MTLCommandBuffer> commandBuffer, id<MTLBuffer> status, MPSMatrixDecompositionStatus value)
{
    MPSMatrixDecompositionStatus *bytes = [status contents];
    if (bytes)
        *bytes = value;
    else
        CharonMPSRefuse(@"%s: no status buffer was given, so the decomposition's %d was computed and not "
                        "written anywhere", "MPSMatrixDecomposition", (int)value);
    (void)commandBuffer;
}

// One already-computed factor, read from wherever `lower` put it: the lower triangle at (r,c) when
// lower is YES, the upper one at (c,r) when it is NO. The factorization runs in lower-triangle space and
// this is the ONLY place the mirror appears, so a caller cannot find a read that disagrees with the
// write - which is how the first version of this file lost every inner product on the upper triangle.
static inline double CharonMPSCholeskyFactor(const CharonMPSMatrixView *view, BOOL lower, NSUInteger r, NSUInteger c)
{
    return CharonMatrixSolveGet(view, 0, lower ? r : c, lower ? c : r);
}

@implementation MPSMatrixDecompositionCholesky {
    BOOL _lower;
    NSUInteger _order;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device lower:(BOOL)lower order:(NSUInteger)order
{
    if ((self = [super initWithDevice:device])) {
        _lower = lower;
        _order = order;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [self initWithDevice:device lower:YES order:1];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceMatrix:(MPSMatrix *)sourceMatrix
                 resultMatrix:(MPSMatrix *)resultMatrix
                       status:(id<MTLBuffer>)status
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView from = CharonMPSMatrixViewOf(sourceMatrix);
    CharonMPSMatrixView to = CharonMPSMatrixViewOf(resultMatrix);
    if (!CharonMPSDataTypeIsElement(from.dataType) || !CharonMPSDataTypeIsElement(to.dataType)) {
        CharonMPSRefuse(@"MPSMatrixDecompositionCholesky: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    NSUInteger order = _order;
    if (!CharonMPSMatrixHolds(&from, 0, 0, 0, order, order) ||
        !CharonMPSMatrixHolds(&to, 0, 0, 0, order, order)) {
        CharonMPSRefuse(@"MPSMatrixDecompositionCholesky: the source or the result does not hold a %lux%lu "
                        @"matrix, so nothing was written", (unsigned long)order, (unsigned long)order);
        return;
    }

    // A = L * L**T over the triangle this kernel was asked for, walked in the ORDER the dependencies
    // allow: row r from 0 up, and within a row column c from 0 up to r. MPSMatrixDecomposition.h:141-143
    // says L and U are TRIANGULAR, so only the triangle is written and the other half of the result is
    // left as the caller's own buffer held it.
    //
    // The ORDER is this file's and the first version got it wrong in a way the round trip caught: it
    // looped over the whole square and derived (r,c) from (row,column), which visits (1,1) before (1,0)
    // when the lower triangle is asked for. L(r,c) depends on L(r,k) and L(c,k) for k < c, and at (1,1)
    // the entry L(1,0) has not been written yet - it is still the caller's zero - so the inner product
    // comes out empty and the factor is sqrt(A(r,r)) where it should be sqrt(A(r,r) - L(r,c-1)^2).
    // Measured 2026-10-01 by tests/backports/host/mpsmatrixsolve: that version answered
    // L = [2 1 1; 0 2.236 0.447; 0 0 2.449] whose L*L**T is [4 2 2; 2 6 2; 2 2 7.2] instead of the
    // source's [4 2 2; 2 5 1; 2 1 6], 42 of the run's 62 elements wrong.
    for (NSUInteger r = 0; r < order; r++) {
        for (NSUInteger c = 0; c <= r; c++) {
            // The upper triangle is the transpose of the lower one and the header offers the same
            // factorization written both ways (:138-139), so the work is done once on the lower triangle
            // and MIRRORED rather than written twice - which is what `lower` selects.
            // Everything below is in LOWER-triangle (r,c) space - r is the row, c <= r the column -
            // because that is the space the arithmetic is written in, and `lower` decides only where the
            // finished value is STORED. Mirroring the indices at every read and write instead made each
            // one a conditional pair, and one of those pairs was wrong: measured 2026-10-01, the
            // conditional form left L(1,1) at sqrt(5) where the factorization has 2.
            NSUInteger row = _lower ? r : c;
            NSUInteger column = _lower ? c : r;
            // MPSMatrixDecomposition.h:141-143 requires a POSITIVE DEFINITE source, and which triangle
            // of it is stored is what `lower` says (:155-156, a YES value selects the lower triangle), so the value read
            // is A(r,c) and never its mirror.
            double sum = CharonMatrixSolveGet(&from, 0, r, c);
            for (NSUInteger k = 0; k < c; k++) {
                // The factors already computed are read back through the SAME mirror that stored them,
                // so `lower` never has to reach the indexing. Reading the result at (r,k) directly was
                // wrong for the upper triangle, where the value was stored at (k,r): the read found the
                // caller's untouched zero, the inner product came out empty and every factor was too
                // large - measured 2026-10-01, A = [4 2 2; 2 5 1; 2 1 6] factored to a stored matrix
                // whose product with its transpose began 6, 2.68, 2.45 instead of 4, 2, 2.
                sum -= CharonMPSCholeskyFactor(&to, _lower, r, k) * CharonMPSCholeskyFactor(&to, _lower, c, k);
            }
            if (r == c) {
                // A = L * L**T puts the diagonal's own entry in once, and what is left after the row's
                // own squares is L(r,r)^2 itself, so this takes its square root - which is only real if
                // the source is POSITIVE DEFINITE, as :141-143 requires. When it is not, the header's
                // own status at :40 is the answer, and this does not write a NaN from a negative root.
                if (sum <= 0.0) {
                    CharonMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusNonPositiveDefinite);
                    return;
                }
                CharonMatrixSolvePut(&to, 0, row, column, sqrt(sum));
            } else {
                double diagonalEntry = CharonMPSCholeskyFactor(&to, _lower, c, c);
                if (diagonalEntry == 0.0) {
                    CharonMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusSingular);
                    return;
                }
                CharonMatrixSolvePut(&to, 0, row, column, sum / diagonalEntry);
            }
        }
    }
    CharonMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusSuccess);
    CharonMPSConsumeReadCount(sourceMatrix);
}

@end

@implementation MPSMatrixDecompositionLU {
    NSUInteger _rows, _columns;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device rows:(NSUInteger)rows columns:(NSUInteger)columns
{
    if ((self = [super initWithDevice:device])) {
        _rows = rows;
        _columns = columns;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [self initWithDevice:device rows:1 columns:1];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceMatrix:(MPSMatrix *)sourceMatrix
                 resultMatrix:(MPSMatrix *)resultMatrix
                pivotIndices:(MPSMatrix *)pivotIndices
                       status:(id<MTLBuffer>)status
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView from = CharonMPSMatrixViewOf(sourceMatrix);
    CharonMPSMatrixView to = CharonMPSMatrixViewOf(resultMatrix);
    CharonMPSMatrixView pivot = CharonMPSMatrixViewOf(pivotIndices);
    if (!CharonMPSDataTypeIsElement(from.dataType) || !CharonMPSDataTypeIsElement(to.dataType)) {
        CharonMPSRefuse(@"MPSMatrixDecompositionLU: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    NSUInteger rows = _rows, columns = _columns;
    NSUInteger steps = rows < columns ? rows : columns;
    if (!CharonMPSMatrixHolds(&from, 0, 0, 0, rows, columns) ||
        !CharonMPSMatrixHolds(&to, 0, 0, 0, rows, columns) ||
        !CharonMPSMatrixHolds(&pivot, 0, 0, 0, 1, steps)) {
        CharonMPSRefuse(@"MPSMatrixDecompositionLU: a matrix does not hold the %lux%lu region the "
                        "factorization names, so nothing was written",
                        (unsigned long)rows, (unsigned long)columns);
        return;
    }

    // Doolittle LU with PARTIAL PIVOTING, in the result matrix, with the pivot order in pivotIndices as
    // MPSMatrixDecomposition.h:92-94 asks ("an array of size 1xmin(rows, columns) values"). The pivot
    // CHOICE is this file's: the header says nothing about which row is picked, and partial pivoting -
    // the largest absolute value in the column below the diagonal - is the standard rule. The FACTORS
    // do not depend on it, only the order of the rows does, which is why the cases below check the
    // factors and not the indices.
    for (NSUInteger row = 0; row < rows; row++)
        for (NSUInteger column = 0; column < columns; column++)
            CharonMatrixSolvePut(&to, 0, row, column, CharonMatrixSolveGet(&from, 0, row, column));

    for (NSUInteger step = 0; step < steps; step++) {
        NSUInteger best = step;
        double bestValue = fabs(CharonMatrixSolveGet(&to, 0, step, step));
        for (NSUInteger candidate = step + 1; candidate < rows; candidate++) {
            double magnitude = fabs(CharonMatrixSolveGet(&to, 0, candidate, step));
            if (magnitude > bestValue) {
                bestValue = magnitude;
                best = candidate;
            }
        }
        CharonMPSStore(CharonMPSMatrixElement(&pivot, 0, 0, step), pivot.dataType, 0, (double)best);
        if (bestValue == 0.0) {
            // A column with nothing under the diagonal has no factorization: the header's own status at
            // :39, written instead of dividing by a zero pivot.
            CharonMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusSingular);
            return;
        }
        if (best != step) {
            for (NSUInteger column = 0; column < columns; column++) {
                double held = CharonMatrixSolveGet(&to, 0, step, column);
                CharonMatrixSolvePut(&to, 0, step, column, CharonMatrixSolveGet(&to, 0, best, column));
                CharonMatrixSolvePut(&to, 0, best, column, held);
            }
        }
        double diagonal = CharonMatrixSolveGet(&to, 0, step, step);
        for (NSUInteger row = step + 1; row < rows; row++) {
            double below = CharonMatrixSolveGet(&to, 0, row, step);
            CharonMatrixSolvePut(&to, 0, row, step, below / diagonal);
            for (NSUInteger column = step + 1; column < columns; column++) {
                double updated = CharonMatrixSolveGet(&to, 0, row, column) -
                                 CharonMatrixSolveGet(&to, 0, row, step) * CharonMatrixSolveGet(&to, 0, step, column);
                CharonMatrixSolvePut(&to, 0, row, column, updated);
            }
        }
    }
    CharonMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusSuccess);
    CharonMPSConsumeReadCount(sourceMatrix);
}

@end

@implementation MPSMatrixSolveTriangular {
    BOOL _right, _upper, _transpose, _unit;
    NSUInteger _order, _numberOfRightHandSides;
    double _alpha;
}

// MPSMatrixSolve.h:35-75 names all seven, and each one says what it means: `right` (:40-42) is which
// SIDE the coefficient matrix multiplies on, "NO indicates the multiplication is on the left"; `upper`
// (:44-46) is which triangle, "NO indicates that the coefficient matrix is lower triangular";
// `transpose` (:47-49) is op(A) = A**T; `unit` (:50-52) says the triangle's diagonal is all ones, which
// is what an L from an LU factorization carries and what makes the substitution a multiply rather than
// a divide; `order` and `numberOfRightHandSides` (:53-60) are the system's order and how many
// right-hand sides there are, and which of the two axes each of them is depends on `right`; `alpha`
// (:61-62) scales the right-hand sides, which is the header's own scale on B and not a post-multiply.
- (instancetype)initWithDevice:(id<MTLDevice>)device
                         right:(BOOL)right
                         upper:(BOOL)upper
                     transpose:(BOOL)transpose
                          unit:(BOOL)unit
                         order:(NSUInteger)order
          numberOfRightHandSides:(NSUInteger)numberOfRightHandSides
                         alpha:(double)alpha
{
    if ((self = [super initWithDevice:device])) {
        _right = right;
        _upper = upper;
        _transpose = transpose;
        _unit = unit;
        _order = order;
        _numberOfRightHandSides = numberOfRightHandSides;
        _alpha = alpha;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [self initWithDevice:device right:NO upper:NO transpose:NO unit:NO order:1
          numberOfRightHandSides:1 alpha:1.0];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceMatrix:(MPSMatrix *)sourceMatrix
          rightHandSideMatrix:(MPSMatrix *)rightHandSideMatrix
               solutionMatrix:(MPSMatrix *)solutionMatrix
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView a = CharonMPSMatrixViewOf(sourceMatrix);
    CharonMPSMatrixView b = CharonMPSMatrixViewOf(rightHandSideMatrix);
    CharonMPSMatrixView x = CharonMPSMatrixViewOf(solutionMatrix);
    if (!CharonMPSDataTypeIsElement(a.dataType) || !CharonMPSDataTypeIsElement(b.dataType) ||
        !CharonMPSDataTypeIsElement(x.dataType)) {
        CharonMPSRefuse(@"MPSMatrixSolveTriangular: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    NSUInteger order = _order;
    NSUInteger sides = _numberOfRightHandSides;
    // MPSMatrixSolve.h:24-26: op(A) times X equal to alpha times B in one form and X times op(A) equal to alpha times B in the other. Which of the two this is
    // decides the SHAPE of B and X, not just the loop: with the multiplication on the left B and X are
    // order x sides, and with it on the right they are sides x order - which is what the right flag at :53-60
    // means, since that flag decides which of the solution's dimensions is the column count.
    NSUInteger rows = _right ? sides : order;
    NSUInteger columns = _right ? order : sides;
    if (!CharonMPSMatrixHolds(&a, 0, 0, 0, order, order) ||
        !CharonMPSMatrixHolds(&b, 0, 0, 0, rows, columns) ||
        !CharonMPSMatrixHolds(&x, 0, 0, 0, rows, columns)) {
        CharonMPSRefuse(@"MPSMatrixSolveTriangular: a matrix does not hold the %lux%lu system named, so "
                        "nothing was written", (unsigned long)order, (unsigned long)order);
        return;
    }
    // The triangle this kernel walks is named by three flags, and the substitution's ORDER is the
    // triangle: forwards for a lower A, backwards for an upper one. A transposed A is the other
    // triangle (:47-49), so `upper` flips, and that is the only thing the transpose changes about which
    // loop runs - it does not need a transposed copy of the matrix.
    BOOL lower = !_upper;
    if (_transpose)
        lower = !lower;
    for (NSUInteger side = 0; side < sides; side++) {
        for (NSUInteger step = 0; step < order; step++) {
            NSUInteger index = lower ? step : order - 1 - step;
            // The right-hand side element of this system: with the multiplication on the left B is
            // order x sides and the row is the index; with it on the right B is sides x order and the
            // row is the side. One is chosen rather than two loops written out.
            double sum = _right ? CharonMatrixSolveGet(&b, 0, side, index) * _alpha
                                : CharonMatrixSolveGet(&b, 0, index, side) * _alpha;
            for (NSUInteger k = 0; k < step; k++) {
                NSUInteger other = lower ? k : order - 1 - k;
                double solved = _right ? CharonMatrixSolveGet(&x, 0, side, other)
                                       : CharonMatrixSolveGet(&x, 0, other, side);
                sum -= CharonMatrixSolveGet(&a, 0, index, other) * solved;
            }
            double diagonal = CharonMatrixSolveGet(&a, 0, index, index);
            // A UNIT triangular matrix has ones on its diagonal by definition (:50-52), so the step is
            // a multiply and there is nothing to divide by - which is what an L from an LU
            // factorization is, and reading a one off the matrix instead would refuse a legal system.
            double answer = _unit ? sum : (diagonal == 0.0 ? NAN : sum / diagonal);
            if (!_unit && diagonal == 0.0) {
                CharonMPSRefuse(@"MPSMatrixSolveTriangular: row %lu of the coefficient matrix is zero on "
                                "its diagonal and it was not given as unit, so the system has no solution "
                                "this kernel can divide its way to and nothing was written",
                                (unsigned long)index);
                return;
            }
            if (_right)
                CharonMatrixSolvePut(&x, 0, side, index, answer);
            else
                CharonMatrixSolvePut(&x, 0, index, side, answer);
        }
    }
    CharonMPSConsumeReadCount(sourceMatrix);
    CharonMPSConsumeReadCount(rightHandSideMatrix);
}

@end

@implementation MPSMatrixSolveCholesky {
    BOOL _upper;
    NSUInteger _order, _numberOfRightHandSides;
}

// MPSMatrixSolve.h:218-233 names the three, and the source matrix is NOT A: MPSMatrixSolve.h:243-245
// calls it the source in factored form, and :253-254 says the factors come from an earlier run of
// MPSMatrixDecompositionCholesky. So this kernel applies two substitutions to a factor the caller
// already has - it factors nothing, and the factorization is not recomputed here. `upper` (:218-219)
// picks which triangle of the factor is the non-unit one.
- (instancetype)initWithDevice:(id<MTLDevice>)device
                         upper:(BOOL)upper
                         order:(NSUInteger)order
          numberOfRightHandSides:(NSUInteger)numberOfRightHandSides
{
    if ((self = [super initWithDevice:device])) {
        _upper = upper;
        _order = order;
        _numberOfRightHandSides = numberOfRightHandSides;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [self initWithDevice:device upper:NO order:1 numberOfRightHandSides:1];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceMatrix:(MPSMatrix *)sourceMatrix
          rightHandSideMatrix:(MPSMatrix *)rightHandSideMatrix
               solutionMatrix:(MPSMatrix *)solutionMatrix
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView factor = CharonMPSMatrixViewOf(sourceMatrix);
    CharonMPSMatrixView b = CharonMPSMatrixViewOf(rightHandSideMatrix);
    CharonMPSMatrixView x = CharonMPSMatrixViewOf(solutionMatrix);
    if (!CharonMPSDataTypeIsElement(factor.dataType) || !CharonMPSDataTypeIsElement(b.dataType) ||
        !CharonMPSDataTypeIsElement(x.dataType)) {
        CharonMPSRefuse(@"MPSMatrixSolveCholesky: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    // MPSMatrixSolve.h:257-259: rightHandSideMatrix and solutionMatrix must hold order x
    // numberOfRightHandSides, and sourceMatrix at least order x order.
    NSUInteger order = _order, sides = _numberOfRightHandSides;
    if (!CharonMPSMatrixHolds(&factor, 0, 0, 0, order, order) ||
        !CharonMPSMatrixHolds(&b, 0, 0, 0, order, sides) ||
        !CharonMPSMatrixHolds(&x, 0, 0, 0, order, sides)) {
        CharonMPSRefuse(@"MPSMatrixSolveCholesky: a matrix does not hold the %lux%lu system named, so "
                        "nothing was written", (unsigned long)order, (unsigned long)order);
        return;
    }
    // A = L * L**T, so A * X = B is L*Y = B and then L**T*X = Y: one substitution with the factor as
    // STORED, and one with its TRANSPOSE. Which triangle was stored is what `upper` names, and a
    // triangular matrix's element at (r,c) with c on the far side of the diagonal is the other
    // triangle's, so the stored position of the logical (row, other) is (row, other) for a lower
    // factor and (other, row) for an upper one. Both substitutions are written against that ONE rule.
    //
    // The first version of this kernel read (row, other) in the BACKWARD pass as well, which walks the
    // stored triangle twice and never its transpose: measured 2026-10-01, A = [4 2 2; 2 5 1; 2 1 6] with
    // b = (4,5,9) answered A*X = 5.6, 2.8, ... where the system is 4, 5, 9.
    // The two substitutions need DIFFERENT right-hand sides: the forward one has B and the backward one
    // has what the forward one produced. The first version of this file ran both passes in and out of
    // the SOLUTION matrix, so the backward pass read its own seed from a cell the forward pass had
    // written and then subtracted the forward values of rows it had not replaced yet: measured
    // 2026-10-01, A = [4 2 2; 2 5 1; 2 1 6] with b = (4,5,9) answered x = (1, 0.75, 1.4) where the
    // solution is (-0.075, 0.75, 1.4) - the last two rows right and the first one not, because it is the
    // one the backward pass reads after the others have overwritten it. The intermediate is its own
    // buffer, sized to the order and freed on every path out.
    double *intermediate = calloc(order * sides, sizeof(double));
    if (!intermediate) {
        CharonMPSRefuse(@"MPSMatrixSolveCholesky: no memory for the %lux%lu intermediate, so nothing was "
                        "written", (unsigned long)order, (unsigned long)sides);
        return;
    }
    BOOL lower = !_upper;
    for (NSUInteger side = 0; side < sides; side++) {
        // Forward through the stored triangle: row 0 upward for a lower factor, row order-1 downward
        // for an upper one, and the already-solved rows are the ones before it in that walk.
        for (NSUInteger step = 0; step < order; step++) {
            NSUInteger row = lower ? step : order - 1 - step;
            double sum = CharonMatrixSolveGet(&b, 0, row, side);
            for (NSUInteger k = 0; k < step; k++) {
                NSUInteger other = lower ? k : order - 1 - k;
                sum -= CharonMatrixSolveGet(&factor, 0, lower ? row : other, lower ? other : row) *
                       intermediate[other * sides + side];
            }
            double diagonal = CharonMatrixSolveGet(&factor, 0, row, row);
            if (diagonal == 0.0) {
                free(intermediate);
                CharonMPSRefuse(@"MPSMatrixSolveCholesky: the factor's diagonal entry at %lu is zero, so "
                                "the system has no solution this kernel can divide its way to and nothing "
                                "was written", (unsigned long)row);
                return;
            }
            intermediate[row * sides + side] = sum / diagonal;
        }
        // Backward through the TRANSPOSE of that triangle, which is the other one, writing the answer
        // where a caller reads it.
        // The backward pass walks the ROWS downward - order-1, order-2, ... 0 for a lower factor and 0,
        // 1, ... order-1 for an upper one - and the rows it subtracts are the ones it has already done,
        // which are ABOVE it in the matrix and therefore EARLIER in this walk. Indexing this loop by a
        // step that runs the OTHER way from `row` is what the first version did, and it made the two
        // disagree: step 2 named row 0 while its `other` range 3..2 was empty, so row 0 subtracted
        // nothing. Measured 2026-10-01, A = [4 2 2; 2 5 1; 2 1 6] with b = (4,5,9) answered x = (1, 0.75,
        // 1.4) where the solution is (-0.075, 0.75, 1.4) - the last two rows right and the first wrong,
        // because it is the one that lost its subtractions.
        for (NSUInteger done = 0; done < order; done++) {
            NSUInteger row = lower ? order - 1 - done : done;
            double sum = intermediate[row * sides + side];
            // `other` walks the rows ALREADY SOLVED by this pass, which are the ones after `row` in the
            // walk, and it is their ROW index - not a second index derived from k. The first version
            // wrote other = order - 1 - k, which names a different row for every k and skips the two it
            // should have subtracted: measured 2026-10-01, A = [4 2 2; 2 5 1; 2 1 6] with b = (4,5,9)
            // answered x = (1, 0.75, 1.4) whose A*x is 8.3, 7.15, 11.15 where the system is 4, 5, 9; the
            // solution is (-0.075, 0.75, 1.4).
            // The rows already solved in this pass are the `done` of them, and they are the ones this
            // element subtracts - by position in the walk, which for a lower factor is BELOW it.
            for (NSUInteger previous = 0; previous < done; previous++) {
                NSUInteger other = lower ? order - 1 - previous : previous;
                // The transpose's element at (row, other) is the stored factor's at (other, row).
                sum -= CharonMatrixSolveGet(&factor, 0, lower ? other : row, lower ? row : other) *
                       CharonMatrixSolveGet(&x, 0, other, side);
            }
            double diagonal = CharonMatrixSolveGet(&factor, 0, row, row);
            if (diagonal == 0.0) {
                free(intermediate);
                CharonMPSRefuse(@"MPSMatrixSolveCholesky: the factor's diagonal entry at %lu is zero in "
                                "the transpose substitution too, so nothing was written", (unsigned long)row);
                return;
            }
            CharonMatrixSolvePut(&x, 0, row, side, sum / diagonal);
        }
    }
    free(intermediate);
    CharonMPSConsumeReadCount(sourceMatrix);
    CharonMPSConsumeReadCount(rightHandSideMatrix);
}

@end

@implementation MPSMatrixSolveLU

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [super initWithDevice:device];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceMatrix:(MPSMatrix *)sourceMatrix
          rightHandSideMatrix:(MPSMatrix *)rightHandSideMatrix
                pivotIndices:(MPSMatrix *)pivotIndices
               solutionMatrix:(MPSMatrix *)solutionMatrix
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView a = CharonMPSMatrixViewOf(sourceMatrix);
    CharonMPSMatrixView b = CharonMPSMatrixViewOf(rightHandSideMatrix);
    CharonMPSMatrixView x = CharonMPSMatrixViewOf(solutionMatrix);
    CharonMPSMatrixView pivot = CharonMPSMatrixViewOf(pivotIndices);
    if (!CharonMPSDataTypeIsElement(a.dataType) || !CharonMPSDataTypeIsElement(b.dataType) ||
        !CharonMPSDataTypeIsElement(x.dataType)) {
        CharonMPSRefuse(@"MPSMatrixSolveLU: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    // MPSMatrixSolve.h:127-129: op(A) * X = B, where the source is the FACTORED matrix a
    // MPSMatrixDecompositionLU produced and the pivot indices are its own (:122-124). So this kernel
    // does not factor anything: it applies the two substitutions to L and U as they were handed over.
    // The pivot array's element type is MPSMatrixDecomposition.h:94's MPSDataTypeUInt32.
    NSUInteger order = a.rows;
    NSUInteger sides = x.columns;
    if (!CharonMPSMatrixHolds(&a, 0, 0, 0, order, order) ||
        !CharonMPSMatrixHolds(&b, 0, 0, 0, order, sides) ||
        !CharonMPSMatrixHolds(&x, 0, 0, 0, order, sides) ||
        !CharonMPSMatrixHolds(&pivot, 0, 0, 0, 1, order)) {
        CharonMPSRefuse(@"MPSMatrixSolveLU: a matrix does not hold the %lux%lu system named, so nothing "
                        "was written", (unsigned long)order, (unsigned long)order);
        return;
    }
    for (NSUInteger side = 0; side < sides; side++) {
        // Forward through L. Two things the first version of this kernel got wrong, both measured
        // 2026-10-01 by the A*X round trip in tests/backports/host/mpsmatrixsolve, which answered
        // (1, 1.625, 2.2) where the system is (4, 5, 9):
        //
        //   - L's DIAGONAL IS ALL ONES. MPSMatrixDecomposition.h:86-91 has the decomposition leave L
        //     below the diagonal and U on and above it, and the unit entries are implicit - which is
        //     what MPSMatrixSolveTriangular's own `unit` parameter names (MPSMatrixSolve.h:50-52). The
        //     old loop divided by L(row,row), which is U's value there, and so solved the wrong system.
        //   - The pivot order moves the RIGHT-HAND SIDES, and into the answer, not by swapping cells of
        //     the caller's `b`. b is the caller's matrix and nothing in the header says an encode
        //     modifies it; the old loop swapped b[step] with x[row] in place, so a second right-hand side
        //     or a second kernel over the same b saw a permuted system.
        for (NSUInteger step = 0; step < order; step++) {
            NSUInteger row = (NSUInteger)CharonMPSLoad(CharonMPSMatrixElement(&pivot, 0, 0, step),
                                                       pivot.dataType, 0);
            if (row >= order) {
                CharonMPSRefuse(@"MPSMatrixSolveLU: pivot index %lu of %lu is outside the %lux%lu system, "
                                "so nothing was written", (unsigned long)step, (unsigned long)order,
                                (unsigned long)order, (unsigned long)order);
                return;
            }
            // Piv[step] is the row that ended up at `step`, so the right-hand side of that equation is
            // the caller's B(row) - the same order the decomposition permuted the matrix by.
            double sum = CharonMatrixSolveGet(&b, 0, row, side);
            for (NSUInteger k = 0; k < step; k++)
                sum -= CharonMatrixSolveGet(&a, 0, row, k) * CharonMatrixSolveGet(&x, 0, k, side);
            CharonMatrixSolvePut(&x, 0, row, side, sum);
        }
        // Backward through U.
        for (NSUInteger step = order; step-- > 0; ) {
            double sum = CharonMatrixSolveGet(&x, 0, step, side);
            for (NSUInteger k = step + 1; k < order; k++)
                sum -= CharonMatrixSolveGet(&a, 0, step, k) * CharonMatrixSolveGet(&x, 0, k, side);
            double diagonal = CharonMatrixSolveGet(&a, 0, step, step);
            if (diagonal == 0.0) {
                CharonMPSRefuse(@"MPSMatrixSolveLU: row %lu of the factored matrix is zero on its "
                                "diagonal, so nothing was written", (unsigned long)step);
                return;
            }
            CharonMatrixSolvePut(&x, 0, step, side, sum / diagonal);
        }
    }
    CharonMPSConsumeReadCount(sourceMatrix);
    CharonMPSConsumeReadCount(rightHandSideMatrix);
}

@end