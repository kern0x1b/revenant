#import "CharonMPSCnn.h"

@implementation MPSCNNNormalizationMeanAndVarianceState {
    id<MTLBuffer> _mean;
    id<MTLBuffer> _variance;
}

- (instancetype)initWithMean:(id<MTLBuffer>)mean variance:(id<MTLBuffer>)variance
{
    if (!mean || !variance) {
        CharonMPSRefuse(@"MPSCNNNormalizationMeanAndVarianceState: -initWithMean:variance: was given no mean or no"
                        @" variance, so no state was made");
        return nil;
    }
    NSArray *resources = [NSArray arrayWithObjects:mean, variance, nil];
    MPSCNNNormalizationMeanAndVarianceState *made = [super initWithResources:resources];
    if (made) {
        made->_mean = mean;
        made->_variance = variance;
    }
    return made;
}

- (id<MTLBuffer>)mean { return _mean; }
- (id<MTLBuffer>)variance { return _variance; }

+ (instancetype)temporaryStateWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                        numberOfFeatureChannels:(NSUInteger)numberOfFeatureChannels
{
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : nil;
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    if (!device || !numberOfFeatureChannels) {
        CharonMPSRefuse(@"MPSCNNNormalizationMeanAndVarianceState: no device or no feature channels, so no"
                        @" state was made");
        return nil;
    }
    id<MTLBuffer> mean = [device newBufferWithLength:numberOfFeatureChannels * sizeof(float)
                                             options:MTLResourceStorageModeShared];
    id<MTLBuffer> variance = [device newBufferWithLength:numberOfFeatureChannels * sizeof(float)
                                                options:MTLResourceStorageModeShared];
    if (!mean || !variance) {
        CharonMPSRefuse(@"MPSCNNNormalizationMeanAndVarianceState: the device made no %lu byte buffer, so no"
                        @" state was made",
                        (unsigned long)(numberOfFeatureChannels * sizeof(float)));
        return nil;
    }
    MPSCNNNormalizationMeanAndVarianceState *state = [[self alloc] initWithMean:mean variance:variance];
    [state charon_mps_appendResource:mean];
    [state charon_mps_appendResource:variance];
    return state;
}

@end

@implementation MPSRNNMatrixTrainingState
@end
