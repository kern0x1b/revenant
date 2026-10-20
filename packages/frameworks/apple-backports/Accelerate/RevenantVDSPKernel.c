#import "RevenantVDSPKernel.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

#define REVENANT_VDSP_SPLIT_COMPLEX(Kind, SplitComplex, Suffix)                                                       \
    void revenant_vdsp_split_vma_##Suffix(SplitComplex *out, vDSP_Stride out_stride, const SplitComplex *A,            \
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
    void revenant_vdsp_split_vmmaa_##Suffix(SplitComplex *out, vDSP_Stride out_stride, const SplitComplex *A,           \
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

REVENANT_VDSP_SPLIT_COMPLEX(float, DSPSplitComplex, f)
REVENANT_VDSP_SPLIT_COMPLEX(double, DSPDoubleSplitComplex, d)
