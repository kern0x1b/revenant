#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#include <stdio.h>

// A bundled Mac Catalyst app that has never asked for notification authorization. Its scene delegate asks the notification center for the
// settings, and each setting the notification settings answer is written as one "side<TAB>check<TAB>value" line to the file named by
// CHARON_SCENE_OUT, then the app quits. getNotificationSettings does not prompt: a bundle that never asked reads "not determined", with the
// per-setting values the host gives it. In the port's build the classes are compiled with their names renamed to CharonPort<name>, so the
// host's class is still the one the center is, and the port's is the one measured there. run.sh builds both and diffs them.

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
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
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

@interface CharonAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CharonAppDelegate
@end

@interface CharonSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    const char *path = getenv("CHARON_SCENE_OUT");
    out = fopen(path ? path : "/dev/stdout", "w");
#ifdef CHARON_PORT_SIDE
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
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CharonAppDelegate class]));
    }
}
