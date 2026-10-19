#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphReduction150)

- (MPSGraphTensor *)reductionArgMaximumWithTensor:(MPSGraphTensor *)tensor
                                             axis:(NSInteger)axis
                                             name:(NSString *)name
{
    return [self charon_mps_reduction:CharonMPSGraphOperationKindReductionArgMaximum
                                 axes:@[@(axis)]
                               tensor:tensor
                          parameters:@{@"combination": @"maximum", @"index": @YES,
                                       @"propagateNaN": @NO, @"dataType": @(MPSDataTypeInt32)}
                                 name:name];
}

- (MPSGraphTensor *)reductionArgMinimumWithTensor:(MPSGraphTensor *)tensor
                                             axis:(NSInteger)axis
                                             name:(NSString *)name
{
    return [self charon_mps_reduction:CharonMPSGraphOperationKindReductionArgMinimum
                                 axes:@[@(axis)]
                               tensor:tensor
                          parameters:@{@"combination": @"minimum", @"index": @YES,
                                       @"propagateNaN": @NO, @"dataType": @(MPSDataTypeInt32)}
                                 name:name];
}

- (MPSGraphTensor *)minimumWithNaNPropagationWithPrimaryTensor:(MPSGraphTensor *)primaryTensor
                                              secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                                         name:(NSString *)name
{
    return [self charon_mps_nanPropagatingExtreme:primaryTensor
                                 secondaryTensor:secondaryTensor
                                          lesser:YES
                                            name:name];
}

- (MPSGraphTensor *)maximumWithNaNPropagationWithPrimaryTensor:(MPSGraphTensor *)primaryTensor
                                              secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                                         name:(NSString *)name
{
    return [self charon_mps_nanPropagatingExtreme:primaryTensor
                                 secondaryTensor:secondaryTensor
                                          lesser:NO
                                            name:name];
}

- (MPSGraphTensor *)charon_mps_nanPropagatingExtreme:(MPSGraphTensor *)primaryTensor
                                   secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                            lesser:(BOOL)lesser
                                              name:(NSString *)name
{
    MPSDataType type = primaryTensor.dataType;
    if (type != MPSDataTypeFloat32 && type != MPSDataTypeFloat16) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked of an operand of data type 0x%x, and the release "
                           @"answers it over float16 and float32 alone: measured, every integer type and a "
                           @"boolean raise out of its own kernel table, which has no NaN kernel for an "
                           @"integer type to ask with",
                            name, (unsigned)type];
    }
    return [self charon_mps_operation:lesser ? CharonMPSGraphOperationKindMinimum
                                             : CharonMPSGraphOperationKindMaximum
                                inputs:@[primaryTensor, secondaryTensor]
                            parameters:@{@"latchNaN": @YES}
                                   name:name];
}

@end
