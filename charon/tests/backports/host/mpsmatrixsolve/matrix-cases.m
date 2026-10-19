// matrix-cases.m - does this port's MPSMatrix solve and decomposition family say what the headers say?
//
// Every case here is a ROUND TRIP, checked by CharonMPSMatrixSolveReference.h: a factorization is right
// when its factors multiply back to the matrix that went in, and a solve is right when its answer
// multiplied by the coefficient matrix gives the right-hand side. That is the oracle because this host
// cannot run the release's own kernels - its AGX family lacks computeCommandEncoderWithDispatchType: -
// and because the round trip is a statement about the ANSWER, so it needs no agreement with the
// release's pivot order or its rounding.
//
// The class names reach the port's classes through the rename header the run script generates from the
// port's OWN compiled objects, never from a list written here: a class the port stops defining would
// otherwise fall back to the RELEASE's class and the case would measure the release twice.

#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import "CharonMPSMatrixSolveReference.h"
#include <stdio.h>
#include <string.h>

NSUInteger gCompared = 0;
NSUInteger gMismatches = 0;

static id<MTLDevice> gDevice = nil;

// A matrix over one buffer, built the way tests/backports/host/mpsmatrix/mps-cases.m:150-157 builds
// one: a real MTLBuffer and an MPSMatrixDescriptor. An MPSMatrix does not copy the buffer it was made
// from, which that harness checks rather than assumes and which this one relies on - a kernel that
// writes the matrix writes this buffer.
static MPSMatrix *CharonMakeMatrix(NSUInteger order, NSUInteger columns, MPSDataType dataType, const void *values)
{
    size_t element = MPSSizeofMPSDataType(dataType);
    size_t rowBytes = columns * element, matrixBytes = order * columns * element;
    size_t bytes = (order - 1) * rowBytes + columns * element;
    id<MTLBuffer> buffer = [gDevice newBufferWithBytes:values length:bytes options:MTLResourceStorageModeShared];
    MPSMatrixDescriptor *descriptor =
        [MPSMatrixDescriptor matrixDescriptorWithRows:order columns:columns matrices:1
                                             rowBytes:rowBytes matrixBytes:matrixBytes dataType:dataType];
    return [[MPSMatrix alloc] initWithBuffer:buffer descriptor:descriptor];
}

static MPSMatrix *CharonZeros(NSUInteger order, NSUInteger columns, MPSDataType dataType)
{
    size_t bytes = order * columns * MPSSizeofMPSDataType(dataType);
    void *zeroed = calloc(bytes ? bytes : 1, 1);
    MPSMatrix *made = CharonMakeMatrix(order, columns, dataType, zeroed);
    free(zeroed);
    return made;
}

// A command buffer this host's AGX family accepts: MPSImage13.m's CharonMPSCommandBufferPermits is what
// decides a walk runs, and it runs inside the encode. Nothing is committed - this host's command buffer
// has no -commit ('-[AGXG16XFamilyCommandBuffer_mtlnext commit]: unrecognized selector').
static id CharonBuffer(void)
{
    // The device's own buffer, handed over as `id`. The macOS surface types -newCommandBuffer as
    // MTL4CommandBuffer, and casting that to the older protocol this port's headers declare faults on
    // first use. The port's kernels take id<MTLCommandBuffer> and MPSImage13.m's
    // CharonMPSCommandBufferPermits only asks whether the buffer is an MPSCommandBuffer, so `id` reaches
    // them intact. Nothing is committed - this host's command buffer has no -commit.
    return [gDevice newCommandBuffer];
}

// A status buffer a decomposition writes into, from shared storage so the case can read it back.
static id<MTLBuffer> CharonMakeStatusBuffer(void)
{
    return [gDevice newBufferWithLength:sizeof(MPSMatrixDecompositionStatus) options:MTLResourceStorageModeShared];
}

