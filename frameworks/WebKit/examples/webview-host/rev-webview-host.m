#import <stdio.h>
#import <signal.h>
#import <string.h>
#import <execinfo.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <WebKitLegacy/WebFrame.h>
#import <WebKitLegacy/WebDataSource.h>
#import <WebKitLegacy/WebPreferences.h>
#import <WebKitLegacy/WebPreferencesPrivate.h>
#import <WebKitLegacy/WebView.h>
#import <WebKitLegacy/WAKWindow.h>
@class WAKScrollView;
@interface WAKScrollView : NSObject
- (void)setActualScrollPosition:(CGPoint)point;
@end
#import <WebKitLegacy/WAKView.h>
#import <WebKitLegacy/WebEvent.h>
#import <WebKitLegacy/WebCoreThreadRun.h>
#import <WebKitLegacy/WebViewPrivate.h>
#import <WebKitLegacy/WebFrameLoadDelegate.h>
#import <WebKitLegacy/WebFormDelegate.h>
#import <WebKitLegacy/DOMHTMLInputElement.h>
#import <WebKitLegacy/DOMDocument.h>
#import <WebKitLegacy/DOMElement.h>
#import "ModernTLSURLProtocol.h"
#import "WebKitUIKitDelegate.h"
#import "RevWebViewHostEmbedding.h"

static void hostLog(const char *format, ...)
{
    static FILE *file;
    if (!file) {
        file = fopen("/tmp/rev-webview-host.log", "w");
        if (!file)
            file = stderr;
        else
            dup2(fileno(file), STDERR_FILENO);
    }
    va_list arguments;
    va_start(arguments, format);
    fprintf(file, "[rev-host] ");
    vfprintf(file, format, arguments);
    fprintf(file, "\n");
    va_end(arguments);
    fflush(file);
}

#define LOG_STEP(fmt, ...) hostLog(fmt, ##__VA_ARGS__)

static void reportFatalSignal(int number, siginfo_t *info, void *context)
{
    void *frames[64];
    int count = backtrace(frames, 64);
    hostLog("FATAL signal %d at %p, %d frames", number, info ? info->si_addr : NULL, count);
    char **names = backtrace_symbols(frames, count);
    for (int i = 0; i < count; i++)
        hostLog("  #%02d %s", i, names ? names[i] : "?");
    signal(number, SIG_DFL);
    raise(number);
}

static void reportUncaughtException(NSException *exception)
{
    hostLog("UNCAUGHT %s: %s", [[exception name] UTF8String] ?: "?",
        [[exception reason] UTF8String] ?: "?");
    NSArray *frames = [exception callStackSymbols];
    for (NSUInteger i = 0; i < [frames count] && i < 40; i++)
        hostLog("  %s", [[frames objectAtIndex:i] UTF8String] ?: "?");
}

static void installFatalSignalHandlers(void)
{
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_sigaction = reportFatalSignal;
    action.sa_flags = SA_SIGINFO;
    sigemptyset(&action.sa_mask);
    NSSetUncaughtExceptionHandler(reportUncaughtException);
    int numbers[] = { SIGSEGV, SIGBUS, SIGILL, SIGTRAP, SIGABRT, SIGFPE };
    for (unsigned i = 0; i < sizeof(numbers) / sizeof(numbers[0]); i++)
        sigaction(numbers[i], &action, NULL);
}

extern void WebKitInitialize(void);
extern void WebThreadLock(void);
extern void WebThreadUnlock(void);

