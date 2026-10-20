#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <UserNotifications/UserNotifications.h>

NSDate *revenant_next_date_matching(NSCalendar *calendar, NSDateComponents *components, NSDate *after);
void revenant_on_main(void (^work)(void));
NSError *revenant_unsupported(NSString *reason);

@interface UNNotificationSound (RevenantUserNotifications)
- (NSString *)revenant_fileName;
@end

@interface UNNotificationTrigger (RevenantUserNotifications)
- (instancetype)initRevenantWithRepeats:(BOOL)repeats;
@end

@interface UNPushNotificationTrigger (RevenantUserNotifications)
+ (instancetype)revenant_pushTrigger;
@end

@interface UNNotification (RevenantUserNotifications)
+ (instancetype)notificationWithRequest:(UNNotificationRequest *)request date:(NSDate *)date;
@end

@interface UNNotificationResponse (RevenantUserNotifications)
+ (instancetype)responseWithNotification:(UNNotification *)notification actionIdentifier:(NSString *)actionIdentifier;
- (instancetype)initRevenantWithNotification:(UNNotification *)notification actionIdentifier:(NSString *)actionIdentifier;
@end

@interface UNNotificationAction (RevenantUserNotifications)
- (instancetype)initRevenantWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options;
- (NSString *)revenant_description;
@end

@interface UNTextInputNotificationAction (RevenantUserNotifications)
- (instancetype)initRevenantWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options
                    textInputButtonTitle:(NSString *)buttonTitle textInputPlaceholder:(NSString *)placeholder;
@end

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
