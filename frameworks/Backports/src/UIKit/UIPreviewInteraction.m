#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIPreviewInteraction {
    __weak UIView *_view;
    __weak id<UIPreviewInteractionDelegate> _delegate;
}

- (instancetype)initWithView:(UIView *)view
{
    if ((self = [super init]))
        _view = view;
    return self;
}

- (UIView *)view
{
    return _view;
}

- (id<UIPreviewInteractionDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIPreviewInteractionDelegate>)delegate
{
    _delegate = delegate;
}

- (void)cancelInteraction
{
}

@end
