#import "RevenantSafari.h"

extern SFSafariViewControllerPrewarmingToken *revenant_prewarmingToken(void);

static NSString *const RevenantMisuse = @"Misuse of SFSafariViewController interface. Use -initWithURL: or -initWithURL:configuration: instead.";
static NSString *const RevenantScheme = @"The specified URL has an unsupported scheme. Only HTTP and HTTPS URLs are supported.";

@implementation SFSafariViewController {
    NSURL *_initialURL;
    SFSafariViewControllerConfiguration *_configuration;
    RevenantSafariPage *_page;
}

+ (SFSafariViewControllerPrewarmingToken *)prewarmConnectionsToURLs:(NSArray<NSURL *> *)URLs
{
    return revenant_prewarmingToken();
}

+ (void)revenant_requireWebURL:(NSURL *)URL
{
    NSString *scheme = URL.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])
        [NSException raise:NSInvalidArgumentException format:@"%@", RevenantScheme];
}

- (instancetype)init
{
    [NSException raise:NSGenericException format:@"%@", RevenantMisuse];
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    [NSException raise:NSGenericException format:@"%@", RevenantMisuse];
    return nil;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
    [NSException raise:NSGenericException format:@"%@", RevenantMisuse];
    return nil;
}

- (instancetype)initWithURL:(NSURL *)URL
{
    return [self initWithURL:URL configuration:[[SFSafariViewControllerConfiguration alloc] init]];
}

- (instancetype)initWithURL:(NSURL *)URL entersReaderIfAvailable:(BOOL)entersReaderIfAvailable
{
    SFSafariViewControllerConfiguration *configuration = [[SFSafariViewControllerConfiguration alloc] init];
    configuration.entersReaderIfAvailable = entersReaderIfAvailable;
    return [self initWithURL:URL configuration:configuration];
}

- (instancetype)initWithURL:(NSURL *)URL configuration:(SFSafariViewControllerConfiguration *)configuration
{
    [SFSafariViewController revenant_requireWebURL:URL];
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _initialURL = [URL copy];
        _configuration = [configuration copy];
        _page = [[RevenantSafariPage alloc] initWithURL:URL];
        _page.owner = self;
        self.modalPresentationStyle = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? UIModalPresentationFormSheet : UIModalPresentationFullScreen;
    }
    return self;
}

- (NSURL *)initialURL
{
    return _initialURL;
}

- (SFSafariViewControllerConfiguration *)configuration
{
    return _configuration;
}

- (id<SFSafariViewControllerDelegate>)delegate
{
    return _page.delegate;
}

- (void)setDelegate:(id<SFSafariViewControllerDelegate>)delegate
{
    _page.delegate = delegate;
}

- (UIColor *)preferredBarTintColor
{
    return _page.preferredBarTintColor;
}

- (void)setPreferredBarTintColor:(UIColor *)color
{
    _page.preferredBarTintColor = color;
}

- (UIColor *)preferredControlTintColor
{
    return _page.preferredControlTintColor;
}

- (void)setPreferredControlTintColor:(UIColor *)color
{
    _page.preferredControlTintColor = color;
}

- (SFSafariViewControllerDismissButtonStyle)dismissButtonStyle
{
    return _page.dismissButtonStyle;
}

- (void)setDismissButtonStyle:(SFSafariViewControllerDismissButtonStyle)style
{
    _page.dismissButtonStyle = style;
}

- (void)loadView
{
    UIView *root = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = root;
    [self addChildViewController:_page];
    _page.view.frame = root.bounds;
    _page.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [root addSubview:_page.view];
    [_page didMoveToParentViewController:self];
}

@end
