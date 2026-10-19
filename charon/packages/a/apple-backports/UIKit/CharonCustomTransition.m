#import "CharonCustomTransition.h"
#import "CharonTransitionCoordinator.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface CharonViewState : NSObject
@property (nonatomic, weak) UIView *superview;
@property (nonatomic) NSUInteger index;
@property (nonatomic) CGRect frame;
@property (nonatomic) UIViewAutoresizing autoresizing;
@property (nonatomic) BOOL hidden;
@end

@implementation CharonViewState
@synthesize superview = _superview;
@synthesize index = _index;
@synthesize frame = _frame;
@synthesize autoresizing = _autoresizing;
@synthesize hidden = _hidden;

+ (instancetype)captureView:(UIView *)view
{
    CharonViewState *state = [[CharonViewState alloc] init];
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

static const char charon_deferral_key;

typedef NS_ENUM(NSInteger, CharonDeferralMode) {
    CharonDeferralPass,
    CharonDeferralNative,
    CharonDeferralSwallow,
    CharonDeferralDidOnly
};

@interface CharonDeferral : NSObject
@property (nonatomic) CharonDeferralMode mode;
@property (nonatomic, strong) NSMutableArray *pending;
@property (nonatomic) Class original;
@property (nonatomic) NSInteger owners;
@end

@implementation CharonDeferral
@synthesize mode = _mode;
@synthesize pending = _pending;
@synthesize original = _original;
@synthesize owners = _owners;
@end

static Class charon_deferring_class(Class cls)
{
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });
    NSString *name = [@"CharonDeferring_" stringByAppendingString:NSStringFromClass(cls)];
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
                CharonDeferral *deferral = objc_getAssociatedObject(self, &charon_deferral_key);
                if (deferral.mode == CharonDeferralSwallow || (deferral.mode == CharonDeferralDidOnly && !did))
                    return;
                if ((deferral.mode == CharonDeferralNative || deferral.mode == CharonDeferralDidOnly) && did) {
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

static void charon_collect(UIViewController *controller, NSMutableArray *into)
{
    if (!controller || [into containsObject:controller])
        return;
    [into addObject:controller];
    for (UIViewController *child in controller.childViewControllers)
        charon_collect(child, into);
}

static NSArray *charon_begin_deferral(NSArray *controllers)
{
    NSMutableArray *begun = [NSMutableArray array];
    for (UIViewController *controller in controllers) {
        Class current = object_getClass(controller);
        if (strncmp(class_getName(current), "CharonDeferring_", 16) == 0) {
            CharonDeferral *shared = objc_getAssociatedObject(controller, &charon_deferral_key);
            if (shared) {
                shared.owners++;
                shared.mode = CharonDeferralNative;
                [begun addObject:@[controller, shared]];
            }
            continue;
        }
        if (strncmp(class_getName(current), "NSKVONotifying", 14) == 0)
            continue;
        Class replacement = charon_deferring_class(current);
        if (!replacement)
            continue;
        CharonDeferral *deferral = [[CharonDeferral alloc] init];
        deferral.mode = CharonDeferralNative;
        deferral.pending = [NSMutableArray array];
        deferral.original = current;
        deferral.owners = 1;
        objc_setAssociatedObject(controller, &charon_deferral_key, deferral, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        object_setClass(controller, replacement);
        [begun addObject:@[controller, deferral]];
    }
    return begun;
}

static void charon_set_mode(NSArray *begun, CharonDeferralMode mode)
{
    for (NSArray *entry in begun)
        [entry[1] setMode:mode];
}

static NSArray *charon_take_pending(NSArray *begun)
{
    NSMutableArray *pending = [NSMutableArray array];
    for (NSArray *entry in begun) {
        CharonDeferral *deferral = entry[1];
        [pending addObjectsFromArray:deferral.pending];
        [deferral.pending removeAllObjects];
    }
    return pending;
}

static void charon_release_deferral(NSArray *begun)
{
    for (NSArray *entry in begun) {
        UIViewController *controller = entry[0];
        CharonDeferral *deferral = entry[1];
        if (--deferral.owners > 0)
            continue;
        deferral.mode = CharonDeferralPass;
        object_setClass(controller, deferral.original);
        objc_setAssociatedObject(controller, &charon_deferral_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@implementation CharonTransitionContext {
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
    __weak CharonTransitionCoordinator *_coordinator;
}

- (id<UIViewControllerAnimatedTransitioning>)charon_animator
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
    [_coordinator charon_setPercent:percentComplete];
}

- (void)finishInteractiveTransition
{
    [_coordinator charon_interactionEndedCancelled:NO];
}

- (void)cancelInteractiveTransition
{
    _cancelled = YES;
    [_coordinator charon_interactionEndedCancelled:YES];
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

static void charon_interactive_transition(CharonTransitionKind kind, UIViewController *from, UIViewController *to, id<UIViewControllerAnimatedTransitioning> animator, id<UIViewControllerInteractiveTransitioning> interactor, UIModalPresentationStyle style, void (^native)(void), void (^completion)(BOOL finished))
{
    UIView *fromView = from.view;
    UIView *toView = to.view;
    UIWindow *window = fromView.window ?: [UIApplication sharedApplication].keyWindow;
    BOOL modal = kind == CharonTransitionPresent || kind == CharonTransitionDismiss;
    BOOL keepsPresenter = kind == CharonTransitionPresent && (style == 4 || style == 5 || style == 6);
    UIView *fromParent = fromView.superview;
    UIView *host = modal ? window : (fromParent.superview ?: fromParent);
    CharonViewState *fromPre = [CharonViewState captureView:fromView];
    CGRect initialFrom = fromParent ? [fromParent convertRect:fromView.frame toView:host] : window.bounds;
    CGRect finalTo = initialFrom;
    if (kind == CharonTransitionPresent)
        finalTo = [window convertRect:window.screen.applicationFrame fromWindow:nil];
    else if (kind == CharonTransitionDismiss)
        /* The release frames the presenter's view again in its own dismissal, which runs when the interaction
           has finished; until then the frame it gave the view before taking it out of the window stands for it. */
        finalTo = toView.superview ? [toView.superview convertRect:toView.frame toView:host] : toView.frame;

    NSMutableArray *controllers = [NSMutableArray array];
    charon_collect(from, controllers);
    charon_collect(to, controllers);
    NSArray *begun = charon_begin_deferral(controllers);
    charon_set_mode(begun, CharonDeferralNative);
    [from viewWillDisappear:YES];
    [to viewWillAppear:YES];
    charon_set_mode(begun, CharonDeferralSwallow);

    UIView *container = [[UIView alloc] initWithFrame:host.bounds];
    container.backgroundColor = [UIColor clearColor];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:container];
    [container addSubview:fromView];
    fromView.frame = initialFrom;
    toView.frame = finalTo;

    CharonTransitionContext *context = [[CharonTransitionContext alloc] init];
    context->_container = container;
    context->_from = from;
    context->_to = to;
    context->_animated = YES;
    context->_style = modal ? (kind == CharonTransitionPresent ? to.modalPresentationStyle : from.modalPresentationStyle) : (UIModalPresentationStyle)-1;
    context->_initialFrom = initialFrom;
    context->_finalFrom = kind == CharonTransitionDismiss ? initialFrom : CGRectZero;
    context->_initialTo = CGRectZero;
    context->_finalTo = finalTo;
    context->_interactive = YES;
    context->_animator = animator;
    context->_interactor = interactor;
    NSTimeInterval duration = [animator transitionDuration:context];
    id<UIViewControllerTransitionCoordinator> coordinator = to.transitionCoordinator ?: from.transitionCoordinator;
    if ([coordinator isKindOfClass:[CharonTransitionCoordinator class]]) {
        [(CharonTransitionCoordinator *)coordinator setContainer:container duration:duration];
        [(CharonTransitionCoordinator *)coordinator charon_setInteractive:YES];
        context->_coordinator = (CharonTransitionCoordinator *)coordinator;
    }

    void (^finalize)(BOOL) = ^(BOOL didComplete) {
        [container removeFromSuperview];
        NSArray *pending = charon_take_pending(begun);
        charon_set_mode(begun, CharonDeferralPass);
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
        charon_set_mode(begun, CharonDeferralSwallow);
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSArray *entry in begun)
                    if ([entry[1] owners] == 1)
                        [entry[1] setMode:CharonDeferralPass];
                charon_release_deferral(begun);
            });
        });
        if ([coordinator isKindOfClass:[CharonTransitionCoordinator class]]) {
            [(CharonTransitionCoordinator *)coordinator charon_setCancelled:!didComplete];
            [(CharonTransitionCoordinator *)coordinator finish];
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
        charon_set_mode(begun, CharonDeferralDidOnly);
        UIView *nativeParent = modal ? nil : toView.superview;
        (void)nativeParent;
        native();
        if (!keepsPresenter)
            [fromView removeFromSuperview];
        void (^settle)(void) = ^{
            if (toView.superview == container) {
                /* A dismissal keeps the frame the release's own gave the presenter's view when it put it back. */
                CGRect frame = kind == CharonTransitionDismiss ? [container convertRect:toView.frame toView:window] : finalTo;
                [toView removeFromSuperview];
                if (kind == CharonTransitionDismiss)
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

static NSArray *charon_group(UIViewController *controller)
{
    NSMutableArray *group = [NSMutableArray array];
    charon_collect(controller, group);
    return group;
}

BOOL charon_custom_transition(CharonTransitionKind kind, UIViewController *from, UIViewController *to, UIViewController *source, id<UIViewControllerAnimatedTransitioning> animator, id<UIViewControllerInteractiveTransitioning> interactor, UIModalPresentationStyle style, void (^native)(void), void (^undo)(void), void (^completion)(BOOL finished))
{
    UIView *fromView = from.view;
    UIView *toView = to.view;
    UIWindow *window = fromView.window ?: [UIApplication sharedApplication].keyWindow;
    if (!fromView || !toView || !window || !animator)
        return NO;
    BOOL modal = kind == CharonTransitionPresent || kind == CharonTransitionDismiss;
    BOOL keepsPresenter = kind == CharonTransitionPresent && (style == 4 || style == 5 || style == 6);

    if (interactor && !([interactor respondsToSelector:@selector(wantsInteractiveStart)] && ![interactor wantsInteractiveStart])) {
        charon_interactive_transition(kind, from, to, animator, interactor, style, native, completion);
        return YES;
    }
    CharonViewState *fromPre = [CharonViewState captureView:fromView];
    UIView *fromParent = fromView.superview;
    CGRect initialFrom = fromParent ? [fromParent convertRect:fromView.frame toView:modal ? window : (fromParent.superview ?: fromParent)] : fromView.frame;
    UIView *navigationHost = modal ? nil : (fromParent.superview ?: fromParent);

    NSMutableArray *controllers = [NSMutableArray array];
    charon_collect(from, controllers);
    charon_collect(to, controllers);
    NSArray *begun = charon_begin_deferral(controllers);
    native();

    void (^run)(void) = ^{
        UIView *host = modal ? window : navigationHost;
        UIView *toParent = toView.superview;
        if (!host || (!modal && !toParent)) {
            charon_set_mode(begun, CharonDeferralPass);
            for (NSArray *entry in charon_take_pending(begun))
                ((void (*)(id, SEL, BOOL))objc_msgSend)(entry[0], NSSelectorFromString(entry[1]), NO);
            charon_release_deferral(begun);
            if (completion)
                completion(YES);
            return;
        }
        charon_set_mode(begun, CharonDeferralSwallow);
        CharonViewState *toPost = [CharonViewState captureView:toView];
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

        CharonTransitionContext *context = [[CharonTransitionContext alloc] init];
        context->_container = container;
        context->_from = from;
        context->_to = to;
        context->_animated = YES;
        context->_style = modal ? (kind == CharonTransitionPresent ? to.modalPresentationStyle : from.modalPresentationStyle) : (UIModalPresentationStyle)-1;
        context->_initialFrom = initialFrom;
        context->_finalFrom = kind == CharonTransitionDismiss ? initialFrom : CGRectZero;
        context->_initialTo = CGRectZero;
        context->_finalTo = finalTo;
        BOOL interactive = interactor != nil && !([interactor respondsToSelector:@selector(wantsInteractiveStart)] && ![interactor wantsInteractiveStart]);
        context->_interactive = interactive;
        context->_animator = animator;
        context->_interactor = interactor;

        NSTimeInterval duration = [animator transitionDuration:context];
        id<UIViewControllerTransitionCoordinator> coordinator = to.transitionCoordinator ?: from.transitionCoordinator;
        if ([coordinator isKindOfClass:[CharonTransitionCoordinator class]]) {
            [(CharonTransitionCoordinator *)coordinator setContainer:container duration:duration];
            [(CharonTransitionCoordinator *)coordinator charon_setInteractive:interactive];
            context->_coordinator = (CharonTransitionCoordinator *)coordinator;
        }

        context->_finish = ^(BOOL didComplete) {
            void (^finalize)(void) = ^{
                [container removeFromSuperview];
                NSArray *pending = charon_take_pending(begun);
                charon_set_mode(begun, CharonDeferralPass);
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
                charon_set_mode(begun, CharonDeferralSwallow);
                dispatch_async(dispatch_get_main_queue(), ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (NSArray *entry in begun)
                            if ([entry[1] owners] == 1)
                                [entry[1] setMode:CharonDeferralPass];
                        charon_release_deferral(begun);
                    });
                });
                if ([coordinator isKindOfClass:[CharonTransitionCoordinator class]]) {
                    [(CharonTransitionCoordinator *)coordinator charon_setCancelled:!didComplete];
                    [(CharonTransitionCoordinator *)coordinator finish];
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

static const char charon_presentation_key;

UIPresentationController *charon_presentation_controller_of(UIViewController *controller)
{
    return objc_getAssociatedObject(controller, &charon_presentation_key);
}

void charon_set_presentation_controller(UIViewController *controller, UIPresentationController *presentation)
{
    objc_setAssociatedObject(controller, &charon_presentation_key, presentation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (presentation.presentedViewController == controller && [presentation respondsToSelector:@selector(charon_ownedByPresentedViewController)])
        [presentation charon_ownedByPresentedViewController];
}

@interface CharonPresentationContainer : UIView
@property (nonatomic, weak) UIPresentationController *presentation;
@end

@implementation CharonPresentationContainer
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
    return hit == self && [_presentation charon_containerIgnoresDirectTouches] ? nil : hit;
}

@end

@interface CharonImmediateAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@end

@implementation CharonImmediateAnimator
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

static void charon_presentation_run(BOOL presenting, UIViewController *from, UIViewController *to, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
    UIWindow *window = (presenting ? from.view.window : from.view.window) ?: [UIApplication sharedApplication].keyWindow;
    BOOL removes = [presentation shouldRemovePresentersView];
    UIView *presenterView = presenting ? from.view : to.view;
    UIView *presentedView = presenting ? to.view : from.view;
    BOOL immediate = animator == nil;
    if (immediate)
        animator = [[CharonImmediateAnimator alloc] init];

    CharonPresentationContainer *container = presenting ? nil : (CharonPresentationContainer *)presentation.containerView;
    CharonViewState *presenterPre = [CharonViewState captureView:presenterView];
    NSMutableArray *controllers = [NSMutableArray array];
    charon_collect(from, controllers);
    charon_collect(to, controllers);
    NSArray *begun = charon_begin_deferral(controllers);
    charon_set_mode(begun, CharonDeferralSwallow);

    if (presenting) {
        container = [[CharonPresentationContainer alloc] initWithFrame:window.bounds];
        container.presentation = presentation;
        container.backgroundColor = [UIColor clearColor];
        container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [window addSubview:container];
        [presentation charon_setContainerView:container];
        /* The presenter's view keeps its place on the screen inside the container: the release framed it for its
           controller, and on iOS 6 a root view sits under the status bar, not over the window's bounds. */
        CGRect presenterFrame = [container convertRect:presenterView.frame fromView:presenterView.superview];
        if (removes) {
            [presenterView removeFromSuperview];
            presenterView.frame = presenterFrame;
            [container addSubview:presenterView];
        }
        charon_set_mode(begun, CharonDeferralPass);
        [presentation presentationTransitionWillBegin];
        charon_set_mode(begun, CharonDeferralSwallow);
        native();
        [presentedView removeFromSuperview];
        if (removes) {
            [presenterView removeFromSuperview];
            presenterView.frame = presenterFrame;
            [container addSubview:presenterView];
        } else {
            [presenterPre restoreView:presenterView];
        }
        charon_set_mode(begun, CharonDeferralPass);
        if (removes)
            [from viewWillDisappear:YES];
        [to viewWillAppear:YES];
        charon_set_mode(begun, CharonDeferralSwallow);
    } else {
        charon_set_mode(begun, CharonDeferralPass);
        [presentation dismissalTransitionWillBegin];
        [from viewWillDisappear:YES];
        if (removes)
            [to viewWillAppear:YES];
        charon_set_mode(begun, CharonDeferralSwallow);
    }

    CGRect presentedFrame = [presentation frameOfPresentedViewInContainerView];
    CharonTransitionContext *context = [[CharonTransitionContext alloc] init];
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
    if ([coordinator isKindOfClass:[CharonTransitionCoordinator class]])
        [(CharonTransitionCoordinator *)coordinator setContainer:container duration:duration];

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
            /* A dismissal the user took back (a sheet dragged down and let go above its
               smallest detent) leaves the controller presented. */
            if (didComplete) {
                native();
                /* The release's dismissal frames the presenter's view for its controller and puts it where the
                   presented view was, in this container: it keeps that place on the screen when the container goes. */
                if (presenterView.superview == container && window) {
                    presenterView.frame = [container convertRect:presenterView.frame toView:window];
                    [window insertSubview:presenterView belowSubview:container];
                }
                [container removeFromSuperview];
                [presentation charon_setContainerView:nil];
                if (!presenterView.window && window)
                    [window insertSubview:presenterView atIndex:0];
            }
        }
        charon_set_mode(begun, CharonDeferralPass);
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
        charon_set_mode(begun, CharonDeferralSwallow);
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSArray *entry in begun)
                    if ([entry[1] owners] == 1)
                        [entry[1] setMode:CharonDeferralPass];
                charon_release_deferral(begun);
            });
        });
        if ([coordinator isKindOfClass:[CharonTransitionCoordinator class]])
            [(CharonTransitionCoordinator *)coordinator finish];
        if (completion)
            completion(didComplete);
        if (!immediate && [animator respondsToSelector:@selector(animationEnded:)])
            [animator animationEnded:didComplete];
    };
    [animator animateTransition:context];
}

void charon_presentation_present(UIViewController *presenting, UIViewController *presented, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
    charon_set_presentation_controller(presented, presentation);
    charon_presentation_run(YES, presenting, presented, presentation, animator, native, completion);
}

void charon_presentation_dismiss(UIViewController *presented, UIViewController *presenting, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
    charon_presentation_run(NO, presented, presenting, presentation, animator, native, completion);
}
