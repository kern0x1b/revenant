// MPSRNNSingleGateDescriptor, from the header of MPSRNNLayer.h in the SDK of iOS 16.4: a simple recurrent
// layer's descriptor. It adds its two weight sources to MPSRNNDescriptor and no other member.
//
// The factory is the only creation the 16.4 header declares. Its channels are the arguments, and every other
// member is the base class's default, as measured on the host (see facts/MetalPerformanceShaders/MPSRNNSingleGateDescriptor.md).
// A zero channel count is accepted, as the host accepts it: the factory answers an object with 0 and 0. The
// header asks for at least 1 and says nothing of the refusal, so none is made here either.

#import "CharonMPS.h"

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

// Both weight sources are retained, and nil on a new descriptor: the header's "assumed zero weights".

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
