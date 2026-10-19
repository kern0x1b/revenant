#import "CharonTransitionCoordinator.h"
#import "CharonCustomTransition.h"
#import <objc/runtime.h>

static const char charon_coordinator_key;
static const char charon_transitioning_delegate_key;

@implementation UIViewController (CharonTransitionCoordinator)

- (id<UIViewControllerTransitioningDelegate>)transitioningDelegate
{
    return objc_getAssociatedObject(self, &charon_transitioning_delegate_key);
}

- (void)setTransitioningDelegate:(id<UIViewControllerTransitioningDelegate>)delegate
{
    objc_setAssociatedObject(self, &charon_transitioning_delegate_key, delegate, OBJC_ASSOCIATION_ASSIGN);
}

- (id<UIViewControllerTransitionCoordinator>)transitionCoordinator
{
    return objc_getAssociatedObject(self, &charon_coordinator_key);
}

@end

static void charon_attach(UIViewController *controller, CharonTransitionCoordinator *coordinator)
{
    if (controller)
        objc_setAssociatedObject(controller, &charon_coordinator_key, coordinator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void charon_detach(UIViewController *controller, CharonTransitionCoordinator *coordinator)
{
    if (controller && objc_getAssociatedObject(controller, &charon_coordinator_key) == coordinator)
        objc_setAssociatedObject(controller, &charon_coordinator_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static CharonTransitionCoordinator *charon_begin(UIViewController *from, UIViewController *to, BOOL animated, BOOL modal, UIModalPresentationStyle style)
{
    CharonTransitionCoordinator *coordinator = [[CharonTransitionCoordinator alloc] initWithFrom:from to:to container:nil animated:animated duration:charon_default_duration(modal) style:style];
    charon_attach(from, coordinator);
    charon_attach(to, coordinator);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [coordinator finish];
        charon_detach(from, coordinator);
        charon_detach(to, coordinator);
    });
    return coordinator;
}

static void charon_end_after(CharonTransitionCoordinator *coordinator, UIViewController *from, UIViewController *to, BOOL animated, BOOL modal)
{
    void (^finish)(void) = ^{
        [coordinator finish];
        charon_detach(from, coordinator);
        charon_detach(to, coordinator);
    };
    if (animated)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(charon_default_duration(modal) * NSEC_PER_SEC)), dispatch_get_main_queue(), finish);
    else
        dispatch_async(dispatch_get_main_queue(), finish);
}

static UIViewController *charon_presenting_root(UIViewController *controller)
{
    UIViewController *root = controller;
    while (root.parentViewController && !root.definesPresentationContext)
        root = root.parentViewController;
    return root;
}

static id<UIViewControllerAnimatedTransitioning> charon_present_animator(id<UIViewControllerTransitioningDelegate> delegate, UIViewController *presented, UIViewController *presenting, UIViewController *source)
{
    if (![delegate respondsToSelector:@selector(animationControllerForPresentedController:presentingController:sourceController:)])
        return nil;
    return [delegate animationControllerForPresentedController:presented presentingController:presenting sourceController:source];
}

static id<UIViewControllerAnimatedTransitioning> charon_dismiss_animator(id<UIViewControllerTransitioningDelegate> delegate, UIViewController *presented)
{
    if (![delegate respondsToSelector:@selector(animationControllerForDismissedController:)])
        return nil;
    return [delegate animationControllerForDismissedController:presented];
}

/* A page or form sheet presented in a compact width is the sheet's own presentation (UISheetPresentationController.m).
   The sheet is made only when the presentation is one: asking for it makes it and the controller holds it, so a
   controller that is not presented as a sheet asks for none. The class is asked by name, and by a selector only the port's
   own carries, as this file is linked into releases that do not carry it and into those whose sheet is the release's. */
