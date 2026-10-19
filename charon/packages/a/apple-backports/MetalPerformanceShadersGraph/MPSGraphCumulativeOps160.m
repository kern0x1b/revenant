// MPSGraphCumulativeOps160.m - the sixteen methods of the cumulative header, which arrived with MPSGraph
// in 16.0: the sum, the product, the maximum and the minimum, each in four forms (an axis written down with
// and without the two flags, and an axis fed at run time with and without them). From the header
// MPSGraphCumulativeOps.h in the SDK of iOS 16.4, which declares all sixteen, each with its own
// availability note (ios(16.0)).
//
// One object per release: the band machinery keeps an object whole or drops it whole, so a file here
// carries the API of exactly one release. This one names sixteen methods and no other, and it builds them
// through the two seams on MPSGraph in CharonMPSGraph.h, which is where the axis arithmetic is and which no
// object of an earlier release names anything of this one for.
//
// The one rule the whole family is, measured on this host's own MPSGraph over the case file's feeds and over
// rows chosen for their ties, in float32, int32 and float16 alike: the answer at a position is the fold of
// the elements on one side of it, and whether the element AT that position is in its own answer is the
// exclusive flag. Over the 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) along axis 1, a cumulative sum answers
// (1, 3, 6, 10 | 10, 30, 60, 100), a cumulative maximum answers (1, 2, 3, 4 | 10, 20, 30, 40), and the two
// forms that ask for the other side of the same fold answer (10, 9, 7, 4 | 100, 90, 70, 40) and
// (4, 4, 4, -inf | 40, 40, 40, -inf), the last of which is the seed of a maximum where the walk starts. The
// rule and every number in it are in facts/MetalPerformanceShadersGraph/Core.md.

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