static NSString *startPage(void)
{
    NSString *configured = [NSString stringWithContentsOfFile:@"/tmp/rev-url.txt"
        encoding:NSUTF8StringEncoding error:NULL];
    configured = [configured stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([configured length])
        return configured;
    NSString *bundled = [[NSBundle mainBundle] pathForResource:@"start" ofType:@"html"];
    return bundled ? [[NSURL fileURLWithPath:bundled] absoluteString] : @"about:blank";
}

@interface WebContentScrollView : UIScrollView
@end

@implementation WebContentScrollView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [[self nextResponder] touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [[self nextResponder] touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    [[self nextResponder] touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    [[self nextResponder] touchesCancelled:touches withEvent:event];
}

@end

static void withWebLock(void (^work)(void))
{
    WebThreadRun(work);
}

@protocol RevKeyInputConsumer <NSObject>
- (void)typeCharacters:(NSString *)text;
- (void)typeBackspace;
- (void)typeReturn;
@end

@interface RevKeyInputView : UIView <UIKeyInput> {
    UIKeyboardType _kbType;
    BOOL _secure;
}
@property (nonatomic, assign) id<RevKeyInputConsumer> consumer;
- (void)configureForType:(NSString *)inputType;
@end

@implementation RevKeyInputView
@synthesize consumer = _consumer;
- (BOOL)canBecomeFirstResponder { return YES; }
- (BOOL)hasText { return YES; }
- (void)configureForType:(NSString *)inputType {
    _secure = [inputType isEqualToString:@"password"];
    _kbType = [inputType isEqualToString:@"email"] ? UIKeyboardTypeEmailAddress
            : ([inputType isEqualToString:@"tel"] ? UIKeyboardTypePhonePad
            : ([inputType isEqualToString:@"number"] ? UIKeyboardTypeNumberPad : UIKeyboardTypeDefault));
}
- (void)insertText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) { [_consumer typeReturn]; return; }
    [_consumer typeCharacters:text];
}
- (void)deleteBackward { [_consumer typeBackspace]; }
- (UIKeyboardType)keyboardType { return _kbType; }
- (void)setKeyboardType:(UIKeyboardType)t { _kbType = t; }
- (BOOL)isSecureTextEntry { return _secure; }
- (void)setSecureTextEntry:(BOOL)s { _secure = s; }
- (UITextAutocapitalizationType)autocapitalizationType { return UITextAutocapitalizationTypeNone; }
- (UITextAutocorrectionType)autocorrectionType { return UITextAutocorrectionTypeNo; }
@end

@interface RevWebViewHostViewController : UIViewController <UIScrollViewDelegate, WebFrameLoadDelegate, WebKitRootLayerHandler, RevWebViewHostControlling, WebFormDelegate, RevKeyInputConsumer> {
    RevKeyInputView *_keyInput;
    WebView *_webView;
    WAKWindow *_wakWindow;
    CALayer *_hostLayer;
    CALayer *_compositingRootLayer;
    UIScrollView *_scrollView;
    NSDate *_start;
    BOOL _settled;
    BOOL _selfTestRan;
    CGSize _viewportSize;
    CGSize _documentSize;
    BOOL _documentGrewBeyondViewport;
    CGFloat _tallestDocumentHeight;
    WebKitUIKitDelegate *_uiKitDelegate;
    id<RevWebViewHostDelegate> _hostDelegate;
    CGRect _embeddedFrame;
    BOOL _useEmbeddedFrame;
    NSTimer *_progressTimer;
    NSString *_startURLString;
    DOMHTMLInputElement *_focusedInput;
    UIPanGestureRecognizer *_dragPan;
}
@end

@implementation RevWebViewHostViewController

- (void)loadView
{
    if (_useEmbeddedFrame) {
        UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _embeddedFrame.size.width, _embeddedFrame.size.height)];
        [root setBackgroundColor:[UIColor whiteColor]];
        [self setView:root];
        [root release];
        return;
    }
    CGRect screen = [[UIScreen mainScreen] bounds];
    CGFloat statusBar = CGRectGetHeight([[UIApplication sharedApplication] statusBarFrame]);
    UIView *root = [[UIView alloc] initWithFrame:
        CGRectMake(0, statusBar, screen.size.width, screen.size.height - statusBar)];
    [root setBackgroundColor:[UIColor whiteColor]];
    [self setView:root];
    [root release];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    CGRect bounds = [[self view] bounds];
    LOG_STEP("view %g x %g at scale %g", bounds.size.width, bounds.size.height,
        [[UIScreen mainScreen] scale]);

    WebKitInitialize();
    LOG_STEP("WebKit initialised (class table check: %s / %s)",
        [NSStringFromClass([WebView class]) UTF8String],
        [NSStringFromClass(NSClassFromString(@"WebView")) UTF8String] ?: "(nil, no plain WebView in this process)");

    WebThreadLock();
    _webView = [[WebView alloc] initWithFrame:bounds frameName:nil groupName:nil];
    LOG_STEP("WebView %p, isa %s", _webView, object_getClassName(_webView));

    WebPreferences *preferences = [_webView preferences];
    [preferences setJavaScriptEnabled:YES];
    [WebView _setMemoryCacheCapacitiesForLowMemoryDevice];
    [preferences setAcceleratedCompositingEnabled:YES];
    [preferences setVideoPlaybackRequiresUserGesture:YES];
    [preferences setAudioPlaybackRequiresUserGesture:YES];
    [preferences _setTextAutosizingEnabled:NO];
    [preferences setDatabasesEnabled:YES];
    [preferences setLocalStorageEnabled:YES];

    [_webView setCustomUserAgent:
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 "
        @"(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"];

    LOG_STEP("modern TLS: %s", [ModernTLSURLProtocol install] ? "installed" : "unavailable");
    [_webView setFrameLoadDelegate:self];
    [_webView _setFormDelegate:(id<WebFormDelegate>)self];
    [_webView setUIDelegate:(id)self];

    _uiKitDelegate = [[WebKitUIKitDelegate alloc] init];
    [_uiKitDelegate setHandler:self];
    [_webView _setUIKitDelegate:_uiKitDelegate];
    WebThreadUnlock();

    WebThreadLock();
    _hostLayer = [[CALayer alloc] init];
    [_hostLayer setAnchorPoint:CGPointZero];
    [_hostLayer setPosition:CGPointZero];
    [_hostLayer setBounds:CGRectMake(0, 0, bounds.size.width, bounds.size.height)];
    _wakWindow = [[WAKWindow alloc] initWithLayer:_hostLayer];
    [_wakWindow setScreenSize:bounds.size];
    [_wakWindow setAvailableScreenSize:bounds.size];
    [_wakWindow setScreenScale:[[UIScreen mainScreen] scale]];
    [_wakWindow setVisible:YES];
    [_wakWindow setTilesOpaque:YES];
    [_wakWindow setTilingMode:kWAKWindowTilingModeDisabled];
    [_wakWindow setContentView:_webView];
    [_wakWindow setExposedScrollViewRect:CGRectMake(0, 0, bounds.size.width, bounds.size.height)];
    WebThreadUnlock();
    LOG_STEP("WAKWindow %p (isa %s) hosting layer %p", _wakWindow, object_getClassName(_wakWindow), _hostLayer);

    _scrollView = [[WebContentScrollView alloc] initWithFrame:bounds];
    [_scrollView setDelegate:self];
    [_scrollView setShowsVerticalScrollIndicator:YES];
    [_scrollView setShowsHorizontalScrollIndicator:NO];
    [_scrollView setAlwaysBounceHorizontal:NO];
    [_scrollView setAlwaysBounceVertical:YES];
    [_scrollView setDirectionalLockEnabled:YES];
    [_scrollView setContentSize:bounds.size];
    [_scrollView setDelaysContentTouches:NO];
    [_scrollView setCanCancelContentTouches:YES];
    [_scrollView setScrollsToTop:YES];
    [_scrollView setClipsToBounds:YES];
    [[_scrollView layer] addSublayer:_hostLayer];
    [[self view] addSubview:_scrollView];

    _keyInput = [[RevKeyInputView alloc] initWithFrame:CGRectMake(-20, -20, 1, 1)];
    [_keyInput setConsumer:self];
    [[self view] addSubview:_keyInput];

    _viewportSize = bounds.size;
    _documentSize = bounds.size;
    _start = [[NSDate date] retain];
    NSString *page = [_startURLString length] ? _startURLString : startPage();
    LOG_STEP("loading %s", [page UTF8String]);
    WebThreadLock();
    [[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:page]]];
    WebThreadUnlock();

    if (access("/tmp/rev-dragtest", F_OK) == 0) {
        _selfTestRan = YES;
        [self setScrollingEnabled:NO];
        [self performSelector:@selector(pollDragCount) withObject:nil afterDelay:4.0];
    }
}

