// ARConfiguration.m - the description of what a session is asked to do, and the questions the
// hardware answers about it.
//
// The base class and the video formats live here because they are questions about the camera: which
// device would be captured from, which formats it really has, and the two recommendations chosen
// from those. ARConfiguration2.m holds the subclasses' own settings, because those are the settings
// each one carries, and each class has exactly one implementation across the two files.
//
// `+[ARConfiguration isSupported]` and the three subclasses' own are the whole question an
// application asks before it does anything, and here the answer is the hardware's: a configuration
// that needs the camera and the gyroscope is supported on a device that has both, and one that
// needs a LiDAR's depth or a TrueDepth's face is not, which is what Apple answers for a device
// without those sensors.
//
// Source: ARKit of the arm64 shared cache of iOS 12.0, read with the image's symbols -
// `+[ARConfiguration isSupported]` at 0x19d3b54a0 and `+[ARWorldTrackingConfiguration isSupported]`
// at 0x19d3cfaf4, both of which reach `ARDeviceSupported`, a value computed once from the hardware.

#import <ARKit/ARKit.h>
#import <CoreLocation/CoreLocation.h>

#import "CharonARKitPrivate.h"
#import "CharonARKitPrivate.h"
#import "CharonARTracker.h"

// `+supportedVideoFormats`, `+configurableCaptureDeviceForPrimaryCamera` and the two recommendations
// are declared by the 16.0 headers and are implemented here for a runtime that predates them; the
// class itself only exists from 11.3. A caller reaching one of these is by definition on a release
// new enough for the answer, which is the same reasoning every other backport in this package uses.
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@implementation ARConfiguration

    
    
    
    @dynamic isSupported;
@synthesize worldAlignment = _worldAlignment;
    @synthesize lightEstimationEnabled = _lightEstimationEnabled;
    @synthesize providesAudioData = _providesAudioData;
// Apple's own ARConfiguration defines -init even though its header marks it NS_UNAVAILABLE:
// measured over ARKit of the arm64e shared cache of iOS 16.0 with modules/apple/objc.lua's
// inventory, `-init` is in ARConfiguration's OWN instance selector list, and so it is in the port's.
// The mark is the SDK telling a caller not to build the abstract base directly; the method is there
// and the subclasses below chain to it. See facts/ARKit/ARKit.md.
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
    // Scene semantics are read out of a depth sensor's classification of what the camera sees, and
    // this device has none, so there is no semantics to enable.
    return NO;
}

/// Whether a session may capture in HDR. It may not, and the reason is the camera rather than the
/// setting: HDR is a property of the pixel format a capture device offers, and every format this port
/// builds an ARVideoFormat from is an AVCaptureDeviceFormat, which on the releases this package
/// builds carries no HDR format at all - `-[ARVideoFormat isVideoHDRSupported]` answers NO for the
/// same reason and on the same measurement. A setter that stored YES would answer a caller that asked
/// for HDR and then hand the session a camera that cannot deliver it, which is what makes the setting
/// a lie; this one says no and stays said. The release carries both accessors, read with
/// tools/corpus/skeleton-table.lua in ARKitCore of the arm64e shared cache of iOS 16.0:
/// `videoHDRAllowed` at 0x1af0f3134 and `setVideoHDRAllowed:` at 0x1af0f313c.
- (BOOL)videoHDRAllowed { return NO; }
- (void)setVideoHDRAllowed:(BOOL)videoHDRAllowed { (void)videoHDRAllowed; }

/// Which semantic operation a session runs. None, always, and the setter says so rather than storing
/// a value nothing reads: `+supportsFrameSemantics:` above answers NO for every semantics, because a
/// semantics is a depth sensor's classification of the scene (ARConfiguration.h:27-35 names them
/// person segmentation and the two scene-depth kinds, and each of the three is read out of depth this
/// device has none of), so there is no semantics a caller could set that this port would honour. Left
/// to clang's own synthesis this property would store and return whatever was set, which reads as a
/// session running a classification it never runs. The release carries both accessors:
/// `frameSemantics` at 0x1af084078 and `setFrameSemantics:` at 0x1af0f1cd0.
- (ARFrameSemantics)frameSemantics { return ARFrameSemanticNone; }
- (void)setFrameSemantics:(ARFrameSemantics)frameSemantics { (void)frameSemantics; }

- (id)copyWithZone:(NSZone *)zone
{
    // A configuration describes what a session is asked to do; copying one and changing the copy
    // must not change the original, so every value the base class stores is carried over.
    ARConfiguration *copy = [[self class] allocWithZone:zone];
    copy.worldAlignment = self.worldAlignment;
    copy.lightEstimationEnabled = self.isLightEstimationEnabled;
    copy.providesAudioData = self.providesAudioData;
    return copy;
}

+ (NSArray<ARVideoFormat *> *)supportedVideoFormats
{
    // The formats the back camera really has, in the order the camera reports them, so that a format
    // offered here is one the session can be configured with.
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
    // The largest frame the primary camera can deliver, and the first one at that size.
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

/// The offered format whose frame is closest to the one asked for, measured on the log of each
/// dimension so that a factor of two in either direction costs the same.
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
    // The device, asked the question its own sensors can answer.
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

