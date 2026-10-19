#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char CharonKeyframesKey;
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

+ (void)performSystemAnimation:(UISystemAnimation)animation
                       onViews:(NSArray<__kindof UIView *> *)views
                       options:(UIViewAnimationOptions)options
                    animations:(void (^)(void))parallelAnimations
                    completion:(void (^)(BOOL finished))completion
{
    (void)animation;
    for (UIView *view in views)
        (void)view;
    if (parallelAnimations)
        parallelAnimations();
    if (completion)
        completion(YES);
}

+ (NSTimeInterval)inheritedAnimationDuration
{
    return 0;
}

@end

@implementation UIView (CharonFocusAndSafeArea9)

- (BOOL)canBecomeFocused
{
    return NO;
}

- (BOOL)isFocused
{
    return objc_getAssociatedObject(self, &CharonFocusedKey) != nil;
}

- (void)setFocused:(BOOL)focused
{
    objc_setAssociatedObject(self, &CharonFocusedKey, focused ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)safeAreaInsetsDidChange
{
}

@end
