#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface RevenantGestureRequireDelegate : NSObject <UIGestureRecognizerDelegate>
@end

@implementation RevenantGestureRequireDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}
@end

@interface RevenantGestureFailByDelegate : NSObject <UIGestureRecognizerDelegate>
@end

@implementation RevenantGestureFailByDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}
@end

@interface RevenantGesturePlainDelegate : NSObject <UIGestureRecognizerDelegate>
@end

@implementation RevenantGesturePlainDelegate
@end

@interface RevenantGestureFailureRecognizer : UIGestureRecognizer
@end

@implementation RevenantGestureFailureRecognizer
- (BOOL)shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}
@end

static const unsigned int RevenantGestureRequireBit = 0x20;
static const unsigned int RevenantGestureFailByBit = 0x40;

static unsigned int revenant_gesture_flags(UIGestureRecognizer *recognizer)
{
    Ivar flags = class_getInstanceVariable([UIGestureRecognizer class], "_gestureFlags");
    if (!flags)
        return 0xffff;
    return *(uint16_t *)((char *)(__bridge void *)recognizer + ivar_getOffset(flags));
}

static NSString *revenant_image_of(id object, SEL selector)
{
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    Dl_info info;
    if (!method || !dladdr((void *)method_getImplementation(method), &info) || !info.dli_fname)
        return @"none";
    return [NSString stringWithUTF8String:info.dli_fname].lastPathComponent;
}

REVENANT_CASE(gesture_failure)
{
    SEL require = sel_registerName("_gestureRecognizer:shouldRequireFailureOfGestureRecognizer:");
    SEL fail = sel_registerName("_gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:");
    SEL hook = sel_registerName("_shouldRequireFailureOfGestureRecognizer:");
    BOOL (*send2)(id, SEL, id, id) = (BOOL (*)(id, SEL, id, id))objc_msgSend;

    UIPanGestureRecognizer *bare = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:NULL];
    unsigned int base = revenant_gesture_flags(bare) & (RevenantGestureRequireBit | RevenantGestureFailByBit);

    UIPanGestureRecognizer *requiring = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:NULL];
    RevenantGestureRequireDelegate *requireDelegate = [[RevenantGestureRequireDelegate alloc] init];
    [requiring setDelegate:requireDelegate];
    unsigned int requireFlags = revenant_gesture_flags(requiring);
    revenant_expect_true(@"UIKit caches the require capability of a delegate that has only the public method",
                         ((requireFlags & RevenantGestureRequireBit) != 0 && (requireFlags & RevenantGestureFailByBit) == 0 && base == 0) != (BOOL)negative,
                         [NSString stringWithFormat:@"flags %#x, bare %#x", requireFlags, base]);

    UIPanGestureRecognizer *failedBy = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:NULL];
    RevenantGestureFailByDelegate *failByDelegate = [[RevenantGestureFailByDelegate alloc] init];
    [failedBy setDelegate:failByDelegate];
    unsigned int failFlags = revenant_gesture_flags(failedBy);
    revenant_expect_true(@"UIKit caches the be-required capability of a delegate that has only the public method",
                         ((failFlags & RevenantGestureFailByBit) != 0 && (failFlags & RevenantGestureRequireBit) == 0) != (BOOL)negative,
                         [NSString stringWithFormat:@"flags %#x", failFlags]);

    UIPanGestureRecognizer *plain = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:NULL];
    RevenantGesturePlainDelegate *plainDelegate = [[RevenantGesturePlainDelegate alloc] init];
    [plain setDelegate:plainDelegate];
    unsigned int plainFlags = revenant_gesture_flags(plain) & (RevenantGestureRequireBit | RevenantGestureFailByBit);
    revenant_expect_true(@"a delegate without the public methods leaves UIKit's capability bits clear",
                         (plainFlags == 0 && ![plainDelegate respondsToSelector:require] && ![plainDelegate respondsToSelector:fail]) != (BOOL)negative,
                         [NSString stringWithFormat:@"flags %#x", plainFlags]);

    BOOL forwardRequire = [requireDelegate respondsToSelector:require] && send2(requireDelegate, require, requiring, bare);
    BOOL forwardFail = [failByDelegate respondsToSelector:fail] && send2(failByDelegate, fail, failedBy, bare);
    revenant_expect_true(@"the private names answer what the public methods answer",
                         (forwardRequire && forwardFail) != (BOOL)negative,
                         [NSString stringWithFormat:@"require %d, be-required %d", forwardRequire, forwardFail]);

    RevenantGestureFailureRecognizer *recognizer = [[RevenantGestureFailureRecognizer alloc] init];
    BOOL hookAnswer = ((BOOL (*)(id, SEL, id))objc_msgSend)(recognizer, hook, bare);
    revenant_expect_true(@"a subclass's public hook reaches UIKit's private hook",
                         hookAnswer != (BOOL)negative,
                         [NSString stringWithFormat:@"answer %d, hook implemented in %@", hookAnswer, revenant_image_of(recognizer, hook)]);
}
