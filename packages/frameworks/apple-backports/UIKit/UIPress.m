#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIPress

- (UIKey *)key
{
    return nil;
}

- (NSTimeInterval)timestamp
{
    return 0;
}

- (UIPressPhase)phase
{
    return UIPressPhaseBegan;
}

- (UIPressType)type
{
    return UIPressTypeUpArrow;
}

- (UIWindow *)window
{
    return nil;
}

- (UIResponder *)responder
{
    return nil;
}

- (NSArray<UIGestureRecognizer *> *)gestureRecognizers
{
    return nil;
}

- (CGFloat)force
{
    return 0;
}

@end

@implementation UIPressesEvent

- (UIEventType)type
{
    return UIEventTypePresses;
}

- (NSSet<UIPress *> *)allPresses
{
    return [NSSet set];
}

- (NSSet<UIPress *> *)pressesForGestureRecognizer:(UIGestureRecognizer *)gesture
{
    return [NSSet set];
}

@end

@implementation UIResponder (RevenantPresses)

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
    if (presses.count)
        [self.nextResponder pressesBegan:presses withEvent:event];
}

- (void)pressesChanged:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
    if (presses.count)
        [self.nextResponder pressesChanged:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
    if (presses.count)
        [self.nextResponder pressesEnded:presses withEvent:event];
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
    if (presses.count)
        [self.nextResponder pressesCancelled:presses withEvent:event];
}

@end
