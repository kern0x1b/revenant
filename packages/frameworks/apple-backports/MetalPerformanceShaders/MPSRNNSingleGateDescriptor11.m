#import "RevenantMPS.h"

@implementation MPSRNNSingleGateDescriptor {
    id <MPSCNNConvolutionDataSource> _inputWeights;
    id <MPSCNNConvolutionDataSource> _recurrentWeights;
}

+ (instancetype)createRNNSingleGateDescriptorWithInputFeatureChannels:(NSUInteger)inputFeatureChannels
                                                outputFeatureChannels:(NSUInteger)outputFeatureChannels
{
    MPSRNNSingleGateDescriptor *descriptor = [[self alloc] init];
    descriptor.inputFeatureChannels = inputFeatureChannels;
    descriptor.outputFeatureChannels = outputFeatureChannels;
    return descriptor;
}

- (id <MPSCNNConvolutionDataSource>)inputWeights
{
    return _inputWeights;
}

- (void)setInputWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _inputWeights = weights;
}

- (id <MPSCNNConvolutionDataSource>)recurrentWeights
{
    return _recurrentWeights;
}

- (void)setRecurrentWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _recurrentWeights = weights;
}

@end
