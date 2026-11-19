#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface RevenantGestureFailureDelegate : NSObject <UIGestureRecognizerDelegate>
@end

@implementation RevenantGestureFailureDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}
@end

@interface RevenantGestureFailurePlainDelegate : NSObject <UIGestureRecognizerDelegate>
@end

@implementation RevenantGestureFailurePlainDelegate
@end

@interface RevenantGestureFailureRecognizer : UIGestureRecognizer
@end

@implementation RevenantGestureFailureRecognizer
- (BOOL)shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}
@end

REVENANT_CASE(gesture_failure)
{
    SEL require = sel_registerName("_gestureRecognizer:shouldRequireFailureOfGestureRecognizer:");
    SEL fail = sel_registerName("_gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:");
    SEL query = sel_registerName("_queryFailureRequirements");
    SEL depends = sel_registerName("_requiresGestureRecognizerToFail:");
    SEL hook = sel_registerName("_shouldRequireFailureOfGestureRecognizer:");
    BOOL (*send2)(id, SEL, id, id) = (BOOL (*)(id, SEL, id, id))objc_msgSend;
    void (*send0)(id, SEL) = (void (*)(id, SEL))objc_msgSend;

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    UIPanGestureRecognizer *first = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:NULL];
    UIPanGestureRecognizer *second = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:NULL];
    [view addGestureRecognizer:first];
    [view addGestureRecognizer:second];
    RevenantGestureFailureDelegate *delegate = [[RevenantGestureFailureDelegate alloc] init];
    [first setDelegate:delegate];

    BOOL resolves = [delegate respondsToSelector:require] && [delegate respondsToSelector:fail];
    revenant_expect_true(@"the private failure names resolve when the delegate is set",
                         resolves != (BOOL)negative, @"class_addMethod at setDelegate:");

    ((void (*)(id, SEL))objc_msgSend)(first, query);
    BOOL waits = ((BOOL (*)(id, SEL, id))objc_msgSend)(first, depends, second);
    revenant_expect_true(@"the other pan must wait for the pan whose delegate required it",
                         waits != (BOOL)negative, @"");

    BOOL forward = NO;
    if ([delegate respondsToSelector:require])
        forward = send2(delegate, require, first, second);
    revenant_expect_true(@"the private shouldRequireFailureOf forwards to the iOS 7 public method",
                         forward != (BOOL)negative, @"the delegate answers YES");

    BOOL reverse = NO;
    if ([delegate respondsToSelector:fail])
        reverse = send2(delegate, fail, first, second);
    revenant_expect_true(@"the private shouldBeRequiredToFailBy forwards to the iOS 7 public method",
                         reverse != (BOOL)negative, @"the delegate answers YES");

    UIView *plainView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    UIPanGestureRecognizer *plainFirst = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:NULL];
    UIPanGestureRecognizer *plainSecond = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:NULL];
    [plainView addGestureRecognizer:plainFirst];
    [plainView addGestureRecognizer:plainSecond];
    RevenantGestureFailurePlainDelegate *plain = [[RevenantGestureFailurePlainDelegate alloc] init];
    [plainFirst setDelegate:plain];

    BOOL stock = ![plain respondsToSelector:require] && ![plain respondsToSelector:fail];
    revenant_expect_true(@"a delegate without the public methods keeps the stock private names",
                         stock != (BOOL)negative, @"");

    send0(plainFirst, query);
    BOOL stockWaits = ((BOOL (*)(id, SEL, id))objc_msgSend)(plainFirst, depends, plainSecond);
    revenant_expect_true(@"a delegate without the public methods leaves the pans independent",
                         stockWaits == (BOOL)negative, @"");

    RevenantGestureFailureRecognizer *recognizer = [[RevenantGestureFailureRecognizer alloc] init];
    BOOL hookAnswer = ((BOOL (*)(id, SEL, id))objc_msgSend)(recognizer, hook, first);
    revenant_expect_true(@"a subclass's public hook reaches UIKit's private hook",
                         hookAnswer != (BOOL)negative, @"");
}
