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
