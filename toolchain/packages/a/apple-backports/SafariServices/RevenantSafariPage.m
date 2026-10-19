#import "RevenantSafari.h"

enum {
    RevenantNavigationLinkClicked = 0,
    RevenantNavigationFormSubmitted = 1,
    RevenantNavigationBackForward = 2,
    RevenantNavigationReload = 3,
};

@implementation RevenantSafariPage {
    NSURL *_initialURL;
    id<RevenantWebView> _webView;
    UINavigationBar *_navigationBar;
    UINavigationItem *_barItem;
    UILabel *_addressLabel;
    UIProgressView *_progressView;
    UIToolbar *_toolbar;
    UIBarButtonItem *_backItem;
    UIBarButtonItem *_forwardItem;
    UIBarButtonItem *_actionItem;
    UIBarButtonItem *_reloadItem;
    UIBarButtonItem *_stopItem;
    UIPopoverController *_popover;
    NSURL *_currentURL;
    NSString *_pageTitle;
    BOOL _initialLoadPending;
    BOOL _showingError;
    BOOL _dismissing;
    NSTimer *_progressTimer;
}

@synthesize delegate = _delegate;
@synthesize owner = _owner;
@synthesize callbackMatcher = _callbackMatcher;
@synthesize callback = _callback;
@synthesize preferredBarTintColor = _preferredBarTintColor;
@synthesize preferredControlTintColor = _preferredControlTintColor;
@synthesize dismissButtonStyle = _dismissButtonStyle;

- (instancetype)initWithURL:(NSURL *)URL
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _initialURL = [URL copy];
        _currentURL = _initialURL;
        _initialLoadPending = YES;
    }
    return self;
}

- (NSURL *)initialURL
{
    return _initialURL;
}

- (SFSafariViewController *)revenant_sender
{
    return (SFSafariViewController *)(_owner ?: self);
}

- (void)dealloc
{
    [_progressTimer invalidate];
    [_webView setDelegate:nil];
    [_webView stopLoading];
}

- (void)setPreferredBarTintColor:(UIColor *)color
{
    _preferredBarTintColor = color;
    if (self.isViewLoaded)
        [self revenant_applyColors];
}

- (void)setPreferredControlTintColor:(UIColor *)color
{
    _preferredControlTintColor = color;
    if (self.isViewLoaded)
        [self revenant_applyColors];
}

- (void)setDismissButtonStyle:(SFSafariViewControllerDismissButtonStyle)style
{
    _dismissButtonStyle = style;
    if (self.isViewLoaded)
        [self revenant_applyDismissButton];
}

- (void)revenant_applyColors
{
    UIColor *bar = _preferredBarTintColor;
    _navigationBar.tintColor = bar;
    _toolbar.tintColor = bar;
    _progressView.progressTintColor = _preferredControlTintColor;
    for (UIBarButtonItem *item in @[_backItem, _forwardItem, _actionItem, _reloadItem, _stopItem, _barItem.leftBarButtonItem ?: (id)[NSNull null]])
        if ([item isKindOfClass:[UIBarButtonItem class]])
            item.tintColor = _preferredControlTintColor;
}

- (void)revenant_applyDismissButton
{
    UIBarButtonItem *button;
    switch (_dismissButtonStyle) {
    case SFSafariViewControllerDismissButtonStyleCancel:
        button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(revenant_done)];
        break;
    case SFSafariViewControllerDismissButtonStyleClose:
        button = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleForClass:[UIView class]] localizedStringForKey:@"Close" value:@"Close" table:nil]
                                                  style:UIBarButtonItemStyleBordered target:self action:@selector(revenant_done)];
        break;
    default:
        button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(revenant_done)];
        break;
    }
    button.tintColor = _preferredControlTintColor;
    [_barItem setLeftBarButtonItem:button animated:self.view.window != nil];
}

