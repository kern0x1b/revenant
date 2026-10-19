#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface NSObject (DynamicsPrivate)
- (BOOL)charon_animatorStep:(double)dt;
- (void)_setAlwaysDisableDisplayLink:(BOOL)disable;
@end

static NSString *image_of(Class cls)
{
    Dl_info info;
    return cls && dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static void check_near(double actual, double expected, double tolerance, const char *name, NSString *what)
{
    charon_check(fabs(actual - expected) <= tolerance, name,
                 [NSString stringWithFormat:@"%@: %.9g, expected %.9g within %g", what, actual, expected, tolerance]);
}

static void check_classes(void)
{
    for (NSString *name in @[@"UIDynamicAnimator", @"UIDynamicBehavior", @"UIGravityBehavior", @"UICollisionBehavior",
                             @"UIPushBehavior", @"UISnapBehavior", @"UIAttachmentBehavior", @"UIDynamicItemBehavior"])
        CHECK_EQUAL(image_of(NSClassFromString(name)), @"libUIKitBackports.dylib",
                    [NSString stringWithFormat:@"%@ is the port's", name].UTF8String);
    CHECK([UIView conformsToProtocol:@protocol(UIDynamicItem)], "UIView adopts UIDynamicItem, as on 7.0");
}

static void check_integrator(void)
{
    const double predicted[5] = {50.1598701, 50.5752335, 51.2456779, 52.1707878, 53.3501625};
    UIDynamicAnimator *animator = [[UIDynamicAnimator alloc] init];
    [animator _setAlwaysDisableDisplayLink:YES];
    UIView *item = [[UIView alloc] initWithFrame:CGRectMake(100, 0, 100, 100)];
    [animator addBehavior:[[UIGravityBehavior alloc] initWithItems:@[item]]];
    for (int index = 0; index < 5; index++) {
        [animator charon_animatorStep:1.0 / 60.0];
        check_near(item.center.y, predicted[index], 1e-5, "T1c 7.0's integrator falls as w_sim7 predicts",
                   [NSString stringWithFormat:@"step %d", index]);
    }
}

static void check_cached_velocity(void)
{
    UIDynamicAnimator *animator = [[UIDynamicAnimator alloc] init];
    [animator _setAlwaysDisableDisplayLink:YES];
    UIView *item = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    UIDynamicItemBehavior *behavior = [[UIDynamicItemBehavior alloc] initWithItems:@[item]];
    [behavior addLinearVelocity:CGPointMake(30, 0) forItem:item];
    [behavior addLinearVelocity:CGPointMake(20, -10) forItem:item];
    [behavior addAngularVelocity:0.5 forItem:item];
    CHECK(CGPointEqualToPoint([behavior linearVelocityForItem:item], CGPointZero),
          "an unassociated behaviour answers no velocity");
    [animator addBehavior:behavior];
    CGPoint linear = [behavior linearVelocityForItem:item];
    check_near(linear.x, 50, 1e-4, "the cached linear velocities are summed and given at association", @"x");
    check_near(linear.y, -10, 1e-4, "the cached linear velocities are summed and given at association", @"y");
    check_near([behavior angularVelocityForItem:item], 0.5, 1e-4, "the cached angular velocity is given at association",
               @"angular");
}

static void check_layout_transform(void)
{
    NSIndexPath *path = [NSIndexPath indexPathForItem:0 inSection:0];
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:path];
    CGAffineTransform rotation = CGAffineTransformMakeRotation(0.3);
    attributes.transform = rotation;
    CHECK(CATransform3DEqualToTransform(attributes.transform3D, CATransform3DMakeAffineTransform(rotation)),
          "setting transform sets transform3D to its 3D form");
    CHECK(CGAffineTransformEqualToTransform(attributes.transform, rotation), "transform reads transform3D's affine part");
    attributes.transform3D = CATransform3DMakeRotation(0.4, 1, 0, 0);
    CHECK(CGAffineTransformIsIdentity(attributes.transform), "a transform3D that is not affine reads as the identity");
}

@interface CharonDynamicsDelegate : UIResponder <UIApplicationDelegate, UIDynamicAnimatorDelegate>
@end

@implementation CharonDynamicsDelegate {
    UIWindow *_window;
    UIDynamicAnimator *_animator;
    UIView *_item;
    int _resumed, _paused;
    CFAbsoluteTime _started;
}

- (void)dynamicAnimatorWillResume:(UIDynamicAnimator *)animator
{
    _resumed++;
}

- (void)dynamicAnimatorDidPause:(UIDynamicAnimator *)animator
{
    _paused++;
}

- (void)startLiveRun:(UIView *)reference
{
    _item = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetMidX(reference.bounds) - 20, 60, 40, 40)];
    _item.backgroundColor = [UIColor blueColor];
    [reference addSubview:_item];
    _animator = [[UIDynamicAnimator alloc] initWithReferenceView:reference];
    _animator.delegate = self;
    UICollisionBehavior *collision = [[UICollisionBehavior alloc] initWithItems:@[_item]];
    collision.translatesReferenceBoundsIntoBoundary = YES;
    [_animator addBehavior:[[UIGravityBehavior alloc] initWithItems:@[_item]]];
    [_animator addBehavior:collision];
    _started = CFAbsoluteTimeGetCurrent();
    CHECK(_animator.running, "an animator on a window runs once it has a body");
    CHECK(_resumed == 1, "dynamicAnimatorWillResume: comes when it starts");
    [self performSelector:@selector(watchLiveRun) withObject:nil afterDelay:0.25];
}

- (void)watchLiveRun
{
    if (_paused == 0 && CFAbsoluteTimeGetCurrent() - _started < 15) {
        [self performSelector:@selector(watchLiveRun) withObject:nil afterDelay:0.25];
        return;
    }
    CGFloat bottom = CGRectGetMaxY(_animator.referenceView.bounds);
    CHECK(_paused == 1, "the animator comes to rest and dynamicAnimatorDidPause: comes once");
    CHECK(!_animator.running, "a paused animator is not running");
    check_near(bottom - CGRectGetMaxY(_item.frame), 0, 0.5,
               "the item rests on the reference bounds' bottom (the port's value, not 7.0)",
               [NSString stringWithFormat:@"gap after %.2f s", CFAbsoluteTimeGetCurrent() - _started]);
    [self finish];
}

- (void)finish
{
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n",
                                                   charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"dynamics.done"]
              atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"dynamics.log"]);
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _window.backgroundColor = [UIColor whiteColor];
    _window.rootViewController = [[UIViewController alloc] init];
    [_window makeKeyAndVisible];
    @try {
        check_classes();
        check_integrator();
        check_cached_velocity();
        check_layout_transform();
        [self startLiveRun:_window.rootViewController.view];
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception",
                     [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
        [self finish];
    }
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder
                                  withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonDynamicsDelegate");
    }
}
