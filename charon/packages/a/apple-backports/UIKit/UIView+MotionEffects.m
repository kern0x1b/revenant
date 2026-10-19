#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <math.h>

@interface UIMotionEffect (CharonViewMotionEffects)
+ (id)charon_sumOfRelativeValue:(id)first andRelativeValue:(id)second;
+ (id)charon_relativeValue:(id)value scaledBy:(CGFloat)factor;
@end

@interface UIView (CharonMotionEngine)
- (void)charon_applyMotionEffectsForViewerOffset:(UIOffset)offset duration:(NSTimeInterval)duration;
@end

static const NSTimeInterval charon_motion_interval = 1.0 / 30;
static const NSTimeInterval charon_motion_removal_duration = 0.25;
static const double charon_motion_full_tilt = 0.35;
static const double charon_motion_recentering = 2.0;
static NSString *const CharonMotionAnimationPrefix = @"charon.motionEffect.";

static char charon_effects_key;
static char charon_applied_key;

static NSHashTable *charon_motion_views;
static CMMotionManager *charon_motion_manager;
static BOOL charon_motion_running;
static NSTimeInterval charon_motion_timestamp;
static double charon_tilt_x;
static double charon_tilt_y;
static UIOffset charon_viewer_offset;

static NSString *charon_layer_key_path(NSString *keyPath)
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

static NSDictionary *charon_layer_values(UIView *view, UIOffset offset)
{
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (UIMotionEffect *effect in objc_getAssociatedObject(view, &charon_effects_key)) {
        if (![effect respondsToSelector:@selector(keyPathsAndRelativeValuesForViewerOffset:)])
            continue;
        NSDictionary *emitted = [effect keyPathsAndRelativeValuesForViewerOffset:offset];
        for (NSString *keyPath in emitted) {
            NSString *layerKeyPath = charon_layer_key_path(keyPath);
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
            id combined = existing ? [UIMotionEffect charon_sumOfRelativeValue:existing andRelativeValue:value] : value;
            if (combined)
                [values setObject:combined forKey:layerKeyPath];
        }
    }
    return values;
}

static UIInterfaceOrientation charon_motion_orientation(void)
{
    UIApplication *application = [UIApplication sharedApplication];
    return application ? application.statusBarOrientation : UIInterfaceOrientationPortrait;
}

static UIOffset charon_offset_from_tilt(double x, double y, UIInterfaceOrientation orientation)
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
    horizontal = MAX(-1, MIN(1, horizontal / charon_motion_full_tilt));
    vertical = MAX(-1, MIN(1, vertical / charon_motion_full_tilt));
    return UIOffsetMake((CGFloat)horizontal, (CGFloat)vertical);
}

static void charon_motion_update(CMDeviceMotion *motion)
{
    NSTimeInterval elapsed = charon_motion_timestamp ? motion.timestamp - charon_motion_timestamp : charon_motion_interval;
    charon_motion_timestamp = motion.timestamp;
    elapsed = MAX(0, MIN(elapsed, 0.1));
    CMRotationRate rate = motion.rotationRate;
    double leak = exp(-elapsed / charon_motion_recentering);
    charon_tilt_x = (charon_tilt_x + rate.x * elapsed) * leak;
    charon_tilt_y = (charon_tilt_y + rate.y * elapsed) * leak;
    charon_viewer_offset = charon_offset_from_tilt(charon_tilt_x, charon_tilt_y, charon_motion_orientation());
    for (UIView *view in charon_motion_views.allObjects) {
        if (view.window)
            [view charon_applyMotionEffectsForViewerOffset:charon_viewer_offset duration:charon_motion_interval];
    }
}

static void charon_motion_stop(void)
{
    if (!charon_motion_running)
        return;
    [charon_motion_manager stopDeviceMotionUpdates];
    charon_motion_running = NO;
    charon_motion_timestamp = 0;
    charon_tilt_x = 0;
    charon_tilt_y = 0;
    charon_viewer_offset = (UIOffset){0, 0};
    for (UIView *view in charon_motion_views.allObjects)
        [view charon_applyMotionEffectsForViewerOffset:(UIOffset){0, 0} duration:charon_motion_removal_duration];
}

