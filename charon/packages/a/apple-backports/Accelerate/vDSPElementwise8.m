// The elementwise vDSP entry points iOS 8.0 added, over the release's own vDSP.
//
// Measured from the release's armv7 caches, iOS 8.0 is the first held release that exports vDSP_vaddsub,
// vDSP_vaddsubD, vDSP_vrampmulD, vDSP_vrampmul2D, vDSP_vrampmuladdD, vDSP_vrampmuladd2D, vDSP_vswmax,
// vDSP_vswmaxD, vDSP_vsmsmaD, vDSP_dotpr2D, vDSP_distancesqD, vDSP_zvmaD and vDSP_zvmmaaD, and neither 7.1.2
// nor any earlier one does, so this file holds the API of exactly one release. The vDSP of 9.3 and 16.0
// is the multiple-biquad filter's own setters, in vDSPBiquadm9.m and vDSPBiquadm16.m.
//
// Every answer is the host's own vDSP, measured case by case by tests/backports/host/vdsp and recorded
// in facts/Accelerate/vDSP.md, including the two places the operation is not the one the operation's
// name reads as, and the two where a caller has to know how much buffer the function reads and writes.

#import "CharonVDSPKernel.h"
#include <math.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

// O0 = I0 + I1 and O1 = I1 - I0, in one pass over two outputs. The second is the second operand minus
// the first, not the other way round: the host's vDSP_vaddsub of [1..6] and [0.5,-0.5,1,-1,2,-2] answers
// 1.5 1.5 4 3 7 4 and -0.5 -2.5 -2 -5 -3 -8, and -0.5 is 0.5 - 1 (facts/Accelerate/vDSP.md).
#define CHARON_VDSP_ADDSUB(Kind, Suffix)                                                                            \
    void vDSP_vaddsub##Suffix(const Kind *__I0, vDSP_Stride __I0S, const Kind *__I1, vDSP_Stride __I1S,            \
                              Kind *__O0, vDSP_Stride __O0S, Kind *__O1, vDSP_Stride __O1S, vDSP_Length __N)           \
    {                                                                                                              \
        for (vDSP_Length n = 0; n < __N; n++) {                                                                    \
            __O0[n * __O0S] = __I0[n * __I0S] + __I1[n * __I1S];                                                    \
            __O1[n * __O1S] = __I1[n * __I1S] - __I0[n * __I0S];                                                    \
        }                                                                                                          \
    }

CHARON_VDSP_ADDSUB(float, )
CHARON_VDSP_ADDSUB(double, D)

// The ramp: O[n] = I[n] * (ramp[n]), where ramp[n] = *Start + n * *Step, and *Start is left at where the
// ramp ended. The host leaves it at *Start + N * *Step, not at the last value it used: over five
// elements with a start of 1 and a step of 2 the answers are 1 6 15 28 45 and Start comes back as 11
// (facts/Accelerate/vDSP.md). The "add" forms accumulate into the output instead of overwriting it, and
// the two-output forms walk one ramp across two inputs.
#define CHARON_VDSP_RAMP(Kind, Suffix)                                                                              \
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

CHARON_VDSP_RAMP(double, D)

// C[n] is the greatest of the WindowLength elements of A that begin at n, so the window runs forward
// from n and not around it. vDSP's header says so and says what the buffers must hold: A must contain
// N + WindowLength - 1 elements and C must have room for N + WindowLength - 1, of which the first N are
// the answers, A and C may not overlap, and the window must be positive. Measured: over
// [3,1,4,1,5,9,2] with N = 7 and a window of 3 the host answers 4 4 5 9 9 and then reads past what a
// seven-element buffer holds, which is that last requirement and not a different window (facts/
// Accelerate/vDSP.md). A window of 1 answers A itself, as the same header says it must.
#define CHARON_VDSP_SLIDING_WINDOW_MAXIMUM(Kind, Suffix)                                                           \
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

CHARON_VDSP_SLIDING_WINDOW_MAXIMUM(float, )
CHARON_VDSP_SLIDING_WINDOW_MAXIMUM(double, D)

// E[n] = A[n] * B[0] + C[n] * D[0]: the single-precision vDSP_vsmsma of iOS 6.0 is on the release already,
// and this is its double form. B and D are both scalars - neither has a stride parameter, which is the
// header saying that one element is the whole of it, and its own pseudocode prints B[0] and D[0]. The
// host's answers say the same, and say it for a D that is not constant, which is the case a constant D
// cannot: over A = [1,2,3,4], B = [2,7,7,7], C = [10,20,30,40] and D = [0.5,99,99,99] the host answers
// 7 14 21 28, which is A * 2 + C * 0.5. Reading D as a vector would answer 7 1994 2991 3988, and the
// one-element D the header tells a caller to pass would be read out of bounds (facts/Accelerate/vDSP.md).
void vDSP_vsmsmaD(const double *__A, vDSP_Stride __IA, const double *__B, const double *__C, vDSP_Stride __IC,
                  const double *__D, double *__E, vDSP_Stride __IE, vDSP_Length __N)
{
    double scale = __B[0], weight = __D[0];
    for (vDSP_Length n = 0; n < __N; n++) {
        __E[n * __IE] = __A[n * __IA] * scale + __C[n * __IC] * weight;
    }
}

// C0 = A0 . B and C1 = A1 . B, two dot products over one vector, in one pass. The host's answer over
// A0 = [1,2,3,4], A1 = [1,0,0,1] and B = [5,6,7,8] is 70 and 13, which is the two dot products.
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

// C = the sum of the squares of the differences, A and B read with their own strides. The host answers
// 25 for A = [1,2,3] and B = [4,6,3], whose differences are -3, -4 and 0.
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

// D = A * B + C and F = A * B + C * D + E in double, the same two operations the 7.0 file carries in
// single, from the one body both precisions are written from.
void vDSP_zvmaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA, const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                const DSPDoubleSplitComplex *__C, vDSP_Stride __IC, const DSPDoubleSplitComplex *__D, vDSP_Stride __ID,
                vDSP_Length __N)
{
    charon_vdsp_split_vma_d((DSPDoubleSplitComplex *)__D, __ID, __A, __IA, __B, __IB, __C, __IC, __N);
}

void vDSP_zvmmaaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA, const DSPDoubleSplitComplex *__B,
                  vDSP_Stride __IB, const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                  const DSPDoubleSplitComplex *__D, vDSP_Stride __ID, const DSPDoubleSplitComplex *__E, vDSP_Stride __IE,
                  const DSPDoubleSplitComplex *__F, vDSP_Stride __IF, vDSP_Length __N)
{
    charon_vdsp_split_vmmaa_d((DSPDoubleSplitComplex *)__F, __IF, __A, __IA, __B, __IB, __C, __IC, __D, __ID, __E,
                               __IE, __N);
}
