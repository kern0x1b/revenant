#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

@protocol RevenantMPSImageThresholdHooks <NSObject>
- (float)revenant_mps_thresholdValue;
- (float)revenant_mps_maximumValue;
- (const float *)revenant_mps_transform;
- (BOOL)revenant_mps_hasThreshold;
- (double)RevenantMPSThreshold:(double)value;
@end

static void RevenantMPSFillTransform(float *out, const float *transform)
{
    out[0] = 0.299f; out[1] = 0.587f; out[2] = 0.114f;
    if (transform)
        for (NSUInteger i = 0; i < 3; i++)
            out[i] = transform[i];
}

static BOOL RevenantMPSIsSingleChannel(MPSImage *image)
{
    return image.featureChannels <= 1;
}

@implementation MPSUnaryImageKernel (RevenantImageThreshold)

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    id<RevenantMPSImageThresholdHooks> kernel = (id<RevenantMPSImageThresholdHooks>)self;
    if (!RevenantMPSIsSingleChannel(sourceImage)) {
        RevenantMPSRefuse(@"%@: the image has %lu feature channels. The filter converts a "
                        "multi channel image to ONE scalar luminance with the linearGrayColorTransform "
                        "and then thresholds that, which this port does not implement, so nothing was "
                        "written. The path is owed; a one channel image is answered.",
                        what, (unsigned long)sourceImage.featureChannels);
        return;
    }
    if (!commandBuffer) {
        RevenantMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!kernel.revenant_mps_hasThreshold) {
        RevenantMPSRefuse(@"%@: the kernel carries no threshold value. Every one of the five declares "
                        "-initWithDevice: as NS_UNAVAILABLE and says the initializer carrying the value "
                        "is the one to use, so a kernel that did not get one is not a kernel a caller can "
                        "have, and nothing is written", what);
        return;
    }
    RevenantMPSImageMapUnary(sourceImage, destinationImage, self.clipRect, ^double(NSUInteger pixel,
                                                                                  NSUInteger channel,
                                                                                  double value) {
        (void)pixel; (void)channel;
        return [kernel RevenantMPSThreshold:value];
    }, what);
}

@end

#define REVENANT_MPS_IMAGE_THRESHOLD_STATE                                        \
    float _thresholdValue;                                                      \
    float _maximumValue;                                                        \
    float _revenantTransform[3];                                                  \
    BOOL _hasThreshold;

#define REVENANT_MPS_IMAGE_THRESHOLD_ACCESSORS                                    \
    - (float)revenant_mps_thresholdValue { return _thresholdValue; }             \
    - (float)revenant_mps_maximumValue { return _maximumValue; }                 \
    - (const float *)revenant_mps_transform { return _revenantTransform; }                \
    - (BOOL)revenant_mps_hasThreshold { return _hasThreshold; }

@interface MPSImageThresholdToZero (RevenantThresholdHooks) <RevenantMPSImageThresholdHooks> @end

@implementation MPSImageThresholdToZero {
REVENANT_MPS_IMAGE_THRESHOLD_STATE
}
REVENANT_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = 1.0f;
        _hasThreshold = YES;
        RevenantMPSFillTransform(_revenantTransform, transform);
    }
    return self;
}

- (double)RevenantMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? value : 0.0;
}
@end

@interface MPSImageThresholdToZeroInverse (RevenantThresholdHooks) <RevenantMPSImageThresholdHooks> @end

@implementation MPSImageThresholdToZeroInverse {
REVENANT_MPS_IMAGE_THRESHOLD_STATE
}
REVENANT_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = 1.0f;
        _hasThreshold = YES;
        RevenantMPSFillTransform(_revenantTransform, transform);
    }
    return self;
}

- (double)RevenantMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? 0.0 : value;
}
@end

@interface MPSImageThresholdTruncate (RevenantThresholdHooks) <RevenantMPSImageThresholdHooks> @end

@implementation MPSImageThresholdTruncate {
REVENANT_MPS_IMAGE_THRESHOLD_STATE
}
REVENANT_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = 1.0f;
        _hasThreshold = YES;
        RevenantMPSFillTransform(_revenantTransform, transform);
    }
    return self;
}

- (double)RevenantMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? (double)_thresholdValue : value;
}
@end

@interface MPSImageThresholdBinary (RevenantThresholdHooks) <RevenantMPSImageThresholdHooks> @end

@implementation MPSImageThresholdBinary {
REVENANT_MPS_IMAGE_THRESHOLD_STATE
}
REVENANT_MPS_IMAGE_THRESHOLD_ACCESSORS

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
        RevenantMPSFillTransform(_revenantTransform, transform);
    }
    return self;
}

- (double)RevenantMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? (double)_maximumValue : 0.0;
}
@end

@interface MPSImageThresholdBinaryInverse (RevenantThresholdHooks) <RevenantMPSImageThresholdHooks> @end

@implementation MPSImageThresholdBinaryInverse {
REVENANT_MPS_IMAGE_THRESHOLD_STATE
}
REVENANT_MPS_IMAGE_THRESHOLD_ACCESSORS

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
        RevenantMPSFillTransform(_revenantTransform, transform);
    }
    return self;
}

- (double)RevenantMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? 0.0 : (double)_maximumValue;
}
@end
