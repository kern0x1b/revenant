#import "customtransition-cases.h"

static NSString *frame_kind(CGRect rect, CGRect container)
{
    if (CGRectEqualToRect(rect, CGRectZero))
        return @"zero";
    BOOL fills = rect.origin.x == container.origin.x && rect.size.width == container.size.width && CGRectGetMaxY(rect) == CGRectGetMaxY(container) && rect.origin.y >= container.origin.y && rect.origin.y < container.origin.y + 100;
    return fills ? @"full" : @"other";
}

static NSString *frame_text(CGRect rect)
{
    return [NSString stringWithFormat:@"%.0f,%.0f,%.0f,%.0f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

@interface CaseController : UIViewController
@property (nonatomic, strong) NSMutableArray *events;
@end

@implementation CaseController
- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    view.backgroundColor = [UIColor colorWithHue:(arc4random() % 100) / 100.0 saturation:0.5 brightness:0.9 alpha:1];
    self.view = view;
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.events addObject:[NSString stringWithFormat:@"willAppear:%@", self.title]]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self.events addObject:[NSString stringWithFormat:@"didAppear:%@", self.title]]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.events addObject:[NSString stringWithFormat:@"willDisappear:%@", self.title]]; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [self.events addObject:[NSString stringWithFormat:@"didDisappear:%@", self.title]]; }
@end

@interface CaseAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, copy) CustomTransitionRecorder record;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic) NSInteger durationCalls;
@property (nonatomic) NSTimeInterval duration;
@end

@implementation CaseAnimator

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context
{
    self.durationCalls++;
    return self.duration ?: 0.3;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context
{
    [self.events addObject:@"animateTransition"];
    UIViewController *from = [context viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *to = [context viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *container = context.containerView;
    UIView *fromView = [context respondsToSelector:@selector(viewForKey:)] ? [context viewForKey:UITransitionContextFromViewKey] : nil;
    UIView *toView = [context respondsToSelector:@selector(viewForKey:)] ? [context viewForKey:UITransitionContextToViewKey] : nil;
    CGRect bounds = container.bounds;
    NSMutableArray *facts = [NSMutableArray array];
    [facts addObject:[NSString stringWithFormat:@"from=%@ to=%@ fromClass=%@ toClass=%@", from.title, to.title, [from isKindOfClass:[UINavigationController class]] ? @"nav" : @"plain", [to isKindOfClass:[UINavigationController class]] ? @"nav" : @"plain"]];
    [facts addObject:[NSString stringWithFormat:@"fromView=%d toView=%d", fromView == from.view, toView == to.view]];
    [facts addObject:[NSString stringWithFormat:@"fromIn=%d toIn=%d", [fromView isDescendantOfView:container], [toView isDescendantOfView:container]]];
    [facts addObject:[NSString stringWithFormat:@"fromDirect=%d toDirect=%d", fromView.superview == container, toView.superview == container]];
    [facts addObject:[NSString stringWithFormat:@"fromWindow=%d toWindow=%d containerWindow=%d", fromView.window != nil, toView.window != nil, container.window != nil]];
    [facts addObject:[NSString stringWithFormat:@"animated=%d interactive=%d cancelled=%d style=%ld", context.isAnimated, context.isInteractive, context.transitionWasCancelled, (long)context.presentationStyle]];
    [facts addObject:[NSString stringWithFormat:@"transform=%d", CGAffineTransformIsIdentity(context.targetTransform)]];
    [facts addObject:[NSString stringWithFormat:@"initialFrom=%@ finalFrom=%@ initialTo=%@ finalTo=%@", frame_kind([context initialFrameForViewController:from], bounds), frame_kind([context finalFrameForViewController:from], bounds), frame_kind([context initialFrameForViewController:to], bounds), frame_kind([context finalFrameForViewController:to], bounds)]];
    [facts addObject:[NSString stringWithFormat:@"subviews=%lu containerSuper=%@", (unsigned long)container.subviews.count, container.superview == self.window ? @"window" : NSStringFromClass([container.superview class]) ? @"other" : @"nil"]];
    self.record([self.name stringByAppendingString:@".start"], [facts componentsJoinedByString:@" "]);
    self.record([@"info." stringByAppendingString:self.name], [NSString stringWithFormat:@"bounds=%@ initialFrom=%@ finalFrom=%@ initialTo=%@ finalTo=%@ container=%@ super=%@", frame_text(bounds), frame_text([context initialFrameForViewController:from]), frame_text([context finalFrameForViewController:from]), frame_text([context initialFrameForViewController:to]), frame_text([context finalFrameForViewController:to]), NSStringFromClass([container class]), NSStringFromClass([container.superview class])]);
    if (toView.superview != container)
        [container addSubview:toView];
    toView.alpha = 0;
    [UIView animateWithDuration:[self transitionDuration:context] animations:^{ toView.alpha = 1; } completion:^(BOOL finished) {
        [self.events addObject:@"completeTransition"];
        [context completeTransition:![context transitionWasCancelled]];
        UIView *final = toView;
        if ([self.name isEqualToString:@"icancel"])
            self.record([self.name stringByAppendingString:@".afterComplete"], [NSString stringWithFormat:@"fromWindow=%d toAlpha=%.0f", fromView.window != nil, final.alpha]);
        else
            self.record([self.name stringByAppendingString:@".afterComplete"], [NSString stringWithFormat:@"toWindow=%d fromWindow=%d toAlpha=%.0f", final.window != nil, fromView.window != nil, final.alpha]);
    }];
}

- (void)animationEnded:(BOOL)transitionCompleted
{
    [self.events addObject:transitionCompleted ? @"animationEnded:1" : @"animationEnded:0"];
}

@end

@interface CaseDelegate : NSObject <UIViewControllerTransitioningDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) CaseAnimator *presentAnimator, *dismissAnimator, *pushAnimator, *popAnimator;
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactor;
@end

@implementation CaseDelegate
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return self.presentAnimator;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return self.dismissAnimator;
}
- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id<UIViewControllerAnimatedTransitioning>)animator
{
    return self.interactor;
}
- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator
{
    return self.interactor;
}
- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController
{
    return self.interactor;
}
- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    return operation == UINavigationControllerOperationPush ? self.pushAnimator : self.popAnimator;
}
@end

