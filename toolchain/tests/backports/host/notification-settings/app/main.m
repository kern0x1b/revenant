#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#include <stdio.h>

static FILE *out;
static const char *side;

static void report(const char *check, NSString *value)
{
    fprintf(out, "%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *number(NSInteger value)
{
    return [NSString stringWithFormat:@"%ld", (long)value];
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"RevenantPort"] ? [name substringFromIndex:12] : name;
}

static void settings_checks(UNNotificationSettings *settings)
{
    report("settings-class", class_name(settings));
    report("authorization-status", number(settings.authorizationStatus));
    report("sound-setting", number(settings.soundSetting));
    report("badge-setting", number(settings.badgeSetting));
    report("alert-setting", number(settings.alertSetting));
    report("notification-center-setting", number(settings.notificationCenterSetting));
    report("lock-screen-setting", number(settings.lockScreenSetting));
    report("car-play-setting", number(settings.carPlaySetting));
    report("alert-style", number(settings.alertStyle));
    report("show-previews-setting", number(settings.showPreviewsSetting));
    report("critical-alert-setting", number(settings.criticalAlertSetting));
    report("provides-app-notification-settings", yes_no(settings.providesAppNotificationSettings));
    report("announcement-setting", number(settings.announcementSetting));
    report("time-sensitive-setting", number(settings.timeSensitiveSetting));
    report("scheduled-delivery-setting", number(settings.scheduledDeliverySetting));
    report("direct-messages-setting", number(settings.directMessagesSetting));
}

@interface RevenantAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation RevenantAppDelegate
@end

@interface RevenantSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RevenantSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    const char *path = getenv("REVENANT_SCENE_OUT");
    out = fopen(path ? path : "/dev/stdout", "w");
#ifdef REVENANT_PORT_SIDE
    side = "port";
#else
    side = "host";
#endif
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        settings_checks(settings);
        fclose(out);
        exit(0);
    }];
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantAppDelegate class]));
    }
}
