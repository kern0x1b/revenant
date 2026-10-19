#import "RevenantMPSGraph.h"

@implementation MPSGraph (RevenantMPSGraphTensorShapeOps182)

- (void)revenant_mps_refuseFloatingPointIndex:(MPSGraphTensor *)fed of:(NSString *)name
{
    MPSDataType type = fed.dataType;
    if (type == MPSDataTypeFloat32 || type == MPSDataTypeFloat16 || type == MPSDataTypeBool) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for a start, an end, a stride or a size fed as a tensor of "
                           @"data type 0x%x, and they are all indices: measured, the release's own compiler "
                           @"refuses a floating point operand and the process goes down with it",
                         name, (unsigned)type];
    }
}

- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor
                    startTensor:(MPSGraphTensor *)startTensor
                      endTensor:(MPSGraphTensor *)endTensor
                   strideTensor:(MPSGraphTensor *)strideTensor
                      startMask:(uint32_t)startMask
                        endMask:(uint32_t)endMask
                    squeezeMask:(uint32_t)squeezeMask
                           name:(NSString *)name
{
    for (MPSGraphTensor *fed in @[startTensor, endTensor, strideTensor])
        [self revenant_mps_refuseFloatingPointIndex:fed of:name];
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                          inputs:@[tensor, startTensor, endTensor, strideTensor]
                      parameters:@{@"gather": @"slice",
                                   @"sliceStartMask": @(startMask), @"sliceEndMask": @(endMask),
                                   @"sliceSqueezeMask": @(squeezeMask),
                                   @"sliceFedFrom": @1}
                             name:name];
}

- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor
                    startTensor:(MPSGraphTensor *)startTensor
                     sizeTensor:(MPSGraphTensor *)sizeTensor
                    squeezeMask:(uint32_t)squeezeMask
                           name:(NSString *)name
{
    for (MPSGraphTensor *fed in @[startTensor, sizeTensor])
        [self revenant_mps_refuseFloatingPointIndex:fed of:name];
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                          inputs:@[tensor, startTensor, sizeTensor]
                      parameters:@{@"gather": @"slice", @"sliceSqueezeMask": @(squeezeMask),
                                   @"sliceSizes": @YES, @"sliceFedFrom": @1}
                             name:name];
}

- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor
                       fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor
                            startTensor:(MPSGraphTensor *)startTensor
                              endTensor:(MPSGraphTensor *)endTensor
                           strideTensor:(MPSGraphTensor *)strideTensor
                              startMask:(uint32_t)startMask
                                endMask:(uint32_t)endMask
                            squeezeMask:(uint32_t)squeezeMask
                                   name:(NSString *)name
{
    for (MPSGraphTensor *fed in @[startTensor, endTensor, strideTensor])
        [self revenant_mps_refuseFloatingPointIndex:fed of:name];
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                          inputs:@[inputGradientTensor, fwdInShapeTensor, startTensor, endTensor, strideTensor]
                      parameters:@{@"gather": @"sliceGradient",
                                   @"sliceStartMask": @(startMask), @"sliceEndMask": @(endMask),
                                   @"sliceSqueezeMask": @(squeezeMask),
                                   @"sliceScatteredShape": inputGradientTensor.shape,
                                   @"sliceFedFrom": @2}
                             name:name];
}

- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor
                       fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor
                            startTensor:(MPSGraphTensor *)startTensor
                             sizeTensor:(MPSGraphTensor *)sizeTensor
                            squeezeMask:(uint32_t)squeezeMask
                                   name:(NSString *)name
{
    for (MPSGraphTensor *fed in @[startTensor, sizeTensor])
        [self revenant_mps_refuseFloatingPointIndex:fed of:name];
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                          inputs:@[inputGradientTensor, fwdInShapeTensor, startTensor, sizeTensor]
                      parameters:@{@"gather": @"sliceGradient",
                                   @"sliceSqueezeMask": @(squeezeMask),
                                   @"sliceSizes": @YES,
                                   @"sliceScatteredShape": inputGradientTensor.shape,
                                   @"sliceFedFrom": @2}
                             name:name];
}

@end