int main(void)
{
    gDevice = MTLCreateSystemDefaultDevice();

    // A 3x3 symmetric POSITIVE-DEFINITE matrix (leading minors 4, 12, 4 all positive), so the Cholesky
    // exists by :141-143's own requirement and its factors are exactly representable:
    //     A = [ 4  2  2 ]
    //         [ 2  5  1 ]
    //         [ 2  1  6 ]
    // whose L is [2 0 0; 1 2 0; 1 .5 2.2912878...]. The one irrational entry is why the factor's own
    // values are NOT compared for equality and the ROUND TRIP is instead: L*L**T reproduces A exactly
    // even where L(r,c) is irrational, because the irrationality cancels in the product.
    const float spd[9] = {4, 2, 2,
                          2, 5, 1,
                          2, 1, 6};

    // A 3x3 matrix needing a real PIVOT: the first entry is zero, so a factorization that divided by
    // the diagonal without looking for a pivot would answer an infinity and the round trip would catch it.
    const float needsPivot[9] = {0, 2, 1,
                                 3, 4, 5,
                                 6, 7, 8};

    // A LOWER triangular system whose exact solution is integral, so a triangular solve is checkable.
    const float lower[9] = {2, 0, 0,
                            1, 3, 0,
                            2, 1, 4};
    const float rhs[6] = {4, 3, 2, 7, 6, 5};        // two right-hand sides
    //      [2 0 0][2]   [4]
    //      [1 3 0][1] = [5]  and   [1 1 4][1] = [3]
    //      [2 1 4][1]   [9]            2   [7]

    // An UPPER triangular system, the other direction the header's `upper` names.
    const float upper[9] = {2, 1, 2,
                            0, 3, 1,
                            0, 0, 4};
    const float upperRhs[3] = {8, 10, 8};           // solution (2, 2, 2)

    // ---- Cholesky factorization, lower and upper, both checked by the round trip ----
    for (int upperTriangle = 0; upperTriangle < 2; upperTriangle++) {
        MPSMatrixDecompositionCholesky *kernel =
            [[MPSMatrixDecompositionCholesky alloc] initWithDevice:gDevice lower:!upperTriangle order:3];
        MPSMatrix *source = CharonMakeMatrix(3, 3, MPSDataTypeFloat32, spd);
        MPSMatrix *result = CharonZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrixDecompositionStatus status = MPSMatrixDecompositionStatusFailure;
        id<MTLBuffer> statusBuffer = CharonMakeStatusBuffer();
        [kernel encodeToCommandBuffer:CharonBuffer() sourceMatrix:source resultMatrix:result
                              status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];
        float factor[9];
        memcpy(factor, [result.data contents], sizeof factor);
        CharonMPSMatrixSolveCholeskyCheck(upperTriangle ? "cholesky-upper" : "cholesky-lower",
                                          spd, factor, 3, !upperTriangle, (int)status);
    }

    // A matrix that is NOT positive definite - the leading minor is zero - answers the header's own
    // status at :40 rather than a square root of a negative number. The round trip checks the STATUS,
    // because that is what the kernel owes here and no factor exists to multiply back.
    {
        const float singular[9] = {0, 1, 1,
                                   1, 1, 1,
                                   1, 1, 1};
        MPSMatrixDecompositionCholesky *kernel =
            [[MPSMatrixDecompositionCholesky alloc] initWithDevice:gDevice lower:YES order:3];
        MPSMatrix *source = CharonMakeMatrix(3, 3, MPSDataTypeFloat32, singular);
        MPSMatrix *result = CharonZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrixDecompositionStatus status = 0;
        id<MTLBuffer> statusBuffer = CharonMakeStatusBuffer();
        [kernel encodeToCommandBuffer:CharonBuffer() sourceMatrix:source resultMatrix:result
                              status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];
        CharonMPSMatrixSolveCholeskyCheck("cholesky-not-positive-definite", singular, singular, 3, YES, (int)status);
    }

    // ---- LU factorization, including the pivot and the singular column ----
    {
        MPSMatrixDecompositionLU *kernel = [[MPSMatrixDecompositionLU alloc] initWithDevice:gDevice rows:3 columns:3];
        MPSMatrix *source = CharonMakeMatrix(3, 3, MPSDataTypeFloat32, spd);
        MPSMatrix *result = CharonZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrix *pivots = CharonZeros(1, 3, MPSDataTypeUInt32);
        MPSMatrixDecompositionStatus status = MPSMatrixDecompositionStatusFailure;
        id<MTLBuffer> statusBuffer = CharonMakeStatusBuffer();
        [kernel encodeToCommandBuffer:CharonBuffer() sourceMatrix:source resultMatrix:result
                       pivotIndices:pivots status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];
        float factor[9];
        memcpy(factor, [result.data contents], sizeof factor);
        // MPSMatrixDecomposition.h:94: "Element type must be MPSDataTypeUInt32", so the pivots are read
        // as uint32 and not as float. Reading them as float is what made this case report the pivots as
        // 1.4e-45 and 2.8e-45 - the bit patterns 1 and 2 read as denormals - and sent the round trip
        // looking for source row 1 where the factorization had pivoted none. Measured 2026-10-01.
        if (pivots.dataType != MPSDataTypeUInt32) {
            printf("CONTRACT the pivot matrix is %d, and MPSMatrixDecomposition.h:94 requires MPSDataTypeUInt32\n",
                   (int)pivots.dataType);
        }
        uint32_t pivotBits[3];
        memcpy(pivotBits, [pivots.data contents], sizeof pivotBits);
        float pivot[3];
        for (int i = 0; i < 3; i++)
            pivot[i] = (float)pivotBits[i];
        CharonMPSMatrixSolveLUCheck("lu", spd, factor, pivot, 3, (int)status);
    }
    {
        // A column of zeros below the diagonal: the header's own Singular at :39, checked as a status.
        const float rankTwo[9] = {1, 2, 3,
                                  2, 4, 6,
                                  3, 6, 9};
        MPSMatrixDecompositionLU *kernel = [[MPSMatrixDecompositionLU alloc] initWithDevice:gDevice rows:3 columns:3];
        MPSMatrix *source = CharonMakeMatrix(3, 3, MPSDataTypeFloat32, rankTwo);
        MPSMatrix *result = CharonZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrix *pivots = CharonZeros(1, 3, MPSDataTypeUInt32);
        MPSMatrixDecompositionStatus status = 0;
        id<MTLBuffer> statusBuffer = CharonMakeStatusBuffer();
        [kernel encodeToCommandBuffer:CharonBuffer() sourceMatrix:source resultMatrix:result
                       pivotIndices:pivots status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];
        CharonMPSMatrixSolveLUCheck("lu-singular", rankTwo, rankTwo, rankTwo, 3, (int)status);
    }

    // ---- Triangular solve, lower and upper, checked by A*X == alpha*B ----
    {
        MPSMatrixSolveTriangular *kernel =
            [[MPSMatrixSolveTriangular alloc] initWithDevice:gDevice right:NO upper:NO transpose:NO unit:NO
                                                        order:3 numberOfRightHandSides:2 alpha:1.0];
        MPSMatrix *a = CharonMakeMatrix(3, 3, MPSDataTypeFloat32, lower);
        MPSMatrix *b = CharonMakeMatrix(3, 2, MPSDataTypeFloat32, rhs);
        MPSMatrix *x = CharonZeros(3, 2, MPSDataTypeFloat32);
        [kernel encodeToCommandBuffer:CharonBuffer() sourceMatrix:a rightHandSideMatrix:b
                      solutionMatrix:x];
        float answer[6];
        memcpy(answer, [x.data contents], sizeof answer);
        CharonMPSMatrixSolveSystemCheck("triangular-lower", lower, rhs, answer, 3, 2, 1.0);
    }
    {
        MPSMatrixSolveTriangular *kernel =
            [[MPSMatrixSolveTriangular alloc] initWithDevice:gDevice right:NO upper:YES transpose:NO unit:NO
                                                        order:3 numberOfRightHandSides:1 alpha:1.0];
        MPSMatrix *a = CharonMakeMatrix(3, 3, MPSDataTypeFloat32, upper);
        MPSMatrix *b = CharonMakeMatrix(3, 1, MPSDataTypeFloat32, upperRhs);
        MPSMatrix *x = CharonZeros(3, 1, MPSDataTypeFloat32);
        [kernel encodeToCommandBuffer:CharonBuffer() sourceMatrix:a rightHandSideMatrix:b
                      solutionMatrix:x];
        float answer[3];
        memcpy(answer, [x.data contents], sizeof answer);
        CharonMPSMatrixSolveSystemCheck("triangular-upper", upper, upperRhs, answer, 3, 1, 1.0);
    }
    {
        // alpha != 1, which MPSMatrixSolve.h:24's "alpha * B" and :61-62's "scale the right hand sides"
        // both put in the system and which a kernel that ignored the scale would answer differently.
        MPSMatrixSolveTriangular *kernel =
            [[MPSMatrixSolveTriangular alloc] initWithDevice:gDevice right:NO upper:NO transpose:NO unit:NO
                                                        order:3 numberOfRightHandSides:1 alpha:2.0];
        MPSMatrix *a = CharonMakeMatrix(3, 3, MPSDataTypeFloat32, lower);
        MPSMatrix *b = CharonMakeMatrix(3, 1, MPSDataTypeFloat32, upperRhs);
        MPSMatrix *x = CharonZeros(3, 1, MPSDataTypeFloat32);
        [kernel encodeToCommandBuffer:CharonBuffer() sourceMatrix:a rightHandSideMatrix:b
                      solutionMatrix:x];
        float answer[3];
        memcpy(answer, [x.data contents], sizeof answer);
        CharonMPSMatrixSolveSystemCheck("triangular-alpha", lower, upperRhs, answer, 3, 1, 2.0);
    }

    // ---- Cholesky solve: the factor in, the system out ----
    {
        // The factor of the SPD matrix above, written out as MPSMatrixDecompositionCholesky would
        // leave it: L lower, unit diagonal above the stored entries.
        // L of the SPD matrix, as MPSMatrixDecompositionCholesky with lower=YES leaves it and as the
        // round trip above MEASURED it: [2 0 0; 1 2 0; 1 0 2.236068]. The first version of this case
        // wrote the upper triangle's values into the lower ones, and the kernel refused it by name -
        // which is the refusal doing its job, on a factor that was not one.
        const float factorOfSpd[9] = {2, 0, 0,
                                      1, 2, 0,
                                      1, 0, 2.236067977499790f};
        MPSMatrixSolveCholesky *kernel =
            [[MPSMatrixSolveCholesky alloc] initWithDevice:gDevice upper:NO order:3 numberOfRightHandSides:2];
        MPSMatrix *factor = CharonMakeMatrix(3, 3, MPSDataTypeFloat32, factorOfSpd);
        // This system's coefficient matrix is A = L*L**T, which is `spd`, so its right-hand sides are
        // its OWN and not the triangular system's: the first version reused `rhs` here, so the check
        // compared a solution of one system against the right-hand sides of another.
        const float choleskyRhs[6] = {4, 3, 5, 7, 9, 6};
        MPSMatrix *b = CharonMakeMatrix(3, 2, MPSDataTypeFloat32, choleskyRhs);
        MPSMatrix *x = CharonZeros(3, 2, MPSDataTypeFloat32);
        [kernel encodeToCommandBuffer:CharonBuffer() sourceMatrix:factor rightHandSideMatrix:b
                      solutionMatrix:x];
        float answer[6];
        memcpy(answer, [x.data contents], sizeof answer);
        // The coefficient matrix the system is really about is A = L*L**T, which is the SPD matrix.
        CharonMPSMatrixSolveSystemCheck("cholesky-solve", spd, choleskyRhs, answer, 3, 2, 1.0);
    }

    // ---- LU solve against the factorization the decomposition produced ----
    {
        MPSMatrixDecompositionLU *decompose = [[MPSMatrixDecompositionLU alloc] initWithDevice:gDevice rows:3 columns:3];
        MPSMatrix *source = CharonMakeMatrix(3, 3, MPSDataTypeFloat32, spd);
        MPSMatrix *factors = CharonZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrix *pivots = CharonZeros(1, 3, MPSDataTypeUInt32);
        MPSMatrixDecompositionStatus status = MPSMatrixDecompositionStatusFailure;
        id<MTLBuffer> statusBuffer = CharonMakeStatusBuffer();
        [decompose encodeToCommandBuffer:CharonBuffer() sourceMatrix:source resultMatrix:factors
                           pivotIndices:pivots status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];

        MPSMatrixSolveLU *solve = [[MPSMatrixSolveLU alloc] initWithDevice:gDevice];
        // This system's coefficient matrix is the one that was factored, `spd`, so its right-hand sides
        // are its own.
        const float luRhs[6] = {4, 3, 5, 7, 9, 6};
        MPSMatrix *b = CharonMakeMatrix(3, 2, MPSDataTypeFloat32, luRhs);
        MPSMatrix *x = CharonZeros(3, 2, MPSDataTypeFloat32);
        [solve encodeToCommandBuffer:CharonBuffer() sourceMatrix:factors rightHandSideMatrix:b
                      pivotIndices:pivots solutionMatrix:x];
        float answer[6];
        memcpy(answer, [x.data contents], sizeof answer);
        float factorValues[9];
        memcpy(factorValues, [factors.data contents], sizeof factorValues);
        float pivotValues[3];
        memcpy(pivotValues, [pivots.data contents], sizeof pivotValues);
        if (status == 0) {
            // ONE check here, and it is the solve's own: the factors are not checked a second time -
            // the `lu` case above already round-tripped exactly these - so what is left to establish is
            // that the system came out right. The first version ran the L*U check here as well AND fed
            // it `rhs`, which is the TRIANGULAR system's right-hand sides, so a correct solve was
            // reported wrong against a system it was never asked: measured 2026-10-01, the answer
            // (4,5,9)-shaped was compared with the (2,7,6)-shaped array.
            CharonMPSMatrixSolveSystemCheck("lu-solve-system", spd, luRhs, answer, 3, 2, 1.0);
        }
    }

    printf("compared %lu mismatches %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);
    return 0;
}