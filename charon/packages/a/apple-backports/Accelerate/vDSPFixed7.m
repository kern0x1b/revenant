// The elementwise vDSP entry points iOS 7.0 added, over the release's own vDSP.
//
// Measured from the release's armv7 caches, iOS 7.0 is the first held release that exports vDSP_vaddi,
// vDSP_vflt24, vDSP_vfltu24, vDSP_vfltsm24, vDSP_vfltsmu24, vDSP_vsmfix24, vDSP_vsmfixu24, vDSP_zvma and
// vDSP_zvmmaa, and no earlier one does (4.3, 5.1.1, 6.0 and 6.1.3 name none of the nine), so this file
// holds the API of exactly one release and the band machinery places it there. The rest of iOS 7.0's
// vDSP - the multiple-biquad filter and the double-precision DFT - is in vDSPBiquadm7.m and vDSPDFT7.m.
//
// Every answer is the host's own vDSP, measured case by case by tests/backports/host/vdsp and recorded
// in facts/Accelerate/vDSP.md, including the two places the operation vDSP's header documents is not
// the one it performs.

#import "CharonVDSPKernel.h"
#include <math.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

// A 24-bit value is three bytes, least significant first, in a struct of its own (vDSP.h). The signed
// one is sign-extended from bit 23, the unsigned one is not: the host's vDSP_vflt24 of 8388607,
// -8388608 and -12345 answers 8388607, -8388608 and -12345, and its vDSP_vfltu24 of the same three as
// unsigned answers 8388607, 8388608 and 16777215, so the two readers differ only in the sign bit.
static long charon_int24(const vDSP_int24 *value, vDSP_Stride stride, vDSP_Length at)
{
    long raw = (long)value[at * stride].bytes[0] | ((long)value[at * stride].bytes[1] << 8) |
               ((long)value[at * stride].bytes[2] << 16);
    return (raw & 0x800000L) ? raw | ~0xffffffL : raw;
}

static unsigned long charon_uint24(const vDSP_uint24 *value, vDSP_Stride stride, vDSP_Length at)
{
    return (unsigned long)value[at * stride].bytes[0] | ((unsigned long)value[at * stride].bytes[1] << 8) |
           ((unsigned long)value[at * stride].bytes[2] << 16);
}

// C = B[0] * (float)A[n], the scale a single-precision B is read at: the two functions take a B with no
// stride, so B[0] is the whole of it. Measured with B[0] of 2 over the six values of the differential:
// the signed reader answers 0 2 -2 16777214 -16777216 -24690, which is twice the plain conversion, and
// the unsigned reader the same over its own range; with B[0] of -1 the unsigned reader answers
// -0 -1 -8388607 -8388608 -16777215 -12345, so the scale is applied as it stands and nothing is clamped.
void vDSP_vfltsm24(const vDSP_int24 *__A, vDSP_Stride __IA, const float *__B, float *__C, vDSP_Stride __IC,
                   vDSP_Length __N)
{
    float scale = __B[0];
    for (vDSP_Length n = 0; n < __N; n++) {
        __C[n * __IC] = scale * (float)charon_int24(__A, __IA, n);
    }
}

void vDSP_vfltsmu24(const vDSP_uint24 *__A, vDSP_Stride __IA, const float *__B, float *__C, vDSP_Stride __IC,
                    vDSP_Length __N)
{
    float scale = __B[0];
    for (vDSP_Length n = 0; n < __N; n++) {
        __C[n * __IC] = scale * (float)charon_uint24(__A, __IA, n);
    }
}

// C[n] = (float)A[n], no scale: the plain conversion of each of the two readers.
void vDSP_vflt24(const vDSP_int24 *__A, vDSP_Stride __IA, float *__C, vDSP_Stride __IC, vDSP_Length __N)
{
    for (vDSP_Length n = 0; n < __N; n++) {
        __C[n * __IC] = (float)charon_int24(__A, __IA, n);
    }
}

void vDSP_vfltu24(const vDSP_uint24 *__A, vDSP_Stride __IA, float *__C, vDSP_Stride __IC, vDSP_Length __N)
{
    for (vDSP_Length n = 0; n < __N; n++) {
        __C[n * __IC] = (float)charon_uint24(__A, __IA, n);
    }
}

