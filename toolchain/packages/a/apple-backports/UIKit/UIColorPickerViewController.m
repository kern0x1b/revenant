#import "RevenantMenus.h"

static const NSInteger RevenantGridColumns = 12;
static const NSInteger RevenantGridRows = 10;

static UIColor *revenant_grid_color(NSInteger column, NSInteger row)
{
    if (row == 0)
        return [UIColor colorWithWhite:1 - (CGFloat)column / (RevenantGridColumns - 1) alpha:1];
    CGFloat hue = (CGFloat)column / RevenantGridColumns;
    if (row <= 4)
        return [UIColor colorWithHue:hue saturation:row * 0.2f brightness:1 alpha:1];
    return [UIColor colorWithHue:hue saturation:1 brightness:1 - (row - 5) * 0.15f alpha:1];
}

@interface RevenantColorGrid : UIView
@property (nonatomic, copy) void (^picked)(UIColor *color, BOOL continuously);
@end

@implementation RevenantColorGrid {
@private
    void (^_picked)(UIColor *, BOOL);
}

@dynamic picked;

- (void (^)(UIColor *, BOOL))picked
{
    return _picked;
}

- (void)setPicked:(void (^)(UIColor *, BOOL))picked
{
    _picked = [picked copy];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGFloat width = CGRectGetWidth(self.bounds) / RevenantGridColumns, height = CGRectGetHeight(self.bounds) / RevenantGridRows;
    for (NSInteger row = 0; row < RevenantGridRows; row++) {
        for (NSInteger column = 0; column < RevenantGridColumns; column++) {
            CGContextSetFillColorWithColor(context, revenant_grid_color(column, row).CGColor);
            CGContextFillRect(context, CGRectMake(column * width, row * height, width, height));
        }
    }
}

- (void)pickAt:(CGPoint)point continuously:(BOOL)continuously
{
    NSInteger column = MAX(0, MIN(RevenantGridColumns - 1, (NSInteger)(point.x / (CGRectGetWidth(self.bounds) / RevenantGridColumns))));
    NSInteger row = MAX(0, MIN(RevenantGridRows - 1, (NSInteger)(point.y / (CGRectGetHeight(self.bounds) / RevenantGridRows))));
    if (_picked)
        _picked(revenant_grid_color(column, row), continuously);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self pickAt:[[touches anyObject] locationInView:self] continuously:YES];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self pickAt:[[touches anyObject] locationInView:self] continuously:YES];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self pickAt:[[touches anyObject] locationInView:self] continuously:NO];
}

@end

@interface RevenantColorRoot : UIView
@property (nonatomic, copy) void (^laidOut)(void);
@end

@implementation RevenantColorRoot {
@private
    void (^_laidOut)(void);
}

@dynamic laidOut;

- (void (^)(void))laidOut
{
    return _laidOut;
}

- (void)setLaidOut:(void (^)(void))laidOut
{
    _laidOut = [laidOut copy];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (_laidOut)
        _laidOut();
}

@end

@interface UIColorPickerViewController (RevenantPicker)
- (void)revenant_pickColor:(UIColor *)color continuously:(BOOL)continuously;
- (void)revenant_done;
- (void)revenant_finished;
- (void)revenant_dismissedOrForce:(UIViewController *)presenter;
@end

@implementation UIColorPickerViewController {
@private
    __weak id<UIColorPickerViewControllerDelegate> _delegate;
    UIColor *_selectedColor;
    BOOL _supportsAlpha;
    CGFloat _alpha;
    BOOL _finishing;
    UINavigationBar *_bar;
    RevenantColorGrid *_grid;
    UIView *_swatch;
    UISlider *_slider;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
@dynamic supportsEyedropper, maximumLinearExposure;
#endif

- (instancetype)init
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _selectedColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
        _supportsAlpha = YES;
        _alpha = 1;
        self.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self init];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self init];
}

- (id<UIColorPickerViewControllerDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIColorPickerViewControllerDelegate>)delegate
{
    _delegate = delegate;
}

- (UIColor *)selectedColor
{
    return _selectedColor;
}

- (void)setSelectedColor:(UIColor *)selectedColor
{
    if (!selectedColor)
        return;
    _selectedColor = selectedColor;
    CGFloat alpha = 1;
    if ([selectedColor getRed:NULL green:NULL blue:NULL alpha:&alpha] || [selectedColor getWhite:NULL alpha:&alpha])
        _alpha = alpha;
    [self revenant_refresh];
}

- (BOOL)supportsAlpha
{
    return _supportsAlpha;
}

- (void)setSupportsAlpha:(BOOL)supportsAlpha
{
    _supportsAlpha = supportsAlpha;
    [self revenant_refresh];
}

