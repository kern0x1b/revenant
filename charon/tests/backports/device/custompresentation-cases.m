#import "custompresentation-cases.h"

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

static NSMutableArray *events;
static CustomPresentationRecorder recorder;
static BOOL removesPresenter;
static BOOL fullscreenPresentation;
static NSInteger layoutCalls;
static UIView *presenterView;
static CGRect presenterFrame;

/* Where the presenting view is on the screen, against where it was before the presentation. */
static NSString *presenter_place(void)
{
    if (!presenterView.window)
        return @"out of the window";
    return CGRectEqualToRect([presenterView convertRect:presenterView.bounds toView:nil], presenterFrame) ? @"kept" : @"moved";
}

static NSString *presenter_text(void)
{
    return presenterView.window ? frame_text([presenterView convertRect:presenterView.bounds toView:nil]) : @"none";
}

@interface CPController : UIViewController
@end

@implementation CPController
- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    view.backgroundColor = [UIColor colorWithHue:(arc4random() % 100) / 100.0 saturation:0.5 brightness:0.9 alpha:1];
    self.view = view;
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [events addObject:[NSString stringWithFormat:@"willAppear:%@", self.title]]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [events addObject:[NSString stringWithFormat:@"didAppear:%@", self.title]]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [events addObject:[NSString stringWithFormat:@"willDisappear:%@", self.title]]; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [events addObject:[NSString stringWithFormat:@"didDisappear:%@", self.title]]; }
@end

@interface DimPresentation : UIPresentationController
@property (nonatomic, strong) UIView *dimming;
@property (nonatomic, copy) NSString *tag;
@end

@implementation DimPresentation

- (BOOL)shouldPresentInFullscreen { return fullscreenPresentation; }
- (BOOL)shouldRemovePresentersView { return removesPresenter; }

- (CGRect)frameOfPresentedViewInContainerView
{
    CGRect bounds = self.containerView.bounds;
    return CGRectInset(bounds, 20, 60);
}

- (void)presentationTransitionWillBegin
{
    [events addObject:@"pc:willPresent"];
    UIView *container = self.containerView;
    self.dimming = [[UIView alloc] initWithFrame:container.bounds];
    self.dimming.backgroundColor = [UIColor blackColor];
    self.dimming.alpha = 0;
    [container addSubview:self.dimming];
    recorder([self.tag stringByAppendingString:@".willPresent"], [NSString stringWithFormat:@"container=%d subviews=%lu presentedViewIsVCView=%d presentedViewWindow=%d presenterWindow=%d", container != nil, (unsigned long)container.subviews.count, self.presentedView == self.presentedViewController.view, self.presentedView.window != nil, self.presentingViewController.view.window != nil]);
    recorder([@"info." stringByAppendingString:[self.tag stringByAppendingString:@".willPresent"]], [NSString stringWithFormat:@"containerClass=%@ containerBounds=%@ frameOfPresented=%@ presentedViewSuper=%@", NSStringFromClass([container class]), frame_text(container.bounds), frame_text([self frameOfPresentedViewInContainerView]), NSStringFromClass([self.presentedView.superview class])]);
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) { self.dimming.alpha = 0.5; } completion:nil];
}

- (void)presentationTransitionDidEnd:(BOOL)completed
{
    [events addObject:completed ? @"pc:didPresent:1" : @"pc:didPresent:0"];
    UIView *container = self.containerView;
    recorder([self.tag stringByAppendingString:@".presented.presenterFrame"], presenter_place());
    recorder([@"info." stringByAppendingString:[self.tag stringByAppendingString:@".presented.presenterFrame"]], [NSString stringWithFormat:@"before=%@ now=%@", frame_text(presenterFrame), presenter_text()]);
    recorder([self.tag stringByAppendingString:@".didPresent"], [NSString stringWithFormat:@"containerSubviews=%lu presentedFrameInContainer=%d presentedSuperIsContainer=%d dimmingIn=%d presenterWindow=%d presentedWindow=%d", (unsigned long)container.subviews.count, CGRectEqualToRect([self.presentedView convertRect:self.presentedView.bounds toView:container], [self frameOfPresentedViewInContainerView]), self.presentedView.superview == container, self.dimming.superview == container, self.presentingViewController.view.window != nil, self.presentedView.window != nil]);
}

