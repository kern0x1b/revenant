#import "RevenantMPS.h"
#import "RevenantMPS26.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNDepthWiseConvolutionDescriptor

+ (instancetype)cnnConvolutionDescriptorWithKernelWidth:(NSUInteger)kernelWidth
                                           kernelHeight:(NSUInteger)kernelHeight
                                   inputFeatureChannels:(NSUInteger)inputFeatureChannels
                                  outputFeatureChannels:(NSUInteger)outputFeatureChannels
{
    MPSCNNDepthWiseConvolutionDescriptor *descriptor = [[self alloc] init];
    descriptor.kernelWidth = kernelWidth;
    descriptor.kernelHeight = kernelHeight;
    descriptor.inputFeatureChannels = inputFeatureChannels;
    descriptor.outputFeatureChannels = outputFeatureChannels;
    return descriptor;
}

- (instancetype)init
{
    if ((self = [super init])) {
        self.kernelWidth = 1;
        self.kernelHeight = 1;
        self.inputFeatureChannels = 1;
        self.outputFeatureChannels = 1;
        [self setNeuronType:MPSCNNNeuronTypeNone parameterA:1.0f parameterB:1.0f];
    }
    return self;
}

- (NSUInteger)channelMultiplier
{
    NSUInteger inputChannels = self.inputFeatureChannels;
    return inputChannels ? self.outputFeatureChannels / inputChannels : 0;
}

@end
