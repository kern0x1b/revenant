#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static void revenant_collect_descendants(UIView *view, NSMutableArray *found)
{
    for (UIView *subview in view.subviews) {
        [found addObjectsFromArray:subview.gestureRecognizers];
        revenant_collect_descendants(subview, found);
    }
}

static BOOL revenant_requires_failure(UIGestureRecognizer *recognizer, UIGestureRecognizer *other)
{
    id delegate = recognizer.delegate;
    if ([delegate respondsToSelector:@selector(gestureRecognizer:shouldRequireFailureOfGestureRecognizer:)] && [delegate gestureRecognizer:recognizer shouldRequireFailureOfGestureRecognizer:other])
        return YES;
    return [recognizer shouldRequireFailureOfGestureRecognizer:other];
}

static BOOL revenant_required_to_fail_by(UIGestureRecognizer *recognizer, UIGestureRecognizer *other)
{
    id delegate = recognizer.delegate;
    if ([delegate respondsToSelector:@selector(gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:)] && [delegate gestureRecognizer:recognizer shouldBeRequiredToFailByGestureRecognizer:other])
        return YES;
    return [recognizer shouldBeRequiredToFailByGestureRecognizer:other];
}

static void revenant_arbitrate(UIView *view, UIGestureRecognizer *recognizer)
{
    NSMutableArray *others = [NSMutableArray array];
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview)
        [others addObjectsFromArray:ancestor.gestureRecognizers];
    revenant_collect_descendants(view, others);
    for (UIGestureRecognizer *other in others) {
        if (other == recognizer)
            continue;
        if (revenant_requires_failure(recognizer, other) || revenant_required_to_fail_by(other, recognizer))
            [recognizer requireGestureRecognizerToFail:other];
        if (revenant_requires_failure(other, recognizer) || revenant_required_to_fail_by(recognizer, other))
            [other requireGestureRecognizerToFail:recognizer];
    }
}

@interface RevenantGestureFailure7 : NSObject
@end

@implementation RevenantGestureFailure7

+ (void)load
{
    if ([UIGestureRecognizer instancesRespondToSelector:@selector(shouldRequireFailureOfGestureRecognizer:)])
        return;
    SEL add = @selector(addGestureRecognizer:);
    Method method = class_getInstanceMethod([UIView class], add);
    void (*original)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(method);
    class_replaceMethod([UIView class], add, imp_implementationWithBlock(^(UIView *view, UIGestureRecognizer *recognizer) {
        original(view, add, recognizer);
        revenant_arbitrate(view, recognizer);
    }), method_getTypeEncoding(method));
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
