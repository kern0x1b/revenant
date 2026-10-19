#import "CharonUserNotifications.h"

@implementation UNNotificationServiceExtension

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *contentToDeliver))contentHandler
{
    contentHandler(request.content);
}

- (void)serviceExtensionTimeWillExpire
{
}

@end
