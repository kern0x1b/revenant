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
