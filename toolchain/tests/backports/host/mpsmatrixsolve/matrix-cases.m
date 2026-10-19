#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import "RevenantMPSMatrixSolveReference.h"
#include <stdio.h>
#include <string.h>

NSUInteger gCompared = 0;
NSUInteger gMismatches = 0;

static id<MTLDevice> gDevice = nil;

static MPSMatrix *RevenantMakeMatrix(NSUInteger order, NSUInteger columns, MPSDataType dataType, const void *values)
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

static MPSMatrix *RevenantZeros(NSUInteger order, NSUInteger columns, MPSDataType dataType)
{
    size_t bytes = order * columns * MPSSizeofMPSDataType(dataType);
    void *zeroed = calloc(bytes ? bytes : 1, 1);
    MPSMatrix *made = RevenantMakeMatrix(order, columns, dataType, zeroed);
    free(zeroed);
    return made;
}

static id RevenantBuffer(void)
{
    return [gDevice newCommandBuffer];
}

static id<MTLBuffer> RevenantMakeStatusBuffer(void)
{
    return [gDevice newBufferWithLength:sizeof(MPSMatrixDecompositionStatus) options:MTLResourceStorageModeShared];
}

int main(void)
{
    gDevice = MTLCreateSystemDefaultDevice();

    const float spd[9] = {4, 2, 2,
                          2, 5, 1,
                          2, 1, 6};

    const float needsPivot[9] = {0, 2, 1,
                                 3, 4, 5,
                                 6, 7, 8};

    const float lower[9] = {2, 0, 0,
                            1, 3, 0,
                            2, 1, 4};
    const float rhs[6] = {4, 3, 2, 7, 6, 5};

    const float upper[9] = {2, 1, 2,
                            0, 3, 1,
                            0, 0, 4};
    const float upperRhs[3] = {8, 10, 8};

    for (int upperTriangle = 0; upperTriangle < 2; upperTriangle++) {
        MPSMatrixDecompositionCholesky *kernel =
            [[MPSMatrixDecompositionCholesky alloc] initWithDevice:gDevice lower:!upperTriangle order:3];
        MPSMatrix *source = RevenantMakeMatrix(3, 3, MPSDataTypeFloat32, spd);
        MPSMatrix *result = RevenantZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrixDecompositionStatus status = MPSMatrixDecompositionStatusFailure;
        id<MTLBuffer> statusBuffer = RevenantMakeStatusBuffer();
        [kernel encodeToCommandBuffer:RevenantBuffer() sourceMatrix:source resultMatrix:result
                              status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];
        float factor[9];
        memcpy(factor, [result.data contents], sizeof factor);
        RevenantMPSMatrixSolveCholeskyCheck(upperTriangle ? "cholesky-upper" : "cholesky-lower",
                                          spd, factor, 3, !upperTriangle, (int)status);
    }

    {
        const float singular[9] = {0, 1, 1,
                                   1, 1, 1,
                                   1, 1, 1};
        MPSMatrixDecompositionCholesky *kernel =
            [[MPSMatrixDecompositionCholesky alloc] initWithDevice:gDevice lower:YES order:3];
        MPSMatrix *source = RevenantMakeMatrix(3, 3, MPSDataTypeFloat32, singular);
        MPSMatrix *result = RevenantZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrixDecompositionStatus status = 0;
        id<MTLBuffer> statusBuffer = RevenantMakeStatusBuffer();
        [kernel encodeToCommandBuffer:RevenantBuffer() sourceMatrix:source resultMatrix:result
                              status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];
        RevenantMPSMatrixSolveCholeskyCheck("cholesky-not-positive-definite", singular, singular, 3, YES, (int)status);
    }

    {
        MPSMatrixDecompositionLU *kernel = [[MPSMatrixDecompositionLU alloc] initWithDevice:gDevice rows:3 columns:3];
        MPSMatrix *source = RevenantMakeMatrix(3, 3, MPSDataTypeFloat32, spd);
        MPSMatrix *result = RevenantZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrix *pivots = RevenantZeros(1, 3, MPSDataTypeUInt32);
        MPSMatrixDecompositionStatus status = MPSMatrixDecompositionStatusFailure;
        id<MTLBuffer> statusBuffer = RevenantMakeStatusBuffer();
        [kernel encodeToCommandBuffer:RevenantBuffer() sourceMatrix:source resultMatrix:result
                       pivotIndices:pivots status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];
        float factor[9];
        memcpy(factor, [result.data contents], sizeof factor);
        if (pivots.dataType != MPSDataTypeUInt32) {
            printf("CONTRACT the pivot matrix is %d, and MPSMatrixDecomposition.h:94 requires MPSDataTypeUInt32\n",
                   (int)pivots.dataType);
        }
        uint32_t pivotBits[3];
        memcpy(pivotBits, [pivots.data contents], sizeof pivotBits);
        float pivot[3];
        for (int i = 0; i < 3; i++)
            pivot[i] = (float)pivotBits[i];
        RevenantMPSMatrixSolveLUCheck("lu", spd, factor, pivot, 3, (int)status);
    }
    {
        const float rankTwo[9] = {1, 2, 3,
                                  2, 4, 6,
                                  3, 6, 9};
        MPSMatrixDecompositionLU *kernel = [[MPSMatrixDecompositionLU alloc] initWithDevice:gDevice rows:3 columns:3];
        MPSMatrix *source = RevenantMakeMatrix(3, 3, MPSDataTypeFloat32, rankTwo);
        MPSMatrix *result = RevenantZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrix *pivots = RevenantZeros(1, 3, MPSDataTypeUInt32);
        MPSMatrixDecompositionStatus status = 0;
        id<MTLBuffer> statusBuffer = RevenantMakeStatusBuffer();
        [kernel encodeToCommandBuffer:RevenantBuffer() sourceMatrix:source resultMatrix:result
                       pivotIndices:pivots status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];
        RevenantMPSMatrixSolveLUCheck("lu-singular", rankTwo, rankTwo, rankTwo, 3, (int)status);
    }

    {
        MPSMatrixSolveTriangular *kernel =
            [[MPSMatrixSolveTriangular alloc] initWithDevice:gDevice right:NO upper:NO transpose:NO unit:NO
                                                        order:3 numberOfRightHandSides:2 alpha:1.0];
        MPSMatrix *a = RevenantMakeMatrix(3, 3, MPSDataTypeFloat32, lower);
        MPSMatrix *b = RevenantMakeMatrix(3, 2, MPSDataTypeFloat32, rhs);
        MPSMatrix *x = RevenantZeros(3, 2, MPSDataTypeFloat32);
        [kernel encodeToCommandBuffer:RevenantBuffer() sourceMatrix:a rightHandSideMatrix:b
                      solutionMatrix:x];
        float answer[6];
        memcpy(answer, [x.data contents], sizeof answer);
        RevenantMPSMatrixSolveSystemCheck("triangular-lower", lower, rhs, answer, 3, 2, 1.0);
    }
    {
        MPSMatrixSolveTriangular *kernel =
            [[MPSMatrixSolveTriangular alloc] initWithDevice:gDevice right:NO upper:YES transpose:NO unit:NO
                                                        order:3 numberOfRightHandSides:1 alpha:1.0];
        MPSMatrix *a = RevenantMakeMatrix(3, 3, MPSDataTypeFloat32, upper);
        MPSMatrix *b = RevenantMakeMatrix(3, 1, MPSDataTypeFloat32, upperRhs);
        MPSMatrix *x = RevenantZeros(3, 1, MPSDataTypeFloat32);
        [kernel encodeToCommandBuffer:RevenantBuffer() sourceMatrix:a rightHandSideMatrix:b
                      solutionMatrix:x];
        float answer[3];
        memcpy(answer, [x.data contents], sizeof answer);
        RevenantMPSMatrixSolveSystemCheck("triangular-upper", upper, upperRhs, answer, 3, 1, 1.0);
    }
    {
        MPSMatrixSolveTriangular *kernel =
            [[MPSMatrixSolveTriangular alloc] initWithDevice:gDevice right:NO upper:NO transpose:NO unit:NO
                                                        order:3 numberOfRightHandSides:1 alpha:2.0];
        MPSMatrix *a = RevenantMakeMatrix(3, 3, MPSDataTypeFloat32, lower);
        MPSMatrix *b = RevenantMakeMatrix(3, 1, MPSDataTypeFloat32, upperRhs);
        MPSMatrix *x = RevenantZeros(3, 1, MPSDataTypeFloat32);
        [kernel encodeToCommandBuffer:RevenantBuffer() sourceMatrix:a rightHandSideMatrix:b
                      solutionMatrix:x];
        float answer[3];
        memcpy(answer, [x.data contents], sizeof answer);
        RevenantMPSMatrixSolveSystemCheck("triangular-alpha", lower, upperRhs, answer, 3, 1, 2.0);
    }

    {
        const float factorOfSpd[9] = {2, 0, 0,
                                      1, 2, 0,
                                      1, 0, 2.236067977499790f};
        MPSMatrixSolveCholesky *kernel =
            [[MPSMatrixSolveCholesky alloc] initWithDevice:gDevice upper:NO order:3 numberOfRightHandSides:2];
        MPSMatrix *factor = RevenantMakeMatrix(3, 3, MPSDataTypeFloat32, factorOfSpd);
        const float choleskyRhs[6] = {4, 3, 5, 7, 9, 6};
        MPSMatrix *b = RevenantMakeMatrix(3, 2, MPSDataTypeFloat32, choleskyRhs);
        MPSMatrix *x = RevenantZeros(3, 2, MPSDataTypeFloat32);
        [kernel encodeToCommandBuffer:RevenantBuffer() sourceMatrix:factor rightHandSideMatrix:b
                      solutionMatrix:x];
        float answer[6];
        memcpy(answer, [x.data contents], sizeof answer);
        RevenantMPSMatrixSolveSystemCheck("cholesky-solve", spd, choleskyRhs, answer, 3, 2, 1.0);
    }

    {
        MPSMatrixDecompositionLU *decompose = [[MPSMatrixDecompositionLU alloc] initWithDevice:gDevice rows:3 columns:3];
        MPSMatrix *source = RevenantMakeMatrix(3, 3, MPSDataTypeFloat32, spd);
        MPSMatrix *factors = RevenantZeros(3, 3, MPSDataTypeFloat32);
        MPSMatrix *pivots = RevenantZeros(1, 3, MPSDataTypeUInt32);
        MPSMatrixDecompositionStatus status = MPSMatrixDecompositionStatusFailure;
        id<MTLBuffer> statusBuffer = RevenantMakeStatusBuffer();
        [decompose encodeToCommandBuffer:RevenantBuffer() sourceMatrix:source resultMatrix:factors
                           pivotIndices:pivots status:statusBuffer];
        status = *(MPSMatrixDecompositionStatus *)[statusBuffer contents];

        MPSMatrixSolveLU *solve = [[MPSMatrixSolveLU alloc] initWithDevice:gDevice];
        const float luRhs[6] = {4, 3, 5, 7, 9, 6};
        MPSMatrix *b = RevenantMakeMatrix(3, 2, MPSDataTypeFloat32, luRhs);
        MPSMatrix *x = RevenantZeros(3, 2, MPSDataTypeFloat32);
        [solve encodeToCommandBuffer:RevenantBuffer() sourceMatrix:factors rightHandSideMatrix:b
                      pivotIndices:pivots solutionMatrix:x];
        float answer[6];
        memcpy(answer, [x.data contents], sizeof answer);
        float factorValues[9];
        memcpy(factorValues, [factors.data contents], sizeof factorValues);
        float pivotValues[3];
        memcpy(pivotValues, [pivots.data contents], sizeof pivotValues);
        if (status == 0) {
            RevenantMPSMatrixSolveSystemCheck("lu-solve-system", spd, luRhs, answer, 3, 2, 1.0);
        }
    }

    printf("compared %lu mismatches %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);
    return 0;
}
