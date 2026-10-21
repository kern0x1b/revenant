#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIScreen (RevenantFocus9)

- (BOOL)supportsFocus
{
    return NO;
}

- (UIView *)focusedView
{
    return nil;
}

- (id<UIFocusItem>)focusedItem
{
    return nil;
}

@end
