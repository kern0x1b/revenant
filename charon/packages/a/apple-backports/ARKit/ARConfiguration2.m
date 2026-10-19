// The subclasses' own settings: what the camera and the tracker honour, and what needs hardware
// this device has not. A setting that needs a sensor it has not is `@dynamic`, which is the honest
// spelling: the accessor is declared, the library does not answer it, and a call raises rather than
// quietly reporting a value nothing is behind.

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

/// The auto focus every configuration that has a camera declares, and this camera has one.
@interface ARConfiguration (CharonAutoFocus)
@property (nonatomic, assign, getter=isAutoFocusEnabled) BOOL autoFocusEnabled;
@end

@implementation ARWorldTrackingConfiguration
{
    ARPlaneDetection _planeDetection;
    AREnvironmentTexturing _environmentTexturing;
    NSSet<ARReferenceImage *> *_detectionImages;
    NSInteger _maxTrackedImages;
}

- (instancetype)init
{
    // `ARConfiguration`'s own initialiser is declared unavailable because it is abstract, so a
    // subclass starts from NSObject and carries its own state; the header's default for a world
    // map is horizontal plane detection.
    self = [super initCharonCommon];
    if (self)
        _planeDetection = ARPlaneDetectionHorizontal;
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }

+ (BOOL)supportsUserFaceTracking { return NO; }
+ (BOOL)supportsAppClipCodeTracking { return NO; }

+ (BOOL)supportsSceneReconstruction:(ARSceneReconstruction)sceneReconstruction
{
    // A mesh of the scene is read out of scene depth, and a depth sensor is what this device has not.
    (void)sceneReconstruction;
    return NO;
}

- (BOOL)isAutoFocusEnabled { return YES; }
- (void)setAutoFocusEnabled:(BOOL)autoFocusEnabled { (void)autoFocusEnabled; }

- (ARPlaneDetection)planeDetection { return _planeDetection; }
- (void)setPlaneDetection:(ARPlaneDetection)planeDetection { _planeDetection = planeDetection; }

- (AREnvironmentTexturing)environmentTexturing { return _environmentTexturing; }
- (void)setEnvironmentTexturing:(AREnvironmentTexturing)environmentTexturing { _environmentTexturing = environmentTexturing; }

// The two settings below are not one of the ones this file leaves @dynamic, because nothing about
// them needs a sensor this device has not: the pictures to look for are found in the camera's own
// frames, and how many of them at once is a number the caller sets. Both are declared in
// ARConfiguration.h - detectionImages at :267 as `copy, null_resettable`, maximumNumberOfTrackedImages
// at :283 - and what the header's own attributes say is what these answer: the set is copied, so a
// later change to the caller's set does not change the configuration, and nil resets it, which for a
// null_resettable property means empty rather than nil.
//
// What the tracker does with either is a separate question and this file does not answer it. The
// tracker matches features between consecutive frames and reports planes; it names neither
// ARReferenceImage nor ARImageAnchor, so no image anchor is ever reported and the number limits
// nothing. That is what the two registry rows say as well.
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

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; planeDetection = %lu>",
            NSStringFromClass([self class]), self, (unsigned long)_planeDetection];
}

// initialWorldMap is stored, as the other settings are: a session that starts with the configuration restores the
// map's tracker state into the tracker (ARSession.m), so the map is what the session starts from. It is not a relocalisation:
// the tracker does not match the live frames against the map, and facts/ARKit/ConfigurationSettings.md says what that means.
// The settings below are stored, as the release stores them: what a caller sets is what it reads back, and the
// defaults are the ones a fresh configuration answers on the host (facts/ARKit/ConfigurationSettings.md). A session
// does not act on any of them: the tracker builds no mesh, no face and no collaboration, and no object is matched.
// That is what the registry rows say, and it is not a value the configuration makes up.
@synthesize detectionObjects = _detectionObjects;
@synthesize wantsHDREnvironmentTextures = _wantsHDREnvironmentTextures;
@synthesize automaticImageScaleEstimationEnabled = _automaticImageScaleEstimationEnabled;
@synthesize collaborationEnabled = _collaborationEnabled;
@synthesize userFaceTrackingEnabled = _userFaceTrackingEnabled;
@synthesize appClipCodeTrackingEnabled = _appClipCodeTrackingEnabled;
@synthesize sceneReconstruction = _sceneReconstruction;
@dynamic maximumNumberOfTrackedImages;
@synthesize initialWorldMap = _initialWorldMap;

+ (BOOL)isSupported
{
    // A world-tracking session is a camera and a gyroscope, which is what this device has.
    return [CharonARTracker isSupported];
}

@end

@implementation AROrientationTrackingConfiguration

- (instancetype)init
{
    self = [super initCharonCommon];
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }

- (BOOL)isAutoFocusEnabled { return YES; }
- (void)setAutoFocusEnabled:(BOOL)autoFocusEnabled { (void)autoFocusEnabled; }

+ (BOOL)isSupported
{
    // The gyroscope alone, which is the one sensor this class needs and the one it was named for. The tracker asks
    // CMMotionManager's own deviceMotionAvailable, the same question the orientation session starts on.
    return [CharonARTracker isOrientationSupported];
}

@end

@implementation ARFaceTrackingConfiguration

- (instancetype)init
{
    self = [super initCharonCommon];
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }

+ (NSInteger)supportedNumberOfTrackedFaces { return 0; }
+ (BOOL)supportsWorldTracking { return NO; }

- (BOOL)isAutoFocusEnabled { return YES; }
- (void)setAutoFocusEnabled:(BOOL)autoFocusEnabled { (void)autoFocusEnabled; }

- (NSInteger)maximumNumberOfTrackedFaces { return 0; }
- (void)setMaximumNumberOfTrackedFaces:(NSInteger)maximumNumberOfTrackedFaces { (void)maximumNumberOfTrackedFaces; }

- (BOOL)isWorldTrackingEnabled { return NO; }
- (void)setWorldTrackingEnabled:(BOOL)worldTrackingEnabled { (void)worldTrackingEnabled; }

+ (BOOL)isSupported
{
    // A face is measured by a depth sensor across the face, and this device has none: no TrueDepth, and
    // no LiDAR either. Apple answers NO for a device without the sensor, and so does this.
    return NO;
}

@end
