// CharonMPSMatrixSolveReference.h - the reference the MPSMatrix solve and decomposition kernels are
// checked against, in plain C.
//
// WHAT THE REFERENCE IS, and what it is not. It is the headers' own statements turned into arithmetic:
//   MPSMatrixDecomposition.h:138-143  the Cholesky forms A = L * L**T and A = U**T * U, for a symmetric positive-definite A,
//                                      with L and U the lower and upper triangles
//   MPSMatrixSolve.h:24-26            the triangular solves op(A) times X equal to alpha times B and X times op(A) equal to alpha times B, with A on one
//                                      triangle and op(A) its transpose or itself
//   MPSMatrixDecomposition.h:37-40    the four statuses, with the header's own values
// It never names the port's class, so a case that agrees is two implementations of one sentence and not
// one implementation compared with itself.
//
// THE ORACLE IS A ROUND TRIP, and that is the reason this family can be checked at all. This host's AGX
// family lacks computeCommandEncoderWithDispatchType: and the release's own kernel dies encoding, so
// the release is not the oracle and no number here measures Apple's code. What CAN be checked without it
// is the identity each header states: a factorization is right when multiplying its factors back gives
// the matrix that went in, and a solve is right when multiplying its answer by A gives B. Both are
// statements about the ANSWER, not about the release's pivot order or its rounding, and both are exact
// to a float32 ulp on the values chosen in the cases.
//
// WHAT IS NOT CLAIMED: the pivot INDICES. MPSMatrixDecomposition.h:92-94 says the pivot array holds
// "an array of size 1xmin(rows, columns) values" and says nothing about which row is chosen, so the
// indices are this port's choice (partial pivoting) and the reference does not check them. The factors
// do not depend on that choice - only the order of the rows does - which is exactly why the round trip
// is the right check and an index comparison would not be.
#pragma once

#import <Foundation/Foundation.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

extern NSUInteger gCompared;
extern NSUInteger gMismatches;

// One whole float32 ulp of `want`, the bound the dividing kernels are held to.
static inline double CharonMPSMatrixSolveOneUlp(double want)
{
    if (want == 0.0)
        return 0.0;
    float f = (float)want;
    uint32_t bits;
    memcpy(&bits, &f, sizeof bits);
    bits += (bits & 0x80000000u) ? 0xFFFFFFFFu : 1u;
    float next;
    memcpy(&next, &bits, sizeof next);
    double bound = (double)next - (double)f;
    return bound < 0.0 ? -bound : bound;
}

// Multiply `a` (order x order, row-major) by `b` (order x columns, row-major) into `out`. The plain
// product both round trips are built from, written here so the check does not call the port's own
// multiply - MPSMatrixVectorMultiplication11.m reaches the answer under its own name.
static void CharonMPSMatrixSolveProduct(const float *a, const float *b, float *out,
                                        NSUInteger order, NSUInteger columns)
{
    for (NSUInteger row = 0; row < order; row++)
        for (NSUInteger column = 0; column < columns; column++) {
            double sum = 0.0;
            for (NSUInteger k = 0; k < order; k++)
                sum += (double)a[row * order + k] * (double)b[k * columns + column];
            out[row * columns + column] = (float)sum;
        }
}

// The reference's scratch space, SIZED FROM THE ORDER rather than fixed. It was four 64x64 stack
// buffers, measured 2026-10-01: under an order of 65 the comparison indexed past its own end, and what
// it read there could agree by accident. A buffer that cannot hold the order refuses instead.
typedef struct {
    float *a, *b, *c;
} CharonMPSMatrixScratch;

static inline BOOL CharonMPSMatrixScratchTake(CharonMPSMatrixScratch *scratch, NSUInteger order)
{
    size_t each = order * order * sizeof(float);
    scratch->a = calloc(each ? each : 1, 1);
    scratch->b = calloc(each ? each : 1, 1);
    scratch->c = calloc(each ? each : 1, 1);
    if (!scratch->a || !scratch->b || !scratch->c) {
        free(scratch->a); free(scratch->b); free(scratch->c);
        scratch->a = scratch->b = scratch->c = NULL;
        return NO;
    }
    return YES;
}

static inline void CharonMPSMatrixScratchGive(CharonMPSMatrixScratch *scratch)
{
    free(scratch->a); free(scratch->b); free(scratch->c);
    scratch->a = scratch->b = scratch->c = NULL;
}

// The Cholesky round trip: A = L*L**T for the lower factor and A = U**T*U for the upper one
// (MPSMatrixDecomposition.h:138-139), so the ORDER of the two products is what `lower` decides - not the
// triangle that is read. The first version of this check always multiplied the stored factor by its own
// transpose, which is right for L and wrong for U: measured 2026-10-01, the upper case answered
// 6, 2.68, 2.45 on the diagonal of A where the source has 4, 5, 6.
//
// The stored matrix is read EXACTLY as the kernel wrote it. An earlier version reassembled a
// unit-diagonal lower triangle from the stored values, which is wrong: MPSMatrixDecompositionCholesky
// writes L's diagonal entries themselves (the sqrt of what is left after the row's own squares), and
// only MPSMatrixSolveTriangular's `unit` parameter (MPSMatrixSolve.h:50-52) ever means a diagonal of
// ones.
static void CharonMPSMatrixSolveCholeskyCheck(const char *name, const float *source, const float *factor,
                                               NSUInteger order, BOOL lower, int status)
{
    if (status != 0) {
        // A non-success status is not an answer to check, it IS the answer, and it is checked for being
        // the header's own value at MPSMatrixDecomposition.h:37-40.
        gCompared++;
        if (status != -3) {
            gMismatches++;
            printf("MISMATCH %s status %d, and the header's non-positive-definite is -3\n", name, status);
        }
        return;
    }
    CharonMPSMatrixScratch scratch;
    if (!CharonMPSMatrixScratchTake(&scratch, order)) {
        gCompared++;
        gMismatches++;
        printf("MISMATCH %s: no memory for a %lux%lu reference\n", name, (unsigned long)order, (unsigned long)order);
        return;
    }
    float *product = scratch.c;
    float *transposeOfFactor = scratch.b;
    for (NSUInteger row = 0; row < order; row++)
        for (NSUInteger column = 0; column < order; column++)
            transposeOfFactor[row * order + column] = factor[column * order + row];
    if (lower)
        CharonMPSMatrixSolveProduct(factor, transposeOfFactor, product, order, order);
    else
        CharonMPSMatrixSolveProduct(transposeOfFactor, factor, product, order, order);
    for (NSUInteger i = 0; i < order * order; i++) {
        gCompared++;
        double want = (double)source[i], got = (double)product[i];
        if (fabs(got - want) > CharonMPSMatrixSolveOneUlp(want)) {
            gMismatches++;
            printf("MISMATCH %s L*L**T element %lu: product %0.9g source %0.9g\n", name, (unsigned long)i, got, want);
        }
    }
    CharonMPSMatrixScratchGive(&scratch);
}