static UIPresentationController *charon_sheet_for(UIViewController *presented, UIViewController *presenting)
{
    if (!charon_sheet_style(presented.modalPresentationStyle) || presenting.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClassCompact)
        return nil;
    if (![NSClassFromString(@"UISheetPresentationController") instancesRespondToSelector:@selector(charon_transitionAnimator)] || ![presented respondsToSelector:@selector(sheetPresentationController)])
        return nil;
    return [presented performSelector:@selector(sheetPresentationController)];
}

static id<UIViewControllerInteractiveTransitioning> charon_interactor_for(id<UIViewControllerTransitioningDelegate> delegate, id<UIViewControllerAnimatedTransitioning> animator, BOOL presenting)
{
    SEL selector = presenting ? @selector(interactionControllerForPresentation:) : @selector(interactionControllerForDismissal:);
    if (![delegate respondsToSelector:selector])
        return nil;
    return presenting ? [delegate interactionControllerForPresentation:animator] : [delegate interactionControllerForDismissal:animator];
}

/* This file is linked into every band, UIPresentationController.m only into those below 8.0: from 8.0 on the class is the
   release's, which has none of the methods the port's engine sends a presentation controller, and the release presents
   the custom styles itself (asking the transitioning delegate for the controller and the animators). */
static BOOL charon_release_presents(void)
{
    return ![UIPresentationController instancesRespondToSelector:@selector(charon_setContainerView:)];
}

/* From 8.0 on the port's sheet is presented by the release, through its public custom presentation: while the sheet is
   presented, its view controller's style is Custom only for the release's present call and its transitioning delegate is
   this object, which gives the sheet, and the sheet's animator where the caller's delegate gives none; the caller's
   delegate is put back when the sheet is gone. */
@interface CharonSheetHandover : NSObject <UIViewControllerTransitioningDelegate>
@property (nonatomic, weak) UIPresentationController *sheet;
@property (nonatomic, weak) id<UIViewControllerTransitioningDelegate> original;
@end

@implementation CharonSheetHandover

@synthesize sheet = _sheet;
@synthesize original = _original;

- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source
{
    return self.sheet;
}

