// ARConfiguration3.m - the 12.0 configurations: a tracked image and a scanned object.
//
// Split from ARConfiguration2.m because an object carries the API of one release, beside the
// plane's geometry in ARPlaneGeometry.m and the reference object's constants in
// ARKitConstants12.m.

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

@implementation ARImageTrackingConfiguration
{
    NSInteger _maximumNumberOfTrackedImages;
    NSSet<ARReferenceImage *> *_trackingImages;
}


- (instancetype)init
{
    self = [super initCharonCommon];
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }


- (BOOL)isAutoFocusEnabled { return YES; }
- (void)setAutoFocusEnabled:(BOOL)autoFocusEnabled { (void)autoFocusEnabled; }

- (NSInteger)maximumNumberOfTrackedImages { return _maximumNumberOfTrackedImages; }
- (void)setMaximumNumberOfTrackedImages:(NSInteger)maximumNumberOfTrackedImages {
    _maximumNumberOfTrackedImages = maximumNumberOfTrackedImages;
}

// The pictures the session is asked to look for, and the row's own reading of the property: the set
// as the caller set it, copied so that a later change to their set does not change the configuration.
// ARConfiguration.h:421 declares it `copy`, which is the copy and nothing more.
//
// What the tracker does with the set is a separate question and this file does not answer it: the
// tracker matches features between frames and reports planes, and it names neither ARReferenceImage
// nor ARImageAnchor, so no image anchor comes from it. That is the row's effect as well.
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
    // A tracked image is found in the camera's frames and needs no depth sensor.
    return [CharonARTracker isSupported];
}

@end

@implementation ARObjectScanningConfiguration
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


+ (BOOL)isSupported
{
    // Object scanning reads a mesh out of the depth the camera sees; without a depth sensor there is
    // no mesh to read, and the framework is right to say so.
    return NO;
}

@end