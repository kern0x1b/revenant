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
}

- (void)startPedometerUpdatesFromDate:(NSDate *)start withHandler:(CMPedometerHandler)handler
{
}

- (void)stopPedometerUpdates
{
}

- (void)startPedometerEventUpdatesWithHandler:(CMPedometerEventHandler)handler
{
}

- (void)stopPedometerEventUpdates
{
}

@end
