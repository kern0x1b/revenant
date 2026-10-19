// MPSGraphReductionOps153.m - the two truth folds of the reduction header, which arrived with MPSGraph
// in 15.3. From the header MPSGraphReductionOps.h in the SDK of iOS 16.4, which declares both in each
// of the two forms, with their own availability notes (ios(15.3) for each).
//
// One object per release: the band machinery keeps an object whole or drops it whole, so a file here
// carries the API of exactly one release. This one names four methods and no other, and it builds them
// through the seam on MPSGraph in CharonMPSGraph.h, which is where the axis arithmetic and the result's
// shape are and which no 14.0 object names anything of this release for.

#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphReduction153)

// A reduction AND and a reduction OR, which are a question about the whole reduced set rather than an
// arithmetic over it: the answer is whether every element of it is nonzero and whether any of them is.
// Measured on this host's own MPSGraph over the sixteen classes the committed cases use, and over the
// feeds the reduction family already asks:
//
//  - the answer is written in the OPERAND's own type and not in a boolean: an "and" of a float32 row is
//    float32, an "and" of an int32 row is int32, an "and" of a half row is a half and an "and" of a uint8
//    row is a byte. So this is not one of the predicates that answer MPSDataTypeBool.
//  - the test is against zero, so the two signed zeros are what make the answer false and a NaN is a
//    nonzero like any other value: an "and" of the sixteen classes - a row of (1, -1, +0, -0, +inf, -inf,
//    NaN, -NaN) - answers 0 because that row holds a zero, a row of nothing but NaNs answers 1, and the
//    int32 row (-3, -2, -1, 0 | 1, 2, 3, 4) answers 0 and 1 for the same reason.
//  - the answer is one and not a truth of some other kind: 0x3f800000 in float32, 0x3c00 in float16, 1 in
//    int32 and 1 in uint8.
//  - the axes are the family's own, so axes:nil reduces every axis and answers a 1x1, axes:@[] reduces
//    none and answers the operand byte for byte, and a negative axis counts from the end - all three
//    measured over the same 2x4 the other reductions are asked over.
//
// So each of them is a combination of its own with the family's axes, and the walk in
// MPSGraphInterpreter14.m folds a truth rather than a number when the combination says so.
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