- (void)pollDragCount
{
    WebView *wv = [_webView retain];
    WebThreadRun(^{
        DOMDocument *doc = [[wv mainFrame] DOMDocument];
        DOMElement *c = [doc querySelector:@"#c"];
        NSString *v = c ? [(DOMHTMLInputElement *)c value] : @"(#c missing)";
        LOG_STEP("dragtest: finger move-events = %s", [v UTF8String]);
        [wv release];
    });
    [self performSelector:@selector(pollDragCount) withObject:nil afterDelay:2.0];
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
    if (frame != [sender mainFrame])
        return;
    LOG_STEP("committed %.2f s -> %s", -[_start timeIntervalSinceNow],
        [[[[frame dataSource] request] URL] absoluteString].UTF8String ?: "?");
    if (_hostDelegate && [_hostDelegate respondsToSelector:@selector(webViewHost:didUpdateURLString:canGoBack:canGoForward:)])
        [_hostDelegate webViewHost:self didUpdateURLString:[sender mainFrameURL]
            canGoBack:[sender canGoBack] canGoForward:[sender canGoForward]];

    DOMDocument *doc = [frame DOMDocument];
    DOMElement *root = [doc documentElement];
    if (doc && root) {
        DOMElement *script = [doc createElement:@"script"];
        [script setTextContent:
            @"(function(){var R=document.documentElement;"
            @"function put(k,v){R.setAttribute('data-'+k,((R.getAttribute('data-'+k)||'')+v+' | ').slice(-800));}"
            @"window.onerror=function(m,u,l){put('err',m+'@'+l);};"
            @"var ce=console.error;console.error=function(){put('cerr',Array.prototype.join.call(arguments,' '));if(ce)ce.apply(console,arguments);};"
            @"var probes=['PointerEvent','TouchEvent','requestAnimationFrame','Promise','fetch','WeakMap','Proxy','MutationObserver','crypto','Intl','matchMedia'];"
            @"var miss=[];for(var i=0;i<probes.length;i++){try{if(typeof window[probes[i]]==='undefined')miss.push(probes[i]);}catch(e){miss.push(probes[i]+'!');}}"
            @"put('apis','missing:'+(miss.join(',')||'none'));})();"];
        [root appendChild:script];
    }
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
    if (frame != [sender mainFrame])
        return;
    [self stopProgressTimer];
    _progressTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1 target:self
        selector:@selector(pollLoadProgress) userInfo:nil repeats:YES] retain];
    if (_hostDelegate && [_hostDelegate respondsToSelector:@selector(webViewHost:didStartLoadWithURLString:)])
        [_hostDelegate webViewHost:self didStartLoadWithURLString:
            [[[[frame provisionalDataSource] request] URL] absoluteString]];
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame != [sender mainFrame])
        return;
    if (_hostDelegate && [_hostDelegate respondsToSelector:@selector(webViewHost:didUpdateTitle:)])
        [_hostDelegate webViewHost:self didUpdateTitle:title];
}

