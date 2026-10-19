#import <UIKit/UIKit.h>
#import "RevenantFeedbackGenerator.h"
#import <objc/runtime.h>

static const char RevenantBoundViewKey;

@interface UIImpactFeedbackGenerator (RevenantLocation17Scaling)
- (void)revenant_impactScaledBy:(float)scale;
@end

@implementation UIFeedbackGenerator (RevenantLocation17)

- (instancetype)initWithBoundView:(UIView *)view
{
    self = [self init];
    if (self)
        objc_setAssociatedObject(self, &RevenantBoundViewKey, view, OBJC_ASSOCIATION_ASSIGN);
    return self;
}

- (UIView *)revenant_boundView
{
    return objc_getAssociatedObject(self, &RevenantBoundViewKey);
}

+ (instancetype)feedbackGeneratorForView:(UIView *)view
{
    return [[self alloc] initWithBoundView:view];
}

@end

@implementation UIImpactFeedbackGenerator (RevenantLocation17)

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

@implementation UISelectionFeedbackGenerator (RevenantLocation17)

- (void)selectionChangedAtLocation:(CGPoint)location
{
    (void)location;
    [self selectionChanged];
}

@end

@implementation UINotificationFeedbackGenerator (RevenantLocation17)

- (void)notificationOccurred:(UINotificationFeedbackType)type atLocation:(CGPoint)location
{
    (void)location;
    [self notificationOccurred:type];
}

@end
