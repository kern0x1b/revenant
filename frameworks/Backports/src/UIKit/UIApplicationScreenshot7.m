#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

// SpringBoard cannot post UIApplicationUserDidTakeScreenshotNotification into an application, so
// the screenshot tweak posts a Darwin notification named for the application that was in front.
// This library observes the name for its own application and posts the UIKit notification on the
// main queue. The name is the same rule the tweak uses: the prefix and the bundle identifier, or
// the process name when the process has no bundle.
static NSString *RevenantScreenshotApplicationName(void) {
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
    return identifier ?: [[NSProcessInfo processInfo] processName];
}

static void RevenantScreenshotTaken(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationUserDidTakeScreenshotNotification
                                                            object:[UIApplication sharedApplication]];
    });
}

__attribute__((constructor)) static void RevenantScreenshotObserve(void) {
    NSString *name = [@"org.revenant.screenshot." stringByAppendingString:RevenantScreenshotApplicationName()];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, RevenantScreenshotTaken,
                                    (__bridge CFStringRef)name, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
