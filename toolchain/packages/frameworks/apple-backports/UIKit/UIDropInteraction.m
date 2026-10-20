#import <UIKit/UIKit.h>

@implementation UIDropInteraction {
    __weak id<UIDropInteractionDelegate> _delegate;
    __weak UIView *_view;
    BOOL _allowsSimultaneousDropSessions;
}

- (instancetype)initWithDelegate:(id<UIDropInteractionDelegate>)delegate
{
    self = [super init];
    if (self)
        _delegate = delegate;
    return self;
}

- (id<UIDropInteractionDelegate>)delegate
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
}

- (BOOL)allowsSimultaneousDropSessions
{
    return _allowsSimultaneousDropSessions;
}

- (void)setAllowsSimultaneousDropSessions:(BOOL)allows
{
    _allowsSimultaneousDropSessions = allows;
}

@end
