#import <Foundation/Foundation.h>

@class UNUserNotificationCenter, UNNotification, UNNotificationResponse;
typedef NSUInteger UNNotificationPresentationOptions;

@protocol UNUserNotificationCenterDelegate <NSObject>
@optional
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler;
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler;
- (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(UNNotification *)notification;
@end

__attribute__((used)) static void revenantEmitProtocols(void)
{
    (void)@protocol(UNUserNotificationCenterDelegate);
}
