#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonCustomTransition.h"

static const char charon_popover_presented_key;
static const char charon_popover_presenting_key;

@interface UIPopoverPresentationController ()
- (void)charon_setPresenting:(UIViewController *)presenting arrowDirection:(UIPopoverArrowDirection)direction;
@end

@interface CharonPopoverState : NSObject <UIPopoverControllerDelegate>
@property (nonatomic, strong) UIPopoverController *popover;
@property (nonatomic, strong) UIViewController *presented;
@property (nonatomic, strong) UIViewController *presenting;
@property (nonatomic, strong) UIPopoverPresentationController *presentation;
@end

static void charon_popover_clear(CharonPopoverState *state)
{
    if (objc_getAssociatedObject(state.presented, &charon_popover_presented_key) == state)
        objc_setAssociatedObject(state.presented, &charon_popover_presented_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (objc_getAssociatedObject(state.presenting, &charon_popover_presenting_key) == state)
        objc_setAssociatedObject(state.presenting, &charon_popover_presenting_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [state.presentation charon_setPresenting:nil arrowDirection:(UIPopoverArrowDirection)NSUIntegerMax];
}

@implementation CharonPopoverState

@synthesize popover, presented, presenting, presentation;

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    id<UIPopoverPresentationControllerDelegate> delegate = self.presentation.delegate;
    if ([delegate respondsToSelector:@selector(popoverPresentationControllerShouldDismissPopover:)])
        return [delegate popoverPresentationControllerShouldDismissPopover:self.presentation];
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    UIPopoverPresentationController *presentation = self.presentation;
    charon_popover_clear(self);
    id<UIPopoverPresentationControllerDelegate> delegate = presentation.delegate;
    if ([delegate respondsToSelector:@selector(popoverPresentationControllerDidDismissPopover:)])
        [delegate popoverPresentationControllerDidDismissPopover:presentation];
}

- (void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view
{
    id<UIPopoverPresentationControllerDelegate> delegate = self.presentation.delegate;
    if ([delegate respondsToSelector:@selector(popoverPresentationController:willRepositionPopoverToRect:inView:)])
        [delegate popoverPresentationController:self.presentation willRepositionPopoverToRect:rect inView:view];
}

@end

static CharonPopoverState *charon_popover_state_for(UIViewController *controller)
{
    for (UIViewController *walk = controller; walk; walk = walk.parentViewController) {
        CharonPopoverState *state = objc_getAssociatedObject(walk, &charon_popover_presented_key);
        if (state)
            return state;
    }
    return objc_getAssociatedObject(controller, &charon_popover_presenting_key);
}

static void charon_popover_install_getters(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class controller = [UIViewController class];
        Method presented = class_getInstanceMethod(controller, @selector(presentedViewController));
        UIViewController *(*presentedOriginal)(id, SEL) = (UIViewController * (*)(id, SEL))method_getImplementation(presented);
        class_replaceMethod(controller, @selector(presentedViewController), imp_implementationWithBlock(^UIViewController *(UIViewController *self_) {
            CharonPopoverState *state = objc_getAssociatedObject(self_, &charon_popover_presenting_key);
            return state ? state.presented : presentedOriginal(self_, @selector(presentedViewController));
        }), method_getTypeEncoding(presented));
        Method presenting = class_getInstanceMethod(controller, @selector(presentingViewController));
        UIViewController *(*presentingOriginal)(id, SEL) = (UIViewController * (*)(id, SEL))method_getImplementation(presenting);
        class_replaceMethod(controller, @selector(presentingViewController), imp_implementationWithBlock(^UIViewController *(UIViewController *self_) {
            CharonPopoverState *state = objc_getAssociatedObject(self_, &charon_popover_presented_key);
            return state ? state.presenting : presentingOriginal(self_, @selector(presentingViewController));
        }), method_getTypeEncoding(presenting));
    });
}

