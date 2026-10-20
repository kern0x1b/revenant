#import "RevenantMenus.h"

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
        revenant_menus_say_once(@"edit-menu", @"UIEditMenuInteraction: the interaction is attached; the menu is not shown and the delegate is never called in this build");
}

- (void)presentEditMenuWithConfiguration:(UIEditMenuConfiguration *)configuration
{
    revenant_menus_say_once(@"edit-menu-present", @"UIEditMenuInteraction: presentEditMenuWithConfiguration: shows no menu in this build");
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

- (CGPoint)locationInView:(UIView *)view
{
    return CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
}

@end
