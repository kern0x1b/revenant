#import "CharonMenus.h"

// UIEditMenuInteraction, iOS 16. An interaction the port carries so that an application which makes one, adds it to a view and asks for a
// menu runs, and whose menu the port does not show: the host's own UIKit, asked to present a menu programmatically in a bundled application
// with a window, never calls the delegate, so there is no menu of the release's to reproduce here (facts/UIKit/UIEditMenuInteraction.md).
// The class is made, added to a view and removed like any other interaction, keeps its delegate weakly, and answers the location the host
// answers while no menu is shown. Presenting, dismissing and updating the menu do nothing, and say so once in the log.
@implementation UIEditMenuInteraction {
@private
    __weak id<UIEditMenuInteractionDelegate> _delegate;
    __weak UIView *_view;
}

- (instancetype)initWithDelegate:(id<UIEditMenuInteractionDelegate>)delegate
{
    if ((self = [super init]))
        _delegate = delegate;
    return self;
}

- (id<UIEditMenuInteractionDelegate>)delegate
{
    return _delegate;
}

- (UIView *)view
{
    return _view;
}

- (void)willMoveToView:(UIView *)view
{
}

- (void)didMoveToView:(UIView *)view
{
    _view = view;
    if (view)
        charon_menus_say_once(@"edit-menu", @"UIEditMenuInteraction: the interaction is attached; the menu is not shown and the delegate is never called in this build");
}

- (void)presentEditMenuWithConfiguration:(UIEditMenuConfiguration *)configuration
{
    charon_menus_say_once(@"edit-menu-present", @"UIEditMenuInteraction: presentEditMenuWithConfiguration: shows no menu in this build");
}

- (void)dismissMenu
{
}

- (void)reloadVisibleMenu
{
}

- (void)updateVisibleMenuPositionAnimated:(BOOL)animated
{
}

// The location while no menu is shown: the host answers CGFLOAT_MAX on both axes (measured by tests/backports/host/edit-menu).
- (CGPoint)locationInView:(UIView *)view
{
    return CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
}

@end
