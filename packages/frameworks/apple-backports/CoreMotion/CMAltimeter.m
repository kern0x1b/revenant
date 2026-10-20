#import <CoreMotion/CoreMotion.h>

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
