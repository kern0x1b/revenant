#import "RevenantCustomTransition.h"
#import "RevenantTransitionCoordinator.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface RevenantViewState : NSObject
@property (nonatomic, weak) UIView *superview;
@property (nonatomic) NSUInteger index;
@property (nonatomic) CGRect frame;
@property (nonatomic) UIViewAutoresizing autoresizing;
@property (nonatomic) BOOL hidden;
@end

@implementation RevenantViewState
@synthesize superview = _superview;
@synthesize index = _index;
@synthesize frame = _frame;
@synthesize autoresizing = _autoresizing;
@synthesize hidden = _hidden;

+ (instancetype)captureView:(UIView *)view
{
    RevenantViewState *state = [[RevenantViewState alloc] init];
    state.superview = view.superview;
    state.index = view.superview ? [view.superview.subviews indexOfObject:view] : 0;
    state.frame = view.frame;
    state.autoresizing = view.autoresizingMask;
    state.hidden = view.hidden;
    return state;
}

- (void)restoreView:(UIView *)view
{
    UIView *parent = _superview;
    view.hidden = _hidden;
    if (!parent) {
        [view removeFromSuperview];
        return;
    }
    NSUInteger index = MIN(_index, parent.subviews.count);
    if (view.superview == parent && [parent.subviews indexOfObject:view] == index) {
        view.frame = _frame;
        return;
    }
    [view removeFromSuperview];
    [parent insertSubview:view atIndex:index];
    view.frame = _frame;
    view.autoresizingMask = _autoresizing;
}

@end

static const char revenant_deferral_key;

typedef NS_ENUM(NSInteger, RevenantDeferralMode) {
    RevenantDeferralPass,
    RevenantDeferralNative,
    RevenantDeferralSwallow,
    RevenantDeferralDidOnly
};

@interface RevenantDeferral : NSObject
@property (nonatomic) RevenantDeferralMode mode;
@property (nonatomic, strong) NSMutableArray *pending;
@property (nonatomic) Class original;
@property (nonatomic) NSInteger owners;
@end

@implementation RevenantDeferral
@synthesize mode = _mode;
@synthesize pending = _pending;
@synthesize original = _original;
@synthesize owners = _owners;
@end

static Class revenant_deferring_class(Class cls)
{
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });
    NSString *name = [@"RevenantDeferring_" stringByAppendingString:NSStringFromClass(cls)];
    @synchronized (cache) {
        Class existing = cache[name];
        if (existing)
            return existing;
        Class created = objc_allocateClassPair(cls, name.UTF8String, 0);
        if (!created)
            return nil;
        for (NSString *selectorName in @[@"viewWillAppear:", @"viewWillDisappear:", @"viewDidAppear:", @"viewDidDisappear:"]) {
            SEL selector = NSSelectorFromString(selectorName);
            BOOL did = [selectorName hasPrefix:@"viewDid"];
            class_addMethod(created, selector, imp_implementationWithBlock(^(UIViewController *self, BOOL animated) {
                RevenantDeferral *deferral = objc_getAssociatedObject(self, &revenant_deferral_key);
                if (deferral.mode == RevenantDeferralSwallow || (deferral.mode == RevenantDeferralDidOnly && !did))
                    return;
                if ((deferral.mode == RevenantDeferralNative || deferral.mode == RevenantDeferralDidOnly) && did) {
                    [deferral.pending addObject:@[self, selectorName]];
                    return;
                }
                struct objc_super target = {self, cls};
                ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(&target, selector, animated);
            }), "v@:c");
        }
        class_addMethod(created, @selector(class), imp_implementationWithBlock(^Class(id self) { return cls; }), "#@:");
        objc_registerClassPair(created);
        cache[name] = created;
        return created;
    }
}

static void revenant_collect(UIViewController *controller, NSMutableArray *into)
{
    if (!controller || [into containsObject:controller])
        return;
    [into addObject:controller];
    for (UIViewController *child in controller.childViewControllers)
        revenant_collect(child, into);
}

