#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"
#import "gesture.h"

static NSString *const results_folder = @"/private/var/backports";

typedef struct {
    int width, height;
    unsigned char *pixels;
} Screen;

static Screen capture(NSString *name)
{
    Screen screen = {0, 0, NULL};
    CGImageRef (*grab)(void) = dlsym(RTLD_DEFAULT, "UIGetScreenImage");
    if (!grab)
        return screen;
    CGImageRef image = grab();
    screen.width = (int)CGImageGetWidth(image);
    screen.height = (int)CGImageGetHeight(image);
    screen.pixels = calloc((size_t)screen.width * screen.height, 4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(screen.pixels, screen.width, screen.height, 8, screen.width * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, screen.width, screen.height), image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    if (name)
        [UIImagePNGRepresentation([UIImage imageWithCGImage:image]) writeToFile:[results_folder stringByAppendingPathComponent:[NSString stringWithFormat:@"interactivepan-%@.png", name]] atomically:YES];
    return screen;
}

static NSString *color_at(Screen screen, double fx, double fy)
{
    int x = (int)(fx * (screen.width - 1)), y = (int)(fy * (screen.height - 1));
    const unsigned char *p = screen.pixels + ((size_t)y * screen.width + x) * 4;
    if (p[0] > 200 && p[1] < 80 && p[2] < 80)
        return @"red";
    if (p[2] > 200 && p[0] < 80 && p[1] < 80)
        return @"blue";
    return [NSString stringWithFormat:@"%d,%d,%d", p[0], p[1], p[2]];
}

@interface SolidController : UIViewController
@property (nonatomic, strong) UIColor *color;
@end

@implementation SolidController
- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    view.backgroundColor = self.color;
    self.view = view;
}
@end

@interface DownAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic) BOOL entering;
@end

@implementation DownAnimator
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context { return 1.0; }
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context
{
    UIView *container = context.containerView;
    UIView *fromView = [context viewForKey:UITransitionContextFromViewKey];
    UIView *toView = [context viewForKey:UITransitionContextToViewKey];
    CGRect final = [context finalFrameForViewController:[context viewControllerForKey:UITransitionContextToViewControllerKey]];
    if (self.entering) {
        toView.frame = CGRectOffset(final, 0, container.bounds.size.height);
        [container addSubview:toView];
        [UIView animateWithDuration:1.0 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{ toView.frame = final; } completion:^(BOOL finished) { [context completeTransition:YES]; }];
    } else {
        toView.frame = final;
        [container insertSubview:toView belowSubview:fromView];
        [UIView animateWithDuration:1.0 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{ fromView.frame = CGRectOffset(fromView.frame, 0, container.bounds.size.height); } completion:^(BOOL finished) { [context completeTransition:![context transitionWasCancelled]]; }];
    }
}
@end

@interface PanDelegate : NSObject <UIViewControllerTransitioningDelegate>
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactor;
@end

@implementation PanDelegate
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    DownAnimator *animator = [[DownAnimator alloc] init];
    animator.entering = YES;
    return animator;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed { return [[DownAnimator alloc] init]; }
- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator { return self.interactor; }
@end

@interface PanApp : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) PanDelegate *panDelegate;
@property (nonatomic, strong) UINavigationController *navigation;
@property (nonatomic, strong) SolidController *modal;
@property (nonatomic, strong) NSMutableArray *events;
@end

@implementation PanApp

