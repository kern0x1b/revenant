// MPSGraphTensorShapeOps180.m - the slice's UPDATE as 18.0 spells it: the same two methods as 17.4's with
// the three masks left out of them, which is what the header's own note says they are ("Creates a strided-
// slice update operation with zero masks"). Two methods of one release, both through the slice family's one
// seam in MPSGraph14.m; nothing here names a method of any other release.
//
// What the update does is measured and is 17.4's own measurement, in the header of that object: the result is
// the data tensor's own shape and elements with the update written over the region the starts, the ends and
// the strides select. These two rows differ from that object's in one thing only, and it is the thing this
// file is here for: with the masks left out, the region is the one the caller wrote down and nothing else,
// and the FED form is answered by the release - measured over a 2x4 with the starts, ends and strides fed as
// int32 of shape [2], where the fed form answers exactly what the written-down form answers (100, 200, 300,
// 400 | 1, 2, 3, 4) for a region of row 1 written down as a start of 1 and an end of 4.

#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphTensorShapeOps180)

- (MPSGraphTensor *)sliceUpdateDataTensor:(MPSGraphTensor *)dataTensor
                             updateTensor:(MPSGraphTensor *)updateTensor
                                   starts:(NSArray<NSNumber *> *)starts
                                     ends:(NSArray<NSNumber *> *)ends
                                  strides:(NSArray<NSNumber *> *)strides
                                     name:(NSString *)name
{
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[dataTensor, updateTensor]
                      parameters:@{@"gather": @"sliceUpdate",
                                   @"sliceStarts": starts ?: @[], @"sliceEnds": ends ?: @[],
                                   @"sliceStrides": strides ?: @[],
                                   @"sliceScatteredShape": updateTensor.shape}
                             name:name];
}

- (MPSGraphTensor *)sliceUpdateDataTensor:(MPSGraphTensor *)dataTensor
                             updateTensor:(MPSGraphTensor *)updateTensor
                             startsTensor:(MPSGraphTensor *)startsTensor
                               endsTensor:(MPSGraphTensor *)endsTensor
                            stridesTensor:(MPSGraphTensor *)stridesTensor
                                     name:(NSString *)name
{
    // The three fed parameters are the operation's own inputs after the two the walk reads, and the plan is
    // told where they start. Their data type is refused here for 17.4's own measured reason: the release's
    // compiler refuses a floating point index operand at build time and the process goes down with it.
    for (MPSGraphTensor *fed in @[startsTensor, endsTensor, stridesTensor]) {
        MPSDataType type = fed.dataType;
        if (type == MPSDataTypeFloat32 || type == MPSDataTypeFloat16 || type == MPSDataTypeBool) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked for a start, an end or a stride fed as a tensor of "
                               @"data type 0x%x, and they are all indices: measured, the release's own compiler "
                               @"refuses a floating point operand and the process goes down with it",
                             name, (unsigned)type];
        }
    }
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[dataTensor, updateTensor, startsTensor, endsTensor, stridesTensor]
                      parameters:@{@"gather": @"sliceUpdate",
                                   @"sliceScatteredShape": updateTensor.shape,
                                   @"sliceFedFrom": @2}
                             name:name];
}

@end
