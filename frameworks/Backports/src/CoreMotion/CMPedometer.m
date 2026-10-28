#import <CoreMotion/CoreMotion.h>

@implementation CMPedometer

+ (BOOL)isStepCountingAvailable
{
    return NO;
}

+ (BOOL)isDistanceAvailable
{
    return NO;
}

+ (BOOL)isFloorCountingAvailable
{
    return NO;
}

+ (BOOL)isPaceAvailable
{
    return NO;
}

+ (BOOL)isCadenceAvailable
{
    return NO;
}

+ (BOOL)isPedometerEventTrackingAvailable
{
    return NO;
}

+ (CMAuthorizationStatus)authorizationStatus
{
    return CMAuthorizationStatusNotDetermined;
}

- (void)queryPedometerDataFromDate:(NSDate *)start toDate:(NSDate *)end withHandler:(CMPedometerHandler)handler
{
    if (!handler)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(nil, [NSError errorWithDomain:CMErrorDomain code:CMErrorNotAvailable userInfo:nil]);
    });
}

- (void)startPedometerUpdatesFromDate:(NSDate *)start withHandler:(CMPedometerHandler)handler
{
    if (!handler)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(nil, [NSError errorWithDomain:CMErrorDomain code:CMErrorNotAvailable userInfo:nil]);
    });
}

- (void)stopPedometerUpdates
{
}

- (void)startPedometerEventUpdatesWithHandler:(CMPedometerEventHandler)handler
{
    if (!handler)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(nil, [NSError errorWithDomain:CMErrorDomain code:CMErrorNotAvailable userInfo:nil]);
    });
}

- (void)stopPedometerEventUpdates
{
}

@end
