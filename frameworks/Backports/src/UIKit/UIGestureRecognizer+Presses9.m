#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIGestureRecognizer (RevenantPresses9)

- (void)ignorePress:(UIPress *)button forEvent:(UIPressesEvent *)event
{
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
}

- (void)pressesChanged:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
}

- (void)touchesEstimatedPropertiesUpdated:(NSSet<UITouch *> *)touches
{
}

@end

@implementation UIResponder (RevenantEstimatedTouches9)

- (void)touchesEstimatedPropertiesUpdated:(NSSet<UITouch *> *)touches
{
}

@end
