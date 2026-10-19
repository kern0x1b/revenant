#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphCumulative160)

#pragma mark - the sum

- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor
                                       axis:(NSInteger)axis
                                       name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeSum
                             axis:axis
                           tensor:tensor
                      combination:@"sum"
                         exclusive:NO
                           reverse:NO
                              name:name];
}

- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor
                                       axis:(NSInteger)axis
                                  exclusive:(BOOL)exclusive
                                    reverse:(BOOL)reverse
                                       name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeSum
                             axis:axis
                           tensor:tensor
                      combination:@"sum"
                         exclusive:exclusive
                           reverse:reverse
                              name:name];
}

- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor
                                 axisTensor:(MPSGraphTensor *)axisTensor
                                       name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeSum
                       axisTensor:axisTensor
                           tensor:tensor
                      combination:@"sum"
                         exclusive:NO
                           reverse:NO
                              name:name];
}

- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor
                                 axisTensor:(MPSGraphTensor *)axisTensor
                                  exclusive:(BOOL)exclusive
                                    reverse:(BOOL)reverse
                                       name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeSum
                       axisTensor:axisTensor
                           tensor:tensor
                      combination:@"sum"
                         exclusive:exclusive
                           reverse:reverse
                              name:name];
}

#pragma mark - the product

- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor
                                           axis:(NSInteger)axis
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeProduct
                             axis:axis
                           tensor:tensor
                      combination:@"product"
                         exclusive:NO
                           reverse:NO
                              name:name];
}

- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor
                                           axis:(NSInteger)axis
                                      exclusive:(BOOL)exclusive
                                        reverse:(BOOL)reverse
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeProduct
                             axis:axis
                           tensor:tensor
                      combination:@"product"
                         exclusive:exclusive
                           reverse:reverse
                              name:name];
}

- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor
                                     axisTensor:(MPSGraphTensor *)axisTensor
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeProduct
                       axisTensor:axisTensor
                           tensor:tensor
                      combination:@"product"
                         exclusive:NO
                           reverse:NO
                              name:name];
}

- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor
                                     axisTensor:(MPSGraphTensor *)axisTensor
                                      exclusive:(BOOL)exclusive
                                        reverse:(BOOL)reverse
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeProduct
                       axisTensor:axisTensor
                           tensor:tensor
                      combination:@"product"
                         exclusive:exclusive
                           reverse:reverse
                              name:name];
}

#pragma mark - the maximum

- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor
                                           axis:(NSInteger)axis
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeMaximum
                             axis:axis
                           tensor:tensor
                      combination:@"maximum"
                         exclusive:NO
                           reverse:NO
                              name:name];
}

- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor
                                           axis:(NSInteger)axis
                                      exclusive:(BOOL)exclusive
                                        reverse:(BOOL)reverse
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeMaximum
                             axis:axis
                           tensor:tensor
                      combination:@"maximum"
                         exclusive:exclusive
                           reverse:reverse
                              name:name];
}

- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor
                                     axisTensor:(MPSGraphTensor *)axisTensor
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeMaximum
                       axisTensor:axisTensor
                           tensor:tensor
                      combination:@"maximum"
                         exclusive:NO
                           reverse:NO
                              name:name];
}

- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor
                                     axisTensor:(MPSGraphTensor *)axisTensor
                                      exclusive:(BOOL)exclusive
                                        reverse:(BOOL)reverse
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeMaximum
                       axisTensor:axisTensor
                           tensor:tensor
                      combination:@"maximum"
                         exclusive:exclusive
                           reverse:reverse
                              name:name];
}

#pragma mark - the minimum

- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor
                                           axis:(NSInteger)axis
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeMinimum
                             axis:axis
                           tensor:tensor
                      combination:@"minimum"
                         exclusive:NO
                           reverse:NO
                              name:name];
}

- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor
                                           axis:(NSInteger)axis
                                      exclusive:(BOOL)exclusive
                                        reverse:(BOOL)reverse
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeMinimum
                             axis:axis
                           tensor:tensor
                      combination:@"minimum"
                         exclusive:exclusive
                           reverse:reverse
                              name:name];
}

- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor
                                     axisTensor:(MPSGraphTensor *)axisTensor
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeMinimum
                       axisTensor:axisTensor
                           tensor:tensor
                      combination:@"minimum"
                         exclusive:NO
                           reverse:NO
                              name:name];
}

- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor
                                     axisTensor:(MPSGraphTensor *)axisTensor
                                      exclusive:(BOOL)exclusive
                                        reverse:(BOOL)reverse
                                           name:(NSString *)name
{
    return [self charon_mps_scan:CharonMPSGraphOperationKindCumulativeMinimum
                       axisTensor:axisTensor
                           tensor:tensor
                      combination:@"minimum"
                         exclusive:exclusive
                           reverse:reverse
                              name:name];
}

@end
