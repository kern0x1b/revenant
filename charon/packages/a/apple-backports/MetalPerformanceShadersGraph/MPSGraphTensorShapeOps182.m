// MPSGraphTensorShapeOps182.m - the slice family as 18.2 spells it: the two FED slice forms and the two FED
// gradient forms, four methods of one release, all through the slice family's one seam in MPSGraph14.m.
// Nothing here names a method of any other release.
//
// WHAT 18.2'S FOUR METHODS ARE, MEASURED ON THIS HOST'S OWN MPSGRAPH, and it is the same measurement for all
// four: a parameter that arrives as DATA and that the RESULT'S SHAPE depends on is one the release cannot
// build a graph over. Every form here takes the result's shape out of fed tensors - the starts and the ends
// (or the sizes) of `sliceTensor:startTensor:endTensor:strideTensor:...:`, and the shape of the forward
// input of `sliceGradientTensor:...` - and every form dies in the release's own NDArray:
//
//   "Error: NDArray dimension length > INT_MAX" (MPSNDArray.mm:759), exit 134, whatever the fed tensor is
//   made of: an int32 of shape [2], an int32 of shape [1], an int64 of shape [2] and the SIZE form's own
//   `sliceTensor:startTensor:sizeTensor:squeezeMask:name:` all answer that, and an int32 of shape [2,1] and a
//   float32 of shape [2] fail a step earlier in the release's compiler ("Optimize Original Module MLIR pass
//   manager failed").
//
// The gradient's fed forms are the exception in kind rather than in the answer: their result's shape is nil
// on the release's own tensor, before the run and after it, and the process writes the gradient's element 0
// into the destination's element 0 and nothing else, whatever the destination's shape is (measured over five
// shapes of the destination and five shapes of the forward input, all one element).
//
// So these four rows are the family's named divergences: each carries the release's own words and its exit
// status, and the port answers the header - the slice over the starts, ends and strides the caller fed, and
// the gradient of the forward input's shape the caller fed, both read when the graph runs, which is the only
// time a fed value is there to read. The rest of the family's measurements are in
// facts/MetalPerformanceShadersGraph/Core.md and in the header of MPSGraphTensorShapeOps174.m.

#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphTensorShapeOps182)

// The data types a fed index is refused in, and why: a start, an end, a stride and a size are all indices,
// and the release's own compiler refuses a floating point operand at build time and takes the process down
// with it. Checked where the graph is built, which is where the release refuses.
- (void)charon_mps_refuseFloatingPointIndex:(MPSGraphTensor *)fed of:(NSString *)name
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
        [self charon_mps_refuseFloatingPointIndex:fed of:name];
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
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
        [self charon_mps_refuseFloatingPointIndex:fed of:name];
    // A size is a COUNT and not an end, so the region of each axis is the size from the start at one pace a
    // time: there is no stride to read and no end to count the steps to. That is what makes this form one
    // shape and not the other, and it is the only difference between the two.
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
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
        [self charon_mps_refuseFloatingPointIndex:fed of:name];
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
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
        [self charon_mps_refuseFloatingPointIndex:fed of:name];
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[inputGradientTensor, fwdInShapeTensor, startTensor, sizeTensor]
                      parameters:@{@"gather": @"sliceGradient",
                                   @"sliceSqueezeMask": @(squeezeMask),
                                   @"sliceSizes": @YES,
                                   @"sliceScatteredShape": inputGradientTensor.shape,
                                   @"sliceFedFrom": @2}
                             name:name];
}

@end