static NSArray *revenant_begin_deferral(NSArray *controllers)
{
    NSMutableArray *begun = [NSMutableArray array];
    for (UIViewController *controller in controllers) {
        Class current = object_getClass(controller);
        if (strncmp(class_getName(current), "RevenantDeferring_", 18) == 0) {
            RevenantDeferral *shared = objc_getAssociatedObject(controller, &revenant_deferral_key);
            if (shared) {
                shared.owners++;
                shared.mode = RevenantDeferralNative;
                [begun addObject:@[controller, shared]];
            }
            continue;
        }
        if (strncmp(class_getName(current), "NSKVONotifying", 14) == 0)
            continue;
        Class replacement = revenant_deferring_class(current);
        if (!replacement)
            continue;
        RevenantDeferral *deferral = [[RevenantDeferral alloc] init];
        deferral.mode = RevenantDeferralNative;
        deferral.pending = [NSMutableArray array];
        deferral.original = current;
        deferral.owners = 1;
        objc_setAssociatedObject(controller, &revenant_deferral_key, deferral, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        object_setClass(controller, replacement);
        [begun addObject:@[controller, deferral]];
    }
    return begun;
}

static void revenant_set_mode(NSArray *begun, RevenantDeferralMode mode)
{
    for (NSArray *entry in begun)
        [entry[1] setMode:mode];
}

static NSArray *revenant_take_pending(NSArray *begun)
{
    NSMutableArray *pending = [NSMutableArray array];
    for (NSArray *entry in begun) {
        RevenantDeferral *deferral = entry[1];
        [pending addObjectsFromArray:deferral.pending];
        [deferral.pending removeAllObjects];
    }
    return pending;
}

static void revenant_release_deferral(NSArray *begun)
{
    for (NSArray *entry in begun) {
        UIViewController *controller = entry[0];
        RevenantDeferral *deferral = entry[1];
        if (--deferral.owners > 0)
            continue;
        deferral.mode = RevenantDeferralPass;
        object_setClass(controller, deferral.original);
        objc_setAssociatedObject(controller, &revenant_deferral_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@implementation RevenantTransitionContext {
@public
    UIView *_container;
    UIViewController *_from;
    UIViewController *_to;
    BOOL _animated;
    BOOL _interactive;
    BOOL _cancelled;
    BOOL _completed;
    UIModalPresentationStyle _style;
    CGRect _initialFrom, _finalFrom, _initialTo, _finalTo;
    BOOL _fromViewKeyHidden;
    BOOL _toViewKeyHidden;
    void (^_finish)(BOOL didComplete);
    id<UIViewControllerAnimatedTransitioning> _animator;
    id<UIViewControllerInteractiveTransitioning> _interactor;
    __weak RevenantTransitionCoordinator *_coordinator;
}

- (id<UIViewControllerAnimatedTransitioning>)revenant_animator
{
    return _animator;
}

- (UIView *)containerView { return _container; }
- (BOOL)isAnimated { return _animated; }
- (BOOL)isInteractive { return _interactive; }
- (BOOL)transitionWasCancelled { return _cancelled; }
- (UIModalPresentationStyle)presentationStyle { return _style; }
- (CGAffineTransform)targetTransform { return CGAffineTransformIdentity; }

- (void)updateInteractiveTransition:(CGFloat)percentComplete
{
    [_coordinator revenant_setPercent:percentComplete];
}

- (void)finishInteractiveTransition
{
    [_coordinator revenant_interactionEndedCancelled:NO];
}

- (void)cancelInteractiveTransition
{
    _cancelled = YES;
    [_coordinator revenant_interactionEndedCancelled:YES];
}

- (void)pauseInteractiveTransition
{
}

- (void)completeTransition:(BOOL)didComplete
{
    if (_completed)
        return;
    _completed = YES;
    if (_finish)
        _finish(didComplete && !_cancelled);
}

- (UIViewController *)viewControllerForKey:(UITransitionContextViewControllerKey)key
{
    if ([key isEqualToString:UITransitionContextFromViewControllerKey])
        return _from;
    if ([key isEqualToString:UITransitionContextToViewControllerKey])
        return _to;
    return nil;
}

- (UIView *)viewForKey:(UITransitionContextViewKey)key
{
    if ([key isEqualToString:UITransitionContextFromViewKey])
        return _fromViewKeyHidden ? nil : _from.view;
    if ([key isEqualToString:UITransitionContextToViewKey])
        return _toViewKeyHidden ? nil : _to.view;
    return nil;
}

- (CGRect)initialFrameForViewController:(UIViewController *)controller
{
    return controller == _from ? _initialFrom : controller == _to ? _initialTo : CGRectZero;
}

- (CGRect)finalFrameForViewController:(UIViewController *)controller
{
    return controller == _from ? _finalFrom : controller == _to ? _finalTo : CGRectZero;
}

@end

static void revenant_interactive_transition(RevenantTransitionKind kind, UIViewController *from, UIViewController *to, id<UIViewControllerAnimatedTransitioning> animator, id<UIViewControllerInteractiveTransitioning> interactor, UIModalPresentationStyle style, void (^native)(void), void (^completion)(BOOL finished))
{
    UIView *fromView = from.view;
    UIView *toView = to.view;
    UIWindow *window = fromView.window ?: [UIApplication sharedApplication].keyWindow;
    BOOL modal = kind == RevenantTransitionPresent || kind == RevenantTransitionDismiss;
    BOOL keepsPresenter = kind == RevenantTransitionPresent && (style == 4 || style == 5 || style == 6);
    UIView *fromParent = fromView.superview;
    UIView *host = modal ? window : (fromParent.superview ?: fromParent);
    RevenantViewState *fromPre = [RevenantViewState captureView:fromView];
    CGRect initialFrom = fromParent ? [fromParent convertRect:fromView.frame toView:host] : window.bounds;
    CGRect finalTo = initialFrom;
    if (kind == RevenantTransitionPresent)
        finalTo = [window convertRect:window.screen.applicationFrame fromWindow:nil];
    else if (kind == RevenantTransitionDismiss)
        finalTo = toView.superview ? [toView.superview convertRect:toView.frame toView:host] : toView.frame;

    NSMutableArray *controllers = [NSMutableArray array];
    revenant_collect(from, controllers);
    revenant_collect(to, controllers);
    NSArray *begun = revenant_begin_deferral(controllers);
    revenant_set_mode(begun, RevenantDeferralNative);
    [from viewWillDisappear:YES];
    [to viewWillAppear:YES];
    revenant_set_mode(begun, RevenantDeferralSwallow);

    UIView *container = [[UIView alloc] initWithFrame:host.bounds];
    container.backgroundColor = [UIColor clearColor];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:container];
    [container addSubview:fromView];
    fromView.frame = initialFrom;
    toView.frame = finalTo;

    RevenantTransitionContext *context = [[RevenantTransitionContext alloc] init];
    context->_container = container;
    context->_from = from;
    context->_to = to;
    context->_animated = YES;
    context->_style = modal ? (kind == RevenantTransitionPresent ? to.modalPresentationStyle : from.modalPresentationStyle) : (UIModalPresentationStyle)-1;
    context->_initialFrom = initialFrom;
    context->_finalFrom = kind == RevenantTransitionDismiss ? initialFrom : CGRectZero;
    context->_initialTo = CGRectZero;
    context->_finalTo = finalTo;
    context->_interactive = YES;
    context->_animator = animator;
    context->_interactor = interactor;
    NSTimeInterval duration = [animator transitionDuration:context];
    id<UIViewControllerTransitionCoordinator> coordinator = to.transitionCoordinator ?: from.transitionCoordinator;
    if ([coordinator isKindOfClass:[RevenantTransitionCoordinator class]]) {
        [(RevenantTransitionCoordinator *)coordinator setContainer:container duration:duration];
        [(RevenantTransitionCoordinator *)coordinator revenant_setInteractive:YES];
        context->_coordinator = (RevenantTransitionCoordinator *)coordinator;
    }

    void (^finalize)(BOOL) = ^(BOOL didComplete) {
        [container removeFromSuperview];
        NSArray *pending = revenant_take_pending(begun);
        revenant_set_mode(begun, RevenantDeferralPass);
        if (!didComplete) {
            [to viewWillDisappear:YES];
            [to viewDidDisappear:YES];
            [from viewWillAppear:YES];
            [from viewDidAppear:YES];
            pending = @[];
        }
        NSMutableArray *appear = [NSMutableArray array], *disappear = [NSMutableArray array];
        for (NSArray *entry in pending) {
            NSMutableArray *target = [entry[1] hasSuffix:@"Appear:"] ? appear : disappear;
            [target addObject:entry];
        }
        NSArray *ordered = modal ? [appear arrayByAddingObjectsFromArray:disappear] : [disappear arrayByAddingObjectsFromArray:appear];
        for (NSArray *entry in ordered)
            ((void (*)(id, SEL, BOOL))objc_msgSend)(entry[0], NSSelectorFromString(entry[1]), YES);
        revenant_set_mode(begun, RevenantDeferralSwallow);
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSArray *entry in begun)
                    if ([entry[1] owners] == 1)
                        [entry[1] setMode:RevenantDeferralPass];
                revenant_release_deferral(begun);
            });
        });
        if ([coordinator isKindOfClass:[RevenantTransitionCoordinator class]]) {
            [(RevenantTransitionCoordinator *)coordinator revenant_setCancelled:!didComplete];
            [(RevenantTransitionCoordinator *)coordinator finish];
        }
        if (completion)
            completion(didComplete);
        if ([animator respondsToSelector:@selector(animationEnded:)])
            [animator animationEnded:didComplete];
    };
    context->_finish = ^(BOOL didComplete) {
        if (!didComplete) {
            [toView removeFromSuperview];
            [fromView removeFromSuperview];
            [fromPre restoreView:fromView];
            finalize(NO);
            return;
        }
        revenant_set_mode(begun, RevenantDeferralDidOnly);
        UIView *nativeParent = modal ? nil : toView.superview;
        (void)nativeParent;
        native();
        if (!keepsPresenter)
            [fromView removeFromSuperview];
        void (^settle)(void) = ^{
            if (toView.superview == container) {
                CGRect frame = kind == RevenantTransitionDismiss ? [container convertRect:toView.frame toView:window] : finalTo;
                [toView removeFromSuperview];
                if (kind == RevenantTransitionDismiss)
                    [window insertSubview:toView atIndex:0];
                else
                    [host addSubview:toView];
                toView.frame = frame;
            }
            [fromView removeFromSuperview];
            if (keepsPresenter)
                [fromPre restoreView:fromView];
            finalize(YES);
        };
        if (modal)
            settle();
        else
            dispatch_async(dispatch_get_main_queue(), settle);
    };
    [interactor startInteractiveTransition:context];
}

