// The arithmetic the vDSP entry points of Accelerate share, in one place.
//
// vDSP names the operands of an operation in the order they are used with the accumulator last, and two
// of the fifty-four functions of this group are one operation in two precisions in two different
// releases: vDSP_zvma and vDSP_zvmaD (iOS 7.0 and 8.0), vDSP_zvmmaa and vDSP_zvmmaaD (the same two
// releases). The bodies below are written once and generated per scalar type, so the two precisions and
// the two releases cannot drift apart.
//
// Nothing here is exported: the entry points a caller names live in vDSPFixed7.m and
// vDSPElementwise8.m, and the gate weighs neither this file nor its symbols against a release
// (modules/apple/backports.lua, internal_symbol - a name beginning with charon_ is the port's own).

#pragma once

#import <Accelerate/Accelerate.h>

void charon_vdsp_split_vma_f(DSPSplitComplex *out, vDSP_Stride out_stride, const DSPSplitComplex *A, vDSP_Stride IA,
                             const DSPSplitComplex *B, vDSP_Stride IB, const DSPSplitComplex *C, vDSP_Stride IC,
                             vDSP_Length N);
void charon_vdsp_split_vma_d(DSPDoubleSplitComplex *out, vDSP_Stride out_stride, const DSPDoubleSplitComplex *A,
                             vDSP_Stride IA, const DSPDoubleSplitComplex *B, vDSP_Stride IB,
                             const DSPDoubleSplitComplex *C, vDSP_Stride IC, vDSP_Length N);
void charon_vdsp_split_vmmaa_f(DSPSplitComplex *out, vDSP_Stride out_stride, const DSPSplitComplex *A, vDSP_Stride IA,
                               const DSPSplitComplex *B, vDSP_Stride IB, const DSPSplitComplex *C, vDSP_Stride IC,
                               const DSPSplitComplex *D, vDSP_Stride ID, const DSPSplitComplex *E, vDSP_Stride IE,
                               vDSP_Length N);
void charon_vdsp_split_vmmaa_d(DSPDoubleSplitComplex *out, vDSP_Stride out_stride, const DSPDoubleSplitComplex *A,
                               vDSP_Stride IA, const DSPDoubleSplitComplex *B, vDSP_Stride IB,
                               const DSPDoubleSplitComplex *C, vDSP_Stride IC, const DSPDoubleSplitComplex *D,
                               vDSP_Stride ID, const DSPDoubleSplitComplex *E, vDSP_Stride IE, vDSP_Length N);