// The LU round trip: the decomposition stores L BELOW the diagonal and U ON AND ABOVE it in the SAME
// matrix - the combined form MPSMatrixDecompositionLU leaves, whose own :86-91 says the result needs room for a
// rows-by-columns matrix and nothing more. So the two factors have to be SPLIT,
// and multiplying the combined matrix by itself - which is what the first version did - gave 18, 16, 18
// where the source has 4, 5, 6: measured 2026-10-01.
//
// L*U is P*A, NOT A: the factorization permuted the source's rows as it went and the pivot array records
// that order (MPSMatrixDecomposition.h:92-94), so the row at step `s` of the product is the source's row
// PIVOT[s].
static void CharonMPSMatrixSolveLUCheck(const char *name, const float *source, const float *factor,
                                        const float *pivot, NSUInteger order, int status)
{
    if (status != 0) {
        gCompared++;
        if (status != -2) {
            gMismatches++;
            printf("MISMATCH %s status %d, and the header's singular is -2\n", name, status);
        }
        return;
    }
    CharonMPSMatrixScratch scratch;
    if (!CharonMPSMatrixScratchTake(&scratch, order)) {
        gCompared++;
        gMismatches++;
        printf("MISMATCH %s: no memory for a %lux%lu reference\n", name, (unsigned long)order, (unsigned long)order);
        return;
    }
    float *lower = scratch.a, *upper = scratch.b, *product = scratch.c;
    for (NSUInteger row = 0; row < order; row++)
        for (NSUInteger column = 0; column < order; column++) {
            if (column < row)
                lower[row * order + column] = factor[row * order + column];
            else
                lower[row * order + column] = (row == column) ? 1.0f : 0.0f;   // L's unit diagonal
            if (column >= row)
                upper[row * order + column] = factor[row * order + column];
            else
                upper[row * order + column] = 0.0f;
        }
    CharonMPSMatrixSolveProduct(lower, upper, product, order, order);
    for (NSUInteger step = 0; step < order; step++) {
        NSUInteger sourceRow = (NSUInteger)pivot[step];
        if (sourceRow >= order) {
            gCompared++;
            gMismatches++;
            printf("MISMATCH %s pivot %lu is %lu, outside the %lux%lu system\n", name,
                   (unsigned long)step, (unsigned long)sourceRow, (unsigned long)order, (unsigned long)order);
            continue;
        }
        for (NSUInteger column = 0; column < order; column++) {
            gCompared++;
            double want = (double)source[sourceRow * order + column];
            double got = (double)product[step * order + column];
            if (fabs(got - want) > CharonMPSMatrixSolveOneUlp(want)) {
                gMismatches++;
                printf("MISMATCH %s L*U at (%lu,%lu): product %0.9g, source row %lu %0.9g\n", name,
                       (unsigned long)step, (unsigned long)column, got, (unsigned long)sourceRow, want);
            }
        }
    }
    CharonMPSMatrixScratchGive(&scratch);
}

// The solve round trip: MPSMatrixSolve.h:24-26 "op(A) * X = alpha * B", so multiplying the answer back by
// the coefficient matrix has to give the right-hand side it was solved from. This is the check that does
// not care which triangle the kernel walked or whether it transposed: if A*X == alpha*B then the system
// was solved.
static void CharonMPSMatrixSolveSystemCheck(const char *name, const float *coefficient, const float *b,
                                            const float *x, NSUInteger order, NSUInteger sides, double alpha)
{
    CharonMPSMatrixScratch scratch;
    if (!CharonMPSMatrixScratchTake(&scratch, order)) {
        gCompared++;
        gMismatches++;
        printf("MISMATCH %s: no memory for a %lux%lu reference\n", name, (unsigned long)order, (unsigned long)order);
        return;
    }
    float *product = scratch.c;
    CharonMPSMatrixSolveProduct(coefficient, x, product, order, sides);
    for (NSUInteger row = 0; row < order; row++)
        for (NSUInteger side = 0; side < sides; side++) {
            gCompared++;
            double want = alpha * (double)b[row * sides + side], got = (double)product[row * sides + side];
            if (fabs(got - want) > CharonMPSMatrixSolveOneUlp(want)) {
                gMismatches++;
                printf("MISMATCH %s A*X at (%lu,%lu): product %0.9g, alpha*B %0.9g\n", name,
                       (unsigned long)row, (unsigned long)side, got, want);
            }
        }
    CharonMPSMatrixScratchGive(&scratch);
}