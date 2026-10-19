#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <UserNotifications/UserNotifications.h>

NSDate *charon_next_date_matching(NSCalendar *calendar, NSDateComponents *components, NSDate *after);
void charon_on_main(void (^work)(void));
NSError *charon_unsupported(NSString *reason);

@interface UNNotificationSound (CharonUserNotifications)
- (NSString *)charon_fileName;
@end

@interface UNNotificationTrigger (CharonUserNotifications)
- (instancetype)initCharonWithRepeats:(BOOL)repeats;
@end

@interface UNPushNotificationTrigger (CharonUserNotifications)
+ (instancetype)charon_pushTrigger;
@end

@interface UNNotification (CharonUserNotifications)
+ (instancetype)notificationWithRequest:(UNNotificationRequest *)request date:(NSDate *)date;
@end

@interface UNNotificationResponse (CharonUserNotifications)
+ (instancetype)responseWithNotification:(UNNotification *)notification actionIdentifier:(NSString *)actionIdentifier;
- (instancetype)initCharonWithNotification:(UNNotification *)notification actionIdentifier:(NSString *)actionIdentifier;
@end

@interface UNNotificationAction (CharonUserNotifications)
- (instancetype)initCharonWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options;
- (NSString *)charon_description;
@end

@interface UNTextInputNotificationAction (CharonUserNotifications)
- (instancetype)initCharonWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options
                    textInputButtonTitle:(NSString *)buttonTitle textInputPlaceholder:(NSString *)placeholder;
@end

// What UNLocationNotificationTrigger10.m needs from the centre, and what the centre needs from it. The
// trigger's own schedule is the region's, which CoreLocation watches since iPhone OS 4.0, so a request
// carrying one is not a UILocalNotification to schedule: it is a region to monitor, and the
// notification is presented when CoreLocation says the device entered or left it. The centre builds
// that notification, because a request's content is turned into one there and nowhere else.
@interface UNUserNotificationCenter (CharonUserNotifications)
- (UILocalNotification *)charon_localNotificationForRequest:(UNNotificationRequest *)request;
- (void)charon_deliverRequest:(UNNotificationRequest *)request state:(UIApplicationState)state;
@end

@interface CharonRegionMonitor : NSObject <CLLocationManagerDelegate> {
@private
    CLLocationManager *_manager;
    NSMutableDictionary<NSString *, NSMutableArray *> *_byRegion;
}
+ (CharonRegionMonitor *)charon_sharedMonitor;
- (NSError *)charon_monitorRequest:(UNNotificationRequest *)request;
- (NSArray<UNNotificationRequest *> *)charon_requests;
- (void)charon_removeRequestsWithIdentifiers:(NSSet<NSString *> *)identifiers;
@end
