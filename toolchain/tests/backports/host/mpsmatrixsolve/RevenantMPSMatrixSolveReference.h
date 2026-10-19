#pragma once

#import <Foundation/Foundation.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

extern NSUInteger gCompared;
extern NSUInteger gMismatches;

static inline double RevenantMPSMatrixSolveOneUlp(double want)
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

static void RevenantMPSMatrixSolveProduct(const float *a, const float *b, float *out,
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

typedef struct {
    float *a, *b, *c;
} RevenantMPSMatrixScratch;

static inline BOOL RevenantMPSMatrixScratchTake(RevenantMPSMatrixScratch *scratch, NSUInteger order)
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

static inline void RevenantMPSMatrixScratchGive(RevenantMPSMatrixScratch *scratch)
{
    free(scratch->a); free(scratch->b); free(scratch->c);
    scratch->a = scratch->b = scratch->c = NULL;
}

static void RevenantMPSMatrixSolveCholeskyCheck(const char *name, const float *source, const float *factor,
                                               NSUInteger order, BOOL lower, int status)
{
    if (status != 0) {
        gCompared++;
        if (status != -3) {
            gMismatches++;
            printf("MISMATCH %s status %d, and the header's non-positive-definite is -3\n", name, status);
        }
        return;
    }
    RevenantMPSMatrixScratch scratch;
    if (!RevenantMPSMatrixScratchTake(&scratch, order)) {
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
        RevenantMPSMatrixSolveProduct(factor, transposeOfFactor, product, order, order);
    else
        RevenantMPSMatrixSolveProduct(transposeOfFactor, factor, product, order, order);
    for (NSUInteger i = 0; i < order * order; i++) {
        gCompared++;
        double want = (double)source[i], got = (double)product[i];
        if (fabs(got - want) > RevenantMPSMatrixSolveOneUlp(want)) {
            gMismatches++;
            printf("MISMATCH %s L*L**T element %lu: product %0.9g source %0.9g\n", name, (unsigned long)i, got, want);
        }
    }
    RevenantMPSMatrixScratchGive(&scratch);
}

static void RevenantMPSMatrixSolveLUCheck(const char *name, const float *source, const float *factor,
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
    RevenantMPSMatrixScratch scratch;
    if (!RevenantMPSMatrixScratchTake(&scratch, order)) {
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
                lower[row * order + column] = (row == column) ? 1.0f : 0.0f;
            if (column >= row)
                upper[row * order + column] = factor[row * order + column];
            else
                upper[row * order + column] = 0.0f;
        }
    RevenantMPSMatrixSolveProduct(lower, upper, product, order, order);
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
            if (fabs(got - want) > RevenantMPSMatrixSolveOneUlp(want)) {
                gMismatches++;
                printf("MISMATCH %s L*U at (%lu,%lu): product %0.9g, source row %lu %0.9g\n", name,
                       (unsigned long)step, (unsigned long)column, got, (unsigned long)sourceRow, want);
            }
        }
    }
    RevenantMPSMatrixScratchGive(&scratch);
}

static void RevenantMPSMatrixSolveSystemCheck(const char *name, const float *coefficient, const float *b,
                                            const float *x, NSUInteger order, NSUInteger sides, double alpha)
{
    RevenantMPSMatrixScratch scratch;
    if (!RevenantMPSMatrixScratchTake(&scratch, order)) {
        gCompared++;
        gMismatches++;
        printf("MISMATCH %s: no memory for a %lux%lu reference\n", name, (unsigned long)order, (unsigned long)order);
        return;
    }
    float *product = scratch.c;
    RevenantMPSMatrixSolveProduct(coefficient, x, product, order, sides);
    for (NSUInteger row = 0; row < order; row++)
        for (NSUInteger side = 0; side < sides; side++) {
            gCompared++;
            double want = alpha * (double)b[row * sides + side], got = (double)product[row * sides + side];
            if (fabs(got - want) > RevenantMPSMatrixSolveOneUlp(want)) {
                gMismatches++;
                printf("MISMATCH %s A*X at (%lu,%lu): product %0.9g, alpha*B %0.9g\n", name,
                       (unsigned long)row, (unsigned long)side, got, want);
            }
        }
    RevenantMPSMatrixScratchGive(&scratch);
}
