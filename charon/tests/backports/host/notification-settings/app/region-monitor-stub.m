#import "CharonUserNotifications.h"

// The harness's stand-in for the region monitor, which is compiled from UNLocationNotificationTrigger10.m in the port and is not built for
// Mac Catalyst (the location trigger is unavailable there). The settings are read through the center, which only reaches the monitor for a
// location request or for the list of pending ones; this test asks for neither, so the stub answers as an empty monitor.
@implementation CharonRegionMonitor

+ (CharonRegionMonitor *)charon_sharedMonitor
{
    static CharonRegionMonitor *monitor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        monitor = [[CharonRegionMonitor alloc] init];
    });
    return monitor;
}

- (NSError *)charon_monitorRequest:(UNNotificationRequest *)request
{
    return nil;
}

- (NSArray<UNNotificationRequest *> *)charon_requests
{
    return @[];
}

- (void)charon_removeRequestsWithIdentifiers:(NSSet<NSString *> *)identifiers
{
}

@end
