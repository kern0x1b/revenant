#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"

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
    if (name)
        [UIImagePNGRepresentation([UIImage imageWithCGImage:image]) writeToFile:[results_folder stringByAppendingPathComponent:[NSString stringWithFormat:@"slidetransition-%@.png", name]] atomically:YES];
    screen.width = (int)CGImageGetWidth(image);
    screen.height = (int)CGImageGetHeight(image);
    screen.pixels = calloc((size_t)screen.width * screen.height, 4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(screen.pixels, screen.width, screen.height, 8, screen.width * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, screen.width, screen.height), image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
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
    if (p[1] > 180 && p[0] < 90 && p[2] < 90)
        return @"green";
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

@interface SlideAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic) BOOL up;
@property (nonatomic) BOOL entering;
@property (nonatomic) BOOL horizontal;
@end

@implementation SlideAnimator

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context { return 1.0; }

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context
{
    UIView *container = context.containerView;
    UIView *fromView = [context viewForKey:UITransitionContextFromViewKey];
    UIView *toView = [context viewForKey:UITransitionContextToViewKey];
    CGRect bounds = container.bounds;
    CGRect final = [context finalFrameForViewController:[context viewControllerForKey:UITransitionContextToViewControllerKey]];
    if (self.entering) {
        toView.frame = CGRectOffset(final, self.horizontal ? bounds.size.width : 0, self.horizontal ? 0 : bounds.size.height);
        [container addSubview:toView];
        [UIView animateWithDuration:1.0 animations:^{ toView.frame = final; } completion:^(BOOL finished) { [context completeTransition:YES]; }];
    } else {
        toView.frame = final;
        [container insertSubview:toView belowSubview:fromView];
        [UIView animateWithDuration:1.0 animations:^{ fromView.frame = CGRectOffset(fromView.frame, self.horizontal ? bounds.size.width : 0, self.horizontal ? 0 : bounds.size.height); } completion:^(BOOL finished) { [context completeTransition:YES]; }];
    }
}

@end

@interface SlideDelegate : NSObject <UIViewControllerTransitioningDelegate, UINavigationControllerDelegate>
@end

@implementation SlideDelegate
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    SlideAnimator *animator = [[SlideAnimator alloc] init];
    animator.entering = YES;
    return animator;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return [[SlideAnimator alloc] init];
}
- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    SlideAnimator *animator = [[SlideAnimator alloc] init];
    animator.horizontal = YES;
    animator.entering = operation == UINavigationControllerOperationPush;
    return animator;
}
@end

@interface SlideApp : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) SlideDelegate *slide;
@end

@implementation SlideApp

- (void)phase:(NSString *)name start:(void (^)(void))start mid:(void (^)(Screen))mid end:(void (^)(Screen))end next:(void (^)(void))next
{
    start();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Screen screen = capture([name stringByAppendingString:@"-mid"]);
        mid(screen);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Screen finished = capture([name stringByAppendingString:@"-end"]);
            end(finished);
            next();
        });
    });
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"slidetransition.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"slidetransition.log"]);
    self.slide = [[SlideDelegate alloc] init];
    SolidController *base = [[SolidController alloc] init];
    base.color = [UIColor redColor];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:base];
    navigation.navigationBarHidden = YES;
    navigation.delegate = self.slide;
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    SolidController *modal = [[SolidController alloc] init];
    modal.color = [UIColor blueColor];
    modal.transitioningDelegate = self.slide;
    SolidController *second = [[SolidController alloc] init];
    second.color = [UIColor greenColor];
    void (^finish)(void) = ^{
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"slidetransition.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    };
    void (^popPhase)(void) = ^{
        [self phase:@"pop" start:^{ [navigation popViewControllerAnimated:YES]; } mid:^(Screen screen) {
            CHECK_EQUAL(color_at(screen, 0.1, 0.5), @"red", "halfway through a pop the controller below shows at the left");
            CHECK_EQUAL(color_at(screen, 0.9, 0.5), @"green", "and the popped one is on its way out at the right");
        } end:^(Screen screen) {
            CHECK_EQUAL(color_at(screen, 0.5, 0.5), @"red", "at the end the first controller is back");
            CHECK(navigation.viewControllers.count == 1 && base.view.window != nil, "alone in the stack");
        } next:finish];
    };
    void (^pushPhase)(void) = ^{
        [self phase:@"push" start:^{ [navigation pushViewController:second animated:YES]; } mid:^(Screen screen) {
            CHECK_EQUAL(color_at(screen, 0.1, 0.5), @"red", "halfway through a push the old controller is seen at the left");
            CHECK_EQUAL(color_at(screen, 0.9, 0.5), @"green", "and the new one at the right");
        } end:^(Screen screen) {
            CHECK_EQUAL(color_at(screen, 0.5, 0.5), @"green", "at the end the pushed controller fills the screen");
            CHECK(navigation.topViewController == second && second.view.window != nil, "and is the top controller");
        } next:popPhase];
    };
    void (^dismissPhase)(void) = ^{
        [self phase:@"dismiss" start:^{ [navigation dismissViewControllerAnimated:YES completion:nil]; } mid:^(Screen screen) {
            CHECK_EQUAL(color_at(screen, 0.5, 0.15), @"red", "halfway through a slide down the presenting controller shows at the top");
            CHECK_EQUAL(color_at(screen, 0.5, 0.9), @"blue", "and the presented one is on its way out at the bottom");
        } end:^(Screen screen) {
            CHECK_EQUAL(color_at(screen, 0.5, 0.5), @"red", "at the end the presenting controller is back");
            CHECK(navigation.presentedViewController == nil && navigation.view.window != nil, "and nothing is presented");
        } next:pushPhase];
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Screen screen = capture(@"start");
        CHECK_EQUAL(color_at(screen, 0.5, 0.5), @"red", "the base controller is red");
        [self phase:@"present" start:^{ [navigation presentViewController:modal animated:YES completion:nil]; } mid:^(Screen mid) {
            CHECK_EQUAL(color_at(mid, 0.5, 0.15), @"red", "halfway through a slide up the presenting controller is still seen at the top");
            CHECK_EQUAL(color_at(mid, 0.5, 0.9), @"blue", "and the presented one has come in at the bottom");
        } end:^(Screen end) {
            CHECK_EQUAL(color_at(end, 0.5, 0.15), @"blue", "at the end the presented controller fills the screen");
            CHECK(navigation.presentedViewController == modal && modal.view.window != nil, "and is the presented controller");
        } next:dismissPhase];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SlideApp class]));
    }
}
