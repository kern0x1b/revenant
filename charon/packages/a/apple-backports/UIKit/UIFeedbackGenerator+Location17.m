#import <UIKit/UIKit.h>
#import "CharonFeedbackGenerator.h"
#import <objc/runtime.h>

static const char CharonBoundViewKey;

@interface UIImpactFeedbackGenerator (CharonLocation17Scaling)
- (void)charon_impactScaledBy:(float)scale;
@end

@implementation UIFeedbackGenerator (CharonLocation17)

- (instancetype)initWithBoundView:(UIView *)view
{
    self = [self init];
    if (self)
        objc_setAssociatedObject(self, &CharonBoundViewKey, view, OBJC_ASSOCIATION_ASSIGN);
    return self;
}

- (UIView *)charon_boundView
{
    return objc_getAssociatedObject(self, &CharonBoundViewKey);
}

+ (instancetype)feedbackGeneratorForView:(UIView *)view
{
    return [[self alloc] initWithBoundView:view];
}

@end

@implementation UIImpactFeedbackGenerator (CharonLocation17)

+ (instancetype)feedbackGeneratorWithStyle:(UIImpactFeedbackStyle)style forView:(UIView *)view
{
    return [[self alloc] initWithStyle:style];
}

- (void)impactOccurredAtLocation:(CGPoint)location
{
    (void)location;
    [self impactOccurred];
}

- (void)impactOccurredWithIntensity:(CGFloat)intensity atLocation:(CGPoint)location
{
    (void)location;
    [self impactOccurredWithIntensity:intensity];
}

@end

@implementation UISelectionFeedbackGenerator (CharonLocation17)

- (void)selectionChangedAtLocation:(CGPoint)location
{
    (void)location;
    [self selectionChanged];
}

@end

@implementation UINotificationFeedbackGenerator (CharonLocation17)

- (void)notificationOccurred:(UINotificationFeedbackType)type atLocation:(CGPoint)location
{
    (void)location;
    [self notificationOccurred:type];
}

@end
