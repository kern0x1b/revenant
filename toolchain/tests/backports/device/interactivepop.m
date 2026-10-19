#import <UIKit/UIKit.h>
#import "check.h"
#import "gesture.h"

static NSString *const results_folder = @"/private/var/backports";

@interface PopGate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, assign) BOOL allow;
@end

@implementation PopGate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer { return self.allow; }
@end

@interface InteractivePopDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigation;
@property (nonatomic, strong) PopGate *gate;
@end

@implementation InteractivePopDelegate

- (UIViewController *)page:(NSString *)title
{
    UIViewController *controller = [[UIViewController alloc] init];
    controller.title = title;
    controller.view.backgroundColor = [UIColor whiteColor];
    return controller;
}

- (void)pushPages:(NSUInteger)count
{
    [self.navigation popToRootViewControllerAnimated:NO];
    for (NSUInteger index = 1; index < count; index++)
        [self.navigation pushViewController:[self page:[NSString stringWithFormat:@"page %lu", (unsigned long)index]] animated:NO];
}

- (void)dragFrom:(CGFloat)startX to:(CGFloat)endX midCheck:(void (^)(void))mid
{
    CGFloat y = 240;
    gesture_step(0.05, ^{ gesture_touch(0, CGPointMake(startX, y)); });
    for (int index = 1; index <= 10; index++) {
        CGFloat x = startX + (endX - startX) * index / 10;
        gesture_step(0.03, ^{ gesture_touch(1, CGPointMake(x, y)); });
        if (index == 5 && mid)
            gesture_step(0.05, mid);
    }
    gesture_step(0.05, ^{ gesture_touch(2, CGPointMake(endX, y)); });
    gesture_step(0.9, ^{});
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"interactivepop.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"interactivepop.log"]);
    self.navigation = [[UINavigationController alloc] initWithRootViewController:[self page:@"root"]];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = self.navigation;
    [self.window makeKeyAndVisible];
    self.gate = [[PopGate alloc] init];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIGestureRecognizer *recognizer = self.navigation.interactivePopGestureRecognizer;
        CHECK(recognizer != nil, "the navigation controller has an interactive pop recognizer");
        CHECK(recognizer.enabled, "it is enabled");
        CHECK(recognizer.delegate != nil, "it has a delegate of its own");
        CHECK([recognizer.view isDescendantOfView:self.navigation.view], "it is on the navigation controller's view");
        CHECK(self.navigation.interactivePopGestureRecognizer == recognizer, "the same one is answered again");
        __block CGFloat offset = 0;
        gesture_step(0.01, ^{ CHECK(gesture_ready(), "touches can be sent"); });
        gesture_step(0.05, ^{ [self pushPages:3]; });
        gesture_step(0.6, ^{});
        [self dragFrom:2 to:260 midCheck:^{
            UIView *top = self.navigation.topViewController.view;
            CALayer *layer = top.layer.presentationLayer ?: top.layer;
            offset = [layer convertPoint:CGPointZero toLayer:self.window.layer].x;
            CHECK(offset > 60, "while the finger moves the top page follows it");
        }];
        gesture_step(0.05, ^{
            CHECK(self.navigation.viewControllers.count == 2, "a drag past the middle pops the page");
            CHECK([self.navigation.topViewController.title isEqual:@"page 1"], "to the page below");
        });
        [self dragFrom:2 to:60 midCheck:nil];
        gesture_step(0.05, ^{ CHECK(self.navigation.viewControllers.count == 2, "a short drag lets go and the page stays"); CHECK(self.navigation.topViewController.view.window != nil, "and it is on the screen"); });
        gesture_step(0.05, ^{ recognizer.enabled = NO; });
        [self dragFrom:2 to:260 midCheck:nil];
        gesture_step(0.05, ^{ CHECK(self.navigation.viewControllers.count == 2, "a disabled recognizer does not pop"); recognizer.enabled = YES; });
        gesture_step(0.05, ^{ recognizer.delegate = self.gate; self.gate.allow = NO; });
        [self dragFrom:2 to:260 midCheck:nil];
        gesture_step(0.05, ^{ CHECK(self.navigation.viewControllers.count == 2, "a delegate that says no keeps the page"); self.gate.allow = YES; });
        [self dragFrom:2 to:260 midCheck:nil];
        gesture_step(0.05, ^{ CHECK(self.navigation.viewControllers.count == 1, "a delegate that says yes lets it pop"); });
        [self dragFrom:2 to:260 midCheck:nil];
        gesture_step(0.05, ^{ CHECK(self.navigation.viewControllers.count == 1 && self.navigation.topViewController.view.window, "the root page stays"); });
        gesture_run(^{
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"interactivepop.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([InteractivePopDelegate class]));
    }
}
