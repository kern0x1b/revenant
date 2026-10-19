#import "CharonMPSReduce.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@interface MPSNNReduceFeatureChannelsSum (CharonMPSNNReduce)
- (float)weight;
- (void)setWeight:(float)weight;
@end

#define CHARON_DEFINE_NN_REDUCE(CLASS, COLUMN, FEATURE_CHANNEL, OPERATION)                          \
    @implementation CLASS                                                                          \
    - (instancetype)initWithDevice:(id<MTLDevice>)device                                          \
    {                                                                                              \
        return [self charon_nnReduceWithDevice:device                                             \
                                     byColumn:(COLUMN)                                            \
                             byFeatureChannel:(FEATURE_CHANNEL)                                    \
                                   operation:(OPERATION)];                                        \
    }                                                                                              \
    @end

CHARON_DEFINE_NN_REDUCE(MPSNNReduceRowMin, NO, NO, CharonMPSReduceMin)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceColumnMin, YES, NO, CharonMPSReduceMin)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsMin, NO, YES, CharonMPSReduceMin)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceRowMax, NO, NO, CharonMPSReduceMax)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceColumnMax, YES, NO, CharonMPSReduceMax)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsMax, NO, YES, CharonMPSReduceMax)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceRowMean, NO, NO, CharonMPSReduceMean)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceColumnMean, YES, NO, CharonMPSReduceMean)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsMean, NO, YES, CharonMPSReduceMean)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceRowSum, NO, NO, CharonMPSReduceSum)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceColumnSum, YES, NO, CharonMPSReduceSum)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsSum, NO, YES, CharonMPSReduceSum)


@implementation MPSNNReduceFeatureChannelsSum (CharonMPSNNReduce)
- (float)weight { return [self charon_nnReduceWeight]; }
- (void)setWeight:(float)weight { [self charon_setNnReduceWeight:weight]; }
@end