BOOL charon_popover_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void))
{
    if (presented.modalPresentationStyle != (UIModalPresentationStyle)7)
        return NO;
    UIPopoverPresentationController *presentation = presented.popoverPresentationController;
    id<UIPopoverPresentationControllerDelegate> delegate = presentation.delegate;
    if ([delegate respondsToSelector:@selector(prepareForPopoverPresentation:)])
        [delegate prepareForPopoverPresentation:presentation];
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        UIModalPresentationStyle adaptive = UIModalPresentationFullScreen;
        if ([delegate respondsToSelector:@selector(adaptivePresentationStyleForPresentationController:)]) {
            UIModalPresentationStyle wanted = [delegate adaptivePresentationStyleForPresentationController:presentation];
            if (wanted == (UIModalPresentationStyle)5)
                adaptive = wanted;
        }
        UIViewController *shown = presented;
        if ([delegate respondsToSelector:@selector(presentationController:viewControllerForAdaptivePresentationStyle:)])
            shown = [delegate presentationController:presentation viewControllerForAdaptivePresentationStyle:adaptive] ?: presented;
        presented.modalPresentationStyle = adaptive;
        shown.modalPresentationStyle = adaptive;
        [presenting presentViewController:shown animated:animated completion:completion];
        return YES;
    }
    if (!presentation.sourceView && !presentation.barButtonItem)
        [NSException raise:NSGenericException format:@"UIPopoverPresentationController (%@) should have a non-nil sourceView or barButtonItem set before the presentation occurs.", presentation];
    charon_popover_install_getters();
    CharonPopoverState *old = objc_getAssociatedObject(presenting, &charon_popover_presenting_key);
    if (old) {
        [old.popover dismissPopoverAnimated:NO];
        charon_popover_clear(old);
    }
    UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:presented];
    CGSize size = presented.preferredContentSize;
    if (!CGSizeEqualToSize(size, CGSizeZero))
        popover.popoverContentSize = size;
    if (!UIEdgeInsetsEqualToEdgeInsets(presentation.popoverLayoutMargins, UIEdgeInsetsZero))
        popover.popoverLayoutMargins = presentation.popoverLayoutMargins;
    if (presentation.popoverBackgroundViewClass)
        popover.popoverBackgroundViewClass = presentation.popoverBackgroundViewClass;
    CharonPopoverState *state = [[CharonPopoverState alloc] init];
    state.popover = popover;
    state.presented = presented;
    state.presenting = presenting;
    state.presentation = presentation;
    popover.delegate = state;
    objc_setAssociatedObject(presented, &charon_popover_presented_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(presenting, &charon_popover_presenting_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIPopoverArrowDirection permitted = presentation.permittedArrowDirections;
    if (presentation.barButtonItem) {
        [popover presentPopoverFromBarButtonItem:presentation.barButtonItem permittedArrowDirections:permitted animated:animated];
    } else {
        CGRect rect = presentation.sourceRect;
        if (CGRectIsNull(rect) || CGRectIsInfinite(rect))
            rect = presentation.sourceView.bounds;
        [popover presentPopoverFromRect:rect inView:presentation.sourceView permittedArrowDirections:permitted animated:animated];
    }
    if (presentation.passthroughViews)
        popover.passthroughViews = presentation.passthroughViews;
    [presentation charon_setPresenting:presenting arrowDirection:popover.popoverArrowDirection];
    if (completion)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((animated ? 0.4 : 0.01) * NSEC_PER_SEC)), dispatch_get_main_queue(), completion);
    return YES;
}

BOOL charon_popover_dismiss(UIViewController *controller, BOOL animated, void (^completion)(void))
{
    CharonPopoverState *state = charon_popover_state_for(controller);
    if (!state)
        return NO;
    [state.popover dismissPopoverAnimated:animated];
    charon_popover_clear(state);
    if (completion)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((animated ? 0.4 : 0.01) * NSEC_PER_SEC)), dispatch_get_main_queue(), completion);
    return YES;
}

@implementation UIViewController (CharonPopover)

- (UIPopoverPresentationController *)popoverPresentationController
{
    if (self.modalPresentationStyle != (UIModalPresentationStyle)7)
        return nil;
    UIPresentationController *existing = charon_presentation_controller_of(self);
    if ([existing isKindOfClass:[UIPopoverPresentationController class]])
        return (UIPopoverPresentationController *)existing;
    UIPopoverPresentationController *presentation = [[UIPopoverPresentationController alloc] initWithPresentedViewController:self presentingViewController:nil];
    charon_set_presentation_controller(self, presentation);
    return presentation;
}

@end
