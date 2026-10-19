#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <math.h>

@interface UIMotionEffect (RevenantViewMotionEffects)
+ (id)revenant_sumOfRelativeValue:(id)first andRelativeValue:(id)second;
+ (id)revenant_relativeValue:(id)value scaledBy:(CGFloat)factor;
@end

@interface UIView (RevenantMotionEngine)
- (void)revenant_applyMotionEffectsForViewerOffset:(UIOffset)offset duration:(NSTimeInterval)duration;
@end

static const NSTimeInterval revenant_motion_interval = 1.0 / 30;
static const NSTimeInterval revenant_motion_removal_duration = 0.25;
static const double revenant_motion_full_tilt = 0.35;
static const double revenant_motion_recentering = 2.0;
static NSString *const RevenantMotionAnimationPrefix = @"revenant.motionEffect.";

static char revenant_effects_key;
static char revenant_applied_key;

static NSHashTable *revenant_motion_views;
static CMMotionManager *revenant_motion_manager;
static BOOL revenant_motion_running;
static NSTimeInterval revenant_motion_timestamp;
static double revenant_tilt_x;
static double revenant_tilt_y;
static UIOffset revenant_viewer_offset;

static NSString *revenant_layer_key_path(NSString *keyPath)
{
    if ([keyPath isEqualToString:@"center"])
        return @"position";
    if ([keyPath hasPrefix:@"center."])
        return [@"position" stringByAppendingString:[keyPath substringFromIndex:6]];
    if ([keyPath hasPrefix:@"layer."])
        return [keyPath substringFromIndex:6];
    if ([keyPath isEqualToString:@"alpha"])
        return @"opacity";
    if ([keyPath isEqualToString:@"bounds"] || [keyPath hasPrefix:@"bounds."])
        return keyPath;
    return nil;
}

static NSDictionary *revenant_layer_values(UIView *view, UIOffset offset)
{
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (UIMotionEffect *effect in objc_getAssociatedObject(view, &revenant_effects_key)) {
        if (![effect respondsToSelector:@selector(keyPathsAndRelativeValuesForViewerOffset:)])
            continue;
        NSDictionary *emitted = [effect keyPathsAndRelativeValuesForViewerOffset:offset];
        for (NSString *keyPath in emitted) {
            NSString *layerKeyPath = revenant_layer_key_path(keyPath);
            if (!layerKeyPath) {
                static NSMutableSet *reported;
                if (!reported)
                    reported = [NSMutableSet set];
                if (![reported containsObject:keyPath]) {
                    [reported addObject:keyPath];
                    NSLog(@"UIMotionEffect: the key path %@ is not applied on iOS %@, which applies motion effects to center, alpha, bounds and layer key paths", keyPath, [UIDevice currentDevice].systemVersion);
                }
                continue;
            }
            id value = [emitted objectForKey:keyPath];
            id existing = [values objectForKey:layerKeyPath];
            id combined = existing ? [UIMotionEffect revenant_sumOfRelativeValue:existing andRelativeValue:value] : value;
            if (combined)
                [values setObject:combined forKey:layerKeyPath];
        }
    }
    return values;
}

static UIInterfaceOrientation revenant_motion_orientation(void)
{
    UIApplication *application = [UIApplication sharedApplication];
    return application ? application.statusBarOrientation : UIInterfaceOrientationPortrait;
}

static UIOffset revenant_offset_from_tilt(double x, double y, UIInterfaceOrientation orientation)
{
    double horizontal = y, vertical = x;
    switch (orientation) {
    case UIInterfaceOrientationPortraitUpsideDown:
        horizontal = -y;
        vertical = -x;
        break;
    case UIInterfaceOrientationLandscapeLeft:
        horizontal = -x;
        vertical = y;
        break;
    case UIInterfaceOrientationLandscapeRight:
        horizontal = x;
        vertical = -y;
        break;
    default:
        break;
    }
    horizontal = MAX(-1, MIN(1, horizontal / revenant_motion_full_tilt));
    vertical = MAX(-1, MIN(1, vertical / revenant_motion_full_tilt));
    return UIOffsetMake((CGFloat)horizontal, (CGFloat)vertical);
}

static void revenant_motion_update(CMDeviceMotion *motion)
{
    NSTimeInterval elapsed = revenant_motion_timestamp ? motion.timestamp - revenant_motion_timestamp : revenant_motion_interval;
    revenant_motion_timestamp = motion.timestamp;
    elapsed = MAX(0, MIN(elapsed, 0.1));
    CMRotationRate rate = motion.rotationRate;
    double leak = exp(-elapsed / revenant_motion_recentering);
    revenant_tilt_x = (revenant_tilt_x + rate.x * elapsed) * leak;
    revenant_tilt_y = (revenant_tilt_y + rate.y * elapsed) * leak;
    revenant_viewer_offset = revenant_offset_from_tilt(revenant_tilt_x, revenant_tilt_y, revenant_motion_orientation());
    for (UIView *view in revenant_motion_views.allObjects) {
        if (view.window)
            [view revenant_applyMotionEffectsForViewerOffset:revenant_viewer_offset duration:revenant_motion_interval];
    }
}

