#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static BOOL revenant_should_require_failure(id self, SEL _cmd, UIGestureRecognizer *recognizer, UIGestureRecognizer *other)
{
    id<UIGestureRecognizerDelegate> delegate = (id<UIGestureRecognizerDelegate>)self;
    if ([delegate respondsToSelector:@selector(gestureRecognizer:shouldRequireFailureOfGestureRecognizer:)])
        return [delegate gestureRecognizer:recognizer shouldRequireFailureOfGestureRecognizer:other];
    return NO;
}

static BOOL revenant_required_to_fail_by(id self, SEL _cmd, UIGestureRecognizer *recognizer, UIGestureRecognizer *other)
{
    id<UIGestureRecognizerDelegate> delegate = (id<UIGestureRecognizerDelegate>)self;
    if ([delegate respondsToSelector:@selector(gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:)])
        return [delegate gestureRecognizer:recognizer shouldBeRequiredToFailByGestureRecognizer:other];
    return NO;
}

static BOOL revenant_recognizer_requires_failure(UIGestureRecognizer *self, SEL _cmd, UIGestureRecognizer *other)
{
    return [self shouldRequireFailureOfGestureRecognizer:other];
}

static void revenant_prepare_delegate(id delegate)
{
    if (!delegate)
        return;
    Class cls = object_getClass(delegate);
    SEL require = @selector(_gestureRecognizer:shouldRequireFailureOfGestureRecognizer:);
    SEL fail = @selector(_gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:);
    if (!class_getInstanceMethod(cls, require) &&
        [delegate respondsToSelector:@selector(gestureRecognizer:shouldRequireFailureOfGestureRecognizer:)])
        class_addMethod(cls, require, (IMP)revenant_should_require_failure, "c16@0:4@8@12");
    if (!class_getInstanceMethod(cls, fail) &&
        [delegate respondsToSelector:@selector(gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:)])
        class_addMethod(cls, fail, (IMP)revenant_required_to_fail_by, "c16@0:4@8@12");
}

@interface RevenantGestureFailure7 : NSObject
@end

@implementation RevenantGestureFailure7
+ (void)load
{
    if ([UIGestureRecognizer instancesRespondToSelector:@selector(shouldRequireFailureOfGestureRecognizer:)])
        return;
    SEL setter = @selector(setDelegate:);
    Method method = class_getInstanceMethod([UIGestureRecognizer class], setter);
    void (*original)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(method);
    class_replaceMethod([UIGestureRecognizer class], setter, imp_implementationWithBlock(^(UIGestureRecognizer *recognizer, id delegate) {
        revenant_prepare_delegate(delegate);
        original(recognizer, setter, delegate);
    }), method_getTypeEncoding(method));
    Method hook = class_getInstanceMethod([UIGestureRecognizer class], sel_registerName("_shouldRequireFailureOfGestureRecognizer:"));
    if (hook)
        class_replaceMethod([UIGestureRecognizer class], sel_registerName("_shouldRequireFailureOfGestureRecognizer:"),
                            (IMP)revenant_recognizer_requires_failure, method_getTypeEncoding(hook));
}
@end

@implementation UIGestureRecognizer (RevenantFailure7)
- (BOOL)shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return NO;
}
- (BOOL)shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return NO;
}
@end