- (void)pollLoadProgress
{
    if (_hostDelegate && [_hostDelegate respondsToSelector:@selector(webViewHost:didUpdateProgress:)])
        [_hostDelegate webViewHost:self didUpdateProgress:[_webView estimatedProgress]];
}

- (void)pollCaptchaErrors
{
    WebView *wv = [_webView retain];
    WebThreadRun(^{
        DOMElement *root = [[[wv mainFrame] DOMDocument] documentElement];
        NSString *apis = [root getAttribute:@"data-apis"] ?: @"";
        NSString *err = [root getAttribute:@"data-err"] ?: @"";
        NSString *cerr = [root getAttribute:@"data-cerr"] ?: @"";
        LOG_STEP("captcha-apis: %s", [apis UTF8String]);
        if ([err length]) LOG_STEP("captcha-err: %s", [err UTF8String]);
        if ([cerr length]) LOG_STEP("captcha-cerr: %s", [cerr UTF8String]);
        [wv release];
    });
    [self performSelector:@selector(pollCaptchaErrors) withObject:nil afterDelay:3.0];
}

- (void)stopProgressTimer
{
    [_progressTimer invalidate];
    [_progressTimer release];
    _progressTimer = nil;
}

- (void)webView:(WebView *)sender didFirstVisuallyNonEmptyLayoutInFrame:(WebFrame *)frame
{
    if (frame != [sender mainFrame])
        return;
    LOG_STEP("first visible layout %.2f s", -[_start timeIntervalSinceNow]);
    [self settle];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (frame != [sender mainFrame])
        return;
    LOG_STEP("finished %.2f s -> %s", -[_start timeIntervalSinceNow],
        [[sender mainFrameURL] UTF8String] ?: "?");
    [self stopProgressTimer];
    if (_hostDelegate) {
        if ([_hostDelegate respondsToSelector:@selector(webViewHost:didUpdateProgress:)])
            [_hostDelegate webViewHost:self didUpdateProgress:1.0];
        if ([_hostDelegate respondsToSelector:@selector(webViewHost:didFinishLoadWithURLString:canGoBack:canGoForward:)])
            [_hostDelegate webViewHost:self didFinishLoadWithURLString:[sender mainFrameURL]
                canGoBack:[sender canGoBack] canGoForward:[sender canGoForward]];
    }
    [self settle];
    if ([[sender mainFrameURL] rangeOfString:@"captcha"].location != NSNotFound)
        [self performSelector:@selector(pollCaptchaErrors) withObject:nil afterDelay:2.0];
    if (!_selfTestRan && access("/tmp/rev-kbdtest", F_OK) == 0)
        [self performSelector:@selector(selfTestKeyInsert) withObject:nil afterDelay:2.5];
    if (!_selfTestRan && access("/tmp/rev-dragtest", F_OK) == 0) {
        _selfTestRan = YES;
        [self setScrollingEnabled:NO];
        [self performSelector:@selector(selfTestDrag) withObject:nil afterDelay:1.5];
    }
}

