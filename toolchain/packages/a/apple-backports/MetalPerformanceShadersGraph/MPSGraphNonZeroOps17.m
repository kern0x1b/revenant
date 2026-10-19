#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphNonZero17)

- (MPSGraphTensor *)nonZeroIndicesOfTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    NSUInteger rank = tensor.shape.count;
    return [self charon_mps_operation:CharonMPSGraphOperationKindNonZero
                              inputs:@[tensor]
                          parameters:@{@"shape": @[@(-1), @(rank)],
                                       @"dataType": @(MPSDataTypeInt32),
                                       @"answerFillsDestination": @YES}
                                 name:name];
}

@end
