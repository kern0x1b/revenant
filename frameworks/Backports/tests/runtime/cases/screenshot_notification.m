#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>
#import <notify.h>

// The screenshot tweak posts the Darwin notification for the application in front. The backport
// must turn it into UIApplicationUserDidTakeScreenshotNotification, once, on the main thread. The
// negative control posts a name that is not this application's, so nothing may arrive, and it still
// expects one delivery: the driver requires the negative run to fail.
REVENANT_CASE(screenshot_notification)
{
    NSString *application = [[NSBundle mainBundle] bundleIdentifier] ?: [[NSProcessInfo processInfo] processName];
    NSString *name = negative ? @"org.revenant.screenshot.not-this-application"
                              : [@"org.revenant.screenshot." stringByAppendingString:application];
    __block NSInteger deliveries = 0;
    __block BOOL onMainThread = NO;
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification
                                                                  object:nil
                                                                   queue:nil
                                                              usingBlock:^(NSNotification *note) {
        deliveries++;
        onMainThread = [NSThread isMainThread];
    }];
    notify_post([name UTF8String]);
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (deliveries == 0 && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    revenant_expect_integer(@"the screenshot notification reaches the application once", deliveries, 1);
    if (!negative) {
        revenant_expect_integer(@"the screenshot notification is posted on the main thread", onMainThread ? 1 : 0, 1);
    }
}