- (void)loadView
{
    CGRect bounds = [UIScreen mainScreen].applicationFrame;
    UIView *root = [[UIView alloc] initWithFrame:bounds];
    root.backgroundColor = [UIColor whiteColor];
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    _navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 44)];
    _navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _barItem = [[UINavigationItem alloc] initWithTitle:@""];
    _addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, MAX(120, bounds.size.width - 200), 30)];
    _addressLabel.backgroundColor = [UIColor clearColor];
    _addressLabel.textColor = [UIColor whiteColor];
    _addressLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
    _addressLabel.shadowOffset = CGSizeMake(0, -1);
    _addressLabel.font = [UIFont boldSystemFontOfSize:16];
    _addressLabel.textAlignment = NSTextAlignmentCenter;
    _addressLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _addressLabel.text = _initialURL.host;
    _barItem.titleView = _addressLabel;
    [_navigationBar pushNavigationItem:_barItem animated:NO];
    [root addSubview:_navigationBar];

    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, bounds.size.height - 44, bounds.size.width, 44)];
    _toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _backItem = [[UIBarButtonItem alloc] initWithTitle:@"◀" style:UIBarButtonItemStyleBordered target:self action:@selector(revenant_back)];
    _forwardItem = [[UIBarButtonItem alloc] initWithTitle:@"▶" style:UIBarButtonItemStyleBordered target:self action:@selector(revenant_forward)];
    _actionItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(revenant_action:)];
    _reloadItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(revenant_reload)];
    _stopItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(revenant_stop)];
    UIBarButtonItem *safari = [[UIBarButtonItem alloc] initWithTitle:@"Safari" style:UIBarButtonItemStyleBordered target:self action:@selector(revenant_openInBrowser)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    _toolbar.items = @[_backItem, space, _forwardItem, space, _actionItem, space, safari, space, _reloadItem];
    [root addSubview:_toolbar];

    _webView = (id<RevenantWebView>)[[NSClassFromString(@"UIWebView") alloc] initWithFrame:CGRectMake(0, 44, bounds.size.width, bounds.size.height - 88)];
    [(UIView *)_webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    _webView.scalesPageToFit = YES;
    _webView.delegate = self;
    [root insertSubview:(UIView *)_webView atIndex:0];

    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    _progressView.frame = CGRectMake(0, 44, bounds.size.width, 3);
    _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _progressView.hidden = YES;
    [root addSubview:_progressView];

    self.view = root;
    [self revenant_applyColors];
    [self revenant_applyDismissButton];
    [self revenant_updateButtons];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat top = 0;
    if ([self respondsToSelector:@selector(topLayoutGuide)])
        top = [[(id)self topLayoutGuide] length];
    CGRect bounds = self.view.bounds;
    _navigationBar.frame = CGRectMake(0, top, bounds.size.width, 44);
    [(UIView *)_webView setFrame:CGRectMake(0, top + 44, bounds.size.width, bounds.size.height - top - 88)];
    _progressView.frame = CGRectMake(0, top + 44, bounds.size.width, 3);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [_webView loadRequest:[NSURLRequest requestWithURL:_initialURL]];
}

- (void)revenant_updateButtons
{
    _backItem.enabled = _webView.canGoBack;
    _forwardItem.enabled = _webView.canGoForward;
    _actionItem.enabled = _currentURL != nil;
    NSMutableArray *items = [_toolbar.items mutableCopy];
    NSUInteger last = items.count - 1;
    UIBarButtonItem *wanted = _webView.loading ? _stopItem : _reloadItem;
    if (items[last] != wanted) {
        items[last] = wanted;
        [_toolbar setItems:items animated:NO];
    }
}

- (void)revenant_back
{
    [_webView goBack];
}

- (void)revenant_forward
{
    [_webView goForward];
}

- (void)revenant_reload
{
    if (_showingError) {
        _showingError = NO;
        [_webView loadRequest:[NSURLRequest requestWithURL:_currentURL]];
    } else
        [_webView reload];
}

- (void)revenant_stop
{
    [_webView stopLoading];
    [self revenant_finishProgress];
    [self revenant_updateButtons];
}

- (void)revenant_done
{
    if (_dismissing)
        return;
    _dismissing = YES;
    void (^finished)(void) = ^{
        self->_dismissing = NO;
        id<SFSafariViewControllerDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(safariViewControllerDidFinish:)])
            [delegate safariViewControllerDidFinish:[self revenant_sender]];
    };
    UIViewController *target = _owner ?: self;
    if (target.presentingViewController)
        [target.presentingViewController dismissViewControllerAnimated:YES completion:finished];
    else if (target.navigationController && target.navigationController.topViewController == target) {
        [target.navigationController popViewControllerAnimated:YES];
        finished();
    } else
        finished();
}

- (void)revenant_openInBrowser
{
    id<SFSafariViewControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(safariViewControllerWillOpenInBrowser:)])
        [delegate safariViewControllerWillOpenInBrowser:[self revenant_sender]];
    if (_currentURL)
        [[UIApplication sharedApplication] openURL:_currentURL];
}

- (void)revenant_action:(UIBarButtonItem *)sender
{
    if (!_currentURL)
        return;
    id<SFSafariViewControllerDelegate> delegate = self.delegate;
    NSArray *activities = nil, *excluded = nil;
    NSString *title = _pageTitle.length ? _pageTitle : nil;
    if ([delegate respondsToSelector:@selector(safariViewController:activityItemsForURL:title:)])
        activities = [delegate safariViewController:[self revenant_sender] activityItemsForURL:_currentURL title:title];
    if ([delegate respondsToSelector:@selector(safariViewController:excludedActivityTypesForURL:title:)])
        excluded = [delegate safariViewController:[self revenant_sender] excludedActivityTypesForURL:_currentURL title:title];
    Class activityViewController = NSClassFromString(@"UIActivityViewController");
    if (!activityViewController) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"the share sheet is not shown: this release has no UIActivityViewController, and the delegate protocol has no message for a share sheet that could not open");
        });
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            [_popover dismissPopoverAnimated:NO];
        return;
    }
    UIActivityViewController *sheet = [[activityViewController alloc] initWithActivityItems:@[_currentURL] applicationActivities:activities];
    if (excluded.count)
        sheet.excludedActivityTypes = excluded;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [_popover dismissPopoverAnimated:NO];
        _popover = [[UIPopoverController alloc] initWithContentViewController:sheet];
        [_popover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
    } else
        [_owner ?: self presentViewController:sheet animated:YES completion:nil];
}

