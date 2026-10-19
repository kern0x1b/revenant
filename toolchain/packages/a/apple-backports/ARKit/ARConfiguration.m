#import <ARKit/ARKit.h>
#import <CoreLocation/CoreLocation.h>

#import "CharonARKitPrivate.h"
#import "CharonARKitPrivate.h"
#import "CharonARTracker.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@implementation ARConfiguration

    
    
    
    @dynamic isSupported;
@synthesize worldAlignment = _worldAlignment;
    @synthesize lightEstimationEnabled = _lightEstimationEnabled;
    @synthesize providesAudioData = _providesAudioData;
- (instancetype)init
{
    return [super init];
}

- (instancetype)initCharonCommon
{
    return [self init];
}

+ (BOOL)supportsFrameSemantics:(ARFrameSemantics)frameSemantics
{
    return NO;
}

- (BOOL)videoHDRAllowed { return NO; }
- (void)setVideoHDRAllowed:(BOOL)videoHDRAllowed { (void)videoHDRAllowed; }

- (ARFrameSemantics)frameSemantics { return ARFrameSemanticNone; }
- (void)setFrameSemantics:(ARFrameSemantics)frameSemantics { (void)frameSemantics; }

- (id)copyWithZone:(NSZone *)zone
{
    ARConfiguration *copy = [[self class] allocWithZone:zone];
    copy.worldAlignment = self.worldAlignment;
    copy.lightEstimationEnabled = self.isLightEstimationEnabled;
    copy.providesAudioData = self.providesAudioData;
    return copy;
}

+ (NSArray<ARVideoFormat *> *)supportedVideoFormats
{
    NSArray<AVCaptureDeviceFormat *> *formats =
            [CharonARTracker supportedCaptureFormatsForPosition:AVCaptureDevicePositionBack];
    NSMutableArray<ARVideoFormat *> *result = [NSMutableArray arrayWithCapacity:formats.count];
    for (AVCaptureDeviceFormat *format in formats)
        [result addObject:[[ARVideoFormat alloc] initWithCaptureFormat:format]];
    return result;
}

+ (AVCaptureDevice *)configurableCaptureDeviceForPrimaryCamera
{
    return [CharonARTracker captureDeviceForPosition:AVCaptureDevicePositionBack];
}

+ (ARVideoFormat *)recommendedVideoFormatFor4KResolution
{
    return [self videoFormatNearestTo:CGSizeMake(3840, 2160)];
}

+ (ARVideoFormat *)recommendedVideoFormatForHighResolutionFrameCapturing
{
    ARVideoFormat *best = nil;
    CGFloat bestArea = 0;
    for (ARVideoFormat *format in self.supportedVideoFormats) {
        CGFloat area = format.imageResolution.width * format.imageResolution.height;
        if (area > bestArea) {
            bestArea = area;
            best = format;
        }
    }
    return best;
}

+ (ARVideoFormat *)videoFormatNearestTo:(CGSize)size
{
    ARVideoFormat *best = nil;
    CGFloat bestDistance = INFINITY;
    for (ARVideoFormat *format in self.supportedVideoFormats) {
        CGFloat width = format.imageResolution.width;
        CGFloat height = format.imageResolution.height;
        if (width <= 0 || height <= 0)
            continue;
        CGFloat distance = hypot(log(width / size.width), log(height / size.height));
        if (distance < bestDistance) {
            bestDistance = distance;
            best = format;
        }
    }
    return best;
}

+ (BOOL)isSupported
{
    return [CharonARTracker isSupported];
}

- (BOOL)isSupported
{
    return [[self class] isSupported];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>", NSStringFromClass([self class]), self];
}

@end