- (void)panned:(UIPanGestureRecognizer *)pan
{
    CGFloat height = self.window.bounds.size.height;
    CGFloat percent = MAX(0, [pan translationInView:pan.view].y / height);
    switch (pan.state) {
    case UIGestureRecognizerStateBegan: {
        self.panDelegate.interactor = [[UIPercentDrivenInteractiveTransition alloc] init];
        [self.navigation dismissViewControllerAnimated:YES completion:nil];
        [self.modal.transitionCoordinator notifyWhenInteractionEndsUsingBlock:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            [self.events addObject:[NSString stringWithFormat:@"interactionEnded cancelled=%d", context.isCancelled]];
        }];
        [self.events addObject:[NSString stringWithFormat:@"began interactive=%d", self.modal.transitionCoordinator.isInteractive]];
        break;
    }
    case UIGestureRecognizerStateChanged:
        [self.panDelegate.interactor updateInteractiveTransition:percent];
        break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled: {
        UIPercentDrivenInteractiveTransition *interactor = self.panDelegate.interactor;
        self.panDelegate.interactor = nil;
        if (percent > 0.5)
            [interactor finishInteractiveTransition];
        else
            [interactor cancelInteractiveTransition];
        [self.events addObject:[NSString stringWithFormat:@"ended percent=%.2f", percent]];
        break;
    }
    default:
        break;
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"interactivepan.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"interactivepan.log"]);
    self.events = [NSMutableArray array];
    self.panDelegate = [[PanDelegate alloc] init];
    SolidController *base = [[SolidController alloc] init];
    base.color = [UIColor redColor];
    self.navigation = [[UINavigationController alloc] initWithRootViewController:base];
    self.navigation.navigationBarHidden = YES;
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = self.navigation;
    [self.window makeKeyAndVisible];
    self.modal = [[SolidController alloc] init];
    self.modal.color = [UIColor blueColor];
    self.modal.transitioningDelegate = self.panDelegate;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    [self.modal.view addGestureRecognizer:pan];
    CGFloat width = self.window.bounds.size.width, height = self.window.bounds.size.height;
    __block Screen screen;

    gesture_step(1.6, ^{ CHECK(gesture_ready(), "touches can be sent"); [self.navigation presentViewController:self.modal animated:YES completion:nil]; });
    gesture_step(0.05, ^{
        screen = capture(@"presented");
        CHECK_EQUAL(color_at(screen, 0.5, 0.5), @"blue", "the presented controller fills the screen");
        CHECK(self.navigation.presentedViewController == self.modal, "and is the presented controller");
        gesture_touch(0, CGPointMake(width / 2, 100));
    });
    for (int step = 1; step <= 8; step++)
        gesture_step(0.05, ^{ gesture_touch(1, CGPointMake(width / 2, 100 + height * 0.3 * step / 8)); });
    gesture_step(0.3, ^{});
    gesture_step(0.1, ^{
        screen = capture(nil);
        CHECK([self.events.firstObject isEqual:@"began interactive=1"], "the coordinator is interactive when the pan begins the dismissal");
        CHECK_EQUAL(color_at(screen, 0.5, 0.15), @"red", "a third of the way down the controller below shows at the top");
        CHECK_EQUAL(color_at(screen, 0.5, 0.85), @"blue", "and the presented one is still at the bottom");
    });
    gesture_step(1.8, ^{ gesture_touch(2, CGPointMake(width / 2, 100 + height * 0.3)); });
    gesture_step(0.05, ^{
        screen = capture(@"cancelled");
        CHECK(self.navigation.presentedViewController == self.modal, "let go at 30% the dismissal is cancelled and the controller is still presented");
        CHECK_EQUAL(color_at(screen, 0.5, 0.15), @"blue", "and it covers the screen again");
        CHECK_EQUAL(color_at(screen, 0.5, 0.85), @"blue", "all of it");
        CHECK([self.events containsObject:@"interactionEnded cancelled=1"], "the coordinator told the end of the interaction, cancelled");
        [self.events removeAllObjects];
        gesture_touch(0, CGPointMake(width / 2, 100));
    });
    for (int step = 1; step <= 8; step++)
        gesture_step(0.05, ^{ gesture_touch(1, CGPointMake(width / 2, 100 + height * 0.7 * step / 8)); });
    gesture_step(2.0, ^{ gesture_touch(2, CGPointMake(width / 2, 100 + height * 0.7)); });
    gesture_step(0.05, ^{
        screen = capture(@"finished");
        CHECK(self.navigation.presentedViewController == nil, "let go at 70% the dismissal finishes");
        CHECK_EQUAL(color_at(screen, 0.5, 0.5), @"red", "and the controller below is back");
        CHECK([self.events containsObject:@"interactionEnded cancelled=0"], "the coordinator told the end of the interaction, not cancelled");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"interactivepan.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ gesture_run(^{}); });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([PanApp class]));
    }
}
