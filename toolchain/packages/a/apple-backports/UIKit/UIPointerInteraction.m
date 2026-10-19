#import "CharonPointer.h"

@implementation UIPointerInteraction {
@private
    __weak id<UIPointerInteractionDelegate> _delegate;
    __weak UIView *_view;
    BOOL _enabled;
}

- (instancetype)initWithDelegate:(id<UIPointerInteractionDelegate>)delegate
{
    if ((self = [super init])) {
        _delegate = delegate;
        _enabled = YES;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithDelegate:nil];
}

- (id<UIPointerInteractionDelegate>)delegate
{
    return _delegate;
}

- (UIView *)view
{
    return _view;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

- (void)invalidate
{
}

- (void)willMoveToView:(UIView *)view
{
}

- (void)didMoveToView:(UIView *)view
{
    _view = view;
    if (view)
        charon_menus_say_once(@"pointer-interaction", @"UIPointerInteraction: this release has no pointing device, so the interaction is attached and its delegate is never called");
}

@end