/* The caller's delegate is asked first for the animators and the interactive controllers, as the release asks it for a
   sheet and as the engine below 8.0 does; the sheet's animator is the one used when it gives none. */
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return charon_present_animator(self.original, presented, presenting, source) ?: [self.sheet charon_transitionAnimator];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return charon_dismiss_animator(self.original, dismissed) ?: [self.sheet charon_transitionAnimator];
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id<UIViewControllerAnimatedTransitioning>)animator
{
    return charon_interactor_for(self.original, animator, YES);
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator
{
    return charon_interactor_for(self.original, animator, NO);
}

@end

static const void *const charon_sheet_handover_key = &charon_sheet_handover_key;

/* Puts the caller's delegate back once the sheet is gone: when its dismissal ends, or at the next presentation of the
   controller when the presentation the handover was made for never happened. */
static void charon_sheet_handover_end(UIViewController *presented, CharonSheetHandover *handover)
{
    if (presented.transitioningDelegate == handover)
        presented.transitioningDelegate = handover.original;
    objc_setAssociatedObject(presented, charon_sheet_handover_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UIViewController (CharonSheetHold)

/* The sheet a dismissal took away is not kept for the controller: UIKit's controller has none after its dismissal and
   makes another, with the default detents, when asked again, and a sheet kept is a sheet the release's presentation
   controller holds the controller for (from 8.0 on its class is the release's, whose init holds it strongly). The sheet
   says so when its dismissal ends, which the release does on every route: the controller's own dismiss, its presenter's,
   and the dismissal of an ancestor that takes it down with it. */
- (void)charon_sheetDidDismiss:(UIPresentationController *)sheet
{
    CharonSheetHandover *handover = objc_getAssociatedObject(self, charon_sheet_handover_key);
    if (!handover || handover.sheet != sheet)
        return;
    charon_sheet_handover_end(self, handover);
    if (charon_presentation_controller_of(self) == sheet)
        charon_set_presentation_controller(self, nil);
}

@end

static UIPresentationController *charon_presentation_for(UIViewController *presented, UIViewController *presenting, UIViewController *source)
{
    UIModalPresentationStyle style = presented.modalPresentationStyle;
    UIPresentationController *sheet = charon_sheet_for(presented, presenting);
    if (sheet)
        return sheet;
    id<UIViewControllerTransitioningDelegate> delegate = presented.transitioningDelegate;
    if (!(style >= 4 && style <= 6))
        return nil;
    UIPresentationController *custom = nil;
    if ([delegate respondsToSelector:@selector(presentationControllerForPresentedViewController:presentingViewController:sourceViewController:)])
        custom = [delegate presentationControllerForPresentedViewController:presented presentingViewController:presenting sourceViewController:source];
    /* A custom presentation whose delegate gives no controller, or that has no delegate, gets a plain
       UIPresentationController (-_presentViewController:withAnimationController:completion:
       0x1891a8fe0 in UIKitCore of 16.0, after -_customPresentationControllerForPresentedController:
       0x1890dafa0 answers nil): the presented view fills the container over the presenter's. */
    if (!custom && style == UIModalPresentationCustom)
        custom = [[UIPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
    return custom;
}

static id<UIViewControllerInteractiveTransitioning> charon_navigation_interactor(UINavigationController *navigation, id<UIViewControllerAnimatedTransitioning> animator)
{
    id<UINavigationControllerDelegate> delegate = navigation.delegate;
    if (![delegate respondsToSelector:@selector(navigationController:interactionControllerForAnimationController:)])
        return animator == charon_edge_pop_animator(navigation) ? charon_edge_pop_interactor(navigation) : nil;
    return [delegate navigationController:navigation interactionControllerForAnimationController:animator];
}

static id<UIViewControllerAnimatedTransitioning> charon_navigation_animator(UINavigationController *navigation, UINavigationControllerOperation operation, UIViewController *from, UIViewController *to)
{
    id<UINavigationControllerDelegate> delegate = navigation.delegate;
    id<UIViewControllerAnimatedTransitioning> animator = [delegate respondsToSelector:@selector(navigationController:animationControllerForOperation:fromViewController:toViewController:)]
        ? [delegate navigationController:navigation animationControllerForOperation:operation fromViewController:from toViewController:to] : nil;
    if (!animator && operation == UINavigationControllerOperationPop)
        animator = charon_edge_pop_animator(navigation);
    return animator;
}

static void (^charon_finisher(CharonTransitionCoordinator *coordinator, UIViewController *from, UIViewController *to, void (^completion)(void)))(BOOL)
{
    return ^(BOOL finished) {
        charon_detach(from, coordinator);
        charon_detach(to, coordinator);
        if (completion)
            completion();
    };
}

@interface CharonTransitionCoordinatorInstaller : NSObject
@end

@implementation CharonTransitionCoordinatorInstaller

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
        if (charon_document_menu_present(self, presented, animated, completion))
            return;
        if (charon_popover_present(self, presented, animated, completion))
            return;
        UIViewController *presenting = charon_presenting_root(self);
        UIModalPresentationStyle style = presented.modalPresentationStyle;
        if (charon_release_presents()) {
            CharonSheetHandover *stale = objc_getAssociatedObject(presented, charon_sheet_handover_key);
            if (stale && !presented.presentingViewController)
                charon_sheet_handover_end(presented, stale);
            UIPresentationController *sheet = charon_sheet_for(presented, presenting);
            if (sheet || (style >= 4 && style <= 6)) {
                if (sheet) {
                    CharonSheetHandover *handover = [[CharonSheetHandover alloc] init];
                    handover.sheet = sheet;
                    handover.original = presented.transitioningDelegate;
                    objc_setAssociatedObject(presented, charon_sheet_handover_key, handover, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    presented.transitioningDelegate = handover;
                    presented.modalPresentationStyle = UIModalPresentationCustom;
                }
                presentOriginal(self, present, presented, animated, completion);
                presented.modalPresentationStyle = style;
                return;
            }
        }
        UIPresentationController *presentation = charon_presentation_for(presented, presenting, self);
        if (presentation) {
            id<UIViewControllerAnimatedTransitioning> presentationAnimator = animated ? charon_present_animator(presented.transitioningDelegate, presented, presenting, self) ?: [presentation charon_transitionAnimator] : nil;
            CharonTransitionCoordinator *coordinator = charon_begin(presenting, presented, animated, YES, style);
            charon_presentation_present(presenting, presented, presentation, presentationAnimator, ^{
                presented.modalPresentationStyle = UIModalPresentationFullScreen;
                presentOriginal(self, present, presented, NO, nil);
                presented.modalPresentationStyle = style;
            }, charon_finisher(coordinator, presenting, presented, completion));
            return;
        }
        id<UIViewControllerAnimatedTransitioning> animator = animated && (style == UIModalPresentationFullScreen || style >= 4) ? charon_present_animator(presented.transitioningDelegate, presented, presenting, self) : nil;
        if (animator) {
            CharonTransitionCoordinator *coordinator = charon_begin(presenting, presented, YES, YES, style);
            BOOL started = charon_custom_transition(CharonTransitionPresent, presenting, presented, self, animator, charon_interactor_for(presented.transitioningDelegate, animator, YES), style, ^{
                presented.modalPresentationStyle = style >= 4 ? UIModalPresentationFullScreen : style;
                presentOriginal(self, present, presented, NO, nil);
                presented.modalPresentationStyle = style;
            }, ^{
                dismissOriginal(presenting, dismiss, NO, nil);
            }, charon_finisher(coordinator, presenting, presented, completion));
            if (started)
                return;
            charon_detach(presenting, coordinator);
            charon_detach(presented, coordinator);
        }
        CharonTransitionCoordinator *coordinator = charon_begin(self, presented, animated, YES, presented.modalPresentationStyle);
        presentOriginal(self, present, presented, animated, ^{
            [coordinator finish];
            charon_detach(self, coordinator);
            charon_detach(presented, coordinator);
            if (completion)
                completion();
        });
    }), method_getTypeEncoding(presentMethod));

    class_replaceMethod(controller, dismiss, imp_implementationWithBlock(^(UIViewController *self, BOOL animated, void (^completion)(void)) {
        if (charon_popover_dismiss(self, animated, completion))
            return;
        UIViewController *presented = self.presentedViewController ?: self;
        UIViewController *presenting = presented.presentingViewController ?: self;
        if (charon_release_presents()) {
            CharonSheetHandover *handover = objc_getAssociatedObject(presented, charon_sheet_handover_key);
            UIModalPresentationStyle style = presented.modalPresentationStyle;
            if (handover || (style >= 4 && style <= 6)) {
                dismissOriginal(self, dismiss, animated, completion);
                return;
            }
        }
        UIPresentationController *presentation = presented.presentingViewController ? charon_presentation_controller_of(presented) : nil;
        if (presentation && presentation.containerView) {
            id<UIViewControllerAnimatedTransitioning> presentationAnimator = animated ? charon_dismiss_animator(presented.transitioningDelegate, presented) ?: [presentation charon_transitionAnimator] : nil;
            CharonTransitionCoordinator *coordinator = charon_begin(presented, presenting, animated, YES, presented.modalPresentationStyle);
            charon_presentation_dismiss(presented, presenting, presentation, presentationAnimator, ^{
                dismissOriginal(self, dismiss, NO, nil);
            }, charon_finisher(coordinator, presented, presenting, completion));
            return;
        }
        id<UIViewControllerAnimatedTransitioning> animator = animated && presented.presentingViewController ? charon_dismiss_animator(presented.transitioningDelegate, presented) : nil;
        if (animator) {
            CharonTransitionCoordinator *coordinator = charon_begin(presented, presenting, YES, YES, presented.modalPresentationStyle);
            UIModalPresentationStyle style = presented.modalPresentationStyle;
            BOOL started = charon_custom_transition(CharonTransitionDismiss, presented, presenting, self, animator, charon_interactor_for(presented.transitioningDelegate, animator, NO), style, ^{
                dismissOriginal(self, dismiss, NO, nil);
            }, ^{
                presentOriginal(presenting, present, presented, NO, nil);
            }, charon_finisher(coordinator, presented, presenting, completion));
            if (started)
                return;
            charon_detach(presented, coordinator);
            charon_detach(presenting, coordinator);
        }
        CharonTransitionCoordinator *coordinator = charon_begin(presented, presenting, animated, YES, presented.modalPresentationStyle);
        dismissOriginal(self, dismiss, animated, ^{
            [coordinator finish];
            charon_detach(presented, coordinator);
            charon_detach(presenting, coordinator);
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
        id<UIViewControllerAnimatedTransitioning> animator = animated && from ? charon_navigation_animator(self, UINavigationControllerOperationPush, from, pushed) : nil;
        if (animator) {
            CharonTransitionCoordinator *coordinator = charon_begin(from, pushed, YES, NO, UIModalPresentationNone);
            BOOL started = charon_custom_transition(CharonTransitionPush, from, pushed, self, animator, charon_navigation_interactor(self, animator), UIModalPresentationNone, ^{
                pushOriginal(self, push, pushed, NO);
            }, ^{
                popOriginal(self, pop, NO);
            }, charon_finisher(coordinator, from, pushed, nil));
            if (started)
                return;
            charon_detach(from, coordinator);
            charon_detach(pushed, coordinator);
        }
        BOOL running = animated && from;
        CharonTransitionCoordinator *coordinator = running ? charon_begin(from, pushed, animated, NO, UIModalPresentationNone) : nil;
        pushOriginal(self, push, pushed, animated);
        if (coordinator)
            charon_end_after(coordinator, from, pushed, animated, NO);
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
        id<UIViewControllerAnimatedTransitioning> animator = animated && running ? charon_navigation_animator(self, UINavigationControllerOperationPop, from, target) : nil;
        if (animator) {
            CharonTransitionCoordinator *coordinator = charon_begin(from, target, YES, NO, UIModalPresentationNone);
            NSArray *stack = self.viewControllers;
            NSUInteger index = [stack indexOfObject:target];
            NSArray *popped = index != NSNotFound ? [stack subarrayWithRange:NSMakeRange(index + 1, stack.count - index - 1)] : @[];
            BOOL started = charon_custom_transition(CharonTransitionPop, from, target, self, animator, charon_navigation_interactor(self, animator), UIModalPresentationNone, ^{
                native(NO);
            }, nil, charon_finisher(coordinator, from, target, nil));
            if (started)
                return popped;
            charon_detach(from, coordinator);
            charon_detach(target, coordinator);
        }
        CharonTransitionCoordinator *coordinator = running ? charon_begin(from, target, animated, NO, UIModalPresentationNone) : nil;
        NSArray *result = native(animated);
        if (coordinator)
            charon_end_after(coordinator, from, target, animated, NO);
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
        id<UIViewControllerAnimatedTransitioning> animator = animated && from ? charon_navigation_animator(self, UINavigationControllerOperationPop, from, to) : nil;
        if (animator) {
            CharonTransitionCoordinator *coordinator = charon_begin(from, to, YES, NO, UIModalPresentationNone);
            BOOL started = charon_custom_transition(CharonTransitionPop, from, to, self, animator, charon_navigation_interactor(self, animator), UIModalPresentationNone, ^{
                popOriginal(self, pop, NO);
            }, ^{
                pushOriginal(self, push, from, NO);
            }, charon_finisher(coordinator, from, to, nil));
            if (started)
                return from;
            charon_detach(from, coordinator);
            charon_detach(to, coordinator);
        }
        CharonTransitionCoordinator *coordinator = from ? charon_begin(from, to, animated, NO, UIModalPresentationNone) : nil;
        UIViewController *result = popOriginal(self, pop, animated);
        if (coordinator)
            charon_end_after(coordinator, from, to, animated, NO);
        return result;
    }), method_getTypeEncoding(popMethod));
}

@end
