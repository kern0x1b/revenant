#import <Foundation/Foundation.h>
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
