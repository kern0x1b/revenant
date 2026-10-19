#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonCustomTransition.h"

static const char charon_recognizer_key;
static const char charon_state_key;
static const char charon_gate_key;

@interface CharonEdgePopAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@end

@implementation CharonEdgePopAnimator

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

@interface CharonEdgePopState : NSObject
@property (nonatomic, strong) CharonEdgePopAnimator *animator;
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactor;
@end

@implementation CharonEdgePopState
@synthesize animator, interactor;
@end

id<UIViewControllerAnimatedTransitioning> charon_edge_pop_animator(UINavigationController *navigation)
{
    return [objc_getAssociatedObject(navigation, &charon_state_key) animator];
}

id<UIViewControllerInteractiveTransitioning> charon_edge_pop_interactor(UINavigationController *navigation)
{
    return [objc_getAssociatedObject(navigation, &charon_state_key) interactor];
}

@interface CharonEdgePopGate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UINavigationController *navigation;
- (void)edge:(UIScreenEdgePanGestureRecognizer *)recognizer;
@end

@implementation CharonEdgePopGate
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
    CharonEdgePopState *state = objc_getAssociatedObject(navigation, &charon_state_key);
    switch (recognizer.state) {
    case UIGestureRecognizerStateBegan: {
        if (navigation.viewControllers.count < 2 || state)
            return;
        state = [[CharonEdgePopState alloc] init];
        state.animator = [[CharonEdgePopAnimator alloc] init];
        state.interactor = [[UIPercentDrivenInteractiveTransition alloc] init];
        objc_setAssociatedObject(navigation, &charon_state_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
        objc_setAssociatedObject(navigation, &charon_state_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

static UIScreenEdgePanGestureRecognizer *charon_install_recognizer(UINavigationController *navigation)
{
    UIScreenEdgePanGestureRecognizer *recognizer = objc_getAssociatedObject(navigation, &charon_recognizer_key);
    if (recognizer || !navigation.isViewLoaded)
        return recognizer;
    CharonEdgePopGate *gate = [[CharonEdgePopGate alloc] init];
    gate.navigation = navigation;
    recognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:gate action:@selector(edge:)];
    recognizer.edges = UIRectEdgeLeft;
    recognizer.delegate = gate;
    objc_setAssociatedObject(navigation, &charon_gate_key, gate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(navigation, &charon_recognizer_key, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [navigation.view addGestureRecognizer:recognizer];
    return recognizer;
}

@interface CharonEdgePopInstaller : NSObject
@end

@implementation CharonEdgePopInstaller

+ (void)load
{
    Class navigation = [UINavigationController class];
    Method method = class_getInstanceMethod(navigation, @selector(viewDidLoad));
    void (*original)(id, SEL) = (void (*)(id, SEL))method_getImplementation(method);
    class_replaceMethod(navigation, @selector(viewDidLoad), imp_implementationWithBlock(^(UINavigationController *self_) {
        original(self_, @selector(viewDidLoad));
        charon_install_recognizer(self_);
    }), method_getTypeEncoding(method));
}

@end

@implementation UINavigationController (CharonInteractivePop)

- (UIGestureRecognizer *)interactivePopGestureRecognizer
{
    return charon_install_recognizer(self);
}

@end