static NSArray *revenant_group(UIViewController *controller)
{
    NSMutableArray *group = [NSMutableArray array];
    revenant_collect(controller, group);
    return group;
}

BOOL revenant_custom_transition(RevenantTransitionKind kind, UIViewController *from, UIViewController *to, UIViewController *source, id<UIViewControllerAnimatedTransitioning> animator, id<UIViewControllerInteractiveTransitioning> interactor, UIModalPresentationStyle style, void (^native)(void), void (^undo)(void), void (^completion)(BOOL finished))
{
    UIView *fromView = from.view;
    UIView *toView = to.view;
    UIWindow *window = fromView.window ?: [UIApplication sharedApplication].keyWindow;
    if (!fromView || !toView || !window || !animator)
        return NO;
    BOOL modal = kind == RevenantTransitionPresent || kind == RevenantTransitionDismiss;
    BOOL keepsPresenter = kind == RevenantTransitionPresent && (style == 4 || style == 5 || style == 6);

    if (interactor && !([interactor respondsToSelector:@selector(wantsInteractiveStart)] && ![interactor wantsInteractiveStart])) {
        revenant_interactive_transition(kind, from, to, animator, interactor, style, native, completion);
        return YES;
    }
    RevenantViewState *fromPre = [RevenantViewState captureView:fromView];
    UIView *fromParent = fromView.superview;
    CGRect initialFrom = fromParent ? [fromParent convertRect:fromView.frame toView:modal ? window : (fromParent.superview ?: fromParent)] : fromView.frame;
    UIView *navigationHost = modal ? nil : (fromParent.superview ?: fromParent);

    NSMutableArray *controllers = [NSMutableArray array];
    revenant_collect(from, controllers);
    revenant_collect(to, controllers);
    NSArray *begun = revenant_begin_deferral(controllers);
    native();

    void (^run)(void) = ^{
        UIView *host = modal ? window : navigationHost;
        UIView *toParent = toView.superview;
        if (!host || (!modal && !toParent)) {
            revenant_set_mode(begun, RevenantDeferralPass);
            for (NSArray *entry in revenant_take_pending(begun))
                ((void (*)(id, SEL, BOOL))objc_msgSend)(entry[0], NSSelectorFromString(entry[1]), NO);
            revenant_release_deferral(begun);
            if (completion)
                completion(YES);
            return;
        }
        revenant_set_mode(begun, RevenantDeferralSwallow);
        RevenantViewState *toPost = [RevenantViewState captureView:toView];
        CGRect finalTo = toParent ? [toParent convertRect:toView.frame toView:modal ? window : host] : toView.frame;

        UIView *container = [[UIView alloc] initWithFrame:modal ? window.bounds : host.bounds];
        container.backgroundColor = [UIColor clearColor];
        container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [host addSubview:container];

        [fromView removeFromSuperview];
        fromView.frame = initialFrom;
        [container addSubview:fromView];
        [toView removeFromSuperview];
        toView.frame = finalTo;

        RevenantTransitionContext *context = [[RevenantTransitionContext alloc] init];
        context->_container = container;
        context->_from = from;
        context->_to = to;
        context->_animated = YES;
        context->_style = modal ? (kind == RevenantTransitionPresent ? to.modalPresentationStyle : from.modalPresentationStyle) : (UIModalPresentationStyle)-1;
        context->_initialFrom = initialFrom;
        context->_finalFrom = kind == RevenantTransitionDismiss ? initialFrom : CGRectZero;
        context->_initialTo = CGRectZero;
        context->_finalTo = finalTo;
        BOOL interactive = interactor != nil && !([interactor respondsToSelector:@selector(wantsInteractiveStart)] && ![interactor wantsInteractiveStart]);
        context->_interactive = interactive;
        context->_animator = animator;
        context->_interactor = interactor;

        NSTimeInterval duration = [animator transitionDuration:context];
        id<UIViewControllerTransitionCoordinator> coordinator = to.transitionCoordinator ?: from.transitionCoordinator;
        if ([coordinator isKindOfClass:[RevenantTransitionCoordinator class]]) {
            [(RevenantTransitionCoordinator *)coordinator setContainer:container duration:duration];
            [(RevenantTransitionCoordinator *)coordinator revenant_setInteractive:interactive];
            context->_coordinator = (RevenantTransitionCoordinator *)coordinator;
        }

        context->_finish = ^(BOOL didComplete) {
            void (^finalize)(void) = ^{
                [container removeFromSuperview];
                NSArray *pending = revenant_take_pending(begun);
                revenant_set_mode(begun, RevenantDeferralPass);
                if (!didComplete) {
                    [to viewWillDisappear:YES];
                    [to viewDidDisappear:YES];
                    [from viewWillAppear:YES];
                    [from viewDidAppear:YES];
                    pending = @[];
                }
                NSMutableArray *appear = [NSMutableArray array], *disappear = [NSMutableArray array];
                for (NSArray *entry in pending) {
                    NSMutableArray *target = [entry[1] hasSuffix:@"Appear:"] ? appear : disappear;
                    [target addObject:entry];
                }
                NSArray *ordered = modal ? [appear arrayByAddingObjectsFromArray:disappear] : [disappear arrayByAddingObjectsFromArray:appear];
                for (NSArray *entry in ordered)
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(entry[0], NSSelectorFromString(entry[1]), YES);
                revenant_set_mode(begun, RevenantDeferralSwallow);
                dispatch_async(dispatch_get_main_queue(), ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (NSArray *entry in begun)
                            if ([entry[1] owners] == 1)
                                [entry[1] setMode:RevenantDeferralPass];
                        revenant_release_deferral(begun);
                    });
                });
                if ([coordinator isKindOfClass:[RevenantTransitionCoordinator class]]) {
                    [(RevenantTransitionCoordinator *)coordinator revenant_setCancelled:!didComplete];
                    [(RevenantTransitionCoordinator *)coordinator finish];
                }
                if (completion)
                    completion(didComplete);
                if ([animator respondsToSelector:@selector(animationEnded:)])
                    [animator animationEnded:didComplete];
            };
            if (didComplete) {
                [toView removeFromSuperview];
                [toPost restoreView:toView];
                [fromView removeFromSuperview];
                if (keepsPresenter)
                    [fromPre restoreView:fromView];
                finalize();
                return;
            }
            [toView removeFromSuperview];
            if (modal)
                [toPost restoreView:toView];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (undo)
                    undo();
                if (modal)
                    finalize();
                else
                    dispatch_async(dispatch_get_main_queue(), finalize);
            });
        };

        if (interactive)
            [interactor startInteractiveTransition:context];
        else
            [animator animateTransition:context];
    };
    if (modal)
        run();
    else
        dispatch_async(dispatch_get_main_queue(), run);
    return YES;
}

