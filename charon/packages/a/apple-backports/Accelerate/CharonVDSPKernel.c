// The split-complex arithmetic vDSP_zvma, vDSP_zvmaD, vDSP_zvmmaa and vDSP_zvmmaaD are one operation in,
// once for each scalar type. See CharonVDSPKernel.h for why this is its own file.

#import "CharonVDSPKernel.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

// D = A * B + C, and F = A * B + C * D + E: vDSP names the operands in the order they are used with the
// accumulator last, which is what the two measured answers say - vDSP_zvma of (1+5i), (2+0i) and
// (1+1i) answers 3 + 11i, which is A*B + C and neither A + B*C nor A + C*B, and vDSP_zvmmaa of the six
// vectors of tests/backports/host/vdsp/differential.m answers A*B + C*D + E (facts/Accelerate/vDSP.md).
// Every step is narrowed to the type, so a float operation is answered in float.
#define CHARON_VDSP_SPLIT_COMPLEX(Kind, SplitComplex, Suffix)                                                       \
    void charon_vdsp_split_vma_##Suffix(SplitComplex *out, vDSP_Stride out_stride, const SplitComplex *A,            \
                                        vDSP_Stride IA, const SplitComplex *B, vDSP_Stride IB,                       \
                                        const SplitComplex *C, vDSP_Stride IC, vDSP_Length N)                        \
    {                                                                                                              \
        for (vDSP_Length n = 0; n < N; n++) {                                                                      \
            Kind ar = (Kind)A->realp[n * IA], ai = (Kind)A->imagp[n * IA];                                         \
            Kind br = (Kind)B->realp[n * IB], bi = (Kind)B->imagp[n * IB];                                         \
            Kind cr = (Kind)C->realp[n * IC], ci = (Kind)C->imagp[n * IC];                                         \
            out->realp[n * out_stride] = (Kind)(ar * br - ai * bi + cr);                                           \
            out->imagp[n * out_stride] = (Kind)(ar * bi + ai * br + ci);                                           \
        }                                                                                                          \
    }                                                                                                              \
                                                                                                                   \
    void charon_vdsp_split_vmmaa_##Suffix(SplitComplex *out, vDSP_Stride out_stride, const SplitComplex *A,           \
                                          vDSP_Stride IA, const SplitComplex *B, vDSP_Stride IB,                     \
                                          const SplitComplex *C, vDSP_Stride IC, const SplitComplex *D,               \
                                          vDSP_Stride ID, const SplitComplex *E, vDSP_Stride IE, vDSP_Length N)      \
    {                                                                                                              \
        for (vDSP_Length n = 0; n < N; n++) {                                                                      \
            Kind ar = (Kind)A->realp[n * IA], ai = (Kind)A->imagp[n * IA];                                         \
            Kind br = (Kind)B->realp[n * IB], bi = (Kind)B->imagp[n * IB];                                         \
            Kind cr = (Kind)C->realp[n * IC], ci = (Kind)C->imagp[n * IC];                                         \
            Kind dr = (Kind)D->realp[n * ID], di = (Kind)D->imagp[n * ID];                                         \
            Kind er = (Kind)E->realp[n * IE], ei = (Kind)E->imagp[n * IE];                                         \
            out->realp[n * out_stride] = (Kind)(ar * br - ai * bi + cr * dr - ci * di + er);                        \
            out->imagp[n * out_stride] = (Kind)(ar * bi + ai * br + cr * di + ci * dr + ei);                        \
        }                                                                                                          \
    }

CHARON_VDSP_SPLIT_COMPLEX(float, DSPSplitComplex, f)
CHARON_VDSP_SPLIT_COMPLEX(double, DSPDoubleSplitComplex, d)
