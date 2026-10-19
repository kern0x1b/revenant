#import <CoreMotion/CoreMotion.h>

// The pedometer of iOS 8, for a device with no motion coprocessor. Every availability answer is NO, which is the answer the
// host gives on hardware without one. The authorization is NotDetermined, which is what the host answers for an application
// with no usage description. The queries and the updates are never delivered: the host, measured as a bare tool, calls
// neither handler and reports no error within four seconds (facts/CoreMotion/CMPedometer.md). Nothing here is measured by
// the port; a caller that waits for steps waits for ever, as it does on the host.
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
