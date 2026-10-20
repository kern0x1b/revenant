#import "RevenantMPS.h"


static inline double RevenantMatrixSolveGet(const RevenantMPSMatrixView *view, NSUInteger matrix, NSUInteger row, NSUInteger column)
{
    return RevenantMPSLoad(RevenantMPSMatrixElement(view, matrix, row, column), view->dataType, 0);
}

static inline void RevenantMatrixSolvePut(const RevenantMPSMatrixView *view, NSUInteger matrix, NSUInteger row, NSUInteger column, double value)
{
    RevenantMPSStore(RevenantMPSMatrixElement(view, matrix, row, column), view->dataType, 0, value);
}

static void RevenantMatrixSolveStatus(id<MTLCommandBuffer> commandBuffer, id<MTLBuffer> status, MPSMatrixDecompositionStatus value)
{
    MPSMatrixDecompositionStatus *bytes = [status contents];
    if (bytes)
        *bytes = value;
    else
        RevenantMPSRefuse(@"%s: no status buffer was given, so the decomposition's %d was computed and not "
                        "written anywhere", "MPSMatrixDecomposition", (int)value);
    (void)commandBuffer;
}

static inline double RevenantMPSCholeskyFactor(const RevenantMPSMatrixView *view, BOOL lower, NSUInteger r, NSUInteger c)
{
    return RevenantMatrixSolveGet(view, 0, lower ? r : c, lower ? c : r);
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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView from = RevenantMPSMatrixViewOf(sourceMatrix);
    RevenantMPSMatrixView to = RevenantMPSMatrixViewOf(resultMatrix);
    if (!RevenantMPSDataTypeIsElement(from.dataType) || !RevenantMPSDataTypeIsElement(to.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixDecompositionCholesky: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    NSUInteger order = _order;
    if (!RevenantMPSMatrixHolds(&from, 0, 0, 0, order, order) ||
        !RevenantMPSMatrixHolds(&to, 0, 0, 0, order, order)) {
        RevenantMPSRefuse(@"MPSMatrixDecompositionCholesky: the source or the result does not hold a %lux%lu "
                        @"matrix, so nothing was written", (unsigned long)order, (unsigned long)order);
        return;
    }

    for (NSUInteger r = 0; r < order; r++) {
        for (NSUInteger c = 0; c <= r; c++) {
            NSUInteger row = _lower ? r : c;
            NSUInteger column = _lower ? c : r;
            double sum = RevenantMatrixSolveGet(&from, 0, r, c);
            for (NSUInteger k = 0; k < c; k++) {
                sum -= RevenantMPSCholeskyFactor(&to, _lower, r, k) * RevenantMPSCholeskyFactor(&to, _lower, c, k);
            }
            if (r == c) {
                if (sum <= 0.0) {
                    RevenantMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusNonPositiveDefinite);
                    return;
                }
                RevenantMatrixSolvePut(&to, 0, row, column, sqrt(sum));
            } else {
                double diagonalEntry = RevenantMPSCholeskyFactor(&to, _lower, c, c);
                if (diagonalEntry == 0.0) {
                    RevenantMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusSingular);
                    return;
                }
                RevenantMatrixSolvePut(&to, 0, row, column, sum / diagonalEntry);
            }
        }
    }
    RevenantMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusSuccess);
    RevenantMPSConsumeReadCount(sourceMatrix);
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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView from = RevenantMPSMatrixViewOf(sourceMatrix);
    RevenantMPSMatrixView to = RevenantMPSMatrixViewOf(resultMatrix);
    RevenantMPSMatrixView pivot = RevenantMPSMatrixViewOf(pivotIndices);
    if (!RevenantMPSDataTypeIsElement(from.dataType) || !RevenantMPSDataTypeIsElement(to.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixDecompositionLU: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    NSUInteger rows = _rows, columns = _columns;
    NSUInteger steps = rows < columns ? rows : columns;
    if (!RevenantMPSMatrixHolds(&from, 0, 0, 0, rows, columns) ||
        !RevenantMPSMatrixHolds(&to, 0, 0, 0, rows, columns) ||
        !RevenantMPSMatrixHolds(&pivot, 0, 0, 0, 1, steps)) {
        RevenantMPSRefuse(@"MPSMatrixDecompositionLU: a matrix does not hold the %lux%lu region the "
                        "factorization names, so nothing was written",
                        (unsigned long)rows, (unsigned long)columns);
        return;
    }

    for (NSUInteger row = 0; row < rows; row++)
        for (NSUInteger column = 0; column < columns; column++)
            RevenantMatrixSolvePut(&to, 0, row, column, RevenantMatrixSolveGet(&from, 0, row, column));

    for (NSUInteger step = 0; step < steps; step++) {
        NSUInteger best = step;
        double bestValue = fabs(RevenantMatrixSolveGet(&to, 0, step, step));
        for (NSUInteger candidate = step + 1; candidate < rows; candidate++) {
            double magnitude = fabs(RevenantMatrixSolveGet(&to, 0, candidate, step));
            if (magnitude > bestValue) {
                bestValue = magnitude;
                best = candidate;
            }
        }
        RevenantMPSStore(RevenantMPSMatrixElement(&pivot, 0, 0, step), pivot.dataType, 0, (double)best);
        if (bestValue == 0.0) {
            RevenantMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusSingular);
            return;
        }
        if (best != step) {
            for (NSUInteger column = 0; column < columns; column++) {
                double held = RevenantMatrixSolveGet(&to, 0, step, column);
                RevenantMatrixSolvePut(&to, 0, step, column, RevenantMatrixSolveGet(&to, 0, best, column));
                RevenantMatrixSolvePut(&to, 0, best, column, held);
            }
        }
        double diagonal = RevenantMatrixSolveGet(&to, 0, step, step);
        for (NSUInteger row = step + 1; row < rows; row++) {
            double below = RevenantMatrixSolveGet(&to, 0, row, step);
            RevenantMatrixSolvePut(&to, 0, row, step, below / diagonal);
            for (NSUInteger column = step + 1; column < columns; column++) {
                double updated = RevenantMatrixSolveGet(&to, 0, row, column) -
                                 RevenantMatrixSolveGet(&to, 0, row, step) * RevenantMatrixSolveGet(&to, 0, step, column);
                RevenantMatrixSolvePut(&to, 0, row, column, updated);
            }
        }
    }
    RevenantMatrixSolveStatus(commandBuffer, status, MPSMatrixDecompositionStatusSuccess);
    RevenantMPSConsumeReadCount(sourceMatrix);
}