// C[n] = trunc(A[n] * B[0]) with no scale of its own, and the result clamped into the range of the
// destination. The host's answers say both the clamp and the rounding: with B[0] of 8388608 over
// 1, -1, 0.5, -0.5, 2/3 and 100 the signed reader answers 8388607 -8388608 4194304 -4194304 5592405
// 8388607, so a positive overflow stops at 8388607, a negative one reaches -8388608 exactly, and 2/3
// truncates down to 5592405. The unsigned reader over the same six answers 8388608 0 4194304 0 5592405
// 16777215, so a negative result becomes 0 rather than wrapping.
void vDSP_vsmfix24(const float *__A, vDSP_Stride __IA, const float *__B, vDSP_int24 *__C, vDSP_Stride __IC,
                   vDSP_Length __N)
{
    float scale = __B[0];
    for (vDSP_Length n = 0; n < __N; n++) {
        double truncated = truncf(__A[n * __IA] * scale);
        long value;
        if (truncated >= 8388607.0) {
            value = 8388607;
        } else if (truncated <= -8388608.0) {
            value = -8388608;
        } else {
            value = (long)truncated;
        }
        vDSP_int24 *out = &__C[n * __IC];
        out->bytes[0] = (unsigned char)(value & 0xff);
        out->bytes[1] = (unsigned char)((value >> 8) & 0xff);
        out->bytes[2] = (unsigned char)((value >> 16) & 0xff);
    }
}

void vDSP_vsmfixu24(const float *__A, vDSP_Stride __IA, const float *__B, vDSP_uint24 *__C, vDSP_Stride __IC,
                    vDSP_Length __N)
{
    float scale = __B[0];
    for (vDSP_Length n = 0; n < __N; n++) {
        double truncated = truncf(__A[n * __IA] * scale);
        unsigned long value;
        if (truncated >= 16777215.0) {
            value = 16777215;
        } else if (truncated <= 0.0) {
            value = 0;
        } else {
            value = (unsigned long)truncated;
        }
        vDSP_uint24 *out = &__C[n * __IC];
        out->bytes[0] = (unsigned char)(value & 0xff);
        out->bytes[1] = (unsigned char)((value >> 8) & 0xff);
        out->bytes[2] = (unsigned char)((value >> 16) & 0xff);
    }
}

// C = A + B over ints, the plain vector add of vDSP's int family.
void vDSP_vaddi(const int *__A, vDSP_Stride __IA, const int *__B, vDSP_Stride __IB, int *__C, vDSP_Stride __IC,
                vDSP_Length __N)
{
    for (vDSP_Length n = 0; n < __N; n++) {
        __C[n * __IC] = __A[n * __IA] + __B[n * __IB];
    }
}

// D = A * B + C and F = A * B + C * D + E, the split-complex operations, in the one place both
// precisions are written.
void vDSP_zvma(const DSPSplitComplex *__A, vDSP_Stride __IA, const DSPSplitComplex *__B, vDSP_Stride __IB,
               const DSPSplitComplex *__C, vDSP_Stride __IC, const DSPSplitComplex *__D, vDSP_Stride __ID,
               vDSP_Length __N)
{
    charon_vdsp_split_vma_f((DSPSplitComplex *)__D, __ID, __A, __IA, __B, __IB, __C, __IC, __N);
}

void vDSP_zvmmaa(const DSPSplitComplex *__A, vDSP_Stride __IA, const DSPSplitComplex *__B, vDSP_Stride __IB,
                 const DSPSplitComplex *__C, vDSP_Stride __IC, const DSPSplitComplex *__D, vDSP_Stride __ID,
                 const DSPSplitComplex *__E, vDSP_Stride __IE, const DSPSplitComplex *__F, vDSP_Stride __IF,
                 vDSP_Length __N)
{
    charon_vdsp_split_vmmaa_f((DSPSplitComplex *)__F, __IF, __A, __IA, __B, __IB, __C, __IC, __D, __ID, __E, __IE,
                              __N);
}
