#import "RevenantUserNotifications.h"

@implementation RevenantRegionMonitor

+ (RevenantRegionMonitor *)revenant_sharedMonitor
{
    static RevenantRegionMonitor *monitor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        monitor = [[RevenantRegionMonitor alloc] init];
    });
    return monitor;
}

- (NSError *)revenant_monitorRequest:(UNNotificationRequest *)request
{
    return nil;
}

- (NSArray<UNNotificationRequest *> *)revenant_requests
{
    return @[];
}

- (void)revenant_removeRequestsWithIdentifiers:(NSSet<NSString *> *)identifiers
{
}

@end