@end

@implementation MPSMatrixSolveTriangular {
    BOOL _right, _upper, _transpose, _unit;
    NSUInteger _order, _numberOfRightHandSides;
    double _alpha;
}

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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView a = RevenantMPSMatrixViewOf(sourceMatrix);
    RevenantMPSMatrixView b = RevenantMPSMatrixViewOf(rightHandSideMatrix);
    RevenantMPSMatrixView x = RevenantMPSMatrixViewOf(solutionMatrix);
    if (!RevenantMPSDataTypeIsElement(a.dataType) || !RevenantMPSDataTypeIsElement(b.dataType) ||
        !RevenantMPSDataTypeIsElement(x.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixSolveTriangular: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    NSUInteger order = _order;
    NSUInteger sides = _numberOfRightHandSides;
    NSUInteger rows = _right ? sides : order;
    NSUInteger columns = _right ? order : sides;
    if (!RevenantMPSMatrixHolds(&a, 0, 0, 0, order, order) ||
        !RevenantMPSMatrixHolds(&b, 0, 0, 0, rows, columns) ||
        !RevenantMPSMatrixHolds(&x, 0, 0, 0, rows, columns)) {
        RevenantMPSRefuse(@"MPSMatrixSolveTriangular: a matrix does not hold the %lux%lu system named, so "
                        "nothing was written", (unsigned long)order, (unsigned long)order);
        return;
    }
    BOOL lower = !_upper;
    if (_transpose)
        lower = !lower;
    for (NSUInteger side = 0; side < sides; side++) {
        for (NSUInteger step = 0; step < order; step++) {
            NSUInteger index = lower ? step : order - 1 - step;
            double sum = _right ? RevenantMatrixSolveGet(&b, 0, side, index) * _alpha
                                : RevenantMatrixSolveGet(&b, 0, index, side) * _alpha;
            for (NSUInteger k = 0; k < step; k++) {
                NSUInteger other = lower ? k : order - 1 - k;
                double solved = _right ? RevenantMatrixSolveGet(&x, 0, side, other)
                                       : RevenantMatrixSolveGet(&x, 0, other, side);
                sum -= RevenantMatrixSolveGet(&a, 0, index, other) * solved;
            }
            double diagonal = RevenantMatrixSolveGet(&a, 0, index, index);
            double answer = _unit ? sum : (diagonal == 0.0 ? NAN : sum / diagonal);
            if (!_unit && diagonal == 0.0) {
                RevenantMPSRefuse(@"MPSMatrixSolveTriangular: row %lu of the coefficient matrix is zero on "
                                "its diagonal and it was not given as unit, so the system has no solution "
                                "this kernel can divide its way to and nothing was written",
                                (unsigned long)index);
                return;
            }
            if (_right)
                RevenantMatrixSolvePut(&x, 0, side, index, answer);
            else
                RevenantMatrixSolvePut(&x, 0, index, side, answer);
        }
    }
    RevenantMPSConsumeReadCount(sourceMatrix);
    RevenantMPSConsumeReadCount(rightHandSideMatrix);
}

@end

@implementation MPSMatrixSolveCholesky {
    BOOL _upper;
    NSUInteger _order, _numberOfRightHandSides;
}

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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView factor = RevenantMPSMatrixViewOf(sourceMatrix);
    RevenantMPSMatrixView b = RevenantMPSMatrixViewOf(rightHandSideMatrix);
    RevenantMPSMatrixView x = RevenantMPSMatrixViewOf(solutionMatrix);
    if (!RevenantMPSDataTypeIsElement(factor.dataType) || !RevenantMPSDataTypeIsElement(b.dataType) ||
        !RevenantMPSDataTypeIsElement(x.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixSolveCholesky: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    NSUInteger order = _order, sides = _numberOfRightHandSides;
    if (!RevenantMPSMatrixHolds(&factor, 0, 0, 0, order, order) ||
        !RevenantMPSMatrixHolds(&b, 0, 0, 0, order, sides) ||
        !RevenantMPSMatrixHolds(&x, 0, 0, 0, order, sides)) {
        RevenantMPSRefuse(@"MPSMatrixSolveCholesky: a matrix does not hold the %lux%lu system named, so "
                        "nothing was written", (unsigned long)order, (unsigned long)order);
        return;
    }
    double *intermediate = calloc(order * sides, sizeof(double));
    if (!intermediate) {
        RevenantMPSRefuse(@"MPSMatrixSolveCholesky: no memory for the %lux%lu intermediate, so nothing was "
                        "written", (unsigned long)order, (unsigned long)sides);
        return;
    }
    BOOL lower = !_upper;
    for (NSUInteger side = 0; side < sides; side++) {
        for (NSUInteger step = 0; step < order; step++) {
            NSUInteger row = lower ? step : order - 1 - step;
            double sum = RevenantMatrixSolveGet(&b, 0, row, side);
            for (NSUInteger k = 0; k < step; k++) {
                NSUInteger other = lower ? k : order - 1 - k;
                sum -= RevenantMatrixSolveGet(&factor, 0, lower ? row : other, lower ? other : row) *
                       intermediate[other * sides + side];
            }
            double diagonal = RevenantMatrixSolveGet(&factor, 0, row, row);
            if (diagonal == 0.0) {
                free(intermediate);
                RevenantMPSRefuse(@"MPSMatrixSolveCholesky: the factor's diagonal entry at %lu is zero, so "
                                "the system has no solution this kernel can divide its way to and nothing "
                                "was written", (unsigned long)row);
                return;
            }
            intermediate[row * sides + side] = sum / diagonal;
        }
        for (NSUInteger done = 0; done < order; done++) {
            NSUInteger row = lower ? order - 1 - done : done;
            double sum = intermediate[row * sides + side];
            for (NSUInteger previous = 0; previous < done; previous++) {
                NSUInteger other = lower ? order - 1 - previous : previous;
                sum -= RevenantMatrixSolveGet(&factor, 0, lower ? other : row, lower ? row : other) *
                       RevenantMatrixSolveGet(&x, 0, other, side);
            }
            double diagonal = RevenantMatrixSolveGet(&factor, 0, row, row);
            if (diagonal == 0.0) {
                free(intermediate);
                RevenantMPSRefuse(@"MPSMatrixSolveCholesky: the factor's diagonal entry at %lu is zero in "
                                "the transpose substitution too, so nothing was written", (unsigned long)row);
                return;
            }
            RevenantMatrixSolvePut(&x, 0, row, side, sum / diagonal);
        }
    }
    free(intermediate);
    RevenantMPSConsumeReadCount(sourceMatrix);
    RevenantMPSConsumeReadCount(rightHandSideMatrix);
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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView a = RevenantMPSMatrixViewOf(sourceMatrix);
    RevenantMPSMatrixView b = RevenantMPSMatrixViewOf(rightHandSideMatrix);
    RevenantMPSMatrixView x = RevenantMPSMatrixViewOf(solutionMatrix);
    RevenantMPSMatrixView pivot = RevenantMPSMatrixViewOf(pivotIndices);
    if (!RevenantMPSDataTypeIsElement(a.dataType) || !RevenantMPSDataTypeIsElement(b.dataType) ||
        !RevenantMPSDataTypeIsElement(x.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixSolveLU: a matrix of a data type that is not one of the eight element types was given, so nothing was written");
        return;
    }
    NSUInteger order = a.rows;
    NSUInteger sides = x.columns;
    if (!RevenantMPSMatrixHolds(&a, 0, 0, 0, order, order) ||
        !RevenantMPSMatrixHolds(&b, 0, 0, 0, order, sides) ||
        !RevenantMPSMatrixHolds(&x, 0, 0, 0, order, sides) ||
        !RevenantMPSMatrixHolds(&pivot, 0, 0, 0, 1, order)) {
        RevenantMPSRefuse(@"MPSMatrixSolveLU: a matrix does not hold the %lux%lu system named, so nothing "
                        "was written", (unsigned long)order, (unsigned long)order);
        return;
    }
    for (NSUInteger side = 0; side < sides; side++) {
        for (NSUInteger step = 0; step < order; step++) {
            NSUInteger row = (NSUInteger)RevenantMPSLoad(RevenantMPSMatrixElement(&pivot, 0, 0, step),
                                                       pivot.dataType, 0);
            if (row >= order) {
                RevenantMPSRefuse(@"MPSMatrixSolveLU: pivot index %lu of %lu is outside the %lux%lu system, "
                                "so nothing was written", (unsigned long)step, (unsigned long)order,
                                (unsigned long)order, (unsigned long)order);
                return;
            }
            double sum = RevenantMatrixSolveGet(&b, 0, row, side);
            for (NSUInteger k = 0; k < step; k++)
                sum -= RevenantMatrixSolveGet(&a, 0, row, k) * RevenantMatrixSolveGet(&x, 0, k, side);
            RevenantMatrixSolvePut(&x, 0, row, side, sum);
        }
        for (NSUInteger step = order; step-- > 0; ) {
            double sum = RevenantMatrixSolveGet(&x, 0, step, side);
            for (NSUInteger k = step + 1; k < order; k++)
                sum -= RevenantMatrixSolveGet(&a, 0, step, k) * RevenantMatrixSolveGet(&x, 0, k, side);
            double diagonal = RevenantMatrixSolveGet(&a, 0, step, step);
            if (diagonal == 0.0) {
                RevenantMPSRefuse(@"MPSMatrixSolveLU: row %lu of the factored matrix is zero on its "
                                "diagonal, so nothing was written", (unsigned long)step);
                return;
            }
            RevenantMatrixSolvePut(&x, 0, step, side, sum / diagonal);
        }
    }
    RevenantMPSConsumeReadCount(sourceMatrix);
    RevenantMPSConsumeReadCount(rightHandSideMatrix);
}

@end
