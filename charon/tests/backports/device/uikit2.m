#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const double pause_seconds = 1;
static const double step_timeout_seconds = 30;
static const double run_timeout_seconds = 300;
static NSString *const results_folder = @"/private/var/backports";

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

typedef void (^Step)(void (^done)(void));

static NSInteger running_step;

static void guarded(dispatch_block_t block)
{
    @try {
        block();
    } @catch (NSException *exception) {
        charon_check(NO, NAMED(@"step %ld raises no exception", (long)running_step),
                     [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
}

static void after(double seconds, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        guarded(block);
    });
}

static void write_summary(NSString *reason)
{
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d%@\n", charon_failures ? @"FAIL" : @"ok",
                         charon_checks, charon_failures, reason.length ? [@" " stringByAppendingString:reason] : @""];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"uikit2.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void uncaught(NSException *exception)
{
    charon_failures++;
    printf("FAIL uncaught %s: %s\n%s\n", exception.name.UTF8String, exception.reason.UTF8String,
           [exception.callStackReturnAddresses description].UTF8String);
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    fflush(stdout);
    write_summary([@"uncaught " stringByAppendingString:exception.name]);
}

static NSString *image_of(Class class, SEL selector)
{
    Dl_info info;
    IMP implementation = class_getMethodImplementation(class, selector);
    return implementation && dladdr((const void *)implementation, &info) ? [[NSString stringWithUTF8String:info.dli_fname] lastPathComponent] : @"<unknown>";
}

static NSString *traits_of(id environment)
{
    UITraitCollection *traits = [environment traitCollection];
    return [NSString stringWithFormat:@"idiom %ld scale %g horizontal %ld vertical %ld", (long)traits.userInterfaceIdiom,
            (double)traits.displayScale, (long)traits.horizontalSizeClass, (long)traits.verticalSizeClass];
}

@interface RecordingView : UIView
@property (nonatomic, strong) UITraitCollection *previousTraits;
@property (nonatomic) NSInteger traitChanges;
@property (nonatomic) NSInteger tintChanges;
@end

@implementation RecordingView

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    self.previousTraits = previousTraitCollection;
    self.traitChanges++;
}

- (void)tintColorDidChange
{
    self.tintChanges++;
}

@end

@interface RecordingController : UIViewController
@property (nonatomic, strong) UITraitCollection *previousTraits;
@property (nonatomic) NSInteger traitChanges;
@end

@implementation RecordingController

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    self.previousTraits = previousTraitCollection;
    self.traitChanges++;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

@end

@interface DocumentPickerRecorder : NSObject <UIDocumentPickerDelegate>
@property (nonatomic) int cancelled;
@property (nonatomic) BOOL dismissedWhenCancelled;
@end

@implementation DocumentPickerRecorder

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    self.cancelled++;
    self.dismissedWhenCancelled = controller.presentingViewController == nil;
}

@end

@interface UIKitTestDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) RecordingController *host;
@property (nonatomic, strong) RecordingView *content;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UIUserNotificationSettings *registeredSettings;
@property (nonatomic) NSInteger registrations;
@property (nonatomic) BOOL finished;
@end

@interface StatusProbe : UIViewController
@property (nonatomic, strong) UIViewController *child;
@end

@implementation StatusProbe

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleBlackTranslucent;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.child;
}

@end

@implementation UIKitTestDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"uikit2.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"uikit2.log"]);
    NSSetUncaughtExceptionHandler(uncaught);
    printf("uikit2 device test started on iOS %s\n", [UIDevice currentDevice].systemVersion.UTF8String);
    self.host = [[RecordingController alloc] init];
    self.host.view.backgroundColor = [UIColor whiteColor];
    self.content = [[RecordingView alloc] initWithFrame:CGRectMake(20, 60, 200, 100)];
    self.content.backgroundColor = [UIColor lightGrayColor];
    [self.host.view addSubview:self.content];
    self.status = [[UILabel alloc] initWithFrame:CGRectMake(10, 200, 300, 200)];
    self.status.numberOfLines = 0;
    self.status.text = @"Running";
    [self.host.view addSubview:self.status];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = self.host;
    [self.window makeKeyAndVisible];
    NSArray *steps = [self steps];
    after(1, ^{
        [self run:steps index:0];
    });
    after(run_timeout_seconds, ^{
        if (!self.finished)
            charon_check(NO, "the whole test finishes in time", @"the run timed out");
        [self finish];
    });
    return YES;
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    self.registrations++;
    self.registeredSettings = notificationSettings;
}

- (void)run:(NSArray *)steps index:(NSUInteger)index
{
    if (index == steps.count) {
        [self finish];
        return;
    }
    printf("step %lu\n", (unsigned long)index + 1);
    running_step = index + 1;
    self.status.text = [NSString stringWithFormat:@"Step %lu of %lu", (unsigned long)index + 1, (unsigned long)steps.count];
    __block BOOL stepFinished = NO;
    void (^done)(void) = ^{
        if (stepFinished)
            return;
        stepFinished = YES;
        after(pause_seconds, ^{
            [self run:steps index:index + 1];
        });
    };
    after(step_timeout_seconds, ^{
        if (!stepFinished) {
            charon_check(NO, "step finishes in time", [NSString stringWithFormat:@"step %lu timed out", (unsigned long)index + 1]);
            done();
        }
    });
    Step step = [steps objectAtIndex:index];
    guarded(^{
        step(done);
    });
}

