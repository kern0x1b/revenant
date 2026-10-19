// MPSGraphTensorShapeOps174.m - the slice's UPDATE as 17.4 spells it: the written-down form with the three
// masks and the fed form beside it, two methods of one release, both of which go through the slice family's
// one seam in MPSGraph14.m. Nothing here names a method of any other release.
//
// An update is the third direction of the slice family's one arithmetic: the result is the DATA tensor's own
// shape, the data's own elements, with the update written OVER the region the same starts, ends and strides
// select. Measured on this host's own MPSGraph over a 2x4 of (100, 200, 300, 400 | 500, 600, 700, 800):
//
//   - the update REPLACES and does not add: the region row 0, columns 1 and 2 updated with (-1, -2) answers
//     (100, -1, -2, 400 | 500, 600, 700, 800), so the data is there byte for byte everywhere else;
//   - the masks are the slice's own masks, measured: with startMask over axis 0, a written start of 1 and an
//     end of 2 over a 2x4, the whole axis is written, which is what a start of zero and an end of two say;
//   - a NEGATIVE stride writes the update's elements along the region's own order, measured: a region that
//     walks axis 1 from 3 with a stride of -1 puts the update's first element at index 3;
//   - the update's shape must BE the region's shape: one wider than the region and one narrower than it are
//     both refused by the release's own compiler ("Optimize Original Module MLIR pass manager failed"), which
//     is why the plan refuses them where the graph is built;
//   - an endMask and a squeezeMask are refused the same way on an update, measured over four shapes of the
//     update and three masks each: the port answers them, and the rows name the divergence.
//
// The FED form is the one fed parameter the release answers, and the reason is the family's own rule: the
// result's shape is the DATA tensor's own, which the graph knows when it is built, so the starts, the ends
// and the strides can arrive as data - measured, an update whose starts, ends and strides are fed of int32
// answers exactly what the written-down form answers. Every other fed parameter of this family is one the
// result's shape depends on, and those the release cannot build a graph over at all.

#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphTensorShapeOps174)

- (MPSGraphTensor *)sliceUpdateDataTensor:(MPSGraphTensor *)dataTensor
                             updateTensor:(MPSGraphTensor *)updateTensor
                                   starts:(NSArray<NSNumber *> *)starts
                                     ends:(NSArray<NSNumber *> *)ends
                                  strides:(NSArray<NSNumber *> *)strides
                                startMask:(uint32_t)startMask
                                  endMask:(uint32_t)endMask
                              squeezeMask:(uint32_t)squeezeMask
                                     name:(NSString *)name
{
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[dataTensor, updateTensor]
                      parameters:@{@"gather": @"sliceUpdate",
                                   @"sliceStarts": starts ?: @[], @"sliceEnds": ends ?: @[],
                                   @"sliceStrides": strides ?: @[],
                                   @"sliceStartMask": @(startMask), @"sliceEndMask": @(endMask),
                                   @"sliceSqueezeMask": @(squeezeMask),
                                   @"sliceScatteredShape": updateTensor.shape}
                             name:name];
}

- (MPSGraphTensor *)sliceUpdateDataTensor:(MPSGraphTensor *)dataTensor
                             updateTensor:(MPSGraphTensor *)updateTensor
                             startsTensor:(MPSGraphTensor *)startsTensor
                               endsTensor:(MPSGraphTensor *)endsTensor
                            stridesTensor:(MPSGraphTensor *)stridesTensor
                                startMask:(uint32_t)startMask
                                  endMask:(uint32_t)endMask
                              squeezeMask:(uint32_t)squeezeMask
                                     name:(NSString *)name
{
    // The three fed parameters are the operation's own inputs after the two the walk reads, and the plan is
    // told where they start. Their data type is checked here rather than when the graph runs, because the
    // release's own compiler refuses a floating point one at build time and takes the process down with it
    // (measured: 'mps.slice_update' op operand #2 must be 0D tensor of mps index type values, and the failed
    // assertion is in MPSGraphExecutable.mm).
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
                                   @"sliceStartMask": @(startMask), @"sliceEndMask": @(endMask),
                                   @"sliceSqueezeMask": @(squeezeMask),
                                   @"sliceScatteredShape": updateTensor.shape,
                                   @"sliceFedFrom": @2}
                             name:name];
}

@end
