#import "CharonUserNotifications.h"

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
