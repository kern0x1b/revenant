#import "RevenantMPSReduce.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@interface MPSNNReduceFeatureChannelsSum (RevenantMPSNNReduce)
- (float)weight;
- (void)setWeight:(float)weight;
@end

#define REVENANT_DEFINE_NN_REDUCE(CLASS, COLUMN, FEATURE_CHANNEL, OPERATION)                          \
    @implementation CLASS                                                                          \
    - (instancetype)initWithDevice:(id<MTLDevice>)device                                          \
    {                                                                                              \
        return [self revenant_nnReduceWithDevice:device                                             \
                                     byColumn:(COLUMN)                                            \
                             byFeatureChannel:(FEATURE_CHANNEL)                                    \
                                   operation:(OPERATION)];                                        \
    }                                                                                              \
    @end

REVENANT_DEFINE_NN_REDUCE(MPSNNReduceRowMin, NO, NO, RevenantMPSReduceMin)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceColumnMin, YES, NO, RevenantMPSReduceMin)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsMin, NO, YES, RevenantMPSReduceMin)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceRowMax, NO, NO, RevenantMPSReduceMax)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceColumnMax, YES, NO, RevenantMPSReduceMax)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsMax, NO, YES, RevenantMPSReduceMax)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceRowMean, NO, NO, RevenantMPSReduceMean)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceColumnMean, YES, NO, RevenantMPSReduceMean)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsMean, NO, YES, RevenantMPSReduceMean)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceRowSum, NO, NO, RevenantMPSReduceSum)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceColumnSum, YES, NO, RevenantMPSReduceSum)
REVENANT_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsSum, NO, YES, RevenantMPSReduceSum)


@implementation MPSNNReduceFeatureChannelsSum (RevenantMPSNNReduce)
- (float)weight { return [self revenant_nnReduceWeight]; }
- (void)setWeight:(float)weight { [self revenant_setNnReduceWeight:weight]; }
@end
