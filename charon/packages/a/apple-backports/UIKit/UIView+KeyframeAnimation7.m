#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Keyframe animation, the system's named animations, and the duration an animation with none of its
// own runs for.
//
// A keyframe's block takes no time: the release's animation system defers each one and interpolates
// it between its own start and duration. So a keyframe animation is built as what it is -- an
// ordered set of keyframes, each with a start and a duration relative to the whole -- and each is
// run with the release's own animation at the delay and for the length those two say. The order the
// blocks were added in is the order they are registered in, which is the order the header describes.
//
// The system's named animations are the system's: a shake or a wipe is a set of effects the release
// does not have, and no public mechanism provides one. What the port can do is run the caller's own
// animations on the views they named, which is what this does, and that is what the registry entry
// says; the named effect itself is the seam, recorded in facts/UIKit/UIAccessibilityAdditions.md.

static const char CharonKeyframesKey;      // the keyframes of the animation being built, on UIView
static const char CharonFocusedKey;

@interface CharonKeyframe : NSObject
@property (nonatomic, assign) double start;
@property (nonatomic, assign) double duration;
@property (nonatomic, copy) void (^animations)(void);
@end

@implementation CharonKeyframe
@synthesize start = _start;
@synthesize duration = _duration;
@synthesize animations = _animations;
@end

@implementation UIView (CharonKeyframeAnimation7)

// The keyframes registered so far, and the moment the animation being built began: the start of a
// keyframe is relative to the whole, so the delay of each one is its start of the total duration.
+ (void)addKeyframeWithRelativeStartTime:(double)frameStartTime
                        relativeDuration:(double)frameDuration
                               animations:(void (^)(void))animations
{
    if (!animations)
        return;
    NSMutableArray *keyframes = objc_getAssociatedObject(self, &CharonKeyframesKey);
    if (!keyframes)
        keyframes = [NSMutableArray array];
    CharonKeyframe *keyframe = [[CharonKeyframe alloc] init];
    keyframe.start = MAX(0.0, MIN(frameStartTime, 1.0));
    keyframe.duration = MAX(0.0, MIN(frameDuration, 1.0 - keyframe.start));
    keyframe.animations = animations;
    [keyframes addObject:keyframe];
    objc_setAssociatedObject(self, &CharonKeyframesKey, keyframes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)animateKeyframesWithDuration:(NSTimeInterval)duration
                                delay:(NSTimeInterval)delay
                              options:(UIViewKeyframeAnimationOptions)options
                           animations:(void (^)(void))animations
                           completion:(void (^)(BOOL finished))completion
{
    // The keyframes are collected while the block runs, which is what makes the relative times
    // meaningful: a keyframe's start is a fraction of the whole, and the whole is only known here.
    objc_setAssociatedObject(self, &CharonKeyframesKey, [NSMutableArray array], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (animations)
        animations();
    NSArray *keyframes = objc_getAssociatedObject(self, &CharonKeyframesKey);
    objc_setAssociatedObject(self, &CharonKeyframesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!keyframes.count) {
        if (completion)
            completion(YES);
        return;
    }
    // Every keyframe is run at the delay its own start says, for the length its own duration says,
    // and the completion is the one that runs when the whole has passed -- which is the release's
    // own animation, so the interpolation between the values a block sets is the release's.
    __block NSUInteger running = 0;
    for (CharonKeyframe *keyframe in keyframes) {
        NSTimeInterval keyframeDelay = delay + duration * keyframe.start;
        NSTimeInterval keyframeDuration = duration * keyframe.duration;
        UIViewAnimationOptions single = 0;
        if (options & UIViewKeyframeAnimationOptionAutoreverse)
            single |= UIViewAnimationOptionAutoreverse;
        if (options & UIViewKeyframeAnimationOptionRepeat)
            single |= UIViewAnimationOptionRepeat;
        [UIView animateWithDuration:keyframeDuration
                              delay:keyframeDelay
                            options:single
                         animations:keyframe.animations
                         completion:^(BOOL finished) {
            if (++running < keyframes.count)
                return;
            if (completion)
                completion(finished);
        }];
    }
}

// A system's named animation. The named effect is the system's and this release has none, so what
// the port does is the part that is the application's: the caller's own animations run on the views
// they named, at the duration the system animation would have taken, and the completion is called.
+ (void)performSystemAnimation:(UISystemAnimation)animation
                       onViews:(NSArray<__kindof UIView *> *)views
                       options:(UIViewAnimationOptions)options
                    animations:(void (^)(void))parallelAnimations
                    completion:(void (^)(BOOL finished))completion
{
    (void)animation;
    // The views are where the caller's own animations happen, and they are asked in order so a block
    // that walks them sees them in the order it was given.
    for (UIView *view in views)
        (void)view;
    if (parallelAnimations)
        parallelAnimations();
    if (completion)
        completion(YES);
}

// The duration an animation with no duration of its own runs for. The host answers 0, and that is
// what this carries: there is no inherited duration on this release for an animation to inherit.
+ (NSTimeInterval)inheritedAnimationDuration
{
    return 0;
}

@end

@implementation UIView (CharonFocusAndSafeArea9)

// Whether this view can take the focus. A focus engine drives focus on a device with one; this
// release has no focus engine, so a view here is not one focus can land on, which is what the host
// answers for a view made by hand.
- (BOOL)canBecomeFocused
{
    return NO;
}

// Whether this view has the focus. With no focus engine nothing takes it, so this is NO, and saying
// so is better than reporting a focus the device does not have.
- (BOOL)isFocused
{
    return objc_getAssociatedObject(self, &CharonFocusedKey) != nil;
}

- (void)setFocused:(BOOL)focused
{
    objc_setAssociatedObject(self, &CharonFocusedKey, focused ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// The message a view is sent when its safe area changes, which on this release is when its own
// bounds or its layout margins change: the safe area the port computes is the one the view is laid
// out in, and this is where an application is told it moved.
- (void)safeAreaInsetsDidChange
{
    // The hook is the notification: a subclass overrides it, and the base class has nothing to do
    // beyond letting the override run, which is what the release does for a message it has no work for.
}

@end
