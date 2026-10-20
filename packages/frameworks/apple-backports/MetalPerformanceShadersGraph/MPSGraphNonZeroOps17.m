#import "RevenantMPSGraph.h"

@implementation MPSGraph (RevenantMPSGraphNonZero17)

- (MPSGraphTensor *)nonZeroIndicesOfTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    NSUInteger rank = tensor.shape.count;
    return [self revenant_mps_operation:RevenantMPSGraphOperationKindNonZero
                              inputs:@[tensor]
                          parameters:@{@"shape": @[@(-1), @(rank)],
                                       @"dataType": @(MPSDataTypeInt32),
                                       @"answerFillsDestination": @YES}
                                 name:name];
}

@end
