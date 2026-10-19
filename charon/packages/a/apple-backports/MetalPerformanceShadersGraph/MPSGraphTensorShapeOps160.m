// MPSGraphTensorShapeOps160.m - the permutation transpose, which arrived with MPSGraph in 16.0. From the
// header MPSGraphTensorShapeOps.h in the SDK of iOS 16.4, which declares it with its own availability note
// (ios(16.0)).
//
// One object per release: this one names one method of 16.0 and nothing else. It is the walk in
// MPSGraphInterpreter14.m that does the work, and it is 14.0's own -transposeTensor:dimension:withDimension: -
// that arrives with the framework which answers the row-major transpose over two axes; the permutation form
// is that transpose generalised to a whole ordering, and the two agree where they overlap, measured: over the
// 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) a permutation of @[@1, @0] answers (1, 10, 2, 20, 3, 30, 4, 40) into
// a 4x2, which is what transposeTensor:dimension:0 withDimension:1 answers.

#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphTensorShape160)

- (MPSGraphTensor *)transposeTensor:(MPSGraphTensor *)tensor
                         permutation:(NSArray<NSNumber *> *)permutation
                                name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindTranspose
                             tensor:tensor
                        parameters:@{@"gather": @"transpose", @"gatherPermutation": permutation ?: @[]}
                               name:name];
}

@end
