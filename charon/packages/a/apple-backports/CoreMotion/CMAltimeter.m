#import <CoreMotion/CoreMotion.h>

// The altimeter of iOS 8 and, for absolute altitude, iOS 15, for a device with no barometer. Both availability answers are
// NO, which is the answer the host gives on hardware without one. The authorization is NotDetermined, which is what the host
// answers for an application with no usage description. The updates are never delivered: the host, measured as a bare tool,
// calls neither handler and reports no error within four seconds (facts/CoreMotion/CMAltimeter.md). Nothing here is measured
// by the port; a caller that waits for altitude waits for ever, as it does on the host.
@implementation CMAltimeter

+ (BOOL)isRelativeAltitudeAvailable
{
    return NO;
}

+ (BOOL)isAbsoluteAltitudeAvailable
{
    return NO;
}

+ (CMAuthorizationStatus)authorizationStatus
{
    return CMAuthorizationStatusNotDetermined;
}

- (void)startRelativeAltitudeUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMAltitudeHandler)handler
{
}

- (void)stopRelativeAltitudeUpdates
{
}

- (void)startAbsoluteAltitudeUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMAbsoluteAltitudeHandler)handler
{
}

- (void)stopAbsoluteAltitudeUpdates
{
}

@end
