#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UITouch (RevenantForce9)

- (CGFloat)force
{
    return 0;
}

- (CGFloat)maximumPossibleForce
{
    return 0;
}

- (CGPoint)preciseLocationInView:(UIView *)view
{
    return [self locationInView:view];
}

- (CGPoint)precisePreviousLocationInView:(UIView *)view
{
    return [self previousLocationInView:view];
}

- (UITouchProperties)estimatedProperties
{
    return 0;
}

- (UITouchProperties)estimatedPropertiesExpectingUpdates
{
    return 0;
}

- (NSNumber *)estimationUpdateIndex
{
    return nil;
}

@end
