#import <ARKit/ARKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

#import "CharonARKitPrivate.h"
#import "CharonARTracker.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

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
    (void)sceneReconstruction;
    return NO;
}

- (BOOL)isAutoFocusEnabled { return YES; }
- (void)setAutoFocusEnabled:(BOOL)autoFocusEnabled { (void)autoFocusEnabled; }

- (ARPlaneDetection)planeDetection { return _planeDetection; }
- (void)setPlaneDetection:(ARPlaneDetection)planeDetection { _planeDetection = planeDetection; }

- (AREnvironmentTexturing)environmentTexturing { return _environmentTexturing; }
- (void)setEnvironmentTexturing:(AREnvironmentTexturing)environmentTexturing { _environmentTexturing = environmentTexturing; }

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
    return NO;
}

@end
