#import "CharonVDSPKernel.h"
#include <math.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

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

void vDSP_vaddi(const int *__A, vDSP_Stride __IA, const int *__B, vDSP_Stride __IB, int *__C, vDSP_Stride __IC,
                vDSP_Length __N)
{
    for (vDSP_Length n = 0; n < __N; n++) {
        __C[n * __IC] = __A[n * __IA] + __B[n * __IB];
    }
}

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
