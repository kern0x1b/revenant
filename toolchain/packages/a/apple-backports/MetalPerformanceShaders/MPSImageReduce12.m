#import "RevenantMPSReduce.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

#define REVENANT_DEFINE_REDUCE(CLASS, COLUMN, OPERATION)                                          \
    @implementation CLASS                                                                      \
    - (instancetype)initWithDevice:(id<MTLDevice>)device                                      \
    {                                                                                          \
        return [self revenant_initWithDevice:device byColumn:(COLUMN) operation:(OPERATION)];     \
    }                                                                                          \
    @end

REVENANT_DEFINE_REDUCE(MPSImageReduceRowMin, NO, RevenantMPSReduceMin)
REVENANT_DEFINE_REDUCE(MPSImageReduceColumnMin, YES, RevenantMPSReduceMin)
REVENANT_DEFINE_REDUCE(MPSImageReduceRowMax, NO, RevenantMPSReduceMax)
REVENANT_DEFINE_REDUCE(MPSImageReduceColumnMax, YES, RevenantMPSReduceMax)
REVENANT_DEFINE_REDUCE(MPSImageReduceRowMean, NO, RevenantMPSReduceMean)
REVENANT_DEFINE_REDUCE(MPSImageReduceColumnMean, YES, RevenantMPSReduceMean)
REVENANT_DEFINE_REDUCE(MPSImageReduceRowSum, NO, RevenantMPSReduceSum)
REVENANT_DEFINE_REDUCE(MPSImageReduceColumnSum, YES, RevenantMPSReduceSum)
