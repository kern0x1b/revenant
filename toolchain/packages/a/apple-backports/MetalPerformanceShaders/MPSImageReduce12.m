#import "CharonMPSReduce.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

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
