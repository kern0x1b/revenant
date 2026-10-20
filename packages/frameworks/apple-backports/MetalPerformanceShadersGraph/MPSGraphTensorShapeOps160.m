#import "RevenantMPSGraph.h"

@implementation MPSGraph (RevenantMPSGraphTensorShape160)

- (MPSGraphTensor *)transposeTensor:(MPSGraphTensor *)tensor
                         permutation:(NSArray<NSNumber *> *)permutation
                                name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindTranspose
                             tensor:tensor
                        parameters:@{@"gather": @"transpose", @"gatherPermutation": permutation ?: @[]}
                               name:name];
}

@end
