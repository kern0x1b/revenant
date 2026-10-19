#import <UIKit/UIKit.h>

// A focus update context describes one move of the focus, and the focus engine makes one for each move. iOS 6 has no
// focus engine, so no system code makes a context here. An application can still allocate one, and then every answer
// is the zero one: nil, or UIFocusHeadingNone for focusHeading, which is what the host answers for an allocated context
// as well. A plain init raises, as the host's does: its focus system is nil, and the release has none to give it. The
// assertion is the host's own macro, so its exception carries the host's name, reason and user info keys.
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
