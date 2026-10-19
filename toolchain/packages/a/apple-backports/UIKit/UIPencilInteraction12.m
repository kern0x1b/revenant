#import "RevenantMenus.h"

@implementation UIPencilInteraction {
@private
    __weak id<UIPencilInteractionDelegate> _delegate;
    __weak UIView *_view;
    BOOL _enabled;
}

+ (UIPencilPreferredAction)preferredTapAction
{
    return UIPencilPreferredActionIgnore;
}

+ (BOOL)prefersPencilOnlyDrawing
{
    return NO;
}

- (instancetype)init
{
    if ((self = [super init]))
        _enabled = YES;
    return self;
}

- (id<UIPencilInteractionDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIPencilInteractionDelegate>)delegate
{
    _delegate = delegate;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
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
        revenant_menus_say_once(@"pencil", @"UIPencilInteraction: this release has no Apple Pencil, so the interaction is attached and its delegate is never called; preferredTapAction is UIPencilPreferredActionIgnore");
}

@end
