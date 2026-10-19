#import <UIKit/UIKit.h>

// An interaction that shows the app's tool tip while a pointer rests on its view. The state is the release's: the interaction is enabled
// by default, holds no default tip, has no delegate and no view until it is added to one. The release keeps the default tip object it is
// given (the header says copy; the host keeps the same object, measured in tests/backports/host/tooltip-interaction).
//
// The pointer is the part this device does not have. The 4S under 6.1.3 has no pointer, so the system never asks the delegate for a
// configuration, and nothing here calls it: the attach, the detach and the state an app reads are the whole of what happens on it.
//
// Declaring the delegate protocol in a function the image keeps (`used`) emits the protocol, so the release's name for it answers in
// this image. Nothing calls the function: it exists to keep the protocol's metadata in the object.
static Protocol *charon_toolTipDelegateProtocol(void) __attribute__((used));
static Protocol *charon_toolTipDelegateProtocol(void)
{
    return @protocol(UIToolTipInteractionDelegate);
}

@implementation UIToolTipInteraction {
@private
    __weak id<UIToolTipInteractionDelegate> _delegate;
    __weak UIView *_view;
    BOOL _enabled;
    NSString *_defaultToolTip;
}

- (instancetype)initWithDefaultToolTip:(NSString *)defaultToolTip
{
    if ((self = [super init])) {
        _enabled = YES;
        _defaultToolTip = defaultToolTip;
    }
    return self;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _enabled = YES;
    }
    return self;
}

- (id<UIToolTipInteractionDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIToolTipInteractionDelegate>)delegate
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

- (NSString *)defaultToolTip
{
    return _defaultToolTip;
}

- (void)setDefaultToolTip:(NSString *)defaultToolTip
{
    _defaultToolTip = defaultToolTip;
}

- (UIView *)view
{
    return _view;
}

// The view moves the interaction when it is added or removed; the interaction only keeps which view holds it.
- (void)willMoveToView:(UIView *)view
{
    _view = view;
}

- (void)didMoveToView:(UIView *)view
{
}

@end
