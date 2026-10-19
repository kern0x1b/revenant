#import "CharonMenus.h"

@interface UIColorWell (CharonWell) <UIColorPickerViewControllerDelegate>
- (void)charon_present;
@end

@implementation UIColorWell {
@private
    NSString *_title;
    BOOL _supportsAlpha;
    UIColor *_selectedColor;
    CALayer *_ring;
    CALayer *_fill;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
@dynamic supportsEyedropper, maximumLinearExposure;
#endif

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _supportsAlpha = YES;
        _ring = [CALayer layer];
        _ring.borderWidth = 2;
        _ring.borderColor = [UIColor lightGrayColor].CGColor;
        _fill = [CALayer layer];
        [self.layer addSublayer:_ring];
        [self.layer addSublayer:_fill];
        [self charon_refresh];
    }
    return self;
}

- (NSString *)title
{
    return _title;
}

- (void)setTitle:(NSString *)title
{
    _title = title;
}

- (BOOL)supportsAlpha
{
    return _supportsAlpha;
}

- (void)setSupportsAlpha:(BOOL)supportsAlpha
{
    _supportsAlpha = supportsAlpha;
}

- (UIColor *)selectedColor
{
    return _selectedColor;
}

- (void)setSelectedColor:(UIColor *)selectedColor
{
    _selectedColor = selectedColor;
    [self charon_refresh];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    return CGSizeMake(44, 44);
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(44, 44);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat side = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    CGRect ring = CGRectMake((CGRectGetWidth(bounds) - side) / 2, (CGRectGetHeight(bounds) - side) / 2, side, side);
    _ring.frame = ring;
    _ring.cornerRadius = side / 2;
    _fill.frame = CGRectInset(ring, 4, 4);
    _fill.cornerRadius = _fill.bounds.size.width / 2;
}

- (void)charon_refresh
{
    _fill.backgroundColor = (_selectedColor ?: [UIColor whiteColor]).CGColor;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    BOOL inside = touch && [self pointInside:[touch locationInView:self] withEvent:event];
    [super endTrackingWithTouch:touch withEvent:event];
    if (inside)
        [self charon_present];
}

- (void)charon_present
{
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:[UIViewController class]])
        responder = responder.nextResponder;
    UIViewController *top = (UIViewController *)responder;
    while (top.presentedViewController)
        top = top.presentedViewController;
    if (!top) {
        charon_menus_say_once(@"color-well-presenter", @"UIColorWell: the well is not in a view controller's view, so there is nothing to present the color picker from");
        return;
    }
    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    if (_selectedColor)
        picker.selectedColor = _selectedColor;
    picker.supportsAlpha = _supportsAlpha;
    picker.title = _title;
    picker.delegate = self;
    [top presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewController:(UIColorPickerViewController *)viewController didSelectColor:(UIColor *)color continuously:(BOOL)continuously
{
    self.selectedColor = color;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
