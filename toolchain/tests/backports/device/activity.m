#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

static void run_checks(void)
{
    UIApplication *application = [UIApplication sharedApplication];
    NSProcessInfo *info = [NSProcessInfo processInfo];
    CHECK(!application.idleTimerDisabled, "the idle timer is on to begin with");

    id quiet = [info beginActivityWithOptions:NSActivityBackground reason:@"quiet"];
    CHECK(!application.idleTimerDisabled, "an activity that does not ask to stay awake leaves the idle timer alone");
    [info endActivity:quiet];

    id display = [info beginActivityWithOptions:NSActivityIdleDisplaySleepDisabled reason:@"display"];
    CHECK(application.idleTimerDisabled, "an activity that keeps the display awake turns the idle timer off");
    id system = [info beginActivityWithOptions:NSActivityIdleSystemSleepDisabled reason:@"system"];
    [info endActivity:display];
    CHECK(application.idleTimerDisabled, "and it stays off while another such activity runs");
    [info endActivity:system];
    CHECK(!application.idleTimerDisabled, "and is back when the last one ends");
    [info endActivity:system];
    CHECK(!application.idleTimerDisabled, "ending a token twice changes nothing");

    application.idleTimerDisabled = YES;
    id again = [info beginActivityWithOptions:NSActivityIdleSystemSleepDisabled reason:@"again"];
    [info endActivity:again];
    CHECK(application.idleTimerDisabled, "an application's own setting is put back");
    application.idleTimerDisabled = NO;

    __block BOOL insideAwake = NO;
    [info performActivityWithOptions:NSActivityIdleDisplaySleepDisabled reason:@"block" usingBlock:^{ insideAwake = application.idleTimerDisabled; }];
    CHECK(insideAwake && !application.idleTimerDisabled, "a block activity holds the idle timer off while it runs");

    id user = [info beginActivityWithOptions:NSActivityUserInitiated reason:@"user"];
    CHECK(user != nil && application.idleTimerDisabled, "a user-initiated activity stays awake and holds a background task");
    [info endActivity:user];
    CHECK(!application.idleTimerDisabled, "and lets go of both");

    dispatch_semaphore_t began = dispatch_semaphore_create(0);
    __block id other = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        other = [info beginActivityWithOptions:NSActivityIdleSystemSleepDisabled reason:@"thread"];
        dispatch_semaphore_signal(began);
    });
    dispatch_semaphore_wait(began, DISPATCH_TIME_FOREVER);
    dispatch_async(dispatch_get_main_queue(), ^{
        CHECK(application.idleTimerDisabled, "an activity begun on another thread turns it off on the main thread");
        [info endActivity:other];
        dispatch_async(dispatch_get_main_queue(), ^{
            CHECK(!application.idleTimerDisabled, "and ending it there turns it back on");
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"activity.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
}

@interface ActivityDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ActivityDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"activity.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"activity.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ run_checks(); });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ActivityDelegate class]));
    }
}
