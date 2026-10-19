// MPSGraphReductionOps150.m - the four operations of the reduction and arithmetic headers that arrived
// with MPSGraph in 15.0: the two argument reductions and the two binary NaN-propagating extremes.
// From the headers MPSGraphReductionOps.h and MPSGraphArithmeticOps.h in the SDK of iOS 16.4, which
// declare all four, with their own availability notes (ios(15.0) for each).
//
// One object per release: the band machinery keeps an object whole or drops it whole, so a file here
// carries the API of exactly one release. This one names four methods and no other, and it builds them
// through the seam on MPSGraph in CharonMPSGraph.h, which is where the axis arithmetic and the result's
// shape are and which no 14.0 object names anything of this release for.

#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphReduction150)

// The two argument reductions answer the index of the extreme rather than the extreme, which is the
// only difference between them and the two that arrived in 14.0. Measured on this host's own MPSGraph,
// over the sixteen classes the committed cases use and over rows chosen for their ties, in float32,
// float16 and int32 alike:
//
//  - the answer is the index of the FIRST element holding the extreme, so a row of (4, 4, 4, 9) answers
//    3 for a maximum and a row of (9, 9, 1, 1) answers 0 and 2 - a comparison that replaced on equality
//    would answer the last of the three, and the release does not.
//  - a NaN loses every comparison and so is never the answer, wherever it sits: (nan, 1, 2, 3) answers 3
//    for a maximum and 1 for a minimum, (1, 2, 3, nan) answers 2 and 0, and a row of nine with a NaN at
//    either end answers 8 and 7 for a maximum.
//  - a reduced set of nothing but NaNs answers -1 in both, which is "nothing was found" rather than an
//    index into an empty set.
//  - the result is stored as MPSDataTypeInt32 whatever the operand's own type is, and the two signed
//    zeros compare equal, so (0, -0, 0, -0) answers 0 for both.
//
// So the two of them are a maximum and a minimum with @YES where the walk keeps the index instead of the
// value, and the result type the release stores them in. Nothing else about them differs from 14.0's,
// which is why they go through the same seam with the same combination.
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

// The two binary extremes that propagate a NaN, which are the elementwise half of what 14.0's two
// propagating reductions do to a whole reduced set. The header states the rule and the measurement
// confirms it: resultTensor = isNaN(primary) || isNaN(secondary) ? NaN : min(primary, secondary), and
// over the sixteen classes of the committed cases - (1, -1, -0, 0, +inf, -inf, NaN, -NaN) against
// (0, -0, +inf, -inf, NaN, -NaN, 1.4e-45, 2) - the four NaN positions answer a NaN each and the four
// ordinary ones answer what 14.0's pair answers over the same feeds (0, -1, -0, -inf), so the only
// difference between the two pairs is the four NaNs. In float16 the same four answer a NaN as well.
//
// A data type that is not a floating point one is the one thing this release does not answer at all, and
// the set is measured rather than guessed: int8, int16, int32, int64, uint8, uint16, uint32, uint64 and
// bool each raise NSInvalidArgumentException from inside the framework's own kernel table before any
// element is written, and float16 and float32 each answer. The key it is reaching for names the type it
// wanted - isNaN_i8, isNaN_i16_i8, isNaN_i_i8, isNaN_i64_i8, isNaN_u8_i8, isNaN_u16_i8, isNaN_u_i8,
// isNaN_u64_i8, and for a boolean isNaN_i8 again - because there is no NaN kernel for an integer type and a
// boolean is an integer type to it. This port has no kernel table to miss an entry in, so the refusal is
// the same one raised and named, over exactly the nine types measured and no other.
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

// What the two of them share. The arithmetic is 14.0's minimum and maximum, which the interpreter
// already walks, and the one thing that is this release's own is that a NaN latches - so the operation
// is 14.0's operation with @latchNaN set, and no name of this release appears in any object but this
// one. The data type is asked first because it is the data type the refusal is about.
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
