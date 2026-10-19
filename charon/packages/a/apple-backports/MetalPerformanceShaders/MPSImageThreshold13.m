#import "CharonMPS.h"
#import "CharonMPSImage.h"

@protocol CharonMPSImageThresholdHooks <NSObject>
- (float)charon_mps_thresholdValue;
- (float)charon_mps_maximumValue;
- (const float *)charon_mps_transform;
- (BOOL)charon_mps_hasThreshold;
- (double)CharonMPSThreshold:(double)value;
@end

static void CharonMPSFillTransform(float *out, const float *transform)
{
    out[0] = 0.299f; out[1] = 0.587f; out[2] = 0.114f;
    if (transform)
        for (NSUInteger i = 0; i < 3; i++)
            out[i] = transform[i];
}

static BOOL CharonMPSIsSingleChannel(MPSImage *image)
{
    return image.featureChannels <= 1;
}

@implementation MPSUnaryImageKernel (CharonImageThreshold)

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    id<CharonMPSImageThresholdHooks> kernel = (id<CharonMPSImageThresholdHooks>)self;
    if (!CharonMPSIsSingleChannel(sourceImage)) {
        CharonMPSRefuse(@"%@: the image has %lu feature channels. The filter converts a "
                        "multi channel image to ONE scalar luminance with the linearGrayColorTransform "
                        "and then thresholds that, which this port does not implement, so nothing was "
                        "written. The path is owed; a one channel image is answered.",
                        what, (unsigned long)sourceImage.featureChannels);
        return;
    }
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!kernel.charon_mps_hasThreshold) {
        CharonMPSRefuse(@"%@: the kernel carries no threshold value. Every one of the five declares "
                        "-initWithDevice: as NS_UNAVAILABLE and says the initializer carrying the value "
                        "is the one to use, so a kernel that did not get one is not a kernel a caller can "
                        "have, and nothing is written", what);
        return;
    }
    CharonMPSImageMapUnary(sourceImage, destinationImage, self.clipRect, ^double(NSUInteger pixel,
                                                                                  NSUInteger channel,
                                                                                  double value) {
        (void)pixel; (void)channel;
        return [kernel CharonMPSThreshold:value];
    }, what);
}

@end

#define CHARON_MPS_IMAGE_THRESHOLD_STATE                                        \
    float _thresholdValue;                                                      \
    float _maximumValue;                                                        \
    float _charonTransform[3];                                                  \
    BOOL _hasThreshold;

#define CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS                                    \
    - (float)charon_mps_thresholdValue { return _thresholdValue; }             \
    - (float)charon_mps_maximumValue { return _maximumValue; }                 \
    - (const float *)charon_mps_transform { return _charonTransform; }                \
    - (BOOL)charon_mps_hasThreshold { return _hasThreshold; }

@interface MPSImageThresholdToZero (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdToZero {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = 1.0f;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? value : 0.0;
}
@end

@interface MPSImageThresholdToZeroInverse (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdToZeroInverse {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = 1.0f;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? 0.0 : value;
}
@end

@interface MPSImageThresholdTruncate (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdTruncate {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = 1.0f;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? (double)_thresholdValue : value;
}
@end

@interface MPSImageThresholdBinary (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdBinary {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    return [self initWithDevice:device thresholdValue:thresholdValue maximumValue:1.0f
            linearGrayColorTransform:transform];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
                 maximumValue:(float)maximumValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = maximumValue;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? (double)_maximumValue : 0.0;
}
@end

@interface MPSImageThresholdBinaryInverse (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdBinaryInverse {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    return [self initWithDevice:device thresholdValue:thresholdValue maximumValue:1.0f
            linearGrayColorTransform:transform];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
                 maximumValue:(float)maximumValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = maximumValue;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? 0.0 : (double)_maximumValue;
}
@end
