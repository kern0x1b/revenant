#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const RevenantRegisteredTypesKey = @"org.revenant.apple-backports.UIUserNotificationTypes";
static char revenant_remote_registered_key;

static UIUserNotificationType revenant_registered_types(void)
{
    return (UIUserNotificationType)[[[NSUserDefaults standardUserDefaults] objectForKey:RevenantRegisteredTypesKey] unsignedIntegerValue];
}

@implementation UIApplication (RevenantUserNotificationSettings)

- (void)registerUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    UIUserNotificationType types = notificationSettings.types & (UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert);
    if (notificationSettings.categories.count)
        NSLog(@"registerUserNotificationSettings: iOS %@ shows no actions on notifications, so the categories %@ are not registered and currentUserNotificationSettings reports none", [UIDevice currentDevice].systemVersion, [notificationSettings.categories valueForKey:@"identifier"]);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(types) forKey:RevenantRegisteredTypesKey];
    [defaults synchronize];
    if ([objc_getAssociatedObject(self, &revenant_remote_registered_key) boolValue])
        [self registerForRemoteNotificationTypes:(UIRemoteNotificationType)types];
    dispatch_async(dispatch_get_main_queue(), ^{
        id<UIApplicationDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(application:didRegisterUserNotificationSettings:)])
            [delegate application:self didRegisterUserNotificationSettings:self.currentUserNotificationSettings];
    });
}

- (UIUserNotificationSettings *)currentUserNotificationSettings
{
    return [UIUserNotificationSettings settingsForTypes:revenant_registered_types() categories:nil];
}

- (void)registerForRemoteNotifications
{
    objc_setAssociatedObject(self, &revenant_remote_registered_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIUserNotificationType types = revenant_registered_types();
    if (types == UIUserNotificationTypeNone) {
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"iOS %@ hands out a device token only for a set of notification types, and none were registered; call -registerUserNotificationSettings: first", [UIDevice currentDevice].systemVersion]}];
        dispatch_async(dispatch_get_main_queue(), ^{
            id<UIApplicationDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)])
                [delegate application:self didFailToRegisterForRemoteNotificationsWithError:error];
        });
        return;
    }
    [self registerForRemoteNotificationTypes:(UIRemoteNotificationType)types];
}

- (BOOL)isRegisteredForRemoteNotifications
{
    return [self enabledRemoteNotificationTypes] != UIRemoteNotificationTypeNone;
}

@end
