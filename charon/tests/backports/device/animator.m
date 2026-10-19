#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <mach/mach_time.h>
#import "check.h"

/* There is no host to hold the animator to: Mac Catalyst raises no UIWindow, and
   there is neither a simulator nor a device of iOS 10 here. So every expectation
   below is read off the algorithm in UIKit of iOS 10.3.4 and checked here. */

static NSString *const results_folder = @"/private/var/backports";

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

@interface CharonObserver : NSObject
@property (nonatomic, strong) NSMutableArray *seen;
@end

@implementation CharonObserver

- (instancetype)init
{
    if ((self = [super init]))
        _seen = [[NSMutableArray alloc] init];
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [_seen addObject:keyPath];
}

- (NSUInteger)countOf:(NSString *)keyPath
{
    NSUInteger count = 0;
    for (NSString *seen in _seen)
        if ([seen isEqualToString:keyPath])
            count++;
    return count;
}

@end

static NSString *raises(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@|%@", exception.name, exception.reason];
    }
    return nil;
}

static void run_checks(UIView *stage)
{
    for (NSString *name in @[@"UIViewPropertyAnimator"])
        CHECK_EQUAL(image_of(NSClassFromString(name)), @"libUIKitBackports.dylib",
                    [name stringByAppendingString:@" comes from the backports library"].UTF8String);

    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    box.backgroundColor = [UIColor redColor];
    [stage addSubview:box];

    /* What a fresh animator is. */
    UIViewPropertyAnimator *fresh = [[UIViewPropertyAnimator alloc] initWithDuration:2 curve:UIViewAnimationCurveEaseInOut
                                                                         animations:^{ box.alpha = 0.5; }];
    CHECK(fresh.state == UIViewAnimatingStateInactive, "a fresh animator is inactive");
    CHECK(!fresh.isRunning, "a fresh animator is not running");
    CHECK(!fresh.isReversed, "a fresh animator is not reversed");
    CHECK(fresh.isInterruptible, "an animator is interruptible unless told otherwise");
    CHECK(fresh.duration == 2, "the duration is kept");
    CHECK(fresh.fractionComplete == 0, "a fresh animator stands at the beginning");
    CHECK(fresh.timingParameters.timingCurveType == UITimingCurveTypeBuiltin,
          "a curve given by name is a builtin one");
    CHECK([fresh.description rangeOfString:@"[inactive]"].location != NSNotFound,
          "the description names the state");
    CHECK([fresh.description rangeOfString:@" interruptible"].location != NSNotFound,
          "the description says it is interruptible");

    /* A copy carries what was asked for, not what is happening. */
    UIViewPropertyAnimator *copy = [fresh copy];
    CHECK(copy.duration == 2 && copy.isInterruptible == fresh.isInterruptible,
          "a copy carries the duration and the flags");
    CHECK(copy.state == UIViewAnimatingStateInactive, "a copy starts inactive");

    /* The two real exceptions, with the texts UIKit raises. */
    CHECK_EQUAL(raises(^{ [fresh startAnimationAfterDelay:-1]; }),
                @"NSInvalidArgumentException|The delay should be greater than or equal to zero.",
                "a negative delay raises");

    /* Running, and the notifications it sends. */
    CharonObserver *observer = [[CharonObserver alloc] init];
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:2 curve:UIViewAnimationCurveLinear
                                                                            animations:^{ box.center = CGPointMake(200, 200); }];
    for (NSString *key in @[@"state", @"running", @"reversed", @"fractionComplete"])
        [animator addObserver:observer forKeyPath:key options:0 context:NULL];
    [animator startAnimation];
    CHECK(animator.state == UIViewAnimatingStateActive, "a started animator is active");
    CHECK(animator.isRunning, "a started animator is running");
    CHECK([observer countOf:@"state"] >= 1, "starting notifies of the state");
    CHECK([observer countOf:@"running"] >= 1, "starting notifies of running");
    CHECK_EQUAL(raises(^{ animator.interruptible = NO; }),
                ([NSString stringWithFormat:@"NSGenericException|It is not allowed to set the interruptible property of an active animator (%@)", animator]),
                "making an active animator uninterruptible raises");

    [animator pauseAnimation];
    CHECK(!animator.isRunning, "a paused animator is not running");
    CHECK(animator.state == UIViewAnimatingStateActive, "a paused animator is still active");

    animator.fractionComplete = 0.5;
    CHECK(fabs(animator.fractionComplete - 0.5) < 1e-6, "the fraction is where it was put");
    CHECK([observer countOf:@"fractionComplete"] >= 1, "scrubbing notifies of the fraction");
    /* Where the layer is drawn comes from the render server, which answers only
       inside a window; without one there is nothing to read and the check is not
       pretended. */
    if (box.window) {
        [CATransaction flush];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        CGPoint half = [box.layer.presentationLayer position];
        CHECK(half.x > 20 && half.x < 200,
              NAMED(@"half way along the animation the view is between its ends (x = %g)", half.x));
    } else {
        printf("skip half way along the animation the view is between its ends: no window, so no presentation layer\n");
    }

    /* An animation this animator never started must keep running while it is paused.
       Freezing every layer that happens to animate would stop this one too. */
    UIView *other = [[UIView alloc] initWithFrame:CGRectMake(0, 100, 20, 20)];
    other.backgroundColor = [UIColor blueColor];
    [stage addSubview:other];
    CABasicAnimation *elsewhere = [CABasicAnimation animationWithKeyPath:@"opacity"];
    elsewhere.fromValue = @1.0;
    elsewhere.toValue = @0.0;
    elsewhere.duration = 4;
    elsewhere.removedOnCompletion = NO;
    elsewhere.fillMode = kCAFillModeForwards;
    [other.layer addAnimation:elsewhere forKey:@"fade"];
    UIViewPropertyAnimator *second = [[UIViewPropertyAnimator alloc] initWithDuration:2 curve:UIViewAnimationCurveLinear
                                                                          animations:^{ box.alpha = 0.2; }];
    [second startAnimation];
    [second pauseAnimation];
    CHECK(other.layer.speed == 1, "another layer's own animation is not frozen by an animator");
    CHECK(box.layer.speed == 1, "the animator stops its own animation, not the layer");
    [second stopAnimation:NO];
    [second finishAnimationAtPosition:UIViewAnimatingPositionCurrent];

    /* Stopping and finishing. */
    __block UIViewAnimatingPosition reported = (UIViewAnimatingPosition)-1;
    [animator addCompletion:^(UIViewAnimatingPosition position) { reported = position; }];
    [animator stopAnimation:NO];
    CHECK(animator.state == UIViewAnimatingStateStopped, "stopping to be finished leaves it stopped");
    CHECK(!animator.isRunning, "a stopped animator is not running");
    CHECK(reported == (UIViewAnimatingPosition)-1, "stopping to be finished runs no completion yet");
    [animator finishAnimationAtPosition:UIViewAnimatingPositionEnd];
    CHECK(reported == UIViewAnimatingPositionEnd, "finishing runs the completion with the position given");
    CHECK(animator.state == UIViewAnimatingStateInactive, "a finished animator is inactive again");
    for (NSString *key in @[@"state", @"running", @"reversed", @"fractionComplete"])
        [animator removeObserver:observer forKeyPath:key];

    /* Stopping without finishing drops the completions. */
    __block UIViewAnimatingPosition second_reported = (UIViewAnimatingPosition)-1;
    UIViewPropertyAnimator *third = [[UIViewPropertyAnimator alloc] initWithDuration:2 curve:UIViewAnimationCurveLinear
                                                                         animations:^{ box.center = CGPointMake(30, 30); }];
    [third addCompletion:^(UIViewAnimatingPosition position) { second_reported = position; }];
    [third startAnimation];
    [third stopAnimation:YES];
    CHECK(second_reported == (UIViewAnimatingPosition)-1, "stopping without finishing runs no completion");
    CHECK(third.state == UIViewAnimatingStateInactive, "and leaves the animator inactive");
    CHECK(raises(^{ [third finishAnimationAtPosition:UIViewAnimatingPositionEnd]; }) == nil,
          "finishing an inactive animator is quietly nothing");
    CHECK(second_reported == (UIViewAnimatingPosition)-1, "and calls no completion");

    /* Scrubbing an animator that has blocks and has not started starts it paused. */
    UIViewPropertyAnimator *unstarted = [[UIViewPropertyAnimator alloc] initWithDuration:2 curve:UIViewAnimationCurveLinear
                                                                             animations:^{ box.alpha = 0.5; }];
    unstarted.fractionComplete = 0.25;
    CHECK(unstarted.state == UIViewAnimatingStateActive && !unstarted.isRunning,
          "scrubbing an animator that has not started leaves it active and paused");
    [unstarted stopAnimation:YES];

    /* An animator that is not interruptible is left to Core Animation. */
    UIViewPropertyAnimator *plain = [[UIViewPropertyAnimator alloc] initWithDuration:1 curve:UIViewAnimationCurveLinear
                                                                         animations:^{ box.alpha = 1; }];
    plain.interruptible = NO;
    CHECK(!plain.isInterruptible, "an animator can be made uninterruptible before it starts");
    [plain startAnimation];
    CHECK(plain.isRunning, "an uninterruptible animator runs");
}

static CGFloat scrubbed_to_a_quarter(UIView *stage, BOOL linearly)
{
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 300, 20, 20)];
    [stage addSubview:box];
    UIViewPropertyAnimator *animator =
        [[UIViewPropertyAnimator alloc] initWithDuration:2 curve:UIViewAnimationCurveEaseInOut
                                              animations:^{ box.center = CGPointMake(210, 310); }];
    animator.scrubsLinearly = linearly;
    animator.fractionComplete = 0.25;
    [CATransaction flush];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    CGFloat x = [box.layer.presentationLayer position].x - 10;
    [animator stopAnimation:YES];
    [box removeFromSuperview];
    return x;
}

static void measure_scrubbing_curve(UIView *stage)
{
    CGFloat linear = scrubbed_to_a_quarter(stage, YES), curved = scrubbed_to_a_quarter(stage, NO);
    printf("a quarter of the fraction on ease-in-out: scrubbing linearly x = %g, along the curve x = %g\n", linear, curved);
    CHECK(fabs(linear - 50) < 2, NAMED(@"scrubbing linearly puts a quarter a quarter of the way (x = %g)", linear));
    CHECK(fabs(curved - 25.8) < 2,
          NAMED(@"scrubbing along the curve puts a quarter where ease-in-out does, 0.129 of the way (x = %g)", curved));
}

