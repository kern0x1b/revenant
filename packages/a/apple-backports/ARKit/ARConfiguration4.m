// ARConfiguration4.m - the 16.0 configurations: a body pose and a tracked place.
//
// Split from ARConfiguration2.m because an object carries the API of one release, beside the
// raycast vocabulary in ARRaycast.m and the skeleton's joint names in ARKitConstants16.m.

#import <ARKit/ARKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

#import "CharonARKitPrivate.h"
#import "CharonARTracker.h"

// As in ARConfiguration.m: the settings that arrived after the release's own ARKit are carried with
// the header's own guard, and the values behind them are this device's.
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

// `ARConfiguration` is abstract and its initialiser is declared unavailable, which is the SDK telling a
// caller not to build one; a subclass is exactly what is being built here, so the calls that chain
// to it are the base class saying yes. Because the base class names no designated initialiser that a
// subclass can see - the one it has is private, and a category cannot mark a method designated -
// every -init below is reported as a designated initialiser reaching a non-designated one. The chain
// is the base class's own values and nothing else, so the check has nothing left to add here.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation ARBodyTrackingConfiguration
{
    ARPlaneDetection _planeDetection;
    AREnvironmentTexturing _environmentTexturing;
    NSSet<ARReferenceImage *> *_detectionImages;
    NSInteger _maxTrackedImages;
}

- (instancetype)init
{
    self = [super initCharonCommon];
    if (self)
        _planeDetection = ARPlaneDetectionHorizontal;
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }


+ (BOOL)supportsAppClipCodeTracking { return NO; }

- (BOOL)isAutoFocusEnabled { return YES; }
- (void)setAutoFocusEnabled:(BOOL)autoFocusEnabled { (void)autoFocusEnabled; }

- (ARPlaneDetection)planeDetection { return _planeDetection; }
- (void)setPlaneDetection:(ARPlaneDetection)planeDetection { _planeDetection = planeDetection; }

- (AREnvironmentTexturing)environmentTexturing { return _environmentTexturing; }
- (void)setEnvironmentTexturing:(AREnvironmentTexturing)environmentTexturing { _environmentTexturing = environmentTexturing; }

// The two settings below are answered for the same reason and with the same shape as
// ARWorldTrackingConfiguration's in ARConfiguration2.m, and the reason is measured there: nothing
// about them needs a sensor this device has not. The pictures to look for are found in the camera's
// own frames, and how many of them at once is a number the caller sets, so what the header's own
// attributes say is what these answer -- the set is copied, so a later change to the caller's set
// does not change the configuration, and nil resets it, which for a `null_resettable` property means
// empty rather than nil. The release has both pairs in this class's own instance list
// (`detectionImages` 0x1af1684fc, `setDetectionImages:` 0x1af16850c, `maximumNumberOfTrackedImages`
// 0x1af168558, `setMaximumNumberOfTrackedImages:` 0x1af166620 in ARKitCore of the 16.0 arm64e cache).
//
// What the tracker does with either is a separate question and this file does not answer it, here or
// there: the tracker matches features between consecutive frames and reports planes, and it names
// neither ARReferenceImage nor ARImageAnchor, so no image anchor is ever reported and the number
// limits nothing. The two rows say so.
- (NSSet<ARReferenceImage *> *)detectionImages
{
    return _detectionImages ?: [NSSet set];
}

- (void)setDetectionImages:(NSSet<ARReferenceImage *> *)detectionImages
{
    _detectionImages = [detectionImages copy];
}

- (NSInteger)maximumNumberOfTrackedImages { return _maxTrackedImages; }
- (void)setMaximumNumberOfTrackedImages:(NSInteger)maximumNumberOfTrackedImages
{
    _maxTrackedImages = maximumNumberOfTrackedImages;
}

// The four settings are stored, as ARWorldTrackingConfiguration's are (ARConfiguration2.m): what a caller sets is what
// it reads back. initialWorldMap is not stored, as there.
@synthesize wantsHDREnvironmentTextures = _wantsHDREnvironmentTextures;
@synthesize automaticImageScaleEstimationEnabled = _automaticImageScaleEstimationEnabled;
@synthesize automaticSkeletonScaleEstimationEnabled = _automaticSkeletonScaleEstimationEnabled;
@synthesize appClipCodeTrackingEnabled = _appClipCodeTrackingEnabled;
@dynamic initialWorldMap;


+ (BOOL)isSupported
{
    // A body is a pose the release estimates from the frames with a neural network. This port builds no estimator, so
    // a session of this configuration would run and never report a body, and the answer is NO. Apple documents body
    // tracking as needing an A12 chip or later; this device is an A5. That requirement is the documented one and was
    // not measured here, since the host is a Mac and answers NO for every configuration. This is the state until the
    // body pose estimator lands (the v-impl-vision-models band); then the configuration is built on that estimator and
    // this answer comes from the estimator's availability (facts/ARKit/ConfigurationSettings.md).
    return NO;
}

@end

@implementation ARPositionalTrackingConfiguration
{
    ARPlaneDetection _planeDetection;
}

- (instancetype)init
{
    self = [super initCharonCommon];
    if (self)
        _planeDetection = ARPlaneDetectionHorizontal;
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }


- (BOOL)isAutoFocusEnabled { return YES; }
- (void)setAutoFocusEnabled:(BOOL)autoFocusEnabled { (void)autoFocusEnabled; }

- (ARPlaneDetection)planeDetection { return _planeDetection; }
- (void)setPlaneDetection:(ARPlaneDetection)planeDetection { _planeDetection = planeDetection; }


@dynamic initialWorldMap;

+ (BOOL)isSupported
{
    // A tracked image and a place to put it: the camera, and a location service.
    if (![CharonARTracker isSupported])
        return NO;
    return [CLLocationManager class] != nil;
}

@end