#import <UIKit/UIKit.h>

static Protocol *revenant_toolTipDelegateProtocol(void) __attribute__((used));
static Protocol *revenant_toolTipDelegateProtocol(void)
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

- (void)willMoveToView:(UIView *)view
{
    _view = view;
}

- (void)didMoveToView:(UIView *)view
{
}

@end