static void charon_motion_refresh(void)
{
    UIApplication *application = [UIApplication sharedApplication];
    BOOL wanted = charon_motion_views.allObjects.count > 0 && (!application || application.applicationState != UIApplicationStateBackground);
    if (!wanted) {
        charon_motion_stop();
        return;
    }
    if (charon_motion_running)
        return;
    if (!charon_motion_manager) {
        Class manager = NSClassFromString(@"CMMotionManager");
        if (!manager && dlopen("/System/Library/Frameworks/CoreMotion.framework/CoreMotion", RTLD_LAZY))
            manager = NSClassFromString(@"CMMotionManager");
        charon_motion_manager = [[manager alloc] init];
    }
    if (!charon_motion_manager.deviceMotionAvailable)
        return;
    charon_motion_manager.deviceMotionUpdateInterval = charon_motion_interval;
    charon_motion_running = YES;
    [charon_motion_manager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
        if (motion && charon_motion_running)
            charon_motion_update(motion);
    }];
}

static void charon_motion_track(UIView *view)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        charon_motion_views = [NSHashTable weakObjectsHashTable];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
            charon_motion_stop();
        }];
        [center addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
            charon_motion_refresh();
        }];
    });
    if ([objc_getAssociatedObject(view, &charon_effects_key) count])
        [charon_motion_views addObject:view];
    else
        [charon_motion_views removeObject:view];
    if (charon_motion_running && view.window)
        [view charon_applyMotionEffectsForViewerOffset:charon_viewer_offset duration:charon_motion_removal_duration];
    charon_motion_refresh();
}

@implementation UIView (CharonMotionEffects)

- (NSArray *)motionEffects
{
    NSArray *effects = objc_getAssociatedObject(self, &charon_effects_key);
    return effects ? [effects copy] : [NSArray array];
}

- (void)setMotionEffects:(NSArray *)motionEffects
{
    NSMutableArray *effects = [NSMutableArray arrayWithCapacity:motionEffects.count];
    for (UIMotionEffect *effect in motionEffects) {
        if ([effects indexOfObjectIdenticalTo:effect] == NSNotFound)
            [effects addObject:effect];
    }
    objc_setAssociatedObject(self, &charon_effects_key, effects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_motion_track(self);
}

- (void)addMotionEffect:(UIMotionEffect *)effect
{
    if (!effect)
        return;
    NSMutableArray *effects = objc_getAssociatedObject(self, &charon_effects_key);
    if (effects && [effects indexOfObjectIdenticalTo:effect] != NSNotFound)
        return;
    if (!effects) {
        effects = [NSMutableArray array];
        objc_setAssociatedObject(self, &charon_effects_key, effects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [effects addObject:effect];
    charon_motion_track(self);
}

- (void)removeMotionEffect:(UIMotionEffect *)effect
{
    NSMutableArray *effects = objc_getAssociatedObject(self, &charon_effects_key);
    NSUInteger index = effects ? [effects indexOfObjectIdenticalTo:effect] : NSNotFound;
    if (index == NSNotFound)
        return;
    [effects removeObjectAtIndex:index];
    charon_motion_track(self);
}

- (void)charon_applyMotionEffectsForViewerOffset:(UIOffset)offset duration:(NSTimeInterval)duration
{
    NSDictionary *applied = objc_getAssociatedObject(self, &charon_applied_key);
    NSDictionary *values = charon_layer_values(self, offset);
    CALayer *layer = self.layer;
    NSMutableSet *keyPaths = [NSMutableSet setWithArray:applied.allKeys];
    [keyPaths addObjectsFromArray:values.allKeys];
    for (NSString *keyPath in keyPaths) {
        id from = [applied objectForKey:keyPath];
        id to = [values objectForKey:keyPath];
        if (!from)
            from = [UIMotionEffect charon_relativeValue:to scaledBy:0];
        BOOL removing = !to;
        if (removing)
            to = [UIMotionEffect charon_relativeValue:from scaledBy:0];
        NSString *key = [CharonMotionAnimationPrefix stringByAppendingString:keyPath];
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
    objc_setAssociatedObject(self, &charon_applied_key, values.count ? values : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
