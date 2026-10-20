#import "RevenantMPSGraph.h"

@implementation MPSGraph (RevenantMPSGraphReduction153)

- (MPSGraphTensor *)reductionAndWithTensor:(MPSGraphTensor *)tensor
                                      axis:(NSInteger)axis
                                      name:(NSString *)name
{
    return [self revenant_mps_reduction:RevenantMPSGraphOperationKindReductionAnd
                                 axes:@[@(axis)]
                               tensor:tensor
                          parameters:@{@"combination": @"and", @"propagateNaN": @NO}
                                 name:name];
}

- (MPSGraphTensor *)reductionAndWithTensor:(MPSGraphTensor *)tensor
                                      axes:(NSArray<NSNumber *> *)axes
                                      name:(NSString *)name
{
    return [self revenant_mps_reduction:RevenantMPSGraphOperationKindReductionAnd
                                 axes:axes
                               tensor:tensor
                          parameters:@{@"combination": @"and", @"propagateNaN": @NO}
                                 name:name];
}

- (MPSGraphTensor *)reductionOrWithTensor:(MPSGraphTensor *)tensor
                                     axis:(NSInteger)axis
                                     name:(NSString *)name
{
    return [self revenant_mps_reduction:RevenantMPSGraphOperationKindReductionOr
                                 axes:@[@(axis)]
                               tensor:tensor
                          parameters:@{@"combination": @"or", @"propagateNaN": @NO}
                                 name:name];
}

- (MPSGraphTensor *)reductionOrWithTensor:(MPSGraphTensor *)tensor
                                     axes:(NSArray<NSNumber *> *)axes
                                     name:(NSString *)name
{
    return [self revenant_mps_reduction:RevenantMPSGraphOperationKindReductionOr
                                 axes:axes
                               tensor:tensor
                          parameters:@{@"combination": @"or", @"propagateNaN": @NO}
                                 name:name];
}

@end
