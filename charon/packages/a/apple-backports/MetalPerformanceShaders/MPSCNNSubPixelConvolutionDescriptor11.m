// MPSCNNSubPixelConvolutionDescriptor, from the header of MPSCNNConvolution.h in the SDK of iOS 16.4
// (MPSCNNConvolution.h:326-360, iOS 11.0): a convolution descriptor whose own member is subPixelScaleFactor,
// the upscaling factor r of the sub-pixel reshape the header describes at :341-349.
//
// Measured on the macOS host against Apple's own object (tests/backports/host/mps-cnn-descriptors): the
// default subPixelScaleFactor is 1, and the copy keeps it. The shape members and the neuron parameters start
// at the values the depthwise class documents (MPSCNNDepthWiseConvolutionDescriptor11.m), for the same reason:
// the base's init leaves them at zero.
//
// NOT CHECKED HERE: Apple's setter aborts the process when outputFeatureChannels is not a multiple of the
// square of the factor (measured: 16 channels and a factor of 3 is a failed assertion in MPSCNNConvolution.mm:685).
// This class stores the value and does not assert, so that difference is recorded in
// facts/MetalPerformanceShaders/MPSCNNSubPixelConvolutionDescriptor.md and is not claimed as matched.

#import "CharonMPS.h"
#import "CharonMPS26.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNSubPixelConvolutionDescriptor {
    NSUInteger _subPixelScaleFactor;
}

// The header's four-argument factory (MPSCNNConvolution.h:177), inherited by this class from the base, which
// does not implement it. See MPSCNNDepthWiseConvolutionDescriptor11.m for the same factory.
+ (instancetype)cnnConvolutionDescriptorWithKernelWidth:(NSUInteger)kernelWidth
                                           kernelHeight:(NSUInteger)kernelHeight
                                   inputFeatureChannels:(NSUInteger)inputFeatureChannels
                                  outputFeatureChannels:(NSUInteger)outputFeatureChannels
{
    MPSCNNSubPixelConvolutionDescriptor *descriptor = [[self alloc] init];
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
        _subPixelScaleFactor = 1;
    }
    return self;
}

- (NSUInteger)subPixelScaleFactor
{
    return _subPixelScaleFactor;
}

- (void)setSubPixelScaleFactor:(NSUInteger)subPixelScaleFactor
{
    _subPixelScaleFactor = subPixelScaleFactor;
}

// The base's copy is made of the base's own fields, so this class adds its one member to the copy the base
// made. The copy is of this class: the base allocates [self class].
- (id)copyWithZone:(NSZone *)zone
{
    MPSCNNSubPixelConvolutionDescriptor *copy = [super copyWithZone:zone];
    copy->_subPixelScaleFactor = _subPixelScaleFactor;
    return copy;
}

// This class overrides -initWithCoder:, so it answers +supportsSecureCoding itself: the secure-coding rule
// refuses an archive of a subclass that does not, even when the base answers YES (measured: a round trip fails
// without this method and passes with it).
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        _subPixelScaleFactor = (NSUInteger)[aDecoder decodeInt64ForKey:@"subPixelScaleFactor"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeInt64:(int64_t)_subPixelScaleFactor forKey:@"subPixelScaleFactor"];
}

@end
