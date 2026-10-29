#import "RevenantEngineHost.h"

typedef NS_ENUM(NSInteger, RevenantWAKWindowTilingMode) {
    RevenantWAKWindowTilingModeNormal,
    RevenantWAKWindowTilingModeMinimal,
    RevenantWAKWindowTilingModePanning,
    RevenantWAKWindowTilingModeZooming,
    RevenantWAKWindowTilingModeDisabled,
    RevenantWAKWindowTilingModeScrollToTop,
};

typedef void (*RevenantEngineVoidFunction)(void);

static RevenantEngineVoidFunction RevenantEngineFunction(const char *name)
{
    void *symbol = RevenantWebEngineSymbol(name);
    if (!symbol)
        [NSException raise:NSInternalInconsistencyException format:@"the revenant WebKit engine exports no %s", name];
    return (RevenantEngineVoidFunction)symbol;
}

static void RevenantEngineStart(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        RevenantEngineFunction("WebKitInitialize")();
    });
}

static Class RevenantEngineNew(NSString *name)
{
    Class cls = RevenantWebEngineClass(name);
    if (!cls)
        [NSException raise:NSInternalInconsistencyException format:@"the revenant WebKit engine has no class %@", name];
    return cls;
}

@implementation RevenantEngineHost {
    id<RevenantEngineView> _webView;
    id<RevenantEngineWindow> _window;
    CALayer *_hostLayer;
    UIScrollView *_scrollView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super init];
    if (!self)
        return nil;
    NSError *error = nil;
    if (!RevenantWebEngineLoad(&error))
        [NSException raise:NSInternalInconsistencyException format:@"WKWebView needs the revenant WebKit engine: %@", error.localizedDescription];
    RevenantEngineStart();

    RevenantEngineFunction("WebThreadLock")();
    _webView = [[RevenantEngineNew(@"RevWebView") alloc] initWithFrame:frame frameName:nil groupName:nil];
    id<RevenantEnginePreferences> preferences = [_webView preferences];
    [preferences setJavaScriptEnabled:YES];
    [preferences setDatabasesEnabled:YES];
    [preferences setLocalStorageEnabled:YES];
    [preferences setAcceleratedCompositingEnabled:YES];
    [preferences setVideoPlaybackRequiresUserGesture:YES];
    [preferences setAudioPlaybackRequiresUserGesture:YES];
    [preferences _setTextAutosizingEnabled:NO];

    _hostLayer = [[CALayer alloc] init];
    _hostLayer.anchorPoint = CGPointZero;
    _hostLayer.position = CGPointZero;
    _hostLayer.bounds = CGRectMake(0, 0, frame.size.width, frame.size.height);
    _window = [[RevenantEngineNew(@"RevWAKWindow") alloc] initWithLayer:_hostLayer];
    [_window setScreenSize:frame.size];
    [_window setAvailableScreenSize:frame.size];
    [_window setScreenScale:[UIScreen mainScreen].scale];
    [_window setVisible:YES];
    [_window setTilesOpaque:YES];
    [_window setTilingMode:RevenantWAKWindowTilingModeDisabled];
    [_window setContentView:_webView];
    [_window setExposedScrollViewRect:CGRectMake(0, 0, frame.size.width, frame.size.height)];
    RevenantEngineFunction("WebThreadUnlock")();

    _scrollView = [[RevenantEngineNew(@"WebContentScrollView") alloc] initWithFrame:frame];
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.alwaysBounceHorizontal = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.directionalLockEnabled = YES;
    _scrollView.contentSize = frame.size;
    _scrollView.delaysContentTouches = NO;
    _scrollView.canCancelContentTouches = YES;
    _scrollView.scrollsToTop = YES;
    _scrollView.clipsToBounds = YES;
    [_scrollView.layer addSublayer:_hostLayer];
    return self;
}

- (id<RevenantEngineView>)webView
{
    return _webView;
}

- (UIScrollView *)scrollView
{
    return _scrollView;
}

@end
