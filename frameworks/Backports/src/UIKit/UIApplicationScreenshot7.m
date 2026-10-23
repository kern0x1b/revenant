#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

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
