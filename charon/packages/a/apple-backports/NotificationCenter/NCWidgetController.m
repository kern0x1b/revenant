#import <UIKit/UIKit.h>
#import <NotificationCenter/NotificationCenter.h>
#import "../CharonSayOnce.h"

// The widget controller is what tells the system that a Today widget has content worth reloading.
// The record itself is real and lives where the rest of the port keeps per-application state (the
// NSUserDefaults convention UIApplication+UserNotificationSettings.m already uses), and an
// application can read back exactly what it wrote. What this release cannot do is act on it: iOS 6
// has no Notification Center, no Today widgets and no widget host, so there is nothing that would
// ever ask the widget to refresh. That is the whole of the seam, and it is said once, in the log,
// the first time the call is made.

static NSString *const CharonWidgetContentKeyPrefix = @"org.charon.apple-backports.NCWidgetHasContent.";

@implementation NCWidgetController

+ (instancetype)widgetController
{
    static NCWidgetController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[NCWidgetController alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init]))
        charon_say_once_for(@"NCWidgetController.setHasContent:forWidgetWithBundleIdentifier:",
                            @"CharonNotificationCenter: widget content flags are recorded per bundle identifier and read "
                            @"back, but this release has no Notification Center and no widget host, so nothing asks a "
                            @"widget to refresh because of them.");
    return self;
}

- (void)setHasContent:(BOOL)flag forWidgetWithBundleIdentifier:(NSString *)bundleID
{
    if (!bundleID.length)
        return;
    [[NSUserDefaults standardUserDefaults] setBool:flag forKey:[CharonWidgetContentKeyPrefix stringByAppendingString:bundleID]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