- (void)dismissalTransitionWillBegin
{
    [events addObject:@"pc:willDismiss"];
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) { self.dimming.alpha = 0; } completion:nil];
}

- (void)dismissalTransitionDidEnd:(BOOL)completed
{
    [events addObject:completed ? @"pc:didDismiss:1" : @"pc:didDismiss:0"];
    recorder([self.tag stringByAppendingString:@".didDismiss"], [NSString stringWithFormat:@"dimmingIn=%d presenterWindow=%d presentedWindow=%d", self.dimming.superview != nil, self.presentingViewController.view.window != nil, self.presentedView.window != nil]);
}

- (void)containerViewWillLayoutSubviews { layoutCalls++; }
- (void)containerViewDidLayoutSubviews { layoutCalls++; }

@end

@interface CPAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, copy) NSString *tag;
@end

@implementation CPAnimator

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context { return 0.3; }

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context
{
    [events addObject:@"animateTransition"];
    UIViewController *from = [context viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *to = [context viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *container = context.containerView;
    UIView *fromView = [context viewForKey:UITransitionContextFromViewKey];
    UIView *toView = [context viewForKey:UITransitionContextToViewKey];
    NSMutableArray *facts = [NSMutableArray array];
    [facts addObject:[NSString stringWithFormat:@"from=%@ to=%@", from.title, to.title]];
    [facts addObject:[NSString stringWithFormat:@"fromViewNil=%d toViewNil=%d", fromView == nil, toView == nil]];
    [facts addObject:[NSString stringWithFormat:@"style=%ld", (long)context.presentationStyle]];
    [facts addObject:[NSString stringWithFormat:@"subviews=%lu", (unsigned long)container.subviews.count]];
    [facts addObject:[NSString stringWithFormat:@"initialFrom=%@ finalFrom=%@ initialTo=%@ finalTo=%@", frame_kind([context initialFrameForViewController:from], container.bounds), frame_kind([context finalFrameForViewController:from], container.bounds), frame_kind([context initialFrameForViewController:to], container.bounds), frame_kind([context finalFrameForViewController:to], container.bounds)]];
    recorder([self.tag stringByAppendingString:@".start"], [facts componentsJoinedByString:@" "]);
    recorder([@"info." stringByAppendingString:[self.tag stringByAppendingString:@".start"]], [NSString stringWithFormat:@"initialFrom=%@ finalFrom=%@ initialTo=%@ finalTo=%@ container=%@", frame_text([context initialFrameForViewController:from]), frame_text([context finalFrameForViewController:from]), frame_text([context initialFrameForViewController:to]), frame_text([context finalFrameForViewController:to]), NSStringFromClass([container class])]);
    UIView *moving = toView ?: to.view;
    BOOL presenting = [self.tag hasSuffix:@"present"];
    if (presenting) {
        if (moving.superview != container)
            [container addSubview:moving];
        moving.frame = [context finalFrameForViewController:to];
        moving.alpha = 0;
        [UIView animateWithDuration:0.3 animations:^{ moving.alpha = 1; } completion:^(BOOL finished) {
            [events addObject:@"completeTransition"];
            [context completeTransition:YES];
        }];
    } else {
        UIView *leaving = fromView ?: from.view;
        [UIView animateWithDuration:0.3 animations:^{ leaving.alpha = 0; } completion:^(BOOL finished) {
            [events addObject:@"completeTransition"];
            [context completeTransition:![context transitionWasCancelled]];
        }];
    }
}

- (void)animationEnded:(BOOL)transitionCompleted { [events addObject:transitionCompleted ? @"animationEnded:1" : @"animationEnded:0"]; }

@end

@interface CPDelegate : NSObject <UIViewControllerTransitioningDelegate>
@property (nonatomic, copy) NSString *tag;
@property (nonatomic) BOOL animated;
@property (nonatomic, strong) DimPresentation *presentation;
@end

@implementation CPDelegate
- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source
{
    [events addObject:@"delegate:presentationController"];
    DimPresentation *controller = [[DimPresentation alloc] initWithPresentedViewController:presented presentingViewController:presenting];
    controller.tag = self.tag;
    self.presentation = controller;
    return controller;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    if (!self.animated)
        return nil;
    CPAnimator *animator = [[CPAnimator alloc] init];
    animator.tag = [self.tag stringByAppendingString:@".present"];
    return animator;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    if (!self.animated)
        return nil;
    CPAnimator *animator = [[CPAnimator alloc] init];
    animator.tag = [self.tag stringByAppendingString:@".dismiss"];
    return animator;
}
@end

/* A full-screen presentation with an animator and no presentation controller, dismissed through an interaction
   controller: the case where the port's interactive transition puts the presenting view back. */
@interface CPFade : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic) BOOL presenting;
@end

@implementation CPFade
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context { return 0.3; }
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context
{
    UIViewController *to = [context viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *moving = self.presenting ? [context viewForKey:UITransitionContextToViewKey] : [context viewForKey:UITransitionContextFromViewKey];
    if (self.presenting) {
        [context.containerView addSubview:moving];
        moving.frame = [context finalFrameForViewController:to];
        moving.alpha = 0;
    }
    [UIView animateWithDuration:0.3 animations:^{ moving.alpha = self.presenting ? 1 : 0; } completion:^(BOOL finished) {
        [context completeTransition:![context transitionWasCancelled]];
    }];
}
@end

@interface CPInteractiveDelegate : NSObject <UIViewControllerTransitioningDelegate>
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactor;
@end

@implementation CPInteractiveDelegate
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    CPFade *fade = [[CPFade alloc] init];
    fade.presenting = YES;
    return fade;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed { return [[CPFade alloc] init]; }
- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator { return self.interactor; }
@end

void custompresentation_run(UIWindow *window, CustomPresentationRecorder record, void (^done)(void))
{
    events = [NSMutableArray array];
    recorder = record;
    CPController *base = [[CPController alloc] init];
    base.title = @"base";
    window.rootViewController = base;
    presenterView = base.view;

    NSMutableArray *steps = [NSMutableArray array];
    void (^step)(NSTimeInterval, void (^)(void)) = ^(NSTimeInterval wait, void (^block)(void)) { [steps addObject:@[@(wait), [block copy]]]; };
    /* The frame the release gave the root view, which every presentation below is to leave as it is. */
    step(0.3, ^{ presenterFrame = [base.view convertRect:base.view.bounds toView:nil]; });
    NSArray *variants = @[@[@"dim", @NO, @NO, @YES], @[@"remove", @NO, @YES, @YES], @[@"plain", @NO, @NO, @NO], @[@"full", @YES, @NO, @YES]];
    for (NSArray *variant in variants) {
        NSString *tag = variant[0];
        CPController *modal = [[CPController alloc] init];
        modal.title = tag;
        CPDelegate *delegate = [[CPDelegate alloc] init];
        delegate.tag = tag;
        delegate.animated = [variant[3] boolValue];
        static NSMutableArray *keep;
        if (!keep)
            keep = [NSMutableArray array];
        [keep addObject:delegate];
        modal.modalPresentationStyle = UIModalPresentationCustom;
        modal.transitioningDelegate = delegate;
        step(0.3, ^{
            fullscreenPresentation = [variant[1] boolValue];
            removesPresenter = [variant[2] boolValue];
            [events removeAllObjects];
            layoutCalls = 0;
            [base presentViewController:modal animated:YES completion:^{ [events addObject:@"completion"]; }];
        });
        step(1.0, ^{
            record([tag stringByAppendingString:@".present.events"], [events componentsJoinedByString:@","]);
            record([tag stringByAppendingString:@".present.layout"], layoutCalls > 0 ? @"laid out" : @"never laid out");
            DimPresentation *pc = delegate.presentation;
            record([tag stringByAppendingString:@".present.end"], [NSString stringWithFormat:@"presented=%d pcIsPresentationController=%d sameAsProperty=%d modalWindow=%d baseWindow=%d modalFrameRelative=%@ style=%ld", base.presentedViewController == modal, pc != nil, modal.presentationController == pc, modal.view.window != nil, base.view.window != nil, [tag isEqualToString:@"full"] ? @"n/a" : (CGRectEqualToRect([modal.view convertRect:modal.view.bounds toView:pc.containerView], [pc frameOfPresentedViewInContainerView]) ? @"frameOfPresented" : @"other"), (long)pc.presentationStyle]);
            [events removeAllObjects];
            [base dismissViewControllerAnimated:YES completion:^{ [events addObject:@"completion"]; }];
        });
        step(1.0, ^{
            record([tag stringByAppendingString:@".dismiss.events"], [events componentsJoinedByString:@","]);
            record([tag stringByAppendingString:@".dismiss.end"], [NSString stringWithFormat:@"presented=%d modalWindow=%d baseWindow=%d", base.presentedViewController != nil, modal.view.window != nil, base.view.window != nil]);
            record([tag stringByAppendingString:@".dismissed.presenterFrame"], presenter_place());
            record([@"info." stringByAppendingString:[tag stringByAppendingString:@".dismissed.presenterFrame"]], [NSString stringWithFormat:@"before=%@ now=%@", frame_text(presenterFrame), presenter_text()]);
        });
    }
    /* A custom presentation with no transitioning delegate: UIKit makes a presentation controller of its own
       (-_presentViewController:withAnimationController:completion: 0x1891a8fe0 in UIKitCore of 16.0). */
    CPController *bare = [[CPController alloc] init];
    bare.title = @"bare";
    bare.modalPresentationStyle = UIModalPresentationCustom;
    step(0.3, ^{
        fullscreenPresentation = NO;
        removesPresenter = NO;
        [events removeAllObjects];
        [base presentViewController:bare animated:YES completion:^{ [events addObject:@"completion"]; }];
    });
    step(1.0, ^{
        UIPresentationController *pc = bare.presentationController;
        CGRect frame = [bare.view convertRect:bare.view.bounds toView:pc.containerView];
        record(@"bare.present.events", [events componentsJoinedByString:@","]);
        record(@"bare.present.end", [NSString stringWithFormat:@"presented=%d class=%@ modalWindow=%d baseWindow=%d modalFrame=%@ style=%ld", base.presentedViewController == bare,
            NSStringFromClass([pc class]), bare.view.window != nil, base.view.window != nil, CGRectEqualToRect(frame, pc.containerView.bounds) ? @"containerBounds" : frame_text(frame), (long)pc.presentationStyle]);
        [events removeAllObjects];
        [base dismissViewControllerAnimated:YES completion:^{ [events addObject:@"completion"]; }];
    });
    step(1.0, ^{
        record(@"bare.dismiss.events", [events componentsJoinedByString:@","]);
        record(@"bare.dismiss.end", [NSString stringWithFormat:@"presented=%d modalWindow=%d baseWindow=%d", base.presentedViewController != nil, bare.view.window != nil, base.view.window != nil]);
        record(@"bare.dismissed.presenterFrame", presenter_place());
    });
    /* The control: the release's own full-screen presentation and dismissal, with no transitioning delegate. */
    CPController *native = [[CPController alloc] init];
    native.title = @"native";
    native.modalPresentationStyle = UIModalPresentationFullScreen;
    step(0.3, ^{ [base presentViewController:native animated:YES completion:nil]; });
    step(1.0, ^{ [base dismissViewControllerAnimated:YES completion:nil]; });
    step(1.0, ^{
        record(@"native.dismissed.presenterFrame", presenter_place());
        record(@"info.native.dismissed.presenterFrame", [NSString stringWithFormat:@"before=%@ now=%@", frame_text(presenterFrame), presenter_text()]);
    });
    CPController *interactive = [[CPController alloc] init];
    interactive.title = @"interactive";
    interactive.modalPresentationStyle = UIModalPresentationFullScreen;
    static CPInteractiveDelegate *interactiveDelegate;
    interactiveDelegate = [[CPInteractiveDelegate alloc] init];
    interactive.transitioningDelegate = interactiveDelegate;
    step(0.3, ^{ [base presentViewController:interactive animated:YES completion:nil]; });
    step(1.0, ^{
        interactiveDelegate.interactor = [[UIPercentDrivenInteractiveTransition alloc] init];
        [base dismissViewControllerAnimated:YES completion:nil];
    });
    step(0.3, ^{ [interactiveDelegate.interactor updateInteractiveTransition:0.5]; });
    step(0.2, ^{ [interactiveDelegate.interactor finishInteractiveTransition]; });
    step(1.2, ^{
        record(@"interactive.dismissed.presenterFrame", presenter_place());
        record(@"info.interactive.dismissed.presenterFrame", [NSString stringWithFormat:@"before=%@ now=%@ presented=%d", frame_text(presenterFrame), presenter_text(), base.presentedViewController != nil]);
    });
    step(0.3, ^{ done(); });
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