- (void)runSelfTest
{
    WebView *webView = _webView;
    WebThreadRun(^{
        NSString *js = [webView stringByEvaluatingJavaScriptFromString:
            @"(function(){return JSON.stringify({title:document.title,two:1+1,ua:navigator.userAgent.slice(0,40)});})()"];
        LOG_STEP("[selftest] JS eval -> %s", [js UTF8String] ?: "(nil)");
    });

    CGPoint before = [_scrollView contentOffset];
    CGPoint target = CGPointMake(0, before.y + 80);
    [_scrollView setContentOffset:target animated:NO];
    WebView *webView2 = _webView;
    WebThreadRun(^{
        NSString *scrollY = [webView2 stringByEvaluatingJavaScriptFromString:@"String(window.pageYOffset)"];
        LOG_STEP("[selftest] scrolled UIScrollView to y=%g, page reports scrollY=%s",
            target.y, [scrollY UTF8String] ?: "(nil)");
    });

    CGPoint tapPoint = CGPointMake(_viewportSize.width / 2, _viewportSize.height / 2);
    NSString *ask = [NSString stringWithFormat:
        @"(function(){var e=document.elementFromPoint(%g,%g);"
         "return e ? e.tagName+' \"'+(e.innerText||'').slice(0,30)+'\"' : 'nothing';})()",
        tapPoint.x, tapPoint.y];
    WebView *webView3 = _webView;
    WebThreadRun(^{
        NSString *under = [webView3 stringByEvaluatingJavaScriptFromString:ask];
        LOG_STEP("[selftest] tapping screen %g,%g: page says %s under finger",
            tapPoint.x, tapPoint.y, [under UTF8String] ?: "(nil)");
    });
    [self sendTouch:WebEventTouchBegin phase:WebEventTouchPhaseBegan at:tapPoint];
    [self sendTouchEndThenTapAt:tapPoint];
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    LOG_STEP("provisional load failed: %s", [[error localizedDescription] UTF8String]);
    [self stopProgressTimer];
    if (_hostDelegate && [_hostDelegate respondsToSelector:@selector(webViewHost:didFailLoadWithError:)])
        [_hostDelegate webViewHost:self didFailLoadWithError:error];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    LOG_STEP("load failed: %s", [[error localizedDescription] UTF8String]);
    [self stopProgressTimer];
    if (_hostDelegate && [_hostDelegate respondsToSelector:@selector(webViewHost:didFailLoadWithError:)])
        [_hostDelegate webViewHost:self didFailLoadWithError:error];
}

- (void)webView:(WebView *)sender addMessageToConsole:(NSDictionary *)message withSource:(NSString *)source
{
    LOG_STEP("console[%@ %@:%@]: %s",
        [message objectForKey:@"MessageLevel"] ?: @"?",
        [message objectForKey:@"URL"] ?: @"",
        [message objectForKey:@"LineNumber"] ?: @"?",
        [[message objectForKey:@"message"] UTF8String] ?: "?");
}
- (void)webView:(WebView *)sender addMessageToConsole:(NSDictionary *)message
{
    [self webView:sender addMessageToConsole:message withSource:nil];
}

- (void)settle
{
    BOOL first = !_settled;
    _settled = YES;
    WAKWindow *window = [_wakWindow retain];
    WebThreadRun(^{
        [window setTilingMode:kWAKWindowTilingModeDisabled];
        [window setTilingMode:kWAKWindowTilingModeNormal];
        if (first) {
            [window setNeedsDisplay];
            [window layoutTilesNow];
        } else {
            [window layoutTiles];
        }
        [window release];
    });
    [self performSelector:@selector(updateContentSize) withObject:nil afterDelay:1.0];
}

- (void)attachRootLayer:(CALayer *)rootLayer
{
    if (_compositingRootLayer == rootLayer)
        return;
    [_compositingRootLayer removeFromSuperlayer];
    _compositingRootLayer = rootLayer;
    if (rootLayer)
        [_hostLayer addSublayer:rootLayer];
}

- (void)contentsSizeChanged:(NSValue *)boxedSize
{
    CGSize content = [boxedSize CGSizeValue];
    if (content.width < 1 || content.height < 1)
        return;
    [self applyDocumentHeight:content.height];
}

- (void)setDocumentSize:(CGSize)size
{
    if (size.width < _viewportSize.width)
        size.width = _viewportSize.width;
    if (size.height < _viewportSize.height)
        size.height = _viewportSize.height;
    if (CGSizeEqualToSize(size, _documentSize))
        return;
    _documentSize = size;

    [_scrollView setContentSize:size];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [_hostLayer setBounds:CGRectMake(0, 0, size.width, size.height)];
    [_hostLayer setPosition:CGPointZero];
    [CATransaction commit];

    WAKWindow *window = [_wakWindow retain];
    WebView *webView = [_webView retain];
    CGSize viewport = _viewportSize;
    WebThreadRun(^{
        [window setContentRect:CGRectMake(0, 0, size.width, size.height)];
        [webView _setFixedLayoutSize:viewport];
        [webView setFrame:CGRectMake(0, 0, size.width, size.height)];
        [window layoutTiles];
        [webView release];
        [window release];
    });
    LOG_STEP("document %g x %g", size.width, size.height);
}

- (void)applyDocumentHeight:(CGFloat)height
{
    if (height > _viewportSize.height)
        _documentGrewBeyondViewport = YES;
    else if (_documentGrewBeyondViewport)
        return;

    if (height > _tallestDocumentHeight)
        _tallestDocumentHeight = height;
    else if (_tallestDocumentHeight > 0)
        height = _tallestDocumentHeight;

    CGSize page = CGSizeMake(_viewportSize.width, MAX(height, _viewportSize.height));
    if (CGSizeEqualToSize(page, [_scrollView contentSize]))
        return;

    [self setDocumentSize:page];
    if (_settled)
        [self settle];
}

- (void)updateContentSize
{
    withWebLock(^{
        CGSize content = [self->_webView _contentsSize];
        if (content.width < 1 || content.height < 1)
            return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applyDocumentHeight:content.height];
        });
    });
    [self performSelector:@selector(updateContentSize) withObject:nil afterDelay:5.0];
}

