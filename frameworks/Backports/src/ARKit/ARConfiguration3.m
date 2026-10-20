#import <ARKit/ARKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

#import "RevenantARKitPrivate.h"
#import "RevenantARTracker.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation ARImageTrackingConfiguration
{
    NSInteger _maximumNumberOfTrackedImages;
    NSSet<ARReferenceImage *> *_trackingImages;
}


- (instancetype)init
{
    self = [super initRevenantCommon];
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }


- (BOOL)isAutoFocusEnabled { return YES; }
- (void)setAutoFocusEnabled:(BOOL)autoFocusEnabled { (void)autoFocusEnabled; }

- (NSInteger)maximumNumberOfTrackedImages { return _maximumNumberOfTrackedImages; }
- (void)setMaximumNumberOfTrackedImages:(NSInteger)maximumNumberOfTrackedImages {
    _maximumNumberOfTrackedImages = maximumNumberOfTrackedImages;
}

- (NSSet<ARReferenceImage *> *)trackingImages
{
    return _trackingImages;
}

- (void)setTrackingImages:(NSSet<ARReferenceImage *> *)trackingImages
{
    _trackingImages = [trackingImages copy];
}


+ (BOOL)isSupported
{
    return [RevenantARTracker isSupported];
}

@end

@implementation ARObjectScanningConfiguration
{
    ARPlaneDetection _planeDetection;
}

- (instancetype)init
{
    self = [super initRevenantCommon];
    if (self)
        _planeDetection = ARPlaneDetectionHorizontal;
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }


- (BOOL)isAutoFocusEnabled { return YES; }
- (void)setAutoFocusEnabled:(BOOL)autoFocusEnabled { (void)autoFocusEnabled; }

- (ARPlaneDetection)planeDetection { return _planeDetection; }
- (void)setPlaneDetection:(ARPlaneDetection)planeDetection { _planeDetection = planeDetection; }


+ (BOOL)isSupported
{
    return NO;
}

@end