/* What the correct scrubbing costs on this hardware. Rebuilding the animation
   with its own speed and time offset is the only way to scrub one animator
   without freezing animations it never started; freezing the layer is cheaper
   and wrong. The A5 is the slowest thing this port runs on, so the number that
   matters is whether one scrub step fits in a display frame. */
static double per_step_microseconds(NSUInteger steps, void (^step)(double fraction))
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    uint64_t started = mach_absolute_time();
    for (NSUInteger i = 0; i < steps; i++)
        step((double)i / (double)steps);
    uint64_t elapsed = mach_absolute_time() - started;
    double nanoseconds = (double)elapsed * timebase.numer / timebase.denom;
    return nanoseconds / 1000.0 / (double)steps;
}

static void measure_scrubbing(UIView *stage)
{
    static const NSUInteger steps = 200;
    static const double frame_microseconds = 1000000.0 / 60.0;

    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    box.backgroundColor = [UIColor greenColor];
    [stage addSubview:box];

    UIViewPropertyAnimator *animator =
        [[UIViewPropertyAnimator alloc] initWithDuration:2 curve:UIViewAnimationCurveLinear
                                              animations:^{ box.center = CGPointMake(200, 200); }];
    [animator startAnimation];
    [animator pauseAnimation];

    __block double sink = 0;
    double baseline = per_step_microseconds(steps, ^(double fraction) { sink += fraction; });
    double rebuild = per_step_microseconds(steps, ^(double fraction) { animator.fractionComplete = fraction; });
    CALayer *layer = box.layer;
    double freeze = per_step_microseconds(steps, ^(double fraction) {
        layer.speed = 0;
        layer.timeOffset = fraction * 2;
    });
    [animator stopAnimation:YES];
    [box removeFromSuperview];

    printf("scrub %lu steps: loop %.1f us, freeze-the-layer %.1f us, rebuild-the-animation %.1f us (frame is %.1f us)\n",
           (unsigned long)steps, baseline, freeze, rebuild, frame_microseconds);
    charon_check(rebuild < frame_microseconds,
                 "one scrub step fits in a display frame on this hardware",
                 [NSString stringWithFormat:@"%.1f us >= %.1f us", rebuild, frame_microseconds]);
    (void)sink;
}

@interface CharonAnimatorDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CharonAnimatorDelegate {
    UIWindow *_window;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"animator.log"]);
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _window.backgroundColor = [UIColor whiteColor];
    _window.rootViewController = [[UIViewController alloc] init];
    [_window makeKeyAndVisible];
    @try {
        run_checks(_window.rootViewController.view);
        measure_scrubbing_curve(_window.rootViewController.view);
        measure_scrubbing(_window.rootViewController.view);
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception",
                     [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n",
                                                   charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"animator.done"]
              atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder
                                  withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonAnimatorDelegate");
    }
}
