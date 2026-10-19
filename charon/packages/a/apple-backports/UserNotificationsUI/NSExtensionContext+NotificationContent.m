#import <UIKit/UIKit.h>
#import <UserNotificationsUI/UserNotificationsUI.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation NSExtensionContext (UNNotificationContentExtension)

@dynamic notificationActions;

- (NSArray<UNNotificationAction *> *)notificationActions
{
    return objc_getAssociatedObject(self, @selector(notificationActions)) ?: @[];
}

- (void)setNotificationActions:(NSArray<UNNotificationAction *> *)notificationActions
{
    objc_setAssociatedObject(self, @selector(notificationActions), notificationActions, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
