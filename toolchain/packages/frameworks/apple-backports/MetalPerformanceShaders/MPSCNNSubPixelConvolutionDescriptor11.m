#import "RevenantMPS.h"
#import "RevenantMPS26.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNSubPixelConvolutionDescriptor {
    NSUInteger _subPixelScaleFactor;
}

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

- (id)copyWithZone:(NSZone *)zone
{
    MPSCNNSubPixelConvolutionDescriptor *copy = [super copyWithZone:zone];
    copy->_subPixelScaleFactor = _subPixelScaleFactor;
    return copy;
}

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
