// MPSGraphNonZeroOps17.m - the one non-zero operation of 17.0: the indices of the elements of a tensor that
// are not a zero. From the header MPSGraphNonZeroOps.h of the 26.2 SDK, which declares it with its own
// availability note (ios(17.0)) and no other method.
//
// One object per release: this one names one method of 17.0 and nothing of any other release. All of its
// behaviour is measured on this host's own MPSGraph by the cases of tests/backports/host/mpsgraph and the
// probe beside them, and what is measured is in MPSGraphInterpreter14.m (the walk) and in
// facts/MetalPerformanceShadersGraph/Core.md. What is here is the operation's own rule about its result:
//
//   - the result is a list, one row of the OPERAND'S RANK coordinates for each element of the operand that is
//     not a zero, in the operand's own row-major order, and its own length is not known when the graph is
//     built. Measured over a [3, 4, 6]: the result tensor carries -1 for the count and the operand's rank for
//     the width - `-1x3`, and `-1x1` of a [6] and `-1x2` of a [4, 6] - before the run and after it;
//   - the coordinates are MPSDataTypeInt32 whatever the operand's own data type was (measured: 0x20000020 over
//     a float32, an int32 and a float16 operand alike).

#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphNonZero17)

- (MPSGraphTensor *)nonZeroIndicesOfTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    // The count of non-zero elements is data, so the result's own extent cannot be written down: the -1 the
    // release carries for it goes on the tensor here, and the walk replaces it with the count when the graph
    // runs. @"answerFillsDestination" is what tells the copy-out that this family writes the whole
    // destination rather than only the rows its answer has - see CharonMPSGraphWriteInto, where the
    // measurement behind it is quoted.
    NSUInteger rank = tensor.shape.count;
    return [self charon_mps_operation:CharonMPSGraphOperationKindNonZero
                              inputs:@[tensor]
                          parameters:@{@"shape": @[@(-1), @(rank)],
                                       @"dataType": @(MPSDataTypeInt32),
                                       @"answerFillsDestination": @YES}
                                 name:name];
}

@end