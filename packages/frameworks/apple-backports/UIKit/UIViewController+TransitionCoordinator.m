#import "RevenantTransitionCoordinator.h"
#import "RevenantCustomTransition.h"
#import <objc/runtime.h>

static const char revenant_coordinator_key;
static const char revenant_transitioning_delegate_key;

@implementation UIViewController (RevenantTransitionCoordinator)

- (id<UIViewControllerTransitioningDelegate>)transitioningDelegate
{
    return objc_getAssociatedObject(self, &revenant_transitioning_delegate_key);
}

- (void)setTransitioningDelegate:(id<UIViewControllerTransitioningDelegate>)delegate
{
    objc_setAssociatedObject(self, &revenant_transitioning_delegate_key, delegate, OBJC_ASSOCIATION_ASSIGN);
}

- (id<UIViewControllerTransitionCoordinator>)transitionCoordinator
{
    return objc_getAssociatedObject(self, &revenant_coordinator_key);
}

@end

static void revenant_attach(UIViewController *controller, RevenantTransitionCoordinator *coordinator)
{
    if (controller)
        objc_setAssociatedObject(controller, &revenant_coordinator_key, coordinator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void revenant_detach(UIViewController *controller, RevenantTransitionCoordinator *coordinator)
{
    if (controller && objc_getAssociatedObject(controller, &revenant_coordinator_key) == coordinator)
        objc_setAssociatedObject(controller, &revenant_coordinator_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static RevenantTransitionCoordinator *revenant_begin(UIViewController *from, UIViewController *to, BOOL animated, BOOL modal, UIModalPresentationStyle style)
{
    RevenantTransitionCoordinator *coordinator = [[RevenantTransitionCoordinator alloc] initWithFrom:from to:to container:nil animated:animated duration:revenant_default_duration(modal) style:style];
    revenant_attach(from, coordinator);
    revenant_attach(to, coordinator);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [coordinator finish];
        revenant_detach(from, coordinator);
        revenant_detach(to, coordinator);
    });
    return coordinator;
}

static void revenant_end_after(RevenantTransitionCoordinator *coordinator, UIViewController *from, UIViewController *to, BOOL animated, BOOL modal)
{
    void (^finish)(void) = ^{
        [coordinator finish];
        revenant_detach(from, coordinator);
        revenant_detach(to, coordinator);
    };
    if (animated)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(revenant_default_duration(modal) * NSEC_PER_SEC)), dispatch_get_main_queue(), finish);
    else
        dispatch_async(dispatch_get_main_queue(), finish);
}

static UIViewController *revenant_presenting_root(UIViewController *controller)
{
    UIViewController *root = controller;
    while (root.parentViewController && !root.definesPresentationContext)
        root = root.parentViewController;
    return root;
}

static id<UIViewControllerAnimatedTransitioning> revenant_present_animator(id<UIViewControllerTransitioningDelegate> delegate, UIViewController *presented, UIViewController *presenting, UIViewController *source)
{
    if (![delegate respondsToSelector:@selector(animationControllerForPresentedController:presentingController:sourceController:)])
        return nil;
    return [delegate animationControllerForPresentedController:presented presentingController:presenting sourceController:source];
}

static id<UIViewControllerAnimatedTransitioning> revenant_dismiss_animator(id<UIViewControllerTransitioningDelegate> delegate, UIViewController *presented)
{
    if (![delegate respondsToSelector:@selector(animationControllerForDismissedController:)])
        return nil;
    return [delegate animationControllerForDismissedController:presented];
}

static UIPresentationController *revenant_sheet_for(UIViewController *presented, UIViewController *presenting)
{
    if (!revenant_sheet_style(presented.modalPresentationStyle) || presenting.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClassCompact)
        return nil;
    if (![NSClassFromString(@"UISheetPresentationController") instancesRespondToSelector:@selector(revenant_transitionAnimator)] || ![presented respondsToSelector:@selector(sheetPresentationController)])
        return nil;
    return [presented performSelector:@selector(sheetPresentationController)];
}

static id<UIViewControllerInteractiveTransitioning> revenant_interactor_for(id<UIViewControllerTransitioningDelegate> delegate, id<UIViewControllerAnimatedTransitioning> animator, BOOL presenting)
{
    SEL selector = presenting ? @selector(interactionControllerForPresentation:) : @selector(interactionControllerForDismissal:);
    if (![delegate respondsToSelector:selector])
        return nil;
    return presenting ? [delegate interactionControllerForPresentation:animator] : [delegate interactionControllerForDismissal:animator];
}

static BOOL revenant_release_presents(void)
{
    return ![UIPresentationController instancesRespondToSelector:@selector(revenant_setContainerView:)];
}

@interface RevenantSheetHandover : NSObject <UIViewControllerTransitioningDelegate>
@property (nonatomic, weak) UIPresentationController *sheet;
@property (nonatomic, weak) id<UIViewControllerTransitioningDelegate> original;
@end

@implementation RevenantSheetHandover

@synthesize sheet = _sheet;
@synthesize original = _original;

- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source
{
    return self.sheet;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return revenant_present_animator(self.original, presented, presenting, source) ?: [self.sheet revenant_transitionAnimator];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return revenant_dismiss_animator(self.original, dismissed) ?: [self.sheet revenant_transitionAnimator];
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id<UIViewControllerAnimatedTransitioning>)animator
{
    return revenant_interactor_for(self.original, animator, YES);
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator
{
    return revenant_interactor_for(self.original, animator, NO);
}

@end

static const void *const revenant_sheet_handover_key = &revenant_sheet_handover_key;

static void revenant_sheet_handover_end(UIViewController *presented, RevenantSheetHandover *handover)
{
    if (presented.transitioningDelegate == handover)
        presented.transitioningDelegate = handover.original;
    objc_setAssociatedObject(presented, revenant_sheet_handover_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UIViewController (RevenantSheetHold)

- (void)revenant_sheetDidDismiss:(UIPresentationController *)sheet
{
    RevenantSheetHandover *handover = objc_getAssociatedObject(self, revenant_sheet_handover_key);
    if (!handover || handover.sheet != sheet)
        return;
    revenant_sheet_handover_end(self, handover);
    if (revenant_presentation_controller_of(self) == sheet)
        revenant_set_presentation_controller(self, nil);
}

@end

static UIPresentationController *revenant_presentation_for(UIViewController *presented, UIViewController *presenting, UIViewController *source)
{
    UIModalPresentationStyle style = presented.modalPresentationStyle;
    UIPresentationController *sheet = revenant_sheet_for(presented, presenting);
    if (sheet)
        return sheet;
    id<UIViewControllerTransitioningDelegate> delegate = presented.transitioningDelegate;
    if (!(style >= 4 && style <= 6))
        return nil;
    UIPresentationController *custom = nil;
    if ([delegate respondsToSelector:@selector(presentationControllerForPresentedViewController:presentingViewController:sourceViewController:)])
        custom = [delegate presentationControllerForPresentedViewController:presented presentingViewController:presenting sourceViewController:source];
    if (!custom && style == UIModalPresentationCustom)
        custom = [[UIPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
    return custom;
}

static id<UIViewControllerInteractiveTransitioning> revenant_navigation_interactor(UINavigationController *navigation, id<UIViewControllerAnimatedTransitioning> animator)
{
    id<UINavigationControllerDelegate> delegate = navigation.delegate;
    if (![delegate respondsToSelector:@selector(navigationController:interactionControllerForAnimationController:)])
        return animator == revenant_edge_pop_animator(navigation) ? revenant_edge_pop_interactor(navigation) : nil;
    return [delegate navigationController:navigation interactionControllerForAnimationController:animator];
}

static id<UIViewControllerAnimatedTransitioning> revenant_navigation_animator(UINavigationController *navigation, UINavigationControllerOperation operation, UIViewController *from, UIViewController *to)
{
    id<UINavigationControllerDelegate> delegate = navigation.delegate;
    id<UIViewControllerAnimatedTransitioning> animator = [delegate respondsToSelector:@selector(navigationController:animationControllerForOperation:fromViewController:toViewController:)]
        ? [delegate navigationController:navigation animationControllerForOperation:operation fromViewController:from toViewController:to] : nil;
    if (!animator && operation == UINavigationControllerOperationPop)
        animator = revenant_edge_pop_animator(navigation);
    return animator;
}

static void (^revenant_finisher(RevenantTransitionCoordinator *coordinator, UIViewController *from, UIViewController *to, void (^completion)(void)))(BOOL)
{
    return ^(BOOL finished) {
        revenant_detach(from, coordinator);
        revenant_detach(to, coordinator);
        if (completion)
            completion();
    };
}

@interface RevenantTransitionCoordinatorInstaller : NSObject
@end

@implementation RevenantTransitionCoordinatorInstaller

+ (void)load
{
    Class controller = [UIViewController class];
    SEL present = @selector(presentViewController:animated:completion:);
    Method presentMethod = class_getInstanceMethod(controller, present);
    void (*presentOriginal)(id, SEL, UIViewController *, BOOL, void (^)(void)) = (void (*)(id, SEL, UIViewController *, BOOL, void (^)(void)))method_getImplementation(presentMethod);
    SEL dismiss = @selector(dismissViewControllerAnimated:completion:);
    Method dismissMethod = class_getInstanceMethod(controller, dismiss);
    void (*dismissOriginal)(id, SEL, BOOL, void (^)(void)) = (void (*)(id, SEL, BOOL, void (^)(void)))method_getImplementation(dismissMethod);
    class_replaceMethod(controller, present, imp_implementationWithBlock(^(UIViewController *self, UIViewController *presented, BOOL animated, void (^completion)(void)) {
        if (revenant_document_menu_present(self, presented, animated, completion))
            return;
        if (revenant_popover_present(self, presented, animated, completion))
            return;
        UIViewController *presenting = revenant_presenting_root(self);
        UIModalPresentationStyle style = presented.modalPresentationStyle;
        if (revenant_release_presents()) {
            RevenantSheetHandover *stale = objc_getAssociatedObject(presented, revenant_sheet_handover_key);
            if (stale && !presented.presentingViewController)
                revenant_sheet_handover_end(presented, stale);
            UIPresentationController *sheet = revenant_sheet_for(presented, presenting);
            if (sheet || (style >= 4 && style <= 6)) {
                if (sheet) {
                    RevenantSheetHandover *handover = [[RevenantSheetHandover alloc] init];
                    handover.sheet = sheet;
                    handover.original = presented.transitioningDelegate;
                    objc_setAssociatedObject(presented, revenant_sheet_handover_key, handover, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    presented.transitioningDelegate = handover;
                    presented.modalPresentationStyle = UIModalPresentationCustom;
                }
                presentOriginal(self, present, presented, animated, completion);
                presented.modalPresentationStyle = style;
                return;
            }
        }
        UIPresentationController *presentation = revenant_presentation_for(presented, presenting, self);
        if (presentation) {
            id<UIViewControllerAnimatedTransitioning> presentationAnimator = animated ? revenant_present_animator(presented.transitioningDelegate, presented, presenting, self) ?: [presentation revenant_transitionAnimator] : nil;
            RevenantTransitionCoordinator *coordinator = revenant_begin(presenting, presented, animated, YES, style);
            revenant_presentation_present(presenting, presented, presentation, presentationAnimator, ^{
                presented.modalPresentationStyle = UIModalPresentationFullScreen;
                presentOriginal(self, present, presented, NO, nil);
                presented.modalPresentationStyle = style;
            }, revenant_finisher(coordinator, presenting, presented, completion));
            return;
        }
        id<UIViewControllerAnimatedTransitioning> animator = animated && (style == UIModalPresentationFullScreen || style >= 4) ? revenant_present_animator(presented.transitioningDelegate, presented, presenting, self) : nil;
        if (animator) {
            RevenantTransitionCoordinator *coordinator = revenant_begin(presenting, presented, YES, YES, style);
            BOOL started = revenant_custom_transition(RevenantTransitionPresent, presenting, presented, self, animator, revenant_interactor_for(presented.transitioningDelegate, animator, YES), style, ^{
                presented.modalPresentationStyle = style >= 4 ? UIModalPresentationFullScreen : style;
                presentOriginal(self, present, presented, NO, nil);
                presented.modalPresentationStyle = style;
            }, ^{
                dismissOriginal(presenting, dismiss, NO, nil);
            }, revenant_finisher(coordinator, presenting, presented, completion));
            if (started)
                return;
            revenant_detach(presenting, coordinator);
            revenant_detach(presented, coordinator);
        }
        RevenantTransitionCoordinator *coordinator = revenant_begin(self, presented, animated, YES, presented.modalPresentationStyle);
        presentOriginal(self, present, presented, animated, ^{
            [coordinator finish];
            revenant_detach(self, coordinator);
            revenant_detach(presented, coordinator);
            if (completion)
                completion();
        });
    }), method_getTypeEncoding(presentMethod));

    class_replaceMethod(controller, dismiss, imp_implementationWithBlock(^(UIViewController *self, BOOL animated, void (^completion)(void)) {
        if (revenant_popover_dismiss(self, animated, completion))
            return;
        UIViewController *presented = self.presentedViewController ?: self;
        UIViewController *presenting = presented.presentingViewController ?: self;
        if (revenant_release_presents()) {
            RevenantSheetHandover *handover = objc_getAssociatedObject(presented, revenant_sheet_handover_key);
            UIModalPresentationStyle style = presented.modalPresentationStyle;
            if (handover || (style >= 4 && style <= 6)) {
                dismissOriginal(self, dismiss, animated, completion);
                return;
            }
        }
        UIPresentationController *presentation = presented.presentingViewController ? revenant_presentation_controller_of(presented) : nil;
        if (presentation && presentation.containerView) {
            id<UIViewControllerAnimatedTransitioning> presentationAnimator = animated ? revenant_dismiss_animator(presented.transitioningDelegate, presented) ?: [presentation revenant_transitionAnimator] : nil;
            RevenantTransitionCoordinator *coordinator = revenant_begin(presented, presenting, animated, YES, presented.modalPresentationStyle);
            revenant_presentation_dismiss(presented, presenting, presentation, presentationAnimator, ^{
                dismissOriginal(self, dismiss, NO, nil);
            }, revenant_finisher(coordinator, presented, presenting, completion));
            return;
        }
        id<UIViewControllerAnimatedTransitioning> animator = animated && presented.presentingViewController ? revenant_dismiss_animator(presented.transitioningDelegate, presented) : nil;
        if (animator) {
            RevenantTransitionCoordinator *coordinator = revenant_begin(presented, presenting, YES, YES, presented.modalPresentationStyle);
            UIModalPresentationStyle style = presented.modalPresentationStyle;
            BOOL started = revenant_custom_transition(RevenantTransitionDismiss, presented, presenting, self, animator, revenant_interactor_for(presented.transitioningDelegate, animator, NO), style, ^{
                dismissOriginal(self, dismiss, NO, nil);
            }, ^{
                presentOriginal(presenting, present, presented, NO, nil);
            }, revenant_finisher(coordinator, presented, presenting, completion));
            if (started)
                return;
            revenant_detach(presented, coordinator);
            revenant_detach(presenting, coordinator);
        }
        RevenantTransitionCoordinator *coordinator = revenant_begin(presented, presenting, animated, YES, presented.modalPresentationStyle);
        dismissOriginal(self, dismiss, animated, ^{
            [coordinator finish];
            revenant_detach(presented, coordinator);
            revenant_detach(presenting, coordinator);
            if (completion)
                completion();
        });
    }), method_getTypeEncoding(dismissMethod));

    Class navigation = [UINavigationController class];
    SEL push = @selector(pushViewController:animated:);
    Method pushMethod = class_getInstanceMethod(navigation, push);
    void (*pushOriginal)(id, SEL, UIViewController *, BOOL) = (void (*)(id, SEL, UIViewController *, BOOL))method_getImplementation(pushMethod);
    SEL pop = @selector(popViewControllerAnimated:);
    Method popMethod = class_getInstanceMethod(navigation, pop);
    UIViewController *(*popOriginal)(id, SEL, BOOL) = (UIViewController *(*)(id, SEL, BOOL))method_getImplementation(popMethod);
    class_replaceMethod(navigation, push, imp_implementationWithBlock(^(UINavigationController *self, UIViewController *pushed, BOOL animated) {
        UIViewController *from = self.topViewController;
        id<UIViewControllerAnimatedTransitioning> animator = animated && from ? revenant_navigation_animator(self, UINavigationControllerOperationPush, from, pushed) : nil;
        if (animator) {
            RevenantTransitionCoordinator *coordinator = revenant_begin(from, pushed, YES, NO, UIModalPresentationNone);
            BOOL started = revenant_custom_transition(RevenantTransitionPush, from, pushed, self, animator, revenant_navigation_interactor(self, animator), UIModalPresentationNone, ^{
                pushOriginal(self, push, pushed, NO);
            }, ^{
                popOriginal(self, pop, NO);
            }, revenant_finisher(coordinator, from, pushed, nil));
            if (started)
                return;
            revenant_detach(from, coordinator);
            revenant_detach(pushed, coordinator);
        }
        BOOL running = animated && from;
        RevenantTransitionCoordinator *coordinator = running ? revenant_begin(from, pushed, animated, NO, UIModalPresentationNone) : nil;
        pushOriginal(self, push, pushed, animated);
        if (coordinator)
            revenant_end_after(coordinator, from, pushed, animated, NO);
    }), method_getTypeEncoding(pushMethod));

    SEL popTo = @selector(popToViewController:animated:);
    Method popToMethod = class_getInstanceMethod(navigation, popTo);
    NSArray *(*popToOriginal)(id, SEL, UIViewController *, BOOL) = (NSArray *(*)(id, SEL, UIViewController *, BOOL))method_getImplementation(popToMethod);
    SEL popRoot = @selector(popToRootViewControllerAnimated:);
    Method popRootMethod = class_getInstanceMethod(navigation, popRoot);
    NSArray *(*popRootOriginal)(id, SEL, BOOL) = (NSArray *(*)(id, SEL, BOOL))method_getImplementation(popRootMethod);
    NSArray *(^popping)(UINavigationController *, UIViewController *, BOOL, NSArray *(^)(BOOL)) = ^NSArray *(UINavigationController *self, UIViewController *target, BOOL animated, NSArray *(^native)(BOOL)) {
        UIViewController *from = self.topViewController;
        BOOL running = from && target && from != target && [self.viewControllers containsObject:target];
        id<UIViewControllerAnimatedTransitioning> animator = animated && running ? revenant_navigation_animator(self, UINavigationControllerOperationPop, from, target) : nil;
        if (animator) {
            RevenantTransitionCoordinator *coordinator = revenant_begin(from, target, YES, NO, UIModalPresentationNone);
            NSArray *stack = self.viewControllers;
            NSUInteger index = [stack indexOfObject:target];
            NSArray *popped = index != NSNotFound ? [stack subarrayWithRange:NSMakeRange(index + 1, stack.count - index - 1)] : @[];
            BOOL started = revenant_custom_transition(RevenantTransitionPop, from, target, self, animator, revenant_navigation_interactor(self, animator), UIModalPresentationNone, ^{
                native(NO);
            }, nil, revenant_finisher(coordinator, from, target, nil));
            if (started)
                return popped;
            revenant_detach(from, coordinator);
            revenant_detach(target, coordinator);
        }
        RevenantTransitionCoordinator *coordinator = running ? revenant_begin(from, target, animated, NO, UIModalPresentationNone) : nil;
        NSArray *result = native(animated);
        if (coordinator)
            revenant_end_after(coordinator, from, target, animated, NO);
        return result;
    };
    class_replaceMethod(navigation, popTo, imp_implementationWithBlock(^NSArray *(UINavigationController *self, UIViewController *target, BOOL animated) {
        return popping(self, target, animated, ^NSArray *(BOOL flag) { return popToOriginal(self, popTo, target, flag); });
    }), method_getTypeEncoding(popToMethod));
    class_replaceMethod(navigation, popRoot, imp_implementationWithBlock(^NSArray *(UINavigationController *self, BOOL animated) {
        return popping(self, self.viewControllers.firstObject, animated, ^NSArray *(BOOL flag) { return popRootOriginal(self, popRoot, flag); });
    }), method_getTypeEncoding(popRootMethod));

    class_replaceMethod(navigation, pop, imp_implementationWithBlock(^UIViewController *(UINavigationController *self, BOOL animated) {
        NSArray *stack = self.viewControllers;
        UIViewController *from = stack.count > 1 ? stack.lastObject : nil;
        UIViewController *to = stack.count > 1 ? stack[stack.count - 2] : nil;
        id<UIViewControllerAnimatedTransitioning> animator = animated && from ? revenant_navigation_animator(self, UINavigationControllerOperationPop, from, to) : nil;
        if (animator) {
            RevenantTransitionCoordinator *coordinator = revenant_begin(from, to, YES, NO, UIModalPresentationNone);
            BOOL started = revenant_custom_transition(RevenantTransitionPop, from, to, self, animator, revenant_navigation_interactor(self, animator), UIModalPresentationNone, ^{
                popOriginal(self, pop, NO);
            }, ^{
                pushOriginal(self, push, from, NO);
            }, revenant_finisher(coordinator, from, to, nil));
            if (started)
                return from;
            revenant_detach(from, coordinator);
            revenant_detach(to, coordinator);
        }
        RevenantTransitionCoordinator *coordinator = from ? revenant_begin(from, to, animated, NO, UIModalPresentationNone) : nil;
        UIViewController *result = popOriginal(self, pop, animated);
        if (coordinator)
            revenant_end_after(coordinator, from, to, animated, NO);
        return result;
    }), method_getTypeEncoding(popMethod));
}

@end
