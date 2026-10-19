#import <ARKit/ARKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

#import "CharonARKitPrivate.h"
#import "CharonARTracker.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

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

@synthesize wantsHDREnvironmentTextures = _wantsHDREnvironmentTextures;
@synthesize automaticImageScaleEstimationEnabled = _automaticImageScaleEstimationEnabled;
@synthesize automaticSkeletonScaleEstimationEnabled = _automaticSkeletonScaleEstimationEnabled;
@synthesize appClipCodeTrackingEnabled = _appClipCodeTrackingEnabled;
@dynamic initialWorldMap;


+ (BOOL)isSupported
{
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


@synthesize initialWorldMap = _initialWorldMap;

+ (BOOL)isSupported
{
    if (![CharonARTracker isSupported])
        return NO;
    return [CLLocationManager class] != nil;
}

@end
