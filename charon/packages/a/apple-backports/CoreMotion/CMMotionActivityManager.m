#import <CoreMotion/CoreMotion.h>

// The activity manager of iOS 7, for a device with no motion coprocessor. The availability
// answer is NO, which is the answer the host gives on hardware without one. The authorization
// is NotDetermined, which is what the host answers for an application with no usage description.
// The queries and the updates are never delivered: the host, measured as a bare tool, calls
// neither handler and reports no error within four seconds (facts/CoreMotion/CMMotionActivity.md).
// Nothing here is measured by the port; a caller that waits for activity waits for ever, as it
// does on the host.
@implementation CMMotionActivityManager

+ (BOOL)isActivityAvailable
{
    return NO;
}

+ (CMAuthorizationStatus)authorizationStatus
{
    return CMAuthorizationStatusNotDetermined;
}

- (void)startActivityUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMMotionActivityHandler)handler
{
}

- (void)stopActivityUpdates
{
}

- (void)queryActivityStartingFromDate:(NSDate *)start toDate:(NSDate *)end toQueue:(NSOperationQueue *)queue withHandler:(CMMotionActivityQueryHandler)handler
{
}

@end
