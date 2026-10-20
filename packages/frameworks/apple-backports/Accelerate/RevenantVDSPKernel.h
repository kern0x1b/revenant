#pragma once

#import <Accelerate/Accelerate.h>

void revenant_vdsp_split_vma_f(DSPSplitComplex *out, vDSP_Stride out_stride, const DSPSplitComplex *A, vDSP_Stride IA,
                             const DSPSplitComplex *B, vDSP_Stride IB, const DSPSplitComplex *C, vDSP_Stride IC,
                             vDSP_Length N);
void revenant_vdsp_split_vma_d(DSPDoubleSplitComplex *out, vDSP_Stride out_stride, const DSPDoubleSplitComplex *A,
                             vDSP_Stride IA, const DSPDoubleSplitComplex *B, vDSP_Stride IB,
                             const DSPDoubleSplitComplex *C, vDSP_Stride IC, vDSP_Length N);
void revenant_vdsp_split_vmmaa_f(DSPSplitComplex *out, vDSP_Stride out_stride, const DSPSplitComplex *A, vDSP_Stride IA,
                               const DSPSplitComplex *B, vDSP_Stride IB, const DSPSplitComplex *C, vDSP_Stride IC,
                               const DSPSplitComplex *D, vDSP_Stride ID, const DSPSplitComplex *E, vDSP_Stride IE,
                               vDSP_Length N);
void revenant_vdsp_split_vmmaa_d(DSPDoubleSplitComplex *out, vDSP_Stride out_stride, const DSPDoubleSplitComplex *A,
                               vDSP_Stride IA, const DSPDoubleSplitComplex *B, vDSP_Stride IB,
                               const DSPDoubleSplitComplex *C, vDSP_Stride IC, const DSPDoubleSplitComplex *D,
                               vDSP_Stride ID, const DSPDoubleSplitComplex *E, vDSP_Stride IE, vDSP_Length N);
