#import <UIKit/UIKit.h>
#import "check.h"
#import "gesture.h"

static NSString *const results_folder = @"/private/var/backports";

@interface UnblockView : UIView
@property (nonatomic) int touches;
@end

@implementation UnblockView
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.touches++;
}
@end

@interface UnblockDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation UnblockDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"unblock.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"unblock.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *controller = [[UIViewController alloc] init];
    UnblockView *view = [[UnblockView alloc] initWithFrame:self.window.bounds];
    view.backgroundColor = [UIColor whiteColor];
    controller.view = view;
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CHECK(gesture_ready(), "touches can be sent to the application through the HID event system");
        gesture_unblock(self.window, ^(BOOL blocked, BOOL reached) {
            CHECK(!blocked && reached, "with nothing in the way the first touch arrives");
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location" message:@"The application would like to use your location" delegate:nil cancelButtonTitle:@"Don't Allow" otherButtonTitles:@"OK", nil];
            [alert show];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                int before = view.touches;
                gesture_step(0.05, ^{});
                gesture_tap(^{ return CGPointMake(CGRectGetMidX(view.bounds), CGRectGetHeight(view.bounds) * 0.25); }, 0.5);
                gesture_run(^{
                    CHECK(view.touches == before, "a modal alert takes the touches");
                    gesture_unblock(self.window, ^(BOOL blockedNow, BOOL reachedNow) {
                        CHECK(blockedNow && reachedNow, "the alert is found in the way and dismissed by a tap on one of its buttons");
                        int after = view.touches;
                        gesture_step(0.05, ^{});
                        gesture_tap(^{ return CGPointMake(CGRectGetMidX(view.bounds), CGRectGetHeight(view.bounds) * 0.25); }, 0.5);
                        gesture_run(^{
                            CHECK(view.touches == after + 1, "and the touches reach the application again");
                            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
                            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
                            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"unblock.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
                        });
                    });
                });
            });
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([UnblockDelegate class]));
    }
}