- (void)loadView
{
    RevenantColorRoot *view = [[RevenantColorRoot alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    __weak UIColorPickerViewController *weakSelf = self;
    view.laidOut = ^{
        [weakSelf revenant_layout];
    };
    view.backgroundColor = [UIColor whiteColor];
    _bar = [[UINavigationBar alloc] init];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:self.title ?: @"Colors"];
    item.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(revenant_done)];
    _bar.items = @[item];
    [view addSubview:_bar];
    _grid = [[RevenantColorGrid alloc] init];
    __weak UIColorPickerViewController *weak = self;
    _grid.picked = ^(UIColor *color, BOOL continuously) {
        [weak revenant_pickColor:color continuously:continuously];
    };
    [view addSubview:_grid];
    _swatch = [[UIView alloc] init];
    _swatch.layer.borderWidth = 1;
    _swatch.layer.borderColor = [UIColor lightGrayColor].CGColor;
    [view addSubview:_swatch];
    _slider = [[UISlider alloc] init];
    [_slider addTarget:self action:@selector(revenant_alphaChanged:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:_slider];
    self.view = view;
    [self revenant_layout];
    [self revenant_refresh];
}

- (void)revenant_layout
{
    CGRect bounds = self.view.bounds;
    _bar.frame = CGRectMake(0, 0, CGRectGetWidth(bounds), 44);
    CGFloat footer = 60;
    _grid.frame = CGRectMake(0, 44, CGRectGetWidth(bounds), MAX(0, CGRectGetHeight(bounds) - 44 - footer));
    _swatch.frame = CGRectMake(12, CGRectGetMaxY(_grid.frame) + 12, 36, 36);
    _slider.frame = CGRectMake(60, CGRectGetMaxY(_grid.frame) + 20, MAX(0, CGRectGetWidth(bounds) - 72), 24);
    [_grid setNeedsDisplay];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self revenant_layout];
}

- (void)revenant_refresh
{
    if (!self.isViewLoaded)
        return;
    _swatch.backgroundColor = _selectedColor;
    _slider.hidden = !_supportsAlpha;
    _slider.value = (float)_alpha;
}

- (void)revenant_alphaChanged:(UISlider *)slider
{
    _alpha = slider.value;
    UIColor *base = _selectedColor;
    CGFloat red = 0, green = 0, blue = 0, white = 0;
    if ([base getRed:&red green:&green blue:&blue alpha:NULL])
        [self revenant_pickColor:[UIColor colorWithRed:red green:green blue:blue alpha:1] continuously:slider.tracking];
    else if ([base getWhite:&white alpha:NULL])
        [self revenant_pickColor:[UIColor colorWithWhite:white alpha:1] continuously:slider.tracking];
}

- (void)revenant_pickColor:(UIColor *)color continuously:(BOOL)continuously
{
    _selectedColor = _supportsAlpha && _alpha < 1 ? [color colorWithAlphaComponent:_alpha] : color;
    [self revenant_refresh];
    id<UIColorPickerViewControllerDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(colorPickerViewController:didSelectColor:continuously:)])
        [delegate colorPickerViewController:self didSelectColor:_selectedColor continuously:continuously];
    else if (!continuously && [delegate respondsToSelector:@selector(colorPickerViewControllerDidSelectColor:)])
        [delegate colorPickerViewControllerDidSelectColor:self];
}

- (void)revenant_done
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(revenant_done) withObject:nil waitUntilDone:NO];
        return;
    }
    if (_finishing)
        return;
    _finishing = YES;
    UIViewController *root = self;
    while (!root.presentingViewController && root.parentViewController)
        root = root.parentViewController;
    UIViewController *presenter = root.presentingViewController;
    NSLog(@"UIColorPickerViewController: Done, presenter %@, delegate %@", presenter, _delegate);
    if (!presenter) {
        [self revenant_finished];
        return;
    }
    [presenter dismissViewControllerAnimated:YES completion:^{
        [self revenant_finished];
    }];
    [self performSelector:@selector(revenant_dismissedOrForce:) withObject:presenter afterDelay:1.0];
}

- (void)revenant_dismissedOrForce:(UIViewController *)presenter
{
    if (!_finishing)
        return;
    NSLog(@"UIColorPickerViewController: the dismissal did not finish, dismissing without animation");
    [presenter dismissViewControllerAnimated:NO completion:nil];
    [self revenant_finished];
}

- (void)revenant_finished
{
    if (!_finishing)
        return;
    _finishing = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(revenant_dismissedOrForce:) object:self.presentingViewController];
    id<UIColorPickerViewControllerDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(colorPickerViewControllerDidFinish:)])
        [delegate colorPickerViewControllerDidFinish:self];
}

@end