static WebEvent *touchEvent(WebEventType type, WebEventTouchPhaseType phase, CGPoint point)
{
    NSArray *locations = [NSArray arrayWithObject:[NSValue valueWithCGPoint:point]];
    NSArray *identifiers = [NSArray arrayWithObject:[NSNumber numberWithUnsignedInt:0]];
    NSArray *phases = [NSArray arrayWithObject:[NSNumber numberWithUnsignedInt:phase]];
    return [[[WebEvent alloc] initWithTouchEventType:type
        timeStamp:CACurrentMediaTime()
        location:point
        modifiers:0
        touchCount:1
        touchLocations:locations
        touchIdentifiers:identifiers
        touchPhases:phases
        isGesture:NO
        gestureScale:1
        gestureRotation:0] autorelease];
}

static WebEvent *mouseEvent(WebEventType type, CGPoint point)
{
    return [[[WebEvent alloc] initWithMouseEventType:type
        timeStamp:CACurrentMediaTime() location:point modifiers:0] autorelease];
}

- (void)sendTouch:(WebEventType)type phase:(WebEventTouchPhaseType)phase at:(CGPoint)point
{
    WAKWindow *window = [_wakWindow retain];
    WebEvent *event = [touchEvent(type, phase, point) retain];
    WebThreadRun(^{
        [window sendEvent:event];
        [event release];
        [window release];
    });
}

- (void)sendTouchEndThenTapAt:(CGPoint)point
{
    WAKWindow *window = [_wakWindow retain];
    WebEvent *end = [touchEvent(WebEventTouchEnd, WebEventTouchPhaseEnded, point) retain];
    WebThreadRun(^{
        [window sendEvent:end];
        BOOL handled = [end wasHandled];
        [end release];
        if (!handled) {
            [window sendEvent:mouseEvent(WebEventMouseDown, point)];
            [window sendEvent:mouseEvent(WebEventMouseUp, point)];
        }
        [window release];
    });
}

- (void)sendMouse:(WebEventType)type at:(CGPoint)point
{
    WAKWindow *window = [_wakWindow retain];
    WebEvent *event = [mouseEvent(type, point) retain];
    WebThreadRun(^{
        [window sendEvent:event];
        [event release];
        [window release];
    });
}
- (BOOL)dragMode
{
    return ![_scrollView isScrollEnabled];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self dragMode]) return;
    CGPoint point = [[touches anyObject] locationInView:_scrollView];
    [self sendTouch:WebEventTouchBegin phase:WebEventTouchPhaseBegan at:point];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self dragMode]) return;
    CGPoint point = [[touches anyObject] locationInView:_scrollView];
    [self sendTouch:WebEventTouchChange phase:WebEventTouchPhaseMoved at:point];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self dragMode]) return;
    CGPoint point = [[touches anyObject] locationInView:_scrollView];
    [self sendTouchEndThenTapAt:point];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint point = [[touches anyObject] locationInView:_scrollView];
    [self sendTouch:WebEventTouchCancel phase:WebEventTouchPhaseCancelled at:point];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGPoint offset = [scrollView contentOffset];
    if ([_hostDelegate respondsToSelector:@selector(webViewHost:didScrollToOffsetY:tracking:)])
        [_hostDelegate webViewHost:self didScrollToOffsetY:offset.y
            tracking:([scrollView isTracking] || [scrollView isDragging] || [scrollView isDecelerating])];
    WAKWindow *window = [_wakWindow retain];
    CGRect exposed = CGRectMake(offset.x, offset.y,
        CGRectGetWidth([scrollView bounds]), CGRectGetHeight([scrollView bounds]));
    WebThreadRun(^{
        [window setExposedScrollViewRect:exposed];
        [window release];
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    WAKWindow *window = [_wakWindow retain];
    WebThreadRun(^{
        [window removeAllNonVisibleTiles];
        [window release];
    });
}

- (void)raiseKeyboardForType:(NSString *)type
{
    RevKeyInputView *keyInput = _keyInput;
    NSString *t = [type copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(lowerKeyboard) object:nil];
        [keyInput configureForType:t];
        if (![keyInput isFirstResponder])
            [keyInput becomeFirstResponder];
        [t release];
    });
}
- (void)lowerKeyboard
{
    [_keyInput resignFirstResponder];
}
- (void)trackFocusedInput:(DOMHTMLInputElement *)element
{
    [element retain];
    [_focusedInput release];
    _focusedInput = element;
}
- (void)didFocusTextField:(DOMHTMLInputElement *)element inFrame:(WebFrame *)frame
{
    [self trackFocusedInput:element];
    [self raiseKeyboardForType:[element type]];
}
- (void)textFieldDidBeginEditing:(DOMHTMLInputElement *)element inFrame:(WebFrame *)frame
{
    [self trackFocusedInput:element];
    [self raiseKeyboardForType:[element type]];
}
- (void)textFieldDidEndEditing:(DOMHTMLInputElement *)element inFrame:(WebFrame *)frame
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(lowerKeyboard) withObject:nil afterDelay:0.35];
    });
}

