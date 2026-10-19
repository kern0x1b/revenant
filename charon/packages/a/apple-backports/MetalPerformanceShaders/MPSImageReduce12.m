// The eight concrete MPSImageReduce classes, from MPSImageReduce.h of the iPhoneOS 26.2 surface. The release exports
// these from iOS 12.0, and the abstract base MPSImageReduceUnary they inherit from only from iOS 16.0, so they are
// their own object apart from MPSImageReduceUnary16.m. Each differs from the base only in the axis and the
// operation, which is exactly what MPSImageReduce.h's eight per-class comments describe.

#import "CharonMPSReduce.h"

// See MPSImageReduceUnary16.m for why: each concrete class's -initWithDevice: is NS_DESIGNATED_INITIALIZER and
// the base's only designated initializer cannot know which operation to build. Recorded in coordination/crutches.md.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// Each concrete class declares -initWithDevice: as its designated initializer (:64 and its seven siblings).
#define CHARON_DEFINE_REDUCE(CLASS, COLUMN, OPERATION)                                          \
    @implementation CLASS                                                                      \
    - (instancetype)initWithDevice:(id<MTLDevice>)device                                      \
    {                                                                                          \
        return [self charon_initWithDevice:device byColumn:(COLUMN) operation:(OPERATION)];     \
    }                                                                                          \
    @end

CHARON_DEFINE_REDUCE(MPSImageReduceRowMin, NO, CharonMPSReduceMin)
CHARON_DEFINE_REDUCE(MPSImageReduceColumnMin, YES, CharonMPSReduceMin)
CHARON_DEFINE_REDUCE(MPSImageReduceRowMax, NO, CharonMPSReduceMax)
CHARON_DEFINE_REDUCE(MPSImageReduceColumnMax, YES, CharonMPSReduceMax)
CHARON_DEFINE_REDUCE(MPSImageReduceRowMean, NO, CharonMPSReduceMean)
CHARON_DEFINE_REDUCE(MPSImageReduceColumnMean, YES, CharonMPSReduceMean)
CHARON_DEFINE_REDUCE(MPSImageReduceRowSum, NO, CharonMPSReduceSum)
CHARON_DEFINE_REDUCE(MPSImageReduceColumnSum, YES, CharonMPSReduceSum)
