#import <RCTSwiftUIWrapper/RCTSwiftUIContainerViewWrapper.h>

@implementation RCTSwiftUIContainerViewWrapper {
  UIView *_hostingView;
  UIView *_contentView;
}

- (instancetype)init
{
  if (self = [super init]) {
    _hostingView = [UIView new];
  }
  return self;
}

- (UIView *_Nullable)contentView
{
  return _contentView;
}

- (UIView *_Nullable)hostingView
{
  return _hostingView;
}

- (void)updateContentView:(UIView *)view
{
  if (_contentView == view) {
    return;
  }
  [_contentView removeFromSuperview];
  _contentView = view;
  [_hostingView addSubview:view];
}

- (void)updateLayoutWithBounds:(CGRect)bounds
{
  _hostingView.frame = bounds;
  _contentView.frame = bounds;
}

- (void)resetStyles {}
- (void)updateBlurRadius:(NSNumber *)radius {}
- (void)updateGrayscale:(NSNumber *)grayscale {}
- (void)updateDropShadow:(NSNumber *)standardDeviation x:(NSNumber *)x y:(NSNumber *)y color:(UIColor *)color {}
- (void)updateSaturation:(NSNumber *)saturation {}
- (void)updateContrast:(NSNumber *)contrast {}
- (void)updateHueRotate:(NSNumber *)degrees {}

@end