static void revenant_motion_stop(void)
{
    if (!revenant_motion_running)
        return;
    [revenant_motion_manager stopDeviceMotionUpdates];
    revenant_motion_running = NO;
    revenant_motion_timestamp = 0;
    revenant_tilt_x = 0;
    revenant_tilt_y = 0;
    revenant_viewer_offset = (UIOffset){0, 0};
    for (UIView *view in revenant_motion_views.allObjects)
        [view revenant_applyMotionEffectsForViewerOffset:(UIOffset){0, 0} duration:revenant_motion_removal_duration];
}

static void revenant_motion_refresh(void)
{
    UIApplication *application = [UIApplication sharedApplication];
    BOOL wanted = revenant_motion_views.allObjects.count > 0 && (!application || application.applicationState != UIApplicationStateBackground);
    if (!wanted) {
        revenant_motion_stop();
        return;
    }
    if (revenant_motion_running)
        return;
    if (!revenant_motion_manager) {
        Class manager = NSClassFromString(@"CMMotionManager");
        if (!manager && dlopen("/System/Library/Frameworks/CoreMotion.framework/CoreMotion", RTLD_LAZY))
            manager = NSClassFromString(@"CMMotionManager");
        revenant_motion_manager = [[manager alloc] init];
    }
    if (!revenant_motion_manager.deviceMotionAvailable)
        return;
    revenant_motion_manager.deviceMotionUpdateInterval = revenant_motion_interval;
    revenant_motion_running = YES;
    [revenant_motion_manager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
        if (motion && revenant_motion_running)
            revenant_motion_update(motion);
    }];
}

static void revenant_motion_track(UIView *view)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_motion_views = [NSHashTable weakObjectsHashTable];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
            revenant_motion_stop();
        }];
        [center addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
            revenant_motion_refresh();
        }];
    });
    if ([objc_getAssociatedObject(view, &revenant_effects_key) count])
        [revenant_motion_views addObject:view];
    else
        [revenant_motion_views removeObject:view];
    if (revenant_motion_running && view.window)
        [view revenant_applyMotionEffectsForViewerOffset:revenant_viewer_offset duration:revenant_motion_removal_duration];
    revenant_motion_refresh();
}

@implementation UIView (RevenantMotionEffects)

- (NSArray *)motionEffects
{
    NSArray *effects = objc_getAssociatedObject(self, &revenant_effects_key);
    return effects ? [effects copy] : [NSArray array];
}

- (void)setMotionEffects:(NSArray *)motionEffects
{
    NSMutableArray *effects = [NSMutableArray arrayWithCapacity:motionEffects.count];
    for (UIMotionEffect *effect in motionEffects) {
        if ([effects indexOfObjectIdenticalTo:effect] == NSNotFound)
            [effects addObject:effect];
    }
    objc_setAssociatedObject(self, &revenant_effects_key, effects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_motion_track(self);
}

- (void)addMotionEffect:(UIMotionEffect *)effect
{
    if (!effect)
        return;
    NSMutableArray *effects = objc_getAssociatedObject(self, &revenant_effects_key);
    if (effects && [effects indexOfObjectIdenticalTo:effect] != NSNotFound)
        return;
    if (!effects) {
        effects = [NSMutableArray array];
        objc_setAssociatedObject(self, &revenant_effects_key, effects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [effects addObject:effect];
    revenant_motion_track(self);
}

- (void)removeMotionEffect:(UIMotionEffect *)effect
{
    NSMutableArray *effects = objc_getAssociatedObject(self, &revenant_effects_key);
    NSUInteger index = effects ? [effects indexOfObjectIdenticalTo:effect] : NSNotFound;
    if (index == NSNotFound)
        return;
    [effects removeObjectAtIndex:index];
    revenant_motion_track(self);
}

- (void)revenant_applyMotionEffectsForViewerOffset:(UIOffset)offset duration:(NSTimeInterval)duration
{
    NSDictionary *applied = objc_getAssociatedObject(self, &revenant_applied_key);
    NSDictionary *values = revenant_layer_values(self, offset);
    CALayer *layer = self.layer;
    NSMutableSet *keyPaths = [NSMutableSet setWithArray:applied.allKeys];
    [keyPaths addObjectsFromArray:values.allKeys];
    for (NSString *keyPath in keyPaths) {
        id from = [applied objectForKey:keyPath];
        id to = [values objectForKey:keyPath];
        if (!from)
            from = [UIMotionEffect revenant_relativeValue:to scaledBy:0];
        BOOL removing = !to;
        if (removing)
            to = [UIMotionEffect revenant_relativeValue:from scaledBy:0];
        NSString *key = [RevenantMotionAnimationPrefix stringByAppendingString:keyPath];
        if (!from || !to) {
            [layer removeAnimationForKey:key];
            continue;
        }
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:keyPath];
        animation.additive = YES;
        animation.fromValue = from;
        animation.toValue = to;
        animation.duration = duration;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        animation.fillMode = removing ? kCAFillModeRemoved : kCAFillModeForwards;
        animation.removedOnCompletion = removing;
        [layer addAnimation:animation forKey:key];
    }
    objc_setAssociatedObject(self, &revenant_applied_key, values.count ? values : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
