#import <UIKit/UIKit.h>

@implementation UIFocusUpdateContext

- (instancetype)init
{
    id focusSystem = nil;
    NSParameterAssert(focusSystem);
    return nil;
}

- (UIView *)previouslyFocusedView
{
    return nil;
}

- (UIView *)nextFocusedView
{
    return nil;
}

- (id<UIFocusItem>)previouslyFocusedItem
{
    return nil;
}

- (id<UIFocusItem>)nextFocusedItem
{
    return nil;
}

- (UIFocusHeading)focusHeading
{
    return UIFocusHeadingNone;
}

@end