- (void)finish
{
    if (self.finished)
        return;
    self.finished = YES;
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    fflush(stdout);
    self.status.text = [NSString stringWithFormat:@"%@\nchecks=%d failures=%d", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    write_summary(nil);
}

- (NSArray *)steps
{
    UIKitTestDelegate *test = self;
    return @[
        [^(void (^done)(void)) {
            UIScreen *screen = [UIScreen mainScreen];
            UIUserInterfaceIdiom idiom = [UIDevice currentDevice].userInterfaceIdiom;
            BOOL landscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
            CGSize inOrientation = landscape ? CGSizeMake(screen.bounds.size.height, screen.bounds.size.width) : screen.bounds.size;
            NSString *expected = [NSString stringWithFormat:@"idiom %ld scale %g horizontal %ld vertical %ld", (long)idiom, (double)screen.scale,
                                  (long)(inOrientation.width > 667 ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact),
                                  (long)(idiom == UIUserInterfaceIdiomPad || inOrientation.height >= 480 ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact)];
            printf("info the screen is %s in the orientation %ld\n", NSStringFromCGSize(inOrientation).UTF8String, (long)[UIApplication sharedApplication].statusBarOrientation);
            charon_check([traits_of(screen) isEqualToString:expected], "the screen traits follow the iOS 8 rules", [NSString stringWithFormat:@"%@ != %@", traits_of(screen), expected]);
            charon_check([traits_of(test.window) isEqualToString:traits_of(screen)], "a window takes the traits of its screen", traits_of(test.window));
            charon_check([traits_of(test.host) isEqualToString:traits_of(screen)], "a view controller in a window takes its traits", traits_of(test.host));
            charon_check([traits_of(test.content) isEqualToString:traits_of(screen)], "a view takes the traits of its controller", traits_of(test.content));
            charon_check([traits_of([[UIView alloc] init]) isEqualToString:traits_of(screen)], "a view outside any window falls back to the main screen", traits_of([[UIView alloc] init]));
            charon_check([test.content conformsToProtocol:@protocol(UITraitEnvironment)], "a view is a trait environment", @"the protocol is missing");
            charon_check([test.host conformsToProtocol:@protocol(UITraitEnvironment)], "a view controller is a trait environment", @"the protocol is missing");
            charon_check([screen conformsToProtocol:@protocol(UITraitEnvironment)], "a screen is a trait environment", @"the protocol is missing");
            charon_check([test.content.traitCollection containsTraitsInCollection:[UITraitCollection traitCollectionWithDisplayScale:screen.scale]],
                         "the view traits contain the display scale", traits_of(test.content));
            CGRect bounds = screen.bounds;
            charon_check(CGRectEqualToRect(screen.nativeBounds, CGRectMake(0, 0, bounds.size.width * screen.scale, bounds.size.height * screen.scale)),
                         "nativeBounds is the screen in pixels", NSStringFromCGRect(screen.nativeBounds));
            charon_check(screen.nativeScale == screen.scale, "nativeScale", [NSString stringWithFormat:@"%g", (double)screen.nativeScale]);
            done();
        } copy],
        [^(void (^done)(void)) {
            UIApplication *application = [UIApplication sharedApplication];
            UIInterfaceOrientation start = application.statusBarOrientation;
            test.content.traitChanges = 0;
            test.host.traitChanges = 0;
            __block BOOL announced = NO;
            id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
                announced = YES;
            }];
            printf("info the application supports the orientations %lu, the controller %lu, and it autorotates %d\n",
                   (unsigned long)[application supportedInterfaceOrientationsForWindow:test.window],
                   (unsigned long)[test.host supportedInterfaceOrientations], [test.host shouldAutorotate]);
            [application setStatusBarOrientation:UIInterfaceOrientationLandscapeLeft animated:NO];
            after(0.5, ^{
                charon_check(announced, "iOS 6 announces a status bar orientation change", @"no notification arrived");
                charon_check(application.statusBarOrientation == UIInterfaceOrientationLandscapeLeft, "the status bar turned", @"the orientation did not change");
                BOOL pad = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
                UIUserInterfaceSizeClass landscapeVertical = pad ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact;
                NSInteger expectedChanges = pad ? 0 : 1;
                charon_check(test.content.traitCollection.verticalSizeClass == landscapeVertical,
                             pad ? "an iPad keeps the vertical size class regular in landscape" : "landscape makes the vertical size class compact", traits_of(test.content));
                charon_check(test.content.traitChanges == expectedChanges, "the view hears about a change of its traits only when they change",
                             [NSString stringWithFormat:@"%ld changes", (long)test.content.traitChanges]);
                charon_check(test.host.traitChanges == expectedChanges, "the view controller hears about a change of its traits only when they change",
                             [NSString stringWithFormat:@"%ld changes", (long)test.host.traitChanges]);
                charon_check(pad ? test.content.previousTraits == nil : test.content.previousTraits.verticalSizeClass == UIUserInterfaceSizeClassRegular,
                             "the previous traits are the ones before the turn", [NSString stringWithFormat:@"%@", test.content.previousTraits]);
                [application setStatusBarOrientation:start animated:NO];
                after(0.5, ^{
                    charon_check(test.content.traitChanges == expectedChanges * 2, "turning back is announced as well", [NSString stringWithFormat:@"%ld changes", (long)test.content.traitChanges]);
                    charon_check(test.content.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular, "portrait makes the vertical size class regular again", traits_of(test.content));
                    [[NSNotificationCenter defaultCenter] removeObserver:observer];
                    done();
                });
            });
        } copy],
        [^(void (^done)(void)) {
            RecordingController *child = [[RecordingController alloc] init];
            [test.host addChildViewController:child];
            [test.host.view addSubview:child.view];
            [child didMoveToParentViewController:test.host];
            charon_check([traits_of(child) isEqualToString:traits_of(test.host)], "a child controller inherits the traits of its parent", traits_of(child));
            child.traitChanges = 0;
            UIUserInterfaceSizeClass inherited = test.host.traitCollection.horizontalSizeClass;
            UIUserInterfaceSizeClass overridden = inherited == UIUserInterfaceSizeClassRegular ? UIUserInterfaceSizeClassCompact : UIUserInterfaceSizeClassRegular;
            [test.host setOverrideTraitCollection:[UITraitCollection traitCollectionWithHorizontalSizeClass:overridden] forChildViewController:child];
            charon_check(child.traitCollection.horizontalSizeClass == overridden, "an override reaches the child", traits_of(child));
            charon_check(child.traitChanges == 1, "the child hears about the override", [NSString stringWithFormat:@"%ld changes", (long)child.traitChanges]);
            UITraitCollection *given = [UITraitCollection traitCollectionWithHorizontalSizeClass:overridden];
            [test.host setOverrideTraitCollection:given forChildViewController:child];
            charon_check(child.traitChanges == 1, "the same override again is not heard", [NSString stringWithFormat:@"%ld changes", (long)child.traitChanges]);
            charon_check([test.host overrideTraitCollectionForChildViewController:child] == given, "the override is answered as it was given", @"another object");
            charon_check([[[UIViewController alloc] init] overrideTraitCollectionForChildViewController:child] == nil && [test.host overrideTraitCollectionForChildViewController:nil] == nil,
                         "no other controller and no nil child has an override", @"one was answered");
            [test.host setOverrideTraitCollection:given forChildViewController:nil];
            charon_check(child.view.traitCollection.horizontalSizeClass == overridden, "the view of the child takes the override", traits_of(child.view));
            charon_check([[test.host overrideTraitCollectionForChildViewController:child] horizontalSizeClass] == overridden, "the override is kept", @"the override is gone");
            charon_check(test.content.traitCollection.horizontalSizeClass == inherited, "the override leaves the other views alone", traits_of(test.content));
            [test.host setOverrideTraitCollection:nil forChildViewController:child];
            charon_check(child.traitCollection.horizontalSizeClass == inherited, "clearing the override", traits_of(child));
            [child.view removeFromSuperview];
            [child removeFromParentViewController];
            NSString *raised = @"nothing";
            @try {
                [UITraitCollection traitCollectionWithTraitsFromCollections:@[[UITraitCollection traitCollectionWithDisplayScale:2], [NSNull null]]];
            } @catch (NSException *exception) {
                raised = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
            }
            CHECK_EQUAL(raised, @"NSInvalidArgumentException: Arguments to traitCollectionWithTraitsFromCollections: must all be of type UITraitCollection", "merging an object that is no trait collection raises");
            UIViewController *presented = [[UIViewController alloc] init];
            [test.host presentViewController:presented animated:NO completion:nil];
            charon_check([traits_of(presented) isEqualToString:traits_of(test.host)], "a presented controller takes the traits of its presenter", traits_of(presented));
            [test.host dismissViewControllerAnimated:NO completion:nil];
            UIViewController *adopted = [[UIViewController alloc] init];
            UITraitCollection *forAdopter = [UITraitCollection traitCollectionWithHorizontalSizeClass:test.host.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular ? UIUserInterfaceSizeClassCompact : UIUserInterfaceSizeClassRegular];
            RecordingController *adopter = [[RecordingController alloc] init];
            [test.host addChildViewController:adopter];
            [test.host.view addSubview:adopter.view];
            [adopter didMoveToParentViewController:test.host];
            [test.host setOverrideTraitCollection:forAdopter forChildViewController:adopter];
            [adopter.view addSubview:adopted.view];
            charon_check(adopted.traitCollection.horizontalSizeClass == forAdopter.horizontalSizeClass, "a controller whose view sits in another controller's takes that controller's traits", traits_of(adopted));
            [adopted.view removeFromSuperview];
            [adopter.view removeFromSuperview];
            [adopter removeFromParentViewController];
            done();
        } copy],
        [^(void (^done)(void)) {
            UIApplication *application = [UIApplication sharedApplication];
            UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
            action.identifier = @"reply";
            action.title = @"Reply";
            action.activationMode = UIUserNotificationActivationModeBackground;
            UIMutableUserNotificationCategory *category = [[UIMutableUserNotificationCategory alloc] init];
            category.identifier = @"message";
            [category setActions:@[action] forContext:UIUserNotificationActionContextDefault];
            UIUserNotificationType types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:[NSSet setWithObject:category]];
            test.registrations = 0;
            [application registerUserNotificationSettings:settings];
            after(1, ^{
                charon_check(test.registrations == 1, "the delegate hears about the registration once", [NSString stringWithFormat:@"%ld calls", (long)test.registrations]);
                UIUserNotificationSettings *granted = application.currentUserNotificationSettings;
                charon_check(granted != nil, "the application reports its notification settings", @"no settings");
                charon_check([test.registeredSettings isEqual:granted], "the delegate is handed the settings the application reports", [NSString stringWithFormat:@"%@", test.registeredSettings]);
                charon_check(granted.types == types || granted.types == (UIUserNotificationType)[application enabledRemoteNotificationTypes],
                             "iOS 6 grants the local notification types it was asked for", [NSString stringWithFormat:@"%lu, enabled %lu", (unsigned long)granted.types, (unsigned long)[application enabledRemoteNotificationTypes]]);
                charon_check(granted.categories.count == 0, "iOS 6 shows no notification actions, so no category is granted", [NSString stringWithFormat:@"%@", granted.categories]);
                UILocalNotification *notification = [[UILocalNotification alloc] init];
                notification.alertBody = @"Backported settings";
                notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:3600];
                [application scheduleLocalNotification:notification];
                charon_check(application.scheduledLocalNotifications.count > 0, "a local notification can be scheduled after registering", @"nothing was scheduled");
                [application cancelLocalNotification:notification];
                done();
            });
        } copy],
        [^(void (^done)(void)) {
            UIInterpolatingMotionEffect *horizontal = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
            horizontal.minimumRelativeValue = @(-20);
            horizontal.maximumRelativeValue = @20;
            UIInterpolatingMotionEffect *vertical = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
            vertical.minimumRelativeValue = @(-20);
            vertical.maximumRelativeValue = @20;
            UIMotionEffectGroup *group = [[UIMotionEffectGroup alloc] init];
            group.motionEffects = @[horizontal, vertical];
            [test.content addMotionEffect:group];
            charon_check(test.content.motionEffects.count == 1, "the view holds the motion effect group", @"the group is missing");
            CMMotionManager *manager = [[CMMotionManager alloc] init];
            BOOL gyroscope = manager.deviceMotionAvailable;
            __block NSInteger motions = 0;
            printf("info device motion available: %d\n", gyroscope);
            if (gyroscope) {
                manager.deviceMotionUpdateInterval = 1.0 / 30;
                [manager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
                    if (motion)
                        motions++;
                }];
            }
            after(2, ^{
                CAAnimation *animation = [test.content.layer animationForKey:@"charon.motionEffect.position.x"];
                [manager stopDeviceMotionUpdates];
                if (gyroscope && motions == 0)
                    printf("skip a device with a gyroscope applies the effect to the layer: CoreMotion reports a gyroscope but delivers no device motion in this environment, so the effect has nothing to follow\n");
                else if (gyroscope)
                    charon_check(animation != nil, "a device with a gyroscope applies the effect to the layer",
                                 [NSString stringWithFormat:@"no animation was applied for %ld device motions", (long)motions]);
                else
                    charon_check(animation == nil, "a device without a gyroscope applies no effect, as on iOS 7", @"an animation was applied");
                [test.content removeMotionEffect:group];
                charon_check(test.content.motionEffects.count == 0, "the effect can be removed", @"the effect is still there");
                after(1, ^{
                    done();
                });
            });
        } copy],
        [^(void (^done)(void)) {
            UIView *box = [[UIView alloc] initWithFrame:CGRectMake(20, 380, 40, 40)];
            box.backgroundColor = [UIColor blueColor];
            [test.host.view addSubview:box];
            CGPoint start = box.center;
            CGPoint target = CGPointMake(start.x + 200, start.y);
            __block NSInteger completions = 0;
            __block BOOL finishedFlag = NO;
            __block CGFloat furthest = start.x;
            [UIView animateWithDuration:0.8 delay:0 usingSpringWithDamping:0.35 initialSpringVelocity:0 options:0 animations:^{
                box.center = target;
            } completion:^(BOOL finished) {
                completions++;
                finishedFlag = finished;
            }];
            CAAnimation *animation = [box.layer animationForKey:@"position"];
            BOOL keyframed = [animation isKindOfClass:[CAKeyframeAnimation class]];
            NSUInteger frames = keyframed ? ((CAKeyframeAnimation *)animation).values.count : 0;
            charon_check(keyframed, "the spring is animated with key frames", NSStringFromClass([animation class]));
            charon_check(frames > 10, "the key frames follow the spring curve", [NSString stringWithFormat:@"%lu values", (unsigned long)frames]);
            for (int sample = 1; sample <= 16; sample++) {
                after(sample * 0.05, ^{
                    CGFloat position = [(CALayer *)box.layer.presentationLayer position].x;
                    furthest = MAX(furthest, position);
                });
            }
            after(1.2, ^{
                charon_check(completions == 1, "the completion runs once", [NSString stringWithFormat:@"%ld completions", (long)completions]);
                charon_check(finishedFlag, "the completion reports a finished animation", @"the animation was reported unfinished");
                charon_check(fabs(box.center.x - target.x) < 0.5, "the view ends where it was sent", [NSString stringWithFormat:@"%g", (double)box.center.x]);
                charon_check(furthest > target.x + 1, "a lightly damped spring overshoots its target", [NSString stringWithFormat:@"furthest %g, target %g", (double)furthest, (double)target.x]);
                charon_check([box.layer animationForKey:@"position"] == nil, "the animation is gone when it ends", @"an animation is still attached");
                __block NSInteger interrupted = 0;
                __block BOOL interruptedFlag = YES;
                [UIView animateWithDuration:0.8 delay:0 usingSpringWithDamping:0.35 initialSpringVelocity:0 options:0 animations:^{
                    box.center = start;
                } completion:^(BOOL finished) {
                    interrupted++;
                    interruptedFlag = finished;
                }];
                after(0.2, ^{
                    [UIView animateWithDuration:0.2 animations:^{
                        box.center = CGPointMake(start.x + 60, start.y);
                    }];
                    after(0.8, ^{
                        charon_check(interrupted == 1, "an interrupted spring completes once", [NSString stringWithFormat:@"%ld completions", (long)interrupted]);
                        charon_check(!interruptedFlag, "an interrupted spring reports an unfinished animation", @"the animation was reported finished");
                        CGPoint away = CGPointMake(start.x + 120, start.y);
                        box.center = start;
                        __block NSInteger delayed = 0;
                        [UIView animateWithDuration:0.5 delay:0.4 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0 animations:^{
                            box.center = away;
                        } completion:^(BOOL finished) {
                            delayed++;
                        }];
                        CAAnimation *waiting = [box.layer animationForKey:@"position"];
                        charon_check([waiting isKindOfClass:[CAKeyframeAnimation class]], "a delayed spring is animated with key frames as well", NSStringFromClass([waiting class]));
                        __block CGFloat duringTheDelay = away.x;
                        after(0.25, ^{
                            duringTheDelay = [(CALayer *)box.layer.presentationLayer position].x;
                        });
                        after(1.4, ^{
                            charon_check(fabs(duringTheDelay - start.x) < 12, "the spring waits for its delay", [NSString stringWithFormat:@"%g instead of %g", (double)duringTheDelay, (double)start.x]);
                            charon_check(delayed == 1, "the delayed spring completes once", [NSString stringWithFormat:@"%ld completions", (long)delayed]);
                            charon_check(fabs(box.center.x - away.x) < 0.5, "the delayed spring ends where it was sent", [NSString stringWithFormat:@"%g", (double)box.center.x]);
                            [box removeFromSuperview];
                            done();
                        });
                    });
                });
            });
        } copy],
        [^(void (^done)(void)) {
            UIApplication *application = [UIApplication sharedApplication];
            __block NSInteger handlers = 0;
            __block BOOL unknownOpened = YES;
            [application openURL:[NSURL URLWithString:@"charon-backports-nothing://test"] options:@{} completionHandler:^(BOOL success) {
                handlers++;
                unknownOpened = success;
            }];
            __block BOOL universalOpened = YES;
            [application openURL:[NSURL URLWithString:@"https://example.invalid/page"] options:@{UIApplicationOpenURLOptionUniversalLinksOnly: @YES} completionHandler:^(BOOL success) {
                handlers++;
                universalOpened = success;
            }];
            __block BOOL textOpened = YES, nilOpened = YES, handlerOnMain = NO;
            [application openURL:[NSURL URLWithString:@"charon-backports-nothing://test"] options:@{UIApplicationOpenURLOptionUniversalLinksOnly: @"YES"} completionHandler:^(BOOL success) {
                handlers++;
                textOpened = success;
                handlerOnMain = [NSThread isMainThread];
            }];
            [application openURL:nil options:@{} completionHandler:^(BOOL success) {
                handlers++;
                nilOpened = success;
            }];
            [application openURL:[NSURL URLWithString:@"charon-backports-nothing://test"] options:@{} completionHandler:nil];
            after(1, ^{
                charon_check(handlers == 4, "every openURL handler runs", [NSString stringWithFormat:@"%ld handlers", (long)handlers]);
                charon_check(!textOpened && !nilOpened, "a text where the option wants a number and a nil URL are reported as not opened", @"one was opened");
                charon_check(handlerOnMain, "the handler runs on the main thread", @"another thread");
                charon_check(!unknownOpened, "a scheme no application claims is reported as not opened", @"the URL was opened");
                charon_check(!universalOpened, "iOS 6 has no universal links, so a universal link only open fails", @"the URL was opened");
                done();
            });
        } copy],
        [^(void (^done)(void)) {
            UIImage *image = nil;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 10), NO, 0);
            [[UIColor redColor] setFill];
            UIRectFill(CGRectMake(0, 0, 10, 10));
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            charon_check(image.renderingMode == UIImageRenderingModeAutomatic, "a fresh image renders automatically", [NSString stringWithFormat:@"%ld", (long)image.renderingMode]);
            UIImage *template = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            charon_check(template.renderingMode == UIImageRenderingModeAlwaysTemplate, "the rendering mode is kept", [NSString stringWithFormat:@"%ld", (long)template.renderingMode]);
            charon_check(image.renderingMode == UIImageRenderingModeAutomatic, "the original image is left alone", @"the original changed");
            charon_check(CGSizeEqualToSize(template.size, image.size) && template.scale == image.scale, "the image itself is kept", NSStringFromCGSize(template.size));

            UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
            field.font = [UIFont systemFontOfSize:14];
            field.textColor = [UIColor redColor];
            field.textAlignment = NSTextAlignmentCenter;
            NSDictionary *attributes = field.defaultTextAttributes;
            charon_check([[attributes objectForKey:NSFontAttributeName] isEqual:field.font], "defaultTextAttributes carries the font", [NSString stringWithFormat:@"%@", attributes]);
            charon_check([[attributes objectForKey:NSForegroundColorAttributeName] isEqual:field.textColor], "defaultTextAttributes carries the colour", [NSString stringWithFormat:@"%@", attributes]);
            charon_check([[attributes objectForKey:NSParagraphStyleAttributeName] alignment] == NSTextAlignmentCenter, "defaultTextAttributes carries the alignment", [NSString stringWithFormat:@"%@", attributes]);
            field.defaultTextAttributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:20], NSForegroundColorAttributeName: [UIColor greenColor]};
            charon_check(field.font.pointSize == 20 && [field.textColor isEqual:[UIColor greenColor]], "setting defaultTextAttributes changes the field", [NSString stringWithFormat:@"%@ %@", field.font, field.textColor]);
            UITextField *fresh = [[UITextField alloc] init];
            NSParagraphStyle *freshParagraph = [fresh.defaultTextAttributes objectForKey:NSParagraphStyleAttributeName];
            charon_check(freshParagraph.lineBreakMode == NSLineBreakByTruncatingTail && freshParagraph.alignment == fresh.textAlignment, "the paragraph style of a new field truncates the tail and follows the alignment",
                         [NSString stringWithFormat:@"%ld %ld", (long)freshParagraph.lineBreakMode, (long)freshParagraph.alignment]);
            NSMutableParagraphStyle *head = [[NSMutableParagraphStyle alloc] init];
            head.alignment = NSTextAlignmentRight;
            head.lineBreakMode = NSLineBreakByTruncatingHead;
            field.defaultTextAttributes = @{NSParagraphStyleAttributeName: head, NSKernAttributeName: @2};
            NSParagraphStyle *keptParagraph = [field.defaultTextAttributes objectForKey:NSParagraphStyleAttributeName];
            charon_check(keptParagraph.lineBreakMode == NSLineBreakByTruncatingHead && field.textAlignment == NSTextAlignmentRight, "the paragraph style given is kept and its alignment applied",
                         [NSString stringWithFormat:@"%ld %ld", (long)keptParagraph.lineBreakMode, (long)field.textAlignment]);
            charon_check([[field.defaultTextAttributes objectForKey:NSKernAttributeName] isEqual:@2], "an attribute of another kind is kept", [NSString stringWithFormat:@"%@", field.defaultTextAttributes]);
            charon_check([field.font isEqual:fresh.font] && [field.textColor isEqual:fresh.textColor], "an attribute left out goes back to what a new field has", [NSString stringWithFormat:@"%@ %@", field.font, field.textColor]);
            field.defaultTextAttributes = @{};
            charon_check([field.font isEqual:fresh.font] && [field.textColor isEqual:fresh.textColor] && field.textAlignment == fresh.textAlignment && ![field.defaultTextAttributes objectForKey:NSKernAttributeName], "an empty dictionary puts a new field's settings back",
                         [NSString stringWithFormat:@"%@", field.defaultTextAttributes]);
            field.defaultTextAttributes = nil;
            charon_check([field.font isEqual:fresh.font], "nil is the same as an empty dictionary", [NSString stringWithFormat:@"%@", field.font]);

            charon_check(test.host.edgesForExtendedLayout == UIRectEdgeAll, "edgesForExtendedLayout starts as all edges", [NSString stringWithFormat:@"%lu", (unsigned long)test.host.edgesForExtendedLayout]);
            charon_check(!test.host.extendedLayoutIncludesOpaqueBars, "extendedLayoutIncludesOpaqueBars starts as NO", @"the default is YES");
            charon_check(test.host.automaticallyAdjustsScrollViewInsets, "automaticallyAdjustsScrollViewInsets starts as YES", @"the default is NO");
            test.host.edgesForExtendedLayout = UIRectEdgeNone;
            charon_check(test.host.edgesForExtendedLayout == UIRectEdgeNone, "edgesForExtendedLayout is kept", @"the value is not kept");
            UIViewController *content = [[UIViewController alloc] init];
            UINavigationController *bars = [[UINavigationController alloc] initWithRootViewController:content];
            bars.navigationBar.translucent = YES;
            [test.host addChildViewController:bars];
            bars.view.frame = CGRectMake(0, 0, 320, 440);
            [test.host.view addSubview:bars.view];
            [bars.view layoutIfNeeded];
            NSMutableArray *frames = [NSMutableArray array];
            [frames addObject:NSStringFromCGRect(content.view.frame)];
            content.edgesForExtendedLayout = UIRectEdgeNone;
            [bars.view setNeedsLayout];
            [bars.view layoutIfNeeded];
            [frames addObject:NSStringFromCGRect(content.view.frame)];
            content.edgesForExtendedLayout = UIRectEdgeAll;
            content.extendedLayoutIncludesOpaqueBars = YES;
            content.automaticallyAdjustsScrollViewInsets = NO;
            [bars.view setNeedsLayout];
            [bars.view layoutIfNeeded];
            [frames addObject:NSStringFromCGRect(content.view.frame)];
            charon_check([frames[0] isEqualToString:frames[1]] && [frames[1] isEqualToString:frames[2]], "none of the extended layout properties changes a controller's frame on iOS 6", [frames componentsJoinedByString:@" "]);
            [bars.view removeFromSuperview];
            [bars removeFromParentViewController];
            NSMutableData *coded = [NSMutableData data];
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:coded];
            UIViewController *written = [[UIViewController alloc] init];
            written.edgesForExtendedLayout = UIRectEdgeNone;
            written.extendedLayoutIncludesOpaqueBars = YES;
            written.automaticallyAdjustsScrollViewInsets = NO;
            [archiver encodeObject:written forKey:@"root"];
            [archiver finishEncoding];
            UIViewController *read = [[[NSKeyedUnarchiver alloc] initForReadingWithData:coded] decodeObjectForKey:@"root"];
            printf("info after archiving a controller, edges %lu, opaque bars %d, adjusts insets %d\n", (unsigned long)read.edgesForExtendedLayout, read.extendedLayoutIncludesOpaqueBars, read.automaticallyAdjustsScrollViewInsets);
            done();
        } copy],
        [^(void (^done)(void)) {
            UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
            UIColor *colour = [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1];
            bar.barTintColor = colour;
            charon_check([bar.barTintColor isEqual:colour], "the navigation bar keeps its bar tint colour", [NSString stringWithFormat:@"%@", bar.barTintColor]);
            charon_check([bar.tintColor isEqual:colour], "on iOS 6 the bar tint colour is the tint colour of the bar", [NSString stringWithFormat:@"%@", bar.tintColor]);
            bar.barTintColor = nil;
            charon_check(bar.barTintColor == nil && bar.tintColor == nil, "clearing the bar tint colour clears the tint colour of the bar", [NSString stringWithFormat:@"%@ %@", bar.barTintColor, bar.tintColor]);
            bar.barTintColor = colour;
            UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
            search.searchBarStyle = UISearchBarStyleMinimal;
            charon_check(search.searchBarStyle == UISearchBarStyleMinimal, "the search bar style is kept", @"the style is not kept");
            charon_check(search.backgroundImage != nil, "the minimal style takes the iOS 6 bar background away", @"the background is still drawn");
            search.searchBarStyle = (UISearchBarStyle)9;
            charon_check(search.searchBarStyle == UISearchBarStyleProminent, "a search bar style is kept to its three bits", [NSString stringWithFormat:@"%ld", (long)search.searchBarStyle]);
            search.searchBarStyle = (UISearchBarStyle)-1;
            charon_check((NSInteger)search.searchBarStyle == 7, "a negative search bar style is kept to its three bits", [NSString stringWithFormat:@"%ld", (long)search.searchBarStyle]);
            search.searchBarStyle = UISearchBarStyleMinimal;
            UIGraphicsBeginImageContext(CGSizeMake(2, 2));
            UIImage *indicator = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            UIGraphicsBeginImageContext(CGSizeMake(3, 3));
            UIImage *indicatorMask = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            bar.backIndicatorTransitionMaskImage = indicatorMask;
            charon_check(bar.backIndicatorImage == nil && bar.backIndicatorTransitionMaskImage == nil, "a back indicator mask alone answers neither image", @"one of them was answered");
            bar.backIndicatorImage = indicator;
            charon_check(bar.backIndicatorImage == indicator && bar.backIndicatorTransitionMaskImage == indicatorMask, "the back indicator images answer once both are given", @"the pair is not answered");
            bar.backIndicatorImage = nil;
            charon_check(bar.backIndicatorImage == nil && bar.backIndicatorTransitionMaskImage == nil, "clearing one back indicator image clears the answer of both", @"one of them was answered");
            bar.backIndicatorImage = indicator;
            charon_check(bar.backIndicatorTransitionMaskImage == indicatorMask, "the mask is kept while the image is gone", @"the mask was lost");

            RecordingView *parent = [[RecordingView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
            RecordingView *child = [[RecordingView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
            [parent addSubview:child];
            [test.host.view addSubview:parent];
            charon_check(child.tintColor != nil, "a view always has a tint colour", @"the tint colour is nil");
            parent.tintChanges = child.tintChanges = 0;
            parent.tintColor = [UIColor purpleColor];
            charon_check([child.tintColor isEqual:[UIColor purpleColor]], "the tint colour is inherited", [NSString stringWithFormat:@"%@", child.tintColor]);
            charon_check(child.tintChanges == 1 && parent.tintChanges == 1, "tintColorDidChange reaches the views below",
                         [NSString stringWithFormat:@"%ld %ld", (long)parent.tintChanges, (long)child.tintChanges]);
            parent.tintAdjustmentMode = UIViewTintAdjustmentModeDimmed;
            charon_check(child.tintAdjustmentMode == UIViewTintAdjustmentModeDimmed, "the adjustment mode is inherited", @"the mode is not inherited");
            CGFloat red = 0, green = 0, blue = 0, alpha = 0;
            [child.tintColor getRed:&red green:&green blue:&blue alpha:&alpha];
            charon_check(red == green && green == blue, "a dimmed tint colour is grey", [NSString stringWithFormat:@"%g %g %g", (double)red, (double)green, (double)blue]);
            [parent removeFromSuperview];

            UIFont *body = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            charon_check(body.pointSize == 17, "the body text style is 17 points", [NSString stringWithFormat:@"%g", (double)body.pointSize]);
            charon_check([body.familyName isEqualToString:[UIFont systemFontOfSize:17].familyName], "the body text style uses the iOS 6 system font", body.familyName);
            UIFont *headline = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
            charon_check([headline.fontName isEqualToString:[UIFont boldSystemFontOfSize:17].fontName], "the headline text style uses the bold system font", headline.fontName);
            charon_check([[UIFont preferredFontForTextStyle:UIFontTextStyleCaption2] pointSize] == 11, "the caption 2 text style is 11 points", @"the size differs");
            UIFont *light = [UIFont systemFontOfSize:15 weight:UIFontWeightLight];
            UIFont *bold = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            UIFont *regular = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            printf("info weights: light %s, regular %s, bold %s\n", light.fontName.UTF8String, regular.fontName.UTF8String, bold.fontName.UTF8String);
            charon_check([bold.fontName isEqualToString:[UIFont boldSystemFontOfSize:15].fontName], "a semibold weight maps to the iOS 6 bold system font", bold.fontName);
            charon_check([regular.fontName isEqualToString:[UIFont systemFontOfSize:15].fontName], "a medium weight maps to the iOS 6 system font", regular.fontName);
            charon_check([light.familyName isEqualToString:[UIFont systemFontOfSize:15].familyName], "a light weight stays in the system font family", light.familyName);
            charon_check(light.pointSize == 15 && bold.pointSize == 15, "the weighted fonts keep their size", @"the size differs");
            struct { const char *name; NSString *style; CGFloat size; } styles[] = {
                {"headline", UIFontTextStyleHeadline, 17}, {"subheadline", UIFontTextStyleSubheadline, 15}, {"body", UIFontTextStyleBody, 17},
                {"footnote", UIFontTextStyleFootnote, 13}, {"caption 1", UIFontTextStyleCaption1, 12}, {"caption 2", UIFontTextStyleCaption2, 11},
                {"callout", @"UICTFontTextStyleCallout", 16}, {"title 1", @"UICTFontTextStyleTitle1", 28}, {"title 2", @"UICTFontTextStyleTitle2", 22},
                {"title 3", @"UICTFontTextStyleTitle3", 20}, {"title 0", @"UICTFontTextStyleTitle0", 34},
            };
            for (size_t index = 0; index < sizeof styles / sizeof *styles; index++)
                charon_check([UIFont preferredFontForTextStyle:styles[index].style].pointSize == styles[index].size,
                             [[NSString stringWithFormat:@"the %s text style is %g points", styles[index].name, (double)styles[index].size] UTF8String], @"the size differs");
            charon_check([[UIFont preferredFontForTextStyle:@"not a style"] pointSize] == 12, "an unknown text style is 12 points", @"the size differs");
            charon_check([UIFont preferredFontForTextStyle:@""].pointSize == 12, "the empty text style is 12 points", @"the size differs");
            UIFont *nilStyle = [UIFont preferredFontForTextStyle:nil];
            charon_check(nilStyle == nil, "a nil text style answers nil", [NSString stringWithFormat:@"%@ %@", nilStyle, [UIDevice currentDevice].systemVersion]);
            charon_check([UIFontTextStyleHeadline isEqualToString:@"UICTFontTextStyleHeadline"] && [UIFontTextStyleSubheadline isEqualToString:@"UICTFontTextStyleSubhead"] &&
                         [UIFontTextStyleBody isEqualToString:@"UICTFontTextStyleBody"] && [UIFontTextStyleFootnote isEqualToString:@"UICTFontTextStyleFootnote"] &&
                         [UIFontTextStyleCaption1 isEqualToString:@"UICTFontTextStyleCaption1"] && [UIFontTextStyleCaption2 isEqualToString:@"UICTFontTextStyleCaption2"],
                         "the text style constants carry the release's own names", @"a name differs");
            UIFont *nearRegular = [UIFont systemFontOfSize:15 weight:-0.1];
            UIFont *nearLight = [UIFont systemFontOfSize:15 weight:-0.3];
            charon_check([nearRegular.fontName isEqualToString:[UIFont systemFontOfSize:15].fontName], "a weight just under regular stays regular", nearRegular.fontName);
            charon_check([nearLight.fontName isEqualToString:light.fontName], "a weight nearer light than regular is light", nearLight.fontName);
            charon_check([[UIFont systemFontOfSize:15 weight:UIFontWeightBlack].fontName isEqualToString:bold.fontName] && [[UIFont systemFontOfSize:15 weight:UIFontWeightUltraLight].fontName isEqualToString:light.fontName],
                         "the extreme weights take the nearest weight the release has", @"an extreme weight differs");
            charon_check(UIFontWeightUltraLight == -0.8f && UIFontWeightThin == -0.6f && UIFontWeightLight == -0.4f && UIFontWeightRegular == 0 && UIFontWeightMedium == 0.23f &&
                         UIFontWeightSemibold == 0.3f && UIFontWeightBold == 0.4f && UIFontWeightHeavy == 0.56f && UIFontWeightBlack == 0.62f, "the weight constants are the release's values", @"a value differs");

            CGFloat blueRed = 0, blueGreen = 0, blueBlue = 0, blueAlpha = 0;
            [[UIColor systemBlueColor] getRed:&blueRed green:&blueGreen blue:&blueBlue alpha:&blueAlpha];
            charon_check(fabs(blueRed) < 0.01 && fabs(blueGreen - 122 / 255.0) < 0.01 && fabs(blueBlue - 1) < 0.01, "systemBlueColor is the iOS 7 blue",
                         [NSString stringWithFormat:@"%g %g %g", (double)blueRed, (double)blueGreen, (double)blueBlue]);
            done();
        } copy],
        [^(void (^done)(void)) {
            struct { const char *name; int red, green, blue; } systems[] = {
                {"systemRedColor", 255, 59, 48}, {"systemGreenColor", 52, 199, 89}, {"systemBlueColor", 0, 122, 255},
                {"systemOrangeColor", 255, 149, 0}, {"systemYellowColor", 255, 204, 0}, {"systemPinkColor", 255, 45, 85},
                {"systemTealColor", 48, 176, 199}, {"systemGrayColor", 142, 142, 147}, {"systemPurpleColor", 175, 82, 222},
            };
            for (size_t index = 0; index < sizeof systems / sizeof *systems; index++) {
                SEL selector = sel_registerName(systems[index].name);
                UIColor *colour = [UIColor respondsToSelector:selector] ? ((id (*)(id, SEL))objc_msgSend)([UIColor class], selector) : nil;
                CGFloat red = -1, green = -1, blue = -1, alpha = -1;
                [colour getRed:&red green:&green blue:&blue alpha:&alpha];
                charon_check(fabs(red * 255 - systems[index].red) < 0.5 && fabs(green * 255 - systems[index].green) < 0.5 && fabs(blue * 255 - systems[index].blue) < 0.5 && alpha == 1,
                             NAMED(@"%s is %d %d %d", systems[index].name, systems[index].red, systems[index].green, systems[index].blue),
                             [NSString stringWithFormat:@"%g %g %g %g", (double)(red * 255), (double)(green * 255), (double)(blue * 255), (double)alpha]);
            }

            struct { const char *name; CGFloat red, green, blue, alpha, grey, dimmedAlpha; } dims[] = {
                {"red", 1, 0, 0, 1, 77 / 255.0, 0.8}, {"green", 0, 1, 0, 1, 150 / 255.0, 0.8}, {"blue", 0, 0, 1, 1, 28 / 255.0, 0.8}, {"half red", 1, 0, 0, 0.5, 77 / 255.0, 0.4},
            };
            for (size_t index = 0; index < sizeof dims / sizeof *dims; index++) {
                UIView *parent = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
                UIView *child = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
                [parent addSubview:child];
                parent.tintColor = [UIColor colorWithRed:dims[index].red green:dims[index].green blue:dims[index].blue alpha:dims[index].alpha];
                parent.tintAdjustmentMode = UIViewTintAdjustmentModeDimmed;
                CGFloat white = -1, alpha = -1;
                BOOL grey = [child.tintColor getWhite:&white alpha:&alpha];
                charon_check(grey && fabs(white - dims[index].grey) <= 1.5 / 255 && fabs(alpha - dims[index].dimmedAlpha) < 0.001,
                             NAMED(@"dimmed %s is the grey iOS 6 CoreGraphics matches it to, %g, at alpha %g", dims[index].name, (double)(dims[index].grey * 255), (double)dims[index].dimmedAlpha),
                             [NSString stringWithFormat:@"%d %g %g", grey, (double)white, (double)alpha]);
            }

            NSArray *speech = @[@"UIAccessibilitySpeechAttributePunctuation", @"UIAccessibilitySpeechAttributeLanguage", @"UIAccessibilitySpeechAttributePitch"];
            for (NSString *name in speech) {
                void *symbol = dlsym(RTLD_DEFAULT, name.UTF8String);
                Dl_info info;
                NSString *image = symbol && dladdr(symbol, &info) ? [[NSString stringWithUTF8String:info.dli_fname] lastPathComponent] : @"<none>";
                NSString *value = symbol ? *(__unsafe_unretained NSString **)symbol : nil;
                charon_check([value isEqualToString:name], NAMED(@"%@ is its own name", name), value ?: @"<nil>");
                printf("info %s comes from %s\n", name.UTF8String, image.UTF8String);
            }

            Class traits = [UITraitCollection class];
            SEL withStyle = sel_registerName("traitCollectionWithUserInterfaceStyle:");
            SEL style = sel_registerName("userInterfaceStyle");
            charon_check([traits respondsToSelector:withStyle] && [traits instancesRespondToSelector:style], "a trait collection has a user interface style", @"the methods are missing");
            if ([traits respondsToSelector:withStyle]) {
                UITraitCollection *dark = ((id (*)(id, SEL, NSInteger))objc_msgSend)(traits, withStyle, 2);
                UITraitCollection *light = ((id (*)(id, SEL, NSInteger))objc_msgSend)(traits, withStyle, 1);
                NSInteger (*read)(id, SEL) = (NSInteger (*)(id, SEL))objc_msgSend;
                CHECK_EQUAL(@(read(dark, style)), @2, "a collection made with the dark style answers dark");
                CHECK_EQUAL(@(read([UITraitCollection traitCollectionWithDisplayScale:2], style)), @0, "a collection without a style answers unspecified");
                UITraitCollection *merged = [UITraitCollection traitCollectionWithTraitsFromCollections:@[[UITraitCollection traitCollectionWithDisplayScale:2], dark]];
                charon_check(read(merged, style) == 2 && merged.displayScale == 2, "merging keeps the style and the other traits", merged.description);
                charon_check(![dark isEqual:light] && [dark isEqual:((id (*)(id, SEL, NSInteger))objc_msgSend)(traits, withStyle, 2)], "the style takes part in equality", dark.description);
                charon_check([merged containsTraitsInCollection:dark] && ![merged containsTraitsInCollection:light], "the style takes part in containment", merged.description);
                UITraitCollection *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:merged]];
                charon_check([decoded isEqual:merged] && read(decoded, style) == 2, "the style survives archiving", decoded.description);
                CHECK_EQUAL(@(read(test.host.view.window.traitCollection, style)), @1, "the window answers the light style");
            }
            done();
        } copy],
        [^(void (^done)(void)) {
            CLLocationManager *manager = [[CLLocationManager alloc] init];
            charon_check([manager respondsToSelector:@selector(requestWhenInUseAuthorization)], "requestWhenInUseAuthorization is installed on CLLocationManager", @"the method is missing");
            charon_check([manager respondsToSelector:@selector(requestAlwaysAuthorization)], "requestAlwaysAuthorization is installed on CLLocationManager", @"the method is missing");
            CHECK_EQUAL(image_of([CLLocationManager class], @selector(requestWhenInUseAuthorization)), @"libCoreLocationBackports.dylib",
                        "requestWhenInUseAuthorization comes from the CoreLocation backports");
            CHECK_EQUAL(image_of([CLLocationManager class], @selector(requestAlwaysAuthorization)), @"libCoreLocationBackports.dylib",
                        "requestAlwaysAuthorization comes from the CoreLocation backports");
            CHECK_EQUAL(image_of([UIView class], @selector(traitCollection)), @"libUIKitBackports.dylib", "the view traits come from the UIKit backports");
            printf("info location services enabled %d, authorization status %d\n", [CLLocationManager locationServicesEnabled], [CLLocationManager authorizationStatus]);
            [manager requestWhenInUseAuthorization];
            after(2, ^{
                charon_check(YES, "requesting authorization does not raise", @"");
                printf("info authorization status after the request: %d\n", [CLLocationManager authorizationStatus]);
                done();
            });
        } copy],
        [^(void (^done)(void)) {
            UIApplication *application = [UIApplication sharedApplication];
            UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
            UIView *mask = [[UIView alloc] initWithFrame:CGRectMake(5, 5, 10, 10)];
            charon_check(host.maskView == nil, "no mask view at first", @"a mask view is there");
            host.maskView = mask;
            charon_check(host.maskView == mask && host.layer.mask == mask.layer && host.subviews.count == 0, "the mask view is the layer's mask and no subview", @"the mask differs");
            host.maskView = nil;
            charon_check(host.layer.mask == nil, "no mask view, no mask", @"the mask stays");
            NSString *raised = nil;
            @try { host.maskView = host; } @catch (NSException *exception) { raised = exception.name; }
            charon_check([raised isEqualToString:NSInvalidArgumentException], "a view as its own mask raises", raised ?: @"nothing");
            __block BOOL inside = YES;
            [UIView performWithoutAnimation:^{ inside = [UIView areAnimationsEnabled]; }];
            charon_check(!inside && [UIView areAnimationsEnabled], "animations are off inside performWithoutAnimation and back after it", @"the setting differs");
            UIView *attributed = [[UIView alloc] init];
            charon_check(attributed.semanticContentAttribute == 0 && attributed.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionLeftToRight, "a new view is unspecified and left to right", @"the direction differs");
            attributed.semanticContentAttribute = (UISemanticContentAttribute)4;
            charon_check(attributed.semanticContentAttribute == 4 && attributed.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft, "force right to left is right to left", @"the direction differs");
            charon_check([UIView userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)1 relativeToLayoutDirection:UIUserInterfaceLayoutDirectionRightToLeft] == UIUserInterfaceLayoutDirectionLeftToRight &&
                         [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)0 relativeToLayoutDirection:UIUserInterfaceLayoutDirectionRightToLeft] == UIUserInterfaceLayoutDirectionRightToLeft,
                         "playback stays left to right and unspecified follows the application", @"the table differs");
            UIViewController *plain = [[UIViewController alloc] init];
            charon_check(plain.viewIfLoaded == nil && !plain.isViewLoaded, "viewIfLoaded does not load the view", @"the view loaded");
            [plain loadViewIfNeeded];
            charon_check(plain.isViewLoaded && plain.viewIfLoaded == plain.view, "loadViewIfNeeded loads the view", @"the view did not load");
            charon_check(CGSizeEqualToSize(plain.preferredContentSize, CGSizeZero), "the preferred content size starts at zero", NSStringFromCGSize(plain.preferredContentSize));
            plain.preferredContentSize = CGSizeMake(300, 400);
            charon_check(CGSizeEqualToSize(plain.preferredContentSize, CGSizeMake(300, 400)), "the preferred content size is kept", NSStringFromCGSize(plain.preferredContentSize));
            charon_check(plain.preferredStatusBarStyle == UIStatusBarStyleDefault && !plain.prefersStatusBarHidden && plain.preferredStatusBarUpdateAnimation == UIStatusBarAnimationFade &&
                         plain.childViewControllerForStatusBarStyle == nil && !plain.modalPresentationCapturesStatusBarAppearance, "the status bar preferences of a new controller", @"a preference differs");
            UIWindow *window = application.keyWindow;
            UIViewController *original = window.rootViewController;
            UIStatusBarStyle style = application.statusBarStyle;
            BOOL hidden = application.statusBarHidden;
            StatusProbe *probe = [[StatusProbe alloc] init];
            window.rootViewController = probe;
            [probe setNeedsStatusBarAppearanceUpdate];
            charon_check((application.statusBarStyle == UIStatusBarStyleBlackTranslucent || (application.statusBarStyle == UIStatusBarStyleBlackOpaque && [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)) && application.statusBarHidden, "the status bar takes the style and visibility of the controller in charge", [NSString stringWithFormat:@"%ld %d", (long)application.statusBarStyle, application.statusBarHidden]);
            UIViewController *child = [[UIViewController alloc] init];
            probe.child = child;
            [probe setNeedsStatusBarAppearanceUpdate];
            charon_check(application.statusBarStyle == UIStatusBarStyleDefault, "a controller that names a child for the style hands it over", [NSString stringWithFormat:@"%ld", (long)application.statusBarStyle]);
            window.rootViewController = original;
            [application setStatusBarStyle:style animated:NO];
            [application setStatusBarHidden:hidden withAnimation:UIStatusBarAnimationNone];
            done();
        } copy],
        [^(void (^done)(void)) {
            UIView *base = test.host.view;
            UIView *view = [[UIView alloc] initWithFrame:CGRectMake(10, 20, 100, 50)];
            view.backgroundColor = [UIColor redColor];
            UIView *blue = [[UIView alloc] initWithFrame:CGRectMake(50, 0, 50, 50)];
            blue.backgroundColor = [UIColor blueColor];
            [view addSubview:blue];
            [base addSubview:view];
            CGFloat scale = [UIScreen mainScreen].scale;
            UIView *snapshot = [view snapshotViewAfterScreenUpdates:YES];
            charon_check(snapshot != nil && CGRectEqualToRect(snapshot.frame, CGRectMake(0, 0, 100, 50)) && snapshot.subviews.count == 0, "a snapshot is a view the size of the rect with no subviews", NSStringFromCGRect(snapshot.frame));
            CGImageRef image = (__bridge CGImageRef)snapshot.layer.contents;
            charon_check(image != NULL && CGImageGetWidth(image) == (size_t)(100 * scale) && CGImageGetHeight(image) == (size_t)(50 * scale), "the snapshot holds the view at the screen's scale", image ? [NSString stringWithFormat:@"%zu x %zu", CGImageGetWidth(image), CGImageGetHeight(image)] : @"no image");
            charon_check(snapshot.layer.contentsScale == scale && [snapshot.layer.contentsGravity isEqualToString:kCAGravityResize] && CGRectEqualToRect(snapshot.layer.contentsCenter, CGRectMake(0, 0, 1, 1)), "the snapshot resizes, at the screen's scale, over its whole image", NSStringFromCGRect(snapshot.layer.contentsCenter));
            NSString *left = @"none", *right = @"none";
            if (image) {
                uint8_t data[4] = {0};
                CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
                CGContextRef context = CGBitmapContextCreate(data, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
                size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
                CGContextDrawImage(context, CGRectMake(-(double)(width / 4), -(double)(height / 2), width, height), image);
                left = [NSString stringWithFormat:@"%d,%d,%d,%d", data[0], data[1], data[2], data[3]];
                CGContextDrawImage(context, CGRectMake(-(double)(width * 3 / 4), -(double)(height / 2), width, height), image);
                right = [NSString stringWithFormat:@"%d,%d,%d,%d", data[0], data[1], data[2], data[3]];
                CGContextRelease(context);
                CGColorSpaceRelease(space);
            }
            charon_check([left isEqualToString:@"255,0,0,255"] && [right isEqualToString:@"0,0,255,255"], "the snapshot shows the view and its subviews", [NSString stringWithFormat:@"%@ %@", left, right]);
            UIView *capped = [view resizableSnapshotViewFromRect:CGRectMake(0, 0, 40, 40) afterScreenUpdates:YES withCapInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
            CGRect expected = CGRectMake((10 * scale + 1) / (40 * scale), (10 * scale + 1) / (40 * scale), (40 * scale - 20 * scale - 2) / (40 * scale), (40 * scale - 20 * scale - 2) / (40 * scale));
            charon_check(fabs(capped.layer.contentsCenter.origin.x - expected.origin.x) < 1e-6 && fabs(capped.layer.contentsCenter.size.width - expected.size.width) < 1e-6 && CGRectEqualToRect(capped.frame, CGRectMake(0, 0, 40, 40)), "cap insets stretch the middle, a pixel in from each edge", NSStringFromCGRect(capped.layer.contentsCenter));
            UIView *outside = [view resizableSnapshotViewFromRect:CGRectMake(-500, -500, 20, 20) afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
            UIView *empty = [view resizableSnapshotViewFromRect:CGRectNull afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
            charon_check(outside != nil && CGSizeEqualToSize(outside.frame.size, CGSizeMake(20, 20)) && empty != nil && CGSizeEqualToSize(empty.frame.size, CGSizeZero), "a rect outside the view or no rect at all still answers a view of that size", NSStringFromCGRect(outside.frame));

            UIGraphicsBeginImageContextWithOptions(CGSizeMake(100, 50), NO, 1);
            BOOL drew = [view drawViewHierarchyInRect:CGRectMake(0, 0, 100, 50) afterScreenUpdates:YES];
            UIImage *picture = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            uint8_t pixel[4] = {0};
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
            CGContextDrawImage(context, CGRectMake(-75, -25, 100, 50), picture.CGImage);
            charon_check(drew && pixel[0] == 0 && pixel[2] == 255 && pixel[3] == 255, "drawViewHierarchyInRect draws the view and its subviews", [NSString stringWithFormat:@"%d %d,%d,%d,%d", drew, pixel[0], pixel[1], pixel[2], pixel[3]]);
            view.alpha = 0.5;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(100, 50), NO, 1);
            [view drawViewHierarchyInRect:CGRectMake(0, 0, 100, 50) afterScreenUpdates:YES];
            picture = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            memset(pixel, 0, sizeof pixel);
            CGContextDrawImage(context, CGRectMake(-25, -25, 100, 50), picture.CGImage);
            charon_check(pixel[3] >= 126 && pixel[3] <= 130 && pixel[0] >= 126 && pixel[0] <= 130, "a view of half alpha is drawn at half alpha", [NSString stringWithFormat:@"%d,%d,%d,%d", pixel[0], pixel[1], pixel[2], pixel[3]]);
            view.alpha = 1;
            view.hidden = YES;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(100, 50), NO, 1);
            BOOL hiddenAnswer = [view drawViewHierarchyInRect:CGRectMake(0, 0, 100, 50) afterScreenUpdates:YES];
            picture = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            memset(pixel, 0, sizeof pixel);
            CGContextDrawImage(context, CGRectMake(-25, -25, 100, 50), picture.CGImage);
            charon_check(hiddenAnswer && pixel[3] == 0, "a hidden view draws nothing and still answers yes", [NSString stringWithFormat:@"%d %d", hiddenAnswer, pixel[3]]);
            view.hidden = NO;
            UIView *away = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(100, 50), NO, 1);
            BOOL awayAnswer = [away drawViewHierarchyInRect:CGRectMake(0, 0, 40, 40) afterScreenUpdates:NO];
            UIGraphicsEndImageContext();
            charon_check(!awayAnswer, "a view outside a window is not drawn and answers no", @"it answered yes");
            CGContextRelease(context);
            CGColorSpaceRelease(space);
            [view removeFromSuperview];
            done();
        } copy],
                [^(void (^done)(void)) {
            UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            UIVisualEffectView *view = [[UIVisualEffectView alloc] initWithEffect:blur];
            charon_check(view.effect == blur && view.contentView != nil && view.contentView.superview == view && view.contentView.autoresizingMask == (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight), "a visual effect view keeps its effect and has a content view that fills it", @"it does not");
            view.frame = CGRectMake(0, 0, 100, 50);
            charon_check(CGRectEqualToRect(view.contentView.frame, CGRectMake(0, 0, 100, 50)), "the content view follows the size of the view", NSStringFromCGRect(view.contentView.frame));
            NSString *raised = @"none";
            @try {
                [view addSubview:[[UIView alloc] init]];
            } @catch (NSException *exception) {
                raised = exception.name;
            }
            charon_check([raised isEqualToString:NSInternalInconsistencyException] && view.subviews.count == 1, "a subview added to the view itself is refused", raised);
            charon_check([blur isEqual:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]] && ![blur isEqual:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]] && [blur copy] == blur, "effects of one style are equal and a copy is the same object", @"they are not");
            UIVibrancyEffect *vibrancy = [UIVibrancyEffect effectForBlurEffect:blur];
            view.effect = vibrancy;
            charon_check(view.effect == vibrancy && [vibrancy isKindOfClass:[UIVisualEffect class]], "a vibrancy effect can be set", @"it cannot");
            done();
        } copy],
        [^(void (^done)(void)) {
            UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.text"] inMode:UIDocumentPickerModeImport];
            DocumentPickerRecorder *recorder = [[DocumentPickerRecorder alloc] init];
            picker.delegate = recorder;
            charon_check(picker.documentPickerMode == UIDocumentPickerModeImport && picker.delegate == recorder, "a document picker keeps its mode and its delegate", @"it does not");
            [test.host presentViewController:picker animated:NO completion:nil];
            after(0.5, ^{
                UINavigationController *browser = picker.childViewControllers.firstObject;
                UIBarButtonItem *cancel = browser.topViewController.navigationItem.rightBarButtonItem;
                charon_check(picker.presentingViewController == test.host && cancel != nil && cancel.target != nil, "a document picker is shown with a cancel button", @"it is not");
                [cancel.target performSelector:cancel.action withObject:cancel];
                after(1, ^{
                    charon_check(recorder.cancelled == 1 && recorder.dismissedWhenCancelled && test.host.presentedViewController == nil, "cancelling dismisses the picker and then tells the delegate", [NSString stringWithFormat:@"%d %d", recorder.cancelled, recorder.dismissedWhenCancelled]);
                    NSString *raised = @"none";
                    @try {
                        (void)[[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[] inMode:UIDocumentPickerModeExportToService];
                    } @catch (NSException *exception) {
                        raised = exception.name;
                    }
                    charon_check([raised isEqualToString:NSInternalInconsistencyException], "a document picker of the wrong mode is refused", raised);
                    done();
                });
            });
        } copy],
        [^(void (^done)(void)) {
            UITableViewRowAction *destructive = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction *action, NSIndexPath *path) {}];
            UITableViewRowAction *normal = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"More" handler:nil];
            charon_check(destructive.style == UITableViewRowActionStyleDestructive && [destructive.title isEqualToString:@"Delete"] && destructive.backgroundColor != nil && destructive.backgroundEffect == nil, "a row action keeps its style and title and has a colour", @"a field differs");
            CGFloat red = 0, green = 0, blue = 0, alpha = 0;
            [normal.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
            charon_check(normal.style == UITableViewRowActionStyleNormal && fabs(red - 0.78) < 0.01 && fabs(blue - 0.8) < 0.01, "a normal row action is grey", [NSString stringWithFormat:@"%g %g %g", (double)red, (double)green, (double)blue]);
            UITableViewRowAction *copy = [destructive copy];
            charon_check(copy != destructive && [copy.title isEqualToString:@"Delete"] && copy.style == destructive.style && [copy.backgroundColor isEqual:destructive.backgroundColor], "a copy is another action with the same fields", @"the copy differs");
            destructive.title = nil;
            destructive.backgroundColor = nil;
            charon_check(destructive.title == nil && destructive.backgroundColor == nil && [copy.title isEqualToString:@"Delete"], "the title and the colour clear on the action and not on its copy", @"a field differs");
            charon_check(![UITableViewRowAction conformsToProtocol:@protocol(NSSecureCoding)] && [UITableViewRowAction conformsToProtocol:@protocol(NSCopying)], "a row action is copied and not archived", @"the protocols differ");
            NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"com.charon.test"];
            UIView *responder = [[UIView alloc] init];
            charon_check(responder.userActivity == nil, "a responder has no activity at first", @"it has one");
            responder.userActivity = activity;
            [responder updateUserActivityState:activity];
            [responder restoreUserActivityState:activity];
            charon_check(responder.userActivity == activity, "a responder keeps the activity it was given and takes the two messages", @"it does not");
            responder.userActivity = nil;
            charon_check(responder.userActivity == nil, "and gives it up", @"it did not");
            UIKeyCommand *command = [UIKeyCommand keyCommandWithInput:@"a" modifierFlags:UIKeyModifierCommand action:@selector(description)];
            charon_check([command.input isEqualToString:@"a"] && command.modifierFlags == UIKeyModifierCommand && command.action == @selector(description) && command.discoverabilityTitle == nil, "a key command keeps its input, flags and action", @"it does not");
            UIKeyCommand *titled = [UIKeyCommand keyCommandWithInput:@"b" modifierFlags:0 action:@selector(description) discoverabilityTitle:@"Title"];
            charon_check([titled.discoverabilityTitle isEqualToString:@"Title"] && [command copy] != command && [[command copy] isEqual:command] && [command isEqual:[UIKeyCommand keyCommandWithInput:@"a" modifierFlags:UIKeyModifierCommand action:@selector(description)]], "a key command has a discoverability title, and a copy is another command that is equal", @"it does not");
            UIKeyCommand *bare = [[UIKeyCommand alloc] init];
            charon_check(bare.input == nil && [NSStringFromSelector(bare.action) isEqualToString:@"_nop"] && [[UIResponder new] keyCommands] == nil, "a key command made with init has no input, and a responder has no key commands", @"it has");
            charon_check([UIKeyInputUpArrow isEqualToString:@"UIKeyInputUpArrow"] && [UIKeyInputEscape isEqualToString:@"UIKeyInputEscape"] && [UIKeyInputPageDown isEqualToString:@"UIKeyInputPageDown"] && [UIApplicationOpenSettingsURLString isEqualToString:@"app-settings:"], "the key inputs and the settings URL are the system's", @"they differ");
            charon_check(!UIAccessibilityIsBoldTextEnabled() && !UIAccessibilityIsGrayscaleEnabled() && !UIAccessibilityIsReduceMotionEnabled() && !UIAccessibilityIsReduceTransparencyEnabled() && !UIAccessibilityDarkerSystemColorsEnabled() && !UIAccessibilityIsSpeakScreenEnabled() && !UIAccessibilityIsSpeakSelectionEnabled() && !UIAccessibilityIsSwitchControlRunning() && UIAccessibilityIsShakeToUndoEnabled() && UIAccessibilityFocusedElement(UIAccessibilityNotificationVoiceOverIdentifier) == nil, "the accessibility settings this release has none of are off, and shake to undo is on", @"they differ");
            charon_check([UIAccessibilityReduceMotionStatusDidChangeNotification isEqualToString:@"UIAccessibilityReduceMotionStatusDidChangeNotification"] && UIAccessibilityPauseAssistiveTechnologyNotification == 1033 && UIAccessibilityResumeAssistiveTechnologyNotification == 1034, "the notification names and numbers are the system's", @"they differ");
            UIAccessibilityCustomAction *customAction = [[UIAccessibilityCustomAction alloc] initWithName:@"n" target:test selector:@selector(description)];
            NSObject *element = [[NSObject alloc] init];
            charon_check([customAction.name isEqualToString:@"n"] && customAction.target == test && customAction.selector == @selector(description) && element.accessibilityCustomActions == nil && element.accessibilityElements == nil && element.accessibilityNavigationStyle == UIAccessibilityNavigationStyleAutomatic, "a custom action keeps its fields, and an element has none of them at first", @"it does not");
            element.accessibilityCustomActions = @[customAction];
            charon_check(element.accessibilityCustomActions.count == 1, "and keeps the actions it is given", @"it does not");
            UIApplicationShortcutItem *shortcut = [[UIApplicationShortcutItem alloc] initWithType:@"t" localizedTitle:@"L"];
            UIMutableApplicationShortcutItem *mutableShortcut = [shortcut mutableCopy];
            mutableShortcut.localizedTitle = @"M";
            charon_check([shortcut.type isEqualToString:@"t"] && [shortcut.localizedTitle isEqualToString:@"L"] && shortcut.localizedSubtitle == nil && shortcut.icon == nil && shortcut.userInfo == nil && [mutableShortcut isKindOfClass:[UIMutableApplicationShortcutItem class]] && [mutableShortcut.localizedTitle isEqualToString:@"M"] && ![[mutableShortcut copy] isKindOfClass:[UIMutableApplicationShortcutItem class]] && [shortcut copy] == shortcut, "a shortcut item keeps its fields, copies to itself, and copies to the mutable and the immutable kinds", @"it does not");
            charon_check([UIApplication sharedApplication].shortcutItems == nil, "an application has no shortcut items at first", @"it has");
            [UIApplication sharedApplication].shortcutItems = @[shortcut];
            charon_check([UIApplication sharedApplication].shortcutItems.count == 1, "and keeps those it is given", @"it does not");
            [UIApplication sharedApplication].shortcutItems = nil;
            UIBarButtonItem *groupItem = [[UIBarButtonItem alloc] initWithTitle:@"x" style:UIBarButtonItemStylePlain target:nil action:NULL];
            UIBarButtonItemGroup *group = [[UIBarButtonItemGroup alloc] initWithBarButtonItems:@[groupItem] representativeItem:nil];
            charon_check(group.barButtonItems.count == 1 && group.representativeItem == nil && !group.displayingRepresentativeItem && groupItem.buttonGroup == group, "a bar button group keeps its items and each item knows its group", @"it does not");
            UITextInputAssistantItem *assistant = [[UIResponder new] inputAssistantItem];
            assistant.leadingBarButtonGroups = @[group];
            charon_check(assistant.allowsHidingShortcuts && assistant.leadingBarButtonGroups.count == 1 && assistant.trailingBarButtonGroups.count == 0, "an assistant item allows hiding, and keeps the groups it is given", @"it does not");
            charon_check(NSClassFromString(@"UIFontDescriptor") == nil, "UIFontDescriptor is not carried", @"the class is there");
            done();
        } copy],
    ];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([UIKitTestDelegate class]));
    }
}