static const char revenant_presentation_key;

UIPresentationController *revenant_presentation_controller_of(UIViewController *controller)
{
    return objc_getAssociatedObject(controller, &revenant_presentation_key);
}

void revenant_set_presentation_controller(UIViewController *controller, UIPresentationController *presentation)
{
    objc_setAssociatedObject(controller, &revenant_presentation_key, presentation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (presentation.presentedViewController == controller && [presentation respondsToSelector:@selector(revenant_ownedByPresentedViewController)])
        [presentation revenant_ownedByPresentedViewController];
}

@interface RevenantPresentationContainer : UIView
@property (nonatomic, weak) UIPresentationController *presentation;
@end

@implementation RevenantPresentationContainer
@synthesize presentation = _presentation;

- (void)layoutSubviews
{
    [_presentation containerViewWillLayoutSubviews];
    [super layoutSubviews];
    [_presentation containerViewDidLayoutSubviews];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self && [_presentation revenant_containerIgnoresDirectTouches] ? nil : hit;
}

@end

@interface RevenantImmediateAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@end

@implementation RevenantImmediateAnimator
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context { return 0; }
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context
{
    UIViewController *to = [context viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *toView = [context viewForKey:UITransitionContextToViewKey];
    if (toView && toView.superview != context.containerView && [context finalFrameForViewController:to].size.width > 0) {
        toView.frame = [context finalFrameForViewController:to];
        [context.containerView addSubview:toView];
    }
    [context completeTransition:YES];
}
@end

static void revenant_presentation_run(BOOL presenting, UIViewController *from, UIViewController *to, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
    UIWindow *window = (presenting ? from.view.window : from.view.window) ?: [UIApplication sharedApplication].keyWindow;
    BOOL removes = [presentation shouldRemovePresentersView];
    UIView *presenterView = presenting ? from.view : to.view;
    UIView *presentedView = presenting ? to.view : from.view;
    BOOL immediate = animator == nil;
    if (immediate)
        animator = [[RevenantImmediateAnimator alloc] init];

    RevenantPresentationContainer *container = presenting ? nil : (RevenantPresentationContainer *)presentation.containerView;
    RevenantViewState *presenterPre = [RevenantViewState captureView:presenterView];
    NSMutableArray *controllers = [NSMutableArray array];
    revenant_collect(from, controllers);
    revenant_collect(to, controllers);
    NSArray *begun = revenant_begin_deferral(controllers);
    revenant_set_mode(begun, RevenantDeferralSwallow);

    if (presenting) {
        container = [[RevenantPresentationContainer alloc] initWithFrame:window.bounds];
        container.presentation = presentation;
        container.backgroundColor = [UIColor clearColor];
        container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [window addSubview:container];
        [presentation revenant_setContainerView:container];
        CGRect presenterFrame = [container convertRect:presenterView.frame fromView:presenterView.superview];
        if (removes) {
            [presenterView removeFromSuperview];
            presenterView.frame = presenterFrame;
            [container addSubview:presenterView];
        }
        revenant_set_mode(begun, RevenantDeferralPass);
        [presentation presentationTransitionWillBegin];
        revenant_set_mode(begun, RevenantDeferralSwallow);
        native();
        [presentedView removeFromSuperview];
        if (removes) {
            [presenterView removeFromSuperview];
            presenterView.frame = presenterFrame;
            [container addSubview:presenterView];
        } else {
            [presenterPre restoreView:presenterView];
        }
        revenant_set_mode(begun, RevenantDeferralPass);
        if (removes)
            [from viewWillDisappear:YES];
        [to viewWillAppear:YES];
        revenant_set_mode(begun, RevenantDeferralSwallow);
    } else {
        revenant_set_mode(begun, RevenantDeferralPass);
        [presentation dismissalTransitionWillBegin];
        [from viewWillDisappear:YES];
        if (removes)
            [to viewWillAppear:YES];
        revenant_set_mode(begun, RevenantDeferralSwallow);
    }

    CGRect presentedFrame = [presentation frameOfPresentedViewInContainerView];
    RevenantTransitionContext *context = [[RevenantTransitionContext alloc] init];
    context->_container = container;
    context->_from = from;
    context->_to = to;
    context->_animated = !immediate;
    context->_style = presentation.presentationStyle;
    context->_initialFrom = presenting ? presentedFrame : presentedFrame;
    context->_finalFrom = presenting ? (removes ? CGRectZero : container.bounds) : presentedFrame;
    context->_initialTo = CGRectZero;
    context->_finalTo = presenting ? presentedFrame : container.bounds;
    context->_animator = animator;
    context->_fromViewKeyHidden = presenting ? !removes : NO;
    context->_toViewKeyHidden = presenting ? NO : !removes;
    NSTimeInterval duration = [animator transitionDuration:context];
    id<UIViewControllerTransitionCoordinator> coordinator = to.transitionCoordinator ?: from.transitionCoordinator;
    if ([coordinator isKindOfClass:[RevenantTransitionCoordinator class]])
        [(RevenantTransitionCoordinator *)coordinator setContainer:container duration:duration];

    __block UIViewController *(^unused)(void) = nil;
    (void)unused;
    context->_finish = ^(BOOL didComplete) {
        UIView *shown = presentation.presentedView;
        if (presenting) {
            if (shown.superview != container) {
                [shown removeFromSuperview];
                [container addSubview:shown];
            }
            shown.frame = presentedFrame;
            [presentation presentationTransitionDidEnd:didComplete];
            if (removes)
                [presenterView removeFromSuperview];
        } else {
            [presentation dismissalTransitionDidEnd:didComplete];
            if (didComplete) {
                native();
                if (presenterView.superview == container && window) {
                    presenterView.frame = [container convertRect:presenterView.frame toView:window];
                    [window insertSubview:presenterView belowSubview:container];
                }
                [container removeFromSuperview];
                [presentation revenant_setContainerView:nil];
                if (!presenterView.window && window)
                    [window insertSubview:presenterView atIndex:0];
            }
        }
        revenant_set_mode(begun, RevenantDeferralPass);
        if (presenting) {
            [to viewDidAppear:YES];
            if (removes)
                [from viewDidDisappear:YES];
        } else if (didComplete) {
            if (removes)
                [to viewDidAppear:YES];
            [from viewDidDisappear:YES];
        } else {
            if (removes) {
                [to viewWillDisappear:YES];
                [to viewDidDisappear:YES];
            }
            [from viewWillAppear:YES];
            [from viewDidAppear:YES];
        }
        revenant_set_mode(begun, RevenantDeferralSwallow);
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSArray *entry in begun)
                    if ([entry[1] owners] == 1)
                        [entry[1] setMode:RevenantDeferralPass];
                revenant_release_deferral(begun);
            });
        });
        if ([coordinator isKindOfClass:[RevenantTransitionCoordinator class]])
            [(RevenantTransitionCoordinator *)coordinator finish];
        if (completion)
            completion(didComplete);
        if (!immediate && [animator respondsToSelector:@selector(animationEnded:)])
            [animator animationEnded:didComplete];
    };
    [animator animateTransition:context];
}

void revenant_presentation_present(UIViewController *presenting, UIViewController *presented, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
    revenant_set_presentation_controller(presented, presentation);
    revenant_presentation_run(YES, presenting, presented, presentation, animator, native, completion);
}

void revenant_presentation_dismiss(UIViewController *presented, UIViewController *presenting, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
    revenant_presentation_run(NO, presented, presenting, presentation, animator, native, completion);
}
