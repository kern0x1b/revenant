// ARGeoTrackingConfiguration.m - the geographic configuration at 14.0: carried so its name resolves and its
// initialisers answer, and not supported on this device.
//
// A geo-tracking session places the camera against a map of the place the device stands in, and it needs an A12
// chip or later. This device is an iPhone 4S with an A5, so +isSupported answers NO, and a session started with the
// configuration is refused through session:didFailWithError:, as every unsupported configuration is (ARSession.m).
// Its settings and its availability checks are owed rows (registry/ARKit/ios14shells.json), and
// facts/ARKit/AbsentClasses.md says what is measured and what is documented.

#import <ARKit/ARKit.h>

#import "CharonARKitPrivate.h"

// ARKit's own declarations of this class are at ios(14.0); it is built for the release that carries them with the
// header's guard, as ARConfiguration2.m is.
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

// As in ARConfiguration2.m: the base class's initialiser is declared unavailable because the base class is abstract,
// and this subclass reaches it through the port's private name, so the chain is the base class's own.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation ARGeoTrackingConfiguration

- (instancetype)init
{
    self = [super initCharonCommon];
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }

+ (BOOL)isSupported
{
    // A camera and a gyroscope are not enough: the device must also have an A12 chip or later for geographic tracking.
    // This device has an A5. The requirement is Apple's documented one; the host is a Mac, and its answer is the same
    // NO, which says nothing about the device (facts/ARKit/AbsentClasses.md).
    return NO;
}

@end