- (void)revenant_startProgress
{
    [_progressTimer invalidate];
    _progressView.hidden = NO;
    _progressView.progress = 0.1;
    _progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(revenant_tickProgress) userInfo:nil repeats:YES];
}

- (void)revenant_tickProgress
{
    float progress = _progressView.progress;
    _progressView.progress = progress + (0.9f - progress) * 0.08f;
}

- (void)revenant_finishProgress
{
    [_progressTimer invalidate];
    _progressTimer = nil;
    _progressView.progress = 1;
    _progressView.hidden = YES;
}

- (void)revenant_completeInitialLoad:(BOOL)success
{
    if (!_initialLoadPending)
        return;
    _initialLoadPending = NO;
    id<SFSafariViewControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(safariViewController:didCompleteInitialLoad:)])
        [delegate safariViewController:[self revenant_sender] didCompleteInitialLoad:success];
}

- (BOOL)webView:(id<RevenantWebView>)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)type
{
    NSURL *URL = request.URL;
    BOOL mainFrame = [request.mainDocumentURL isEqual:URL];
    if (self.callbackMatcher && self.callbackMatcher(URL)) {
        [_webView stopLoading];
        self.callback(URL);
        return NO;
    }
    NSString *scheme = URL.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"about"] && ![scheme isEqualToString:@"data"] && ![scheme isEqualToString:@"file"]) {
        if (mainFrame && (type == RevenantNavigationLinkClicked || type == RevenantNavigationFormSubmitted) && [[UIApplication sharedApplication] canOpenURL:URL])
            [[UIApplication sharedApplication] openURL:URL];
        return NO;
    }
    if (mainFrame && !_showingError && ![URL isEqual:_currentURL] && ![scheme isEqualToString:@"about"]) {
        BOOL userInitiated = type == RevenantNavigationLinkClicked || type == RevenantNavigationFormSubmitted || type == RevenantNavigationBackForward || type == RevenantNavigationReload;
        BOOL onlyFragment = URL.fragment && [[URL absoluteString] hasPrefix:[[_currentURL absoluteString] componentsSeparatedByString:@"#"][0]];
        if (!userInitiated && !onlyFragment) {
            id<SFSafariViewControllerDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(safariViewController:initialLoadDidRedirectToURL:)])
                [delegate safariViewController:[self revenant_sender] initialLoadDidRedirectToURL:URL];
        }
        _currentURL = URL;
    }
    return YES;
}

- (void)webViewDidStartLoad:(id<RevenantWebView>)webView
{
    if (!_showingError)
        [self revenant_startProgress];
    [self revenant_updateButtons];
}

- (void)webViewDidFinishLoad:(id<RevenantWebView>)webView
{
    if (webView.loading)
        return;
    [self revenant_finishProgress];
    if (!_showingError) {
        NSString *location = [webView stringByEvaluatingJavaScriptFromString:@"document.location.href"];
        NSURL *URL = location.length ? [NSURL URLWithString:location] : nil;
        if (URL && ![URL.scheme isEqualToString:@"about"])
            _currentURL = URL;
        _pageTitle = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
        _addressLabel.text = _currentURL.host ?: _initialURL.host;
        [self revenant_completeInitialLoad:YES];
    }
    [self revenant_updateButtons];
}

- (void)webView:(id<RevenantWebView>)webView didFailLoadWithError:(NSError *)error
{
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)
        return;
    NSString *failing = error.userInfo[NSURLErrorFailingURLStringErrorKey];
    NSURL *failingURL = failing ? [NSURL URLWithString:failing] : nil;
    if (failingURL && self.callbackMatcher && self.callbackMatcher(failingURL)) {
        self.callback(failingURL);
        return;
    }
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102)
        return;
    if (webView.loading)
        return;
    [self revenant_finishProgress];
    BOOL first = _initialLoadPending;
    if (!_showingError) {
        _showingError = YES;
        NSString *reason = error.localizedDescription ?: @"";
        NSString *html = [NSString stringWithFormat:@"<html><head><meta name=\"viewport\" content=\"width=device-width\"></head><body style=\"font-family:Helvetica;text-align:center;color:#555;padding:60px 20px\"><h2>Cannot Open Page</h2><p>%@</p></body></html>",
                          [[reason stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]];
        [webView loadHTMLString:html baseURL:nil];
    }
    if (first)
        [self revenant_completeInitialLoad:NO];
    [self revenant_updateButtons];
}

@end
