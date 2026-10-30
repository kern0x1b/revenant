#import "RevenantUserNotifications.h"
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface UNUserNotificationCenter (RevenantUserNotifications)
- (UILocalNotification *)revenant_localNotificationForRequest:(UNNotificationRequest *)request;
- (void)revenant_deliverRequest:(UNNotificationRequest *)request state:(UIApplicationState)state;
@end

@interface RevenantRegionMonitor : NSObject <CLLocationManagerDelegate> {
@private
    CLLocationManager *_manager;
    NSMutableDictionary<NSString *, NSMutableArray *> *_byRegion;
}
+ (RevenantRegionMonitor *)revenant_sharedMonitor;
- (NSError *)revenant_monitorRequest:(UNNotificationRequest *)request;
- (NSArray<UNNotificationRequest *> *)revenant_requests;
- (void)revenant_removeRequestsWithIdentifiers:(NSSet<NSString *> *)identifiers;
@end
