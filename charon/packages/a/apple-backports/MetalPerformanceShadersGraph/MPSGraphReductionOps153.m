#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphReduction153)

- (MPSGraphTensor *)reductionAndWithTensor:(MPSGraphTensor *)tensor
                                      axis:(NSInteger)axis
                                      name:(NSString *)name
{
    return [self charon_mps_reduction:CharonMPSGraphOperationKindReductionAnd
                                 axes:@[@(axis)]
                               tensor:tensor
                          parameters:@{@"combination": @"and", @"propagateNaN": @NO}
                                 name:name];
}

- (MPSGraphTensor *)reductionAndWithTensor:(MPSGraphTensor *)tensor
                                      axes:(NSArray<NSNumber *> *)axes
                                      name:(NSString *)name
{
    return [self charon_mps_reduction:CharonMPSGraphOperationKindReductionAnd
                                 axes:axes
                               tensor:tensor
                          parameters:@{@"combination": @"and", @"propagateNaN": @NO}
                                 name:name];
}

- (MPSGraphTensor *)reductionOrWithTensor:(MPSGraphTensor *)tensor
                                     axis:(NSInteger)axis
                                     name:(NSString *)name
{
    return [self charon_mps_reduction:CharonMPSGraphOperationKindReductionOr
                                 axes:@[@(axis)]
                               tensor:tensor
                          parameters:@{@"combination": @"or", @"propagateNaN": @NO}
                                 name:name];
}

- (MPSGraphTensor *)reductionOrWithTensor:(MPSGraphTensor *)tensor
                                     axes:(NSArray<NSNumber *> *)axes
                                     name:(NSString *)name
{
    return [self charon_mps_reduction:CharonMPSGraphOperationKindReductionOr
                                 axes:axes
                               tensor:tensor
                          parameters:@{@"combination": @"or", @"propagateNaN": @NO}
                                 name:name];
}

@end