- (void)writeToFocusedInput:(NSString *)newValue
{
    DOMHTMLInputElement *input = [_focusedInput retain];
    WebView *wv = [_webView retain];
    WebThreadRun(^{
        if (input) {
            [input setValue:newValue];
            DOMDocument *doc = [[wv mainFrame] DOMDocument];
            DOMEvent *ev = [doc createEvent:@"Event"];
            [ev initEvent:@"input" canBubbleArg:YES cancelableArg:NO];
            [input dispatchEvent:ev];
            DOMEvent *ch = [doc createEvent:@"Event"];
            [ch initEvent:@"change" canBubbleArg:YES cancelableArg:NO];
            [input dispatchEvent:ch];
        }
        [input release];
        [wv release];
    });
}

- (void)sendKeyCharacters:(NSString *)chars keyCode:(uint16_t)code
{
    WAKWindow *window = [_wakWindow retain];
    WebEvent *down = [[[WebEvent alloc] initWithKeyEventType:WebEventKeyDown
        timeStamp:CACurrentMediaTime() characters:chars charactersIgnoringModifiers:chars
        modifiers:0 isRepeating:NO withFlags:0 withInputManagerHint:nil keyCode:code isTabKey:NO] retain];
    WebEvent *up = [[[WebEvent alloc] initWithKeyEventType:WebEventKeyUp
        timeStamp:CACurrentMediaTime() characters:chars charactersIgnoringModifiers:chars
        modifiers:0 isRepeating:NO withFlags:0 withInputManagerHint:nil keyCode:code isTabKey:NO] retain];
    WebThreadRun(^{
        [window sendEvent:down];
        [window sendEvent:up];
        [down release];
        [up release];
        [window release];
    });
}
- (void)editFocusedInput:(NSString *(^)(NSString *current))transform
{
    DOMHTMLInputElement *input = [_focusedInput retain];
    WebView *wv = [_webView retain];
    WebThreadRun(^{
        if (input) {
            NSString *current = [input value] ?: @"";
            [input setValue:transform(current)];
            DOMDocument *doc = [[wv mainFrame] DOMDocument];
            DOMEvent *ev = [doc createEvent:@"Event"];
            [ev initEvent:@"input" canBubbleArg:YES cancelableArg:NO];
            [input dispatchEvent:ev];
        }
        [input release];
        [wv release];
    });
}
- (void)typeCharacters:(NSString *)text
{
    NSString *t = [text copy];
    [self editFocusedInput:^NSString *(NSString *current) {
        return [current stringByAppendingString:t];
    }];
    [t release];
}
- (void)typeBackspace
{
    [self editFocusedInput:^NSString *(NSString *current) {
        return [current length] ? [current substringToIndex:[current length] - 1] : current;
    }];
}
- (void)typeReturn
{
    DOMHTMLInputElement *input = [_focusedInput retain];
    WebView *wv = [_webView retain];
    WebThreadRun(^{
        if (input) {
            DOMDocument *doc = [[wv mainFrame] DOMDocument];
            DOMEvent *ch = [doc createEvent:@"Event"];
            [ch initEvent:@"change" canBubbleArg:YES cancelableArg:NO];
            [input dispatchEvent:ch];
        }
        [input release];
        [wv release];
    });
}

- (void)selfTestKeyInsert
{
    WebView *wv = [_webView retain];
    WAKWindow *win = [_wakWindow retain];
    WebThreadRun(^{
        DOMDocument *doc = [[wv mainFrame] DOMDocument];
        DOMElement *input = [doc querySelector:@"input[type=email], input[type=text], input"];
        if (!input) { LOG_STEP("selftest: no input yet, will retry on next load"); [wv release]; [win release]; return; }
        self->_selfTestRan = YES;
        [input focus];
        NSString *before = [(DOMHTMLInputElement *)input value] ?: @"";
        LOG_STEP("selftest: focused input, value-before='%s'", [before UTF8String]);
        [(DOMHTMLInputElement *)input setValue:@"selftest@example.com"];
        DOMEvent *ev = [doc createEvent:@"Event"];
        [ev initEvent:@"input" canBubbleArg:YES cancelableArg:NO];
        [input dispatchEvent:ev];
        NSString *after = [(DOMHTMLInputElement *)input value] ?: @"";
        LOG_STEP("selftest: value-after='%s' (%s)", [after UTF8String],
            [after isEqualToString:before] ? "UNCHANGED - DOM setValue failed" : "CHANGED - DOM path WORKS");
        [wv release]; [win release];
    });
}

