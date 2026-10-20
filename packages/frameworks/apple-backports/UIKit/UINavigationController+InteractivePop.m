#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantCustomTransition.h"

static const char revenant_recognizer_key;
static const char revenant_state_key;
static const char revenant_gate_key;

@interface RevenantEdgePopAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@end

@implementation RevenantEdgePopAnimator

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context
{
    return 0.35;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context
{
    UIView *container = context.containerView;
    UIView *fromView = [context viewForKey:UITransitionContextFromViewKey];
    UIView *toView = [context viewForKey:UITransitionContextToViewKey];
    CGRect final = [context finalFrameForViewController:[context viewControllerForKey:UITransitionContextToViewControllerKey]];
    CGRect start = fromView.frame;
    CGFloat width = container.bounds.size.width;
    toView.frame = CGRectOffset(final, -width / 3, 0);
    [container insertSubview:toView belowSubview:fromView];
    UIView *dim = [[UIView alloc] initWithFrame:toView.bounds];
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.1f];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [toView addSubview:dim];
    fromView.layer.shadowColor = [UIColor blackColor].CGColor;
    fromView.layer.shadowOpacity = 0.3f;
    fromView.layer.shadowRadius = 4;
    fromView.layer.shadowOffset = CGSizeMake(-3, 0);
    [UIView animateWithDuration:[self transitionDuration:context] delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        fromView.frame = CGRectOffset(start, width, 0);
        toView.frame = final;
        dim.alpha = 0;
    } completion:^(BOOL finished) {
        BOOL cancelled = [context transitionWasCancelled];
        [dim removeFromSuperview];
        fromView.layer.shadowOpacity = 0;
        if (cancelled) {
            fromView.frame = start;
            toView.frame = final;
        }
        [context completeTransition:!cancelled];
    }];
}

@end

@interface RevenantEdgePopState : NSObject
@property (nonatomic, strong) RevenantEdgePopAnimator *animator;
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactor;
@end

@implementation RevenantEdgePopState
@synthesize animator, interactor;
@end

id<UIViewControllerAnimatedTransitioning> revenant_edge_pop_animator(UINavigationController *navigation)
{
    return [objc_getAssociatedObject(navigation, &revenant_state_key) animator];
}

id<UIViewControllerInteractiveTransitioning> revenant_edge_pop_interactor(UINavigationController *navigation)
{
    return [objc_getAssociatedObject(navigation, &revenant_state_key) interactor];
}

@interface RevenantEdgePopGate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UINavigationController *navigation;
- (void)edge:(UIScreenEdgePanGestureRecognizer *)recognizer;
@end

@implementation RevenantEdgePopGate
@synthesize navigation;

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
    UINavigationController *navigation = self.navigation;
    return navigation.viewControllers.count > 1 && !navigation.topViewController.navigationItem.hidesBackButton && !navigation.topViewController.navigationItem.leftBarButtonItem;
}

- (void)edge:(UIScreenEdgePanGestureRecognizer *)recognizer
{
    UINavigationController *navigation = self.navigation;
    CGFloat width = MAX(1, navigation.view.bounds.size.width);
    CGFloat progress = MIN(1, MAX(0, [recognizer translationInView:navigation.view].x / width));
    RevenantEdgePopState *state = objc_getAssociatedObject(navigation, &revenant_state_key);
    switch (recognizer.state) {
    case UIGestureRecognizerStateBegan: {
        if (navigation.viewControllers.count < 2 || state)
            return;
        state = [[RevenantEdgePopState alloc] init];
        state.animator = [[RevenantEdgePopAnimator alloc] init];
        state.interactor = [[UIPercentDrivenInteractiveTransition alloc] init];
        objc_setAssociatedObject(navigation, &revenant_state_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [navigation popViewControllerAnimated:YES];
        break;
    }
    case UIGestureRecognizerStateChanged:
        [state.interactor updateInteractiveTransition:progress];
        break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed: {
        if (!state)
            return;
        objc_setAssociatedObject(navigation, &revenant_state_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        BOOL finish = recognizer.state == UIGestureRecognizerStateEnded && (progress > 0.5f || [recognizer velocityInView:navigation.view].x > 300);
        if (finish)
            [state.interactor finishInteractiveTransition];
        else
            [state.interactor cancelInteractiveTransition];
        break;
    }
    default:
        break;
    }
}

@end

static UIScreenEdgePanGestureRecognizer *revenant_install_recognizer(UINavigationController *navigation)
{
    UIScreenEdgePanGestureRecognizer *recognizer = objc_getAssociatedObject(navigation, &revenant_recognizer_key);
    if (recognizer || !navigation.isViewLoaded)
        return recognizer;
    RevenantEdgePopGate *gate = [[RevenantEdgePopGate alloc] init];
    gate.navigation = navigation;
    recognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:gate action:@selector(edge:)];
    recognizer.edges = UIRectEdgeLeft;
    recognizer.delegate = gate;
    objc_setAssociatedObject(navigation, &revenant_gate_key, gate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(navigation, &revenant_recognizer_key, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [navigation.view addGestureRecognizer:recognizer];
    return recognizer;
}

@interface RevenantEdgePopInstaller : NSObject
@end

@implementation RevenantEdgePopInstaller

+ (void)load
{
    Class navigation = [UINavigationController class];
    Method method = class_getInstanceMethod(navigation, @selector(viewDidLoad));
    void (*original)(id, SEL) = (void (*)(id, SEL))method_getImplementation(method);
    class_replaceMethod(navigation, @selector(viewDidLoad), imp_implementationWithBlock(^(UINavigationController *self_) {
        original(self_, @selector(viewDidLoad));
        revenant_install_recognizer(self_);
    }), method_getTypeEncoding(method));
}

@end

@implementation UINavigationController (RevenantInteractivePop)

- (UIGestureRecognizer *)interactivePopGestureRecognizer
{
    return revenant_install_recognizer(self);
}

@end
