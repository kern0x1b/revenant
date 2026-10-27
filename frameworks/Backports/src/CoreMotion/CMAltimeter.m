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
    if (!handler)
        return;
    [(queue ?: [NSOperationQueue mainQueue]) addOperationWithBlock:^{
        handler(nil, [NSError errorWithDomain:CMErrorDomain code:CMErrorNotAvailable userInfo:nil]);
    }];
}

- (void)stopRelativeAltitudeUpdates
{
}

- (void)startAbsoluteAltitudeUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMAbsoluteAltitudeHandler)handler
{
    if (!handler)
        return;
    [(queue ?: [NSOperationQueue mainQueue]) addOperationWithBlock:^{
        handler(nil, [NSError errorWithDomain:CMErrorDomain code:CMErrorNotAvailable userInfo:nil]);
    }];
}

- (void)stopAbsoluteAltitudeUpdates
{
}

@end
