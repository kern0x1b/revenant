// MPSCNNDepthWiseConvolutionDescriptor, from the header of MPSCNNConvolution.h in the SDK of iOS 16.4
// (MPSCNNConvolution.h:362-388, iOS 11.0): a convolution descriptor whose own member is channelMultiplier.
//
// The defaults are Apple's, measured on the macOS host by tests/backports/host/mps-cnn-descriptors against
// Apple's own object: every shape member 1 (kernelWidth, kernelHeight, inputFeatureChannels,
// outputFeatureChannels), strides 1, groups 1, dilation rates 1, neuronType None, neuronParameterA and B 1,
// and channelMultiplier 1.
//
// THE BASE CLASS LEAVES SOME OF THOSE AT ZERO. MPSCNNConvolutionDescriptor10.m's init sets the strides,
// groups, dilation rates and neuronType, and nothing else: the kernel size, the channel counts and the
// neuron parameters A and B are zero there, and channelMultiplier is derived from the channel counts, so
// it would be zero too. This class's init sets the values Apple's object starts with, after the base's.
// The base itself is not changed here; a fresh MPSCNNConvolutionDescriptor still answers the base's zeros.
//
// NOT CARRIED: fusedNeuronDescriptor. Apple's object starts with a non-nil MPSNNNeuronDescriptor and the
// port has no such class (it is an iOS 11.3 object, MPSCNNElements10.m:278), so this class answers the
// base's nil and the difference is recorded in facts/MetalPerformanceShaders/MPSCNNDepthWiseConvolutionDescriptor.md.

#import "CharonMPS.h"
#import "CharonMPS26.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNDepthWiseConvolutionDescriptor

// The header's four-argument factory (MPSCNNConvolution.h:177, iOS 11.0). MPSCNNConvolutionDescriptor10.m
// does not implement it, so a depthwise descriptor made by name would have no factory to answer; this one
// makes the same object the base's init makes and sets the four shape members the caller gave.
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
        // The shape members and the neuron parameters the base's init leaves at zero, at the values Apple's
        // fresh descriptor answers (measured). The neuron is None, so A and B are not read by any kernel.
        self.kernelWidth = 1;
        self.kernelHeight = 1;
        self.inputFeatureChannels = 1;
        self.outputFeatureChannels = 1;
        [self setNeuronType:MPSCNNNeuronTypeNone parameterA:1.0f parameterB:1.0f];
    }
    return self;
}

// channelMultiplier is outputFeatureChannels / inputFeatureChannels in whole numbers, which is what Apple's
// object answers at every pair measured: 1 for (1,1), 2 for (4,8), 1 for (4,6), 0 for (6,4), 1 for (3,4),
// 3 for (4,12), and 0 for (0,4). With no input channels there is no ratio and the answer is 0.
- (NSUInteger)channelMultiplier
{
    NSUInteger inputChannels = self.inputFeatureChannels;
    return inputChannels ? self.outputFeatureChannels / inputChannels : 0;
}

@end
