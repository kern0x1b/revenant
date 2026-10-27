#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantAnimationDuration.h"

@interface UIView (RevenantInheritedAnimationDurationSwizzles)
+ (void)revenant_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations;
+ (void)revenant_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)revenant_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)revenant_beginAnimations:(NSString *)animationID context:(void *)context;
+ (void)revenant_setAnimationDuration:(NSTimeInterval)duration;
+ (void)revenant_commitAnimations;
@end

static void RevenantExchangeViewClassMethods(SEL original, SEL replacement)
{
    Method originalMethod = class_getClassMethod([UIView class], original);
    Method replacementMethod = class_getClassMethod([UIView class], replacement);
    if (originalMethod && replacementMethod)
        method_exchangeImplementations(originalMethod, replacementMethod);
}

@implementation UIView (RevenantInheritedAnimationDuration9)

+ (void)load
{
    RevenantExchangeViewClassMethods(@selector(animateWithDuration:animations:), @selector(revenant_animateWithDuration:animations:));
    RevenantExchangeViewClassMethods(@selector(animateWithDuration:animations:completion:), @selector(revenant_animateWithDuration:animations:completion:));
    RevenantExchangeViewClassMethods(@selector(animateWithDuration:delay:options:animations:completion:), @selector(revenant_animateWithDuration:delay:options:animations:completion:));
    RevenantExchangeViewClassMethods(@selector(beginAnimations:context:), @selector(revenant_beginAnimations:context:));
    RevenantExchangeViewClassMethods(@selector(setAnimationDuration:), @selector(revenant_setAnimationDuration:));
    RevenantExchangeViewClassMethods(@selector(commitAnimations), @selector(revenant_commitAnimations));
}

+ (NSTimeInterval)inheritedAnimationDuration
{
    return RevenantAnimationDurationInherited();
}

+ (void)revenant_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
    RevenantAnimationDurationPush(duration);
    @try {
        [self revenant_animateWithDuration:duration animations:animations];
    } @finally {
        RevenantAnimationDurationPop();
    }
}

+ (void)revenant_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    RevenantAnimationDurationPush(duration);
    @try {
        [self revenant_animateWithDuration:duration animations:animations completion:completion];
    } @finally {
        RevenantAnimationDurationPop();
    }
}

+ (void)revenant_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    RevenantAnimationDurationPush(duration);
    @try {
        [self revenant_animateWithDuration:duration delay:delay options:options animations:animations completion:completion];
    } @finally {
        RevenantAnimationDurationPop();
    }
}

+ (void)revenant_beginAnimations:(NSString *)animationID context:(void *)context
{
    RevenantAnimationDurationPush(RevenantAnimationDurationDefault);
    [self revenant_beginAnimations:animationID context:context];
}

+ (void)revenant_setAnimationDuration:(NSTimeInterval)duration
{
    RevenantAnimationDurationSetCurrent(duration);
    [self revenant_setAnimationDuration:duration];
}

+ (void)revenant_commitAnimations
{
    [self revenant_commitAnimations];
    RevenantAnimationDurationPop();
}

@end