void customtransition_run(UIWindow *window, CustomTransitionRecorder record, void (^done)(void))
{
    NSMutableArray *events = [NSMutableArray array];
    CaseController *base = [[CaseController alloc] init];
    base.title = @"base";
    base.events = events;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:base];
    window.rootViewController = navigation;
    static CaseDelegate *delegate;
    delegate = [[CaseDelegate alloc] init];
    NSMutableDictionary *animators = [NSMutableDictionary dictionary];
    for (NSString *name in @[@"present", @"dismiss", @"push", @"pop"]) {
        CaseAnimator *animator = [[CaseAnimator alloc] init];
        animator.name = name;
        animator.events = events;
        animator.record = record;
        animator.window = window;
        animators[name] = animator;
    }
    delegate.presentAnimator = animators[@"present"];
    delegate.dismissAnimator = animators[@"dismiss"];
    delegate.pushAnimator = animators[@"push"];
    delegate.popAnimator = animators[@"pop"];
    navigation.delegate = delegate;
    CaseController *modal = [[CaseController alloc] init];
    modal.title = @"modal";
    modal.events = events;
    modal.modalPresentationStyle = UIModalPresentationFullScreen;
    modal.transitioningDelegate = delegate;
    CaseController *second = [[CaseController alloc] init];
    second.title = @"second";
    second.events = events;

    NSMutableArray *steps = [NSMutableArray array];
    void (^step)(NSTimeInterval, void (^)(void)) = ^(NSTimeInterval wait, void (^block)(void)) { [steps addObject:@[@(wait), [block copy]]]; };
    /* Where the presenting view is on the screen after a dismissal, against where it was before the presentation. */
    __block CGRect presenterFrame = CGRectZero;
    void (^recordPresenter)(NSString *) = ^(NSString *name) {
        UIView *view = navigation.view;
        CGRect now = [view convertRect:view.bounds toView:nil];
        record([name stringByAppendingString:@".presenterFrame"], !view.window ? @"out of the window" : CGRectEqualToRect(now, presenterFrame) ? @"kept" : @"moved");
        record([@"info." stringByAppendingString:[name stringByAppendingString:@".presenterFrame"]], [NSString stringWithFormat:@"before=%@ now=%@", frame_text(presenterFrame), view.window ? frame_text(now) : @"none"]);
    };
    step(0.3, ^{
        presenterFrame = [navigation.view convertRect:navigation.view.bounds toView:nil];
        [events removeAllObjects];
        [navigation presentViewController:modal animated:YES completion:^{ [events addObject:@"completion"]; }];
    });
    step(1.0, ^{
        record(@"present.events", [events componentsJoinedByString:@","]);
        record(@"present.end", [NSString stringWithFormat:@"presented=%d presenting=%d modalWindow=%d", navigation.presentedViewController == modal, modal.presentingViewController == navigation, modal.view.window != nil]);
        record(@"info.durationCalls", [NSString stringWithFormat:@"%ld", (long)[(CaseAnimator *)animators[@"present"] durationCalls]]);
        [events removeAllObjects];
        [navigation dismissViewControllerAnimated:YES completion:^{ [events addObject:@"completion"]; }];
    });
    step(1.0, ^{
        record(@"dismiss.events", [events componentsJoinedByString:@","]);
        record(@"dismiss.end", [NSString stringWithFormat:@"presented=%d baseWindow=%d modalWindow=%d", navigation.presentedViewController == nil, base.view.window != nil, modal.view.window != nil]);
        recordPresenter(@"dismiss");
        [events removeAllObjects];
        [navigation pushViewController:second animated:YES];
    });
    step(1.0, ^{
        record(@"push.events", [events componentsJoinedByString:@","]);
        record(@"push.end", [NSString stringWithFormat:@"top=%d secondWindow=%d baseWindow=%d count=%lu", navigation.topViewController == second, second.view.window != nil, base.view.window != nil, (unsigned long)navigation.viewControllers.count]);
        [events removeAllObjects];
        [navigation popViewControllerAnimated:YES];
    });
    step(1.0, ^{
        record(@"pop.events", [events componentsJoinedByString:@","]);
        record(@"pop.end", [NSString stringWithFormat:@"top=%d baseWindow=%d secondWindow=%d count=%lu", navigation.topViewController == base, base.view.window != nil, second.view.window != nil, (unsigned long)navigation.viewControllers.count]);
    });
    NSTimeInterval slow = 0.8;
    for (NSString *name in @[@"idismiss", @"icancel", @"ipop", @"ipopcancel"]) {
        CaseAnimator *animator = [[CaseAnimator alloc] init];
        animator.name = name;
        animator.events = events;
        animator.record = record;
        animator.window = window;
        animator.duration = slow;
        animators[name] = animator;
    }
    void (^interactiveDismiss)(NSString *, BOOL) = ^(NSString *name, BOOL finish) {
        step(0.3, ^{
            [events removeAllObjects];
            delegate.interactor = nil;
            [navigation presentViewController:modal animated:YES completion:nil];
        });
        step(1.2, ^{
            delegate.dismissAnimator = animators[name];
            delegate.interactor = [[UIPercentDrivenInteractiveTransition alloc] init];
            [events removeAllObjects];
            [navigation dismissViewControllerAnimated:YES completion:^{ [events addObject:@"completion"]; }];
        });
        step(0.3, ^{
            [delegate.interactor updateInteractiveTransition:0.4];
            record([name stringByAppendingString:@".percent"], [NSString stringWithFormat:@"%.2f", delegate.interactor.percentComplete]);
            record([name stringByAppendingString:@".duration"], [NSString stringWithFormat:@"%.2f", delegate.interactor.duration]);
        });
        step(0.2, ^{
            if (finish)
                [delegate.interactor finishInteractiveTransition];
            else
                [delegate.interactor cancelInteractiveTransition];
        });
        step(1.6, ^{
            record([name stringByAppendingString:@".events"], [events componentsJoinedByString:@","]);
            record([name stringByAppendingString:@".end"], [NSString stringWithFormat:@"presented=%d modalWindow=%d modalAlpha=%.0f", navigation.presentedViewController != nil, modal.view.window != nil, modal.view.alpha]);
            if (finish)
                recordPresenter(name);
            delegate.interactor = nil;
            delegate.dismissAnimator = animators[@"dismiss"];
            if (navigation.presentedViewController)
                [navigation dismissViewControllerAnimated:NO completion:nil];
        });
    };
    interactiveDismiss(@"idismiss", YES);
    interactiveDismiss(@"icancel", NO);
    void (^interactivePop)(NSString *, BOOL) = ^(NSString *name, BOOL finish) {
        step(0.4, ^{
            delegate.interactor = nil;
            [navigation pushViewController:second animated:NO];
        });
        step(0.6, ^{
            delegate.popAnimator = animators[name];
            delegate.interactor = [[UIPercentDrivenInteractiveTransition alloc] init];
            [events removeAllObjects];
            [navigation popViewControllerAnimated:YES];
        });
        step(0.4, ^{ [delegate.interactor updateInteractiveTransition:0.4]; });
        step(0.2, ^{
            if (finish)
                [delegate.interactor finishInteractiveTransition];
            else
                [delegate.interactor cancelInteractiveTransition];
        });
        step(1.6, ^{
            record([name stringByAppendingString:@".events"], [events componentsJoinedByString:@","]);
            {
                NSMutableString *chain = [NSMutableString string];
                for (UIView *v = base.view; v; v = v.superview)
                    [chain appendFormat:@"%@>", NSStringFromClass([v class])];
                NSMutableString *chain2 = [NSMutableString string];
                for (UIView *v = second.view; v; v = v.superview)
                    [chain2 appendFormat:@"%@>", NSStringFromClass([v class])];
                record([@"info." stringByAppendingString:[name stringByAppendingString:@".chains"]], [NSString stringWithFormat:@"base %@ second %@", chain, chain2]);
            }
            record([name stringByAppendingString:@".end"], [NSString stringWithFormat:@"top=%@ baseWindow=%d secondWindow=%d count=%lu", navigation.topViewController.title, base.view.window != nil, second.view.window != nil, (unsigned long)navigation.viewControllers.count]);
            delegate.interactor = nil;
            delegate.popAnimator = animators[@"pop"];
            if (navigation.viewControllers.count > 1)
                [navigation popViewControllerAnimated:NO];
        });
    };
    interactivePop(@"ipop", YES);
    interactivePop(@"ipopcancel", NO);
    step(0.5, ^{ done(); });
    __block void (^run)(NSUInteger);
    run = ^(NSUInteger index) {
        if (index >= steps.count)
            return;
        NSArray *entry = steps[index];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([entry[0] doubleValue] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            void (^block)(void) = entry[1];
            block();
            run(index + 1);
        });
    };
    run(0);
}
