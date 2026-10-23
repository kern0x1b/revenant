#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>

static IMP RevenantOriginalSaveScreenshot;

static NSString *RevenantFrontmostApplicationIdentifier(id springBoard) {
    id application = ((id (*)(id, SEL))objc_msgSend)(springBoard, sel_registerName("_accessibilityFrontMostApplication"));
    if (application == nil) {
        return nil;
    }
    return ((id (*)(id, SEL))objc_msgSend)(application, sel_registerName("bundleIdentifier"));
}

static void RevenantSaveScreenshot(id self, SEL command, id argument) {
    ((void (*)(id, SEL, id))RevenantOriginalSaveScreenshot)(self, command, argument);
    id springBoard = ((id (*)(id, SEL))objc_msgSend)(NSClassFromString(@"UIApplication"), sel_registerName("sharedApplication"));
    NSString *identifier = RevenantFrontmostApplicationIdentifier(springBoard);
    if (identifier.length > 0) {
        notify_post([[@"org.revenant.screenshot." stringByAppendingString:identifier] UTF8String]);
    }
}

__attribute__((constructor)) static void RevenantScreenshotInstall(void) {
    Method method = class_getInstanceMethod(NSClassFromString(@"SBScreenShotter"), sel_registerName("saveScreenshot:"));
    if (method == NULL) {
        return;
    }
    RevenantOriginalSaveScreenshot = method_setImplementation(method, (IMP)RevenantSaveScreenshot);
}
