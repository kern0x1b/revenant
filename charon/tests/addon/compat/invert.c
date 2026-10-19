#include <simd/simd.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

simd_float2x2 charon_invert_f2(simd_float2x2);
simd_float3x3 charon_invert_f3(simd_float3x3);
simd_float4x4 charon_invert_f4(simd_float4x4);
simd_double2x2 charon_invert_d2(simd_double2x2);
simd_double3x3 charon_invert_d3(simd_double3x3);
simd_double4x4 charon_invert_d4(simd_double4x4);

static int fails;
static uint64_t seed = 12345;

static double next(void)
{
    seed = seed * 6364136223846793005ULL + 1442695040888963407ULL;
    return ((seed >> 33) / (double)(1ULL << 31)) * 4 - 2;
}

static int same(double ours, double system, double scale, double tolerance)
{
    if (isnan(system) || isnan(ours)) {
        return isnan(system) && isnan(ours);
    }
    if (isinf(system) || isinf(ours)) {
        return ours == system;
    }
    return fabs(ours - system) <= tolerance * scale;
}

#define CASES(N, T, MATRIX, TAG, TOLERANCE)                                                                          \
static void check_##TAG(void)                                                                                        \
{                                                                                                                    \
    for (int trial = 0; trial < 2000; trial++) {                                                                     \
        MATRIX x;                                                                                                    \
        for (int c = 0; c < N; c++) for (int r = 0; r < N; r++) x.columns[c][r] = (T)(next() + (c == r ? 5 * N : 0));\
        MATRIX system = __invert_##TAG(x), ours = charon_invert_##TAG(x);                                            \
        double scale = 0;                                                                                            \
        for (int c = 0; c < N; c++) for (int r = 0; r < N; r++) scale = fmax(scale, fabs((double)system.columns[c][r]));\
        for (int c = 0; c < N; c++) for (int r = 0; r < N; r++) {                                                    \
            if (!same(ours.columns[c][r], system.columns[c][r], scale, TOLERANCE)) {                                 \
                printf("FAIL  __invert_" #TAG " answers %g where the system's answers %g at column %d row %d of a "   \
                       "matrix with an inverse\n", (double)ours.columns[c][r], (double)system.columns[c][r], c, r);   \
                fails++;                                                                                             \
                return;                                                                                              \
            }                                                                                                        \
        }                                                                                                            \
    }                                                                                                                \
                                                                                                                     \
    MATRIX singular, none;                                                                                           \
    for (int c = 0; c < N; c++) for (int r = 0; r < N; r++) {                                                        \
        singular.columns[c][r] = (T)((r + 1) * (c + 1));                                                              \
        none.columns[c][r] = 0;                                                                                      \
    }                                                                                                                \
    MATRIX one[2] = {singular, none};                                                                                \
    for (int which = 0; which < 2; which++) {                                                                        \
        MATRIX system = __invert_##TAG(one[which]), ours = charon_invert_##TAG(one[which]);                          \
        for (int c = 0; c < N; c++) for (int r = 0; r < N; r++) {                                                    \
            if (!same(ours.columns[c][r], system.columns[c][r], 1, TOLERANCE)) {                                     \
                printf("FAIL  __invert_" #TAG " answers %g where the system's answers %g at column %d row %d of "    \
                       "%s\n", (double)ours.columns[c][r], (double)system.columns[c][r], c, r,                       \
                       which ? "the null matrix" : "a matrix with no inverse");                                      \
                fails++;                                                                                             \
                return;                                                                                              \
            }                                                                                                        \
        }                                                                                                            \
    }                                                                                                                \
}
CASES(2, float, simd_float2x2, f2, 2e-6)
CASES(3, float, simd_float3x3, f3, 2e-6)
CASES(4, float, simd_float4x4, f4, 2e-6)
CASES(2, double, simd_double2x2, d2, 1e-13)
CASES(3, double, simd_double3x3, d3, 1e-13)
CASES(4, double, simd_double4x4, d4, 1e-13)

int main(void)
{
    check_f2();
    check_f3();
    check_f4();
    check_d2();
    check_d3();
    check_d4();
    return fails != 0;
}