- (void)setScrollingEnabled:(BOOL)enabled
{
    [_scrollView setScrollEnabled:enabled];
    [_scrollView setCanCancelContentTouches:enabled];
    if (!enabled && !_dragPan) {
        _dragPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragPan:)];
        [_dragPan setMaximumNumberOfTouches:1];
        [_scrollView addGestureRecognizer:_dragPan];
    }
    [_dragPan setEnabled:!enabled];
}

- (void)handleDragPan:(UIPanGestureRecognizer *)pan
{
    CGPoint p = [pan locationInView:_scrollView];
    switch ([pan state]) {
    case UIGestureRecognizerStateBegan:
        [self sendTouch:WebEventTouchBegin phase:WebEventTouchPhaseBegan at:p];
        [self sendMouse:WebEventMouseDown at:p];
        break;
    case UIGestureRecognizerStateChanged:
        [self sendTouch:WebEventTouchChange phase:WebEventTouchPhaseMoved at:p];
        [self sendMouse:WebEventMouseMoved at:p];
        break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
        [self sendTouch:WebEventTouchEnd phase:WebEventTouchPhaseEnded at:p];
        [self sendMouse:WebEventMouseUp at:p];
        break;
    default:
        break;
    }
}

- (void)selfTestDrag
{
    CGFloat y = 200;
    [self sendTouch:WebEventTouchBegin phase:WebEventTouchPhaseBegan at:CGPointMake(40, y)];
    [self sendMouse:WebEventMouseDown at:CGPointMake(40, y)];
    for (int x = 40; x <= 280; x += 15) {
        [self sendTouch:WebEventTouchChange phase:WebEventTouchPhaseMoved at:CGPointMake(x, y)];
        [self sendMouse:WebEventMouseMoved at:CGPointMake(x, y)];
    }
    [self sendTouch:WebEventTouchEnd phase:WebEventTouchPhaseEnded at:CGPointMake(280, y)];
    [self sendMouse:WebEventMouseUp at:CGPointMake(280, y)];

    WebView *wv = [_webView retain];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WebThreadRun(^{
            DOMDocument *doc = [[wv mainFrame] DOMDocument];
            DOMElement *c = [doc querySelector:@"#c"];
            NSString *v = c ? [(DOMHTMLInputElement *)c value] : @"(#c missing)";
            LOG_STEP("dragtest: move-events reaching page = %s", [v UTF8String]);
            [wv release];
        });
    });
}

- (WebView *)webView
{
    return _webView;
}

- (void)setHostDelegate:(id<RevWebViewHostDelegate>)delegate
{
    _hostDelegate = delegate;
}

- (id<RevWebViewHostDelegate>)hostDelegate
{
    return _hostDelegate;
}

- (void)setEmbeddedContentFrame:(CGRect)frame
{
    _embeddedFrame = frame;
    _useEmbeddedFrame = YES;
}

- (void)setStartURLString:(NSString *)urlString
{
    [urlString retain];
    [_startURLString release];
    _startURLString = urlString;
}

- (void)loadURLString:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url)
        return;
    WebView *webView = _webView;
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    WebThreadRun(^{
        [[webView mainFrame] loadRequest:request];
    });
}

- (void)goBack
{
    WebView *webView = _webView;
    WebThreadRun(^{
        [webView goBack];
    });
}

- (void)goForward
{
    WebView *webView = _webView;
    WebThreadRun(^{
        [webView goForward];
    });
}

- (void)reload
{
    WebView *webView = _webView;
    WebThreadRun(^{
        [webView reload:nil];
    });
}

- (void)stopLoading
{
    WebView *webView = _webView;
    WebThreadRun(^{
        [webView stopLoading:nil];
    });
}

- (void)dealloc
{
    [self stopProgressTimer];
    WebThreadLock();
    [_webView _setUIKitDelegate:nil];
    WebThreadUnlock();
    [_uiKitDelegate setHandler:nil];
    [_uiKitDelegate release];
    [_start release];
    [_startURLString release];
    [_keyInput resignFirstResponder];
    [_keyInput removeFromSuperview];
    [_keyInput release];
    [_dragPan release];
    [_webView release];
    [_wakWindow release];
    [_hostLayer release];
    [_scrollView release];
    [super dealloc];
}

@end

#ifndef REV_WEBVIEW_HOST_NO_MAIN
@interface RevWebViewHostAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *_window;
}
@end

@implementation RevWebViewHostAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    LOG_STEP("app launched");
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
        setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];

    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [_window setRootViewController:[[[RevWebViewHostViewController alloc] init] autorelease]];
    [_window makeKeyAndVisible];
    return YES;
}

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

@end

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    installFatalSignalHandlers();
    LOG_STEP("main entered");
    int result = 0;
    @try {
        result = UIApplicationMain(argc, argv, nil, @"RevWebViewHostAppDelegate");
    } @catch (NSException *exception) {
        reportUncaughtException(exception);
    }
    LOG_STEP("UIApplicationMain returned %d", result);
    [pool release];
    return result;
}
#endif
