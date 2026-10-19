#import <UIKit/UIKit.h>
#import <NotificationCenter/NotificationCenter.h>
#import "../CharonSayOnce.h"

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
