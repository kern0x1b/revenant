#import "RevenantMPSGraph.h"

@implementation MPSGraph (RevenantMPSGraphTensorShapeOps174)

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
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
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
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                          inputs:@[dataTensor, updateTensor, startsTensor, endsTensor, stridesTensor]
                      parameters:@{@"gather": @"sliceUpdate",
                                   @"sliceStartMask": @(startMask), @"sliceEndMask": @(endMask),
                                   @"sliceSqueezeMask": @(squeezeMask),
                                   @"sliceScatteredShape": updateTensor.shape,
                                   @"sliceFedFrom": @2}
                             name:name];
}

@end
