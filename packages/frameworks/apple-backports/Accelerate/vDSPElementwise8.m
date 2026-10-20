#import "RevenantVDSPKernel.h"
#include <math.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

#define REVENANT_VDSP_ADDSUB(Kind, Suffix)                                                                            \
    void vDSP_vaddsub##Suffix(const Kind *__I0, vDSP_Stride __I0S, const Kind *__I1, vDSP_Stride __I1S,            \
                              Kind *__O0, vDSP_Stride __O0S, Kind *__O1, vDSP_Stride __O1S, vDSP_Length __N)           \
    {                                                                                                              \
        for (vDSP_Length n = 0; n < __N; n++) {                                                                    \
            __O0[n * __O0S] = __I0[n * __I0S] + __I1[n * __I1S];                                                    \
            __O1[n * __O1S] = __I1[n * __I1S] - __I0[n * __I0S];                                                    \
        }                                                                                                          \
    }

REVENANT_VDSP_ADDSUB(float, )
REVENANT_VDSP_ADDSUB(double, D)

#define REVENANT_VDSP_RAMP(Kind, Suffix)                                                                              \
    void vDSP_vrampmul##Suffix(const Kind *__I, vDSP_Stride __IS, Kind *__Start, const Kind *__Step, Kind *__O,        \
                               vDSP_Stride __OS, vDSP_Length __N)                                                   \
    {                                                                                                              \
        Kind ramp = *__Start;                                                                                      \
        for (vDSP_Length n = 0; n < __N; n++) {                                                                    \
            __O[n * __OS] = __I[n * __IS] * ramp;                                                                   \
            ramp += *__Step;                                                                                        \
        }                                                                                                          \
        *__Start = ramp;                                                                                            \
    }                                                                                                              \
                                                                                                                   \
    void vDSP_vrampmuladd##Suffix(const Kind *__I, vDSP_Stride __IS, Kind *__Start, const Kind *__Step, Kind *__O,   \
                                  vDSP_Stride __OS, vDSP_Length __N)                                                \
    {                                                                                                              \
        Kind ramp = *__Start;                                                                                      \
        for (vDSP_Length n = 0; n < __N; n++) {                                                                    \
            __O[n * __OS] += __I[n * __IS] * ramp;                                                                  \
            ramp += *__Step;                                                                                        \
        }                                                                                                          \
        *__Start = ramp;                                                                                            \
    }                                                                                                              \
                                                                                                                   \
    void vDSP_vrampmul2##Suffix(const Kind *__I0, const Kind *__I1, vDSP_Stride __IS, Kind *__Start,                  \
                                const Kind *__Step, Kind *__O0, Kind *__O1, vDSP_Stride __OS, vDSP_Length __N)        \
    {                                                                                                              \
        Kind ramp = *__Start;                                                                                      \
        for (vDSP_Length n = 0; n < __N; n++) {                                                                    \
            __O0[n * __OS] = __I0[n * __IS] * ramp;                                                                 \
            __O1[n * __OS] = __I1[n * __IS] * ramp;                                                                 \
            ramp += *__Step;                                                                                        \
        }                                                                                                          \
        *__Start = ramp;                                                                                            \
    }                                                                                                              \
                                                                                                                   \
    void vDSP_vrampmuladd2##Suffix(const Kind *__I0, const Kind *__I1, vDSP_Stride __IS, Kind *__Start,               \
                                   const Kind *__Step, Kind *__O0, Kind *__O1, vDSP_Stride __OS, vDSP_Length __N)     \
    {                                                                                                              \
        Kind ramp = *__Start;                                                                                      \
        for (vDSP_Length n = 0; n < __N; n++) {                                                                    \
            __O0[n * __OS] += __I0[n * __IS] * ramp;                                                                \
            __O1[n * __OS] += __I1[n * __IS] * ramp;                                                                \
            ramp += *__Step;                                                                                        \
        }                                                                                                          \
        *__Start = ramp;                                                                                            \
    }

REVENANT_VDSP_RAMP(double, D)

#define REVENANT_VDSP_SLIDING_WINDOW_MAXIMUM(Kind, Suffix)                                                           \
    void vDSP_vswmax##Suffix(const Kind *__A, vDSP_Stride __IA, Kind *__C, vDSP_Stride __IC, vDSP_Length __N,          \
                             vDSP_Length __WindowLength)                                                            \
    {                                                                                                              \
        for (vDSP_Length n = 0; n < __N; n++) {                                                                    \
            Kind best = __A[n * __IA];                                                                             \
            for (vDSP_Length w = 1; w < __WindowLength; w++) {                                                     \
                Kind candidate = __A[(n + w) * __IA];                                                              \
                if (candidate > best) {                                                                            \
                    best = candidate;                                                                              \
                }                                                                                                  \
            }                                                                                                      \
            __C[n * __IC] = best;                                                                                  \
        }                                                                                                          \
    }

REVENANT_VDSP_SLIDING_WINDOW_MAXIMUM(float, )
REVENANT_VDSP_SLIDING_WINDOW_MAXIMUM(double, D)

void vDSP_vsmsmaD(const double *__A, vDSP_Stride __IA, const double *__B, const double *__C, vDSP_Stride __IC,
                  const double *__D, double *__E, vDSP_Stride __IE, vDSP_Length __N)
{
    double scale = __B[0], weight = __D[0];
    for (vDSP_Length n = 0; n < __N; n++) {
        __E[n * __IE] = __A[n * __IA] * scale + __C[n * __IC] * weight;
    }
}

void vDSP_dotpr2D(const double *__A0, vDSP_Stride __IA0, const double *__A1, vDSP_Stride __IA1, const double *__B,
                  vDSP_Stride __IB, double *__C0, double *__C1, vDSP_Length __N)
{
    double first = 0.0, second = 0.0;
    for (vDSP_Length n = 0; n < __N; n++) {
        double b = __B[n * __IB];
        first += __A0[n * __IA0] * b;
        second += __A1[n * __IA1] * b;
    }
    *__C0 = first;
    *__C1 = second;
}

void vDSP_distancesqD(const double *__A, vDSP_Stride __IA, const double *__B, vDSP_Stride __IB, double *__C,
                      vDSP_Length __N)
{
    double sum = 0.0;
    for (vDSP_Length n = 0; n < __N; n++) {
        double difference = __A[n * __IA] - __B[n * __IB];
        sum += difference * difference;
    }
    *__C = sum;
}

void vDSP_zvmaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA, const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                const DSPDoubleSplitComplex *__C, vDSP_Stride __IC, const DSPDoubleSplitComplex *__D, vDSP_Stride __ID,
                vDSP_Length __N)
{
    revenant_vdsp_split_vma_d((DSPDoubleSplitComplex *)__D, __ID, __A, __IA, __B, __IB, __C, __IC, __N);
}

void vDSP_zvmmaaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA, const DSPDoubleSplitComplex *__B,
                  vDSP_Stride __IB, const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                  const DSPDoubleSplitComplex *__D, vDSP_Stride __ID, const DSPDoubleSplitComplex *__E, vDSP_Stride __IE,
                  const DSPDoubleSplitComplex *__F, vDSP_Stride __IF, vDSP_Length __N)
{
    revenant_vdsp_split_vmmaa_d((DSPDoubleSplitComplex *)__F, __IF, __A, __IA, __B, __IB, __C, __IC, __D, __ID, __E,
                               __IE, __N);
}
