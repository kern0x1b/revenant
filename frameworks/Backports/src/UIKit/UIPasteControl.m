#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *revenant_paste_title(void)
{
    return [[NSBundle bundleForClass:[UIView class]] localizedStringForKey:@"Paste" value:@"Paste" table:nil];
}

@implementation UIPasteControl {
    UIPasteControlConfiguration *_configuration;
    __weak id<UIPasteConfigurationSupporting> _target;
    UIButton *_button;
}

- (instancetype)initWithConfiguration:(UIPasteControlConfiguration *)configuration
{
    if ((self = [super initWithFrame:CGRectMake(0, 0, 90, 32)])) {
        _configuration = configuration;
        [self revenant_build];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _configuration = [[UIPasteControlConfiguration alloc] init];
        [self revenant_build];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _configuration = [[UIPasteControlConfiguration alloc] init];
        [self revenant_build];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)revenant_build
{
    _button = [UIButton buttonWithType:UIButtonTypeCustom];
    _button.frame = self.bounds;
    _button.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _button.layer.masksToBounds = YES;
    [_button addTarget:self action:@selector(revenant_tapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_button];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(revenant_refresh) name:UIPasteboardChangedNotification object:nil];
    [self revenant_refresh];
}

- (UIPasteControlConfiguration *)configuration
{
    return _configuration;
}

- (id<UIPasteConfigurationSupporting>)target
{
    return _target;
}

- (void)setTarget:(id<UIPasteConfigurationSupporting>)target
{
    _target = target;
    [self revenant_refresh];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self revenant_refresh];
}

- (void)revenant_refresh
{
    UIPasteControlConfiguration *configuration = _configuration;
    UIColor *foreground = configuration.baseForegroundColor ?: [UIColor whiteColor];
    BOOL label = configuration.displayMode != UIPasteControlDisplayModeIconOnly;
    [_button setTitle:label ? revenant_paste_title() : nil forState:UIControlStateNormal];
    [_button setTitleColor:foreground forState:UIControlStateNormal];
    _button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    _button.backgroundColor = configuration.baseBackgroundColor ?: self.tintColor;
    _button.layer.cornerRadius = configuration.cornerRadius > 0 ? configuration.cornerRadius : self.bounds.size.height / 2;
    id<UIPasteConfigurationSupporting> target = _target;
    BOOL allowed = target && (![target respondsToSelector:@selector(canPasteItemProviders:)] || [target canPasteItemProviders:[UIPasteboard generalPasteboard].itemProviders ?: @[]]);
    _button.enabled = allowed;
    _button.alpha = allowed ? 1 : 0.4f;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _button.layer.cornerRadius = _configuration.cornerRadius > 0 ? _configuration.cornerRadius : self.bounds.size.height / 2;
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    [self revenant_refresh];
}

- (void)revenant_tapped
{
    id<UIPasteConfigurationSupporting> target = _target;
    NSArray<NSItemProvider *> *providers = [UIPasteboard generalPasteboard].itemProviders ?: @[];
    if (!target || ([target respondsToSelector:@selector(canPasteItemProviders:)] && ![target canPasteItemProviders:providers]))
        return;
    [target pasteItemProviders:providers];
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
}

@end
