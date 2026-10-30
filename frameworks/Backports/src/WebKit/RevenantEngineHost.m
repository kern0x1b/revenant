#import <QuartzCore/QuartzCore.h>
#import "RevenantEngineHost.h"
#import "RevenantKeyInputView.h"
#import "RevenantUIKitDelegate.h"

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

typedef void (*RevenantEngineBlockFunction)(void (^)(void));

static void RevenantEngineRunOnWebThread(void (^block)(void))
{
    void *symbol = RevenantWebEngineSymbol("WebThreadRun");
    if (!symbol)
        [NSException raise:NSInternalInconsistencyException format:@"the revenant WebKit engine exports no WebThreadRun"];
    ((RevenantEngineBlockFunction)symbol)(block);
}

static void RevenantEngineLock(void)
{
    static RevenantEngineVoidFunction lock;
    if (!lock)
        lock = RevenantEngineFunction("WebThreadLock");
    lock();
}

static void RevenantEngineUnlock(void)
{
    static RevenantEngineVoidFunction unlock;
    if (!unlock)
        unlock = RevenantEngineFunction("WebThreadUnlock");
    unlock();
}

void RevenantWithWebLock(void (^work)(void))
{
    RevenantEngineLock();
    @try {
        work();
    } @finally {
        RevenantEngineUnlock();
    }
}

id RevenantWithWebLockValue(id (^work)(void))
{
    RevenantEngineLock();
    @try {
        return work();
    } @finally {
        RevenantEngineUnlock();
    }
}

static id<RevenantEngineEvent> RevenantTouchEvent(RevenantWebEventType type, RevenantWebEventTouchPhase phase, CGPoint point)
{
    NSArray *locations = [NSArray arrayWithObject:[NSValue valueWithCGPoint:point]];
    NSArray *identifiers = [NSArray arrayWithObject:[NSNumber numberWithUnsignedInt:0]];
    NSArray *phases = [NSArray arrayWithObject:[NSNumber numberWithUnsignedInt:phase]];
    return [[RevenantEngineNew(@"RevWebEvent") alloc] initWithTouchEventType:type
        timeStamp:CACurrentMediaTime()
        location:point
        modifiers:0
        touchCount:1
        touchLocations:locations
        touchIdentifiers:identifiers
        touchPhases:phases
        isGesture:NO
        gestureScale:1
        gestureRotation:0];
}

static id<RevenantEngineEvent> RevenantMouseEvent(RevenantWebEventType type, CGPoint point)
{
    return [[RevenantEngineNew(@"RevWebEvent") alloc] initWithMouseEventType:type
        timeStamp:CACurrentMediaTime()
        location:point
        modifiers:0];
}

static void RevenantFireDOMEvent(id<RevenantEngineView> webView, id<RevenantDOMInputElement> input, NSString *type)
{
    id<RevenantDOMEvent> event = [[[webView mainFrame] DOMDocument] createEvent:@"Event"];
    [event initEvent:type canBubbleArg:YES cancelableArg:NO];
    [input dispatchEvent:event];
}

@protocol RevenantTouchHandler <NSObject>
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@interface RevenantContentScrollView : UIScrollView
@property (nonatomic, weak) id<RevenantTouchHandler> touchHandler;
@end

@implementation RevenantContentScrollView

@synthesize touchHandler = _touchHandler;

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self.touchHandler touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [self.touchHandler touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    [self.touchHandler touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    [self.touchHandler touchesCancelled:touches withEvent:event];
}

@end

@interface RevenantEngineHost () <RevenantRootLayerHandler, RevenantTouchHandler, RevenantKeyInputConsumer, UIScrollViewDelegate>
@end

@implementation RevenantEngineHost {
    id<RevenantEngineView> _webView;
    id<RevenantEngineWindow> _window;
    CALayer *_hostLayer;
    RevenantContentScrollView *_scrollView;
    RevenantUIKitDelegate *_uiKitDelegate;
    RevenantKeyInputView *_keyInput;
    id<RevenantDOMInputElement> _focusedInput;
    CALayer *_compositingRootLayer;
    CGSize _viewportSize;
    CGSize _documentSize;
    CGFloat _tallestDocumentHeight;
    BOOL _documentGrewBeyondViewport;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super init];
    if (!self)
        return nil;
    NSError *error = nil;
    if (!RevenantWebEngineLoad(&error))
        [NSException raise:NSInternalInconsistencyException format:@"WKWebView needs the revenant WebKit engine, expected under %@ (REVENANT_WEBKIT_ENGINE names another folder): %@. The org.revenant.webkit-engine package installs it, so a missing engine means that package is absent or damaged.", RevenantWebEngineRoot(), error.localizedDescription];
    RevenantEngineStart();

    RevenantWithWebLock(^{
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
        _viewportSize = frame.size;
        _documentSize = frame.size;
        _uiKitDelegate = [[RevenantUIKitDelegate alloc] init];
        _uiKitDelegate.handler = self;
        [_webView _setUIKitDelegate:_uiKitDelegate];
        [_webView _setFormDelegate:self];
    });

    _scrollView = [[RevenantContentScrollView alloc] initWithFrame:frame];
    _scrollView.touchHandler = self;
    _scrollView.delegate = self;
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

    _keyInput = [[RevenantKeyInputView alloc] initWithFrame:CGRectMake(-20, -20, 1, 1)];
    _keyInput.consumer = self;
    [_scrollView addSubview:_keyInput];
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

- (void)dealloc
{
    id<RevenantEngineView> webView = _webView;
    RevenantWithWebLock(^{
        [webView _setFormDelegate:nil];
        [webView _setUIKitDelegate:nil];
    });
    [_keyInput resignFirstResponder];
}

- (void)attachRootLayer:(id)rootLayer
{
    if (_compositingRootLayer == rootLayer)
        return;
    [_compositingRootLayer removeFromSuperlayer];
    _compositingRootLayer = (CALayer *)rootLayer;
    if (rootLayer)
        [_hostLayer addSublayer:(CALayer *)rootLayer];
}

- (void)contentsSizeChanged:(NSValue *)boxedSize
{
    CGSize content = [boxedSize CGSizeValue];
    if (content.width < 1 || content.height < 1)
        return;
    [self applyDocumentHeight:content.height];
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

    id<RevenantEngineWindow> window = _window;
    id<RevenantEngineView> webView = _webView;
    CGSize viewport = _viewportSize;
    RevenantEngineRunOnWebThread(^{
        [window setContentRect:CGRectMake(0, 0, size.width, size.height)];
        [webView _setFixedLayoutSize:viewport];
        [webView setFrame:CGRectMake(0, 0, size.width, size.height)];
        [window layoutTiles];
    });
}

- (BOOL)dragMode
{
    return ![_scrollView isScrollEnabled];
}

- (void)sendTouch:(RevenantWebEventType)type phase:(RevenantWebEventTouchPhase)phase at:(CGPoint)point
{
    id<RevenantEngineWindow> window = _window;
    id<RevenantEngineEvent> event = RevenantTouchEvent(type, phase, point);
    RevenantEngineRunOnWebThread(^{
        [window sendEvent:event];
    });
}

- (void)sendTouchEndThenTapAt:(CGPoint)point
{
    id<RevenantEngineWindow> window = _window;
    id<RevenantEngineEvent> endEvent = RevenantTouchEvent(RevenantWebEventTouchEnd, RevenantWebEventTouchPhaseEnded, point);
    RevenantEngineRunOnWebThread(^{
        [window sendEvent:endEvent];
        if (!endEvent.wasHandled) {
            [window sendEvent:RevenantMouseEvent(RevenantWebEventMouseDown, point)];
            [window sendEvent:RevenantMouseEvent(RevenantWebEventMouseUp, point)];
        }
    });
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self dragMode])
        return;
    CGPoint point = [[touches anyObject] locationInView:_scrollView];
    [self sendTouch:RevenantWebEventTouchBegin phase:RevenantWebEventTouchPhaseBegan at:point];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self dragMode])
        return;
    CGPoint point = [[touches anyObject] locationInView:_scrollView];
    [self sendTouch:RevenantWebEventTouchChange phase:RevenantWebEventTouchPhaseMoved at:point];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self dragMode])
        return;
    CGPoint point = [[touches anyObject] locationInView:_scrollView];
    [self sendTouchEndThenTapAt:point];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint point = [[touches anyObject] locationInView:_scrollView];
    [self sendTouch:RevenantWebEventTouchCancel phase:RevenantWebEventTouchPhaseCancelled at:point];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGPoint offset = scrollView.contentOffset;
    CGRect exposed = CGRectMake(offset.x, offset.y, CGRectGetWidth(scrollView.bounds), CGRectGetHeight(scrollView.bounds));
    id<RevenantEngineWindow> window = _window;
    RevenantEngineRunOnWebThread(^{
        [window setExposedScrollViewRect:exposed];
    });
}

- (void)raiseKeyboardForType:(NSString *)type
{
    RevenantKeyInputView *keyInput = _keyInput;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(lowerKeyboard) object:nil];
        [keyInput configureForType:type];
        if (![keyInput isFirstResponder])
            [keyInput becomeFirstResponder];
    });
}

- (void)lowerKeyboard
{
    [_keyInput resignFirstResponder];
}

- (void)trackFocusedInput:(id<RevenantDOMInputElement>)element
{
    _focusedInput = element;
}

- (void)didFocusTextField:(id<RevenantDOMInputElement>)element inFrame:(id<RevenantEngineFrame>)frame
{
    [self trackFocusedInput:element];
    [self raiseKeyboardForType:[element type]];
}

- (void)textFieldDidBeginEditing:(id<RevenantDOMInputElement>)element inFrame:(id<RevenantEngineFrame>)frame
{
    [self trackFocusedInput:element];
    [self raiseKeyboardForType:[element type]];
}

- (void)textFieldDidEndEditing:(id<RevenantDOMInputElement>)element inFrame:(id<RevenantEngineFrame>)frame
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(lowerKeyboard) withObject:nil afterDelay:0.35];
    });
}

- (void)editFocusedInput:(NSString *(^)(NSString *current))transform
{
    id<RevenantEngineView> webView = _webView;
    RevenantEngineRunOnWebThread(^{
        id<RevenantDOMInputElement> input = self->_focusedInput;
        if (!input)
            return;
        input.value = transform(input.value ?: @"");
        RevenantFireDOMEvent(webView, input, @"input");
    });
}

- (void)typeCharacters:(NSString *)text
{
    [self editFocusedInput:^NSString *(NSString *current) {
        return [current stringByAppendingString:text];
    }];
}

- (void)typeBackspace
{
    [self editFocusedInput:^NSString *(NSString *current) {
        return current.length ? [current substringToIndex:current.length - 1] : current;
    }];
}

- (void)typeReturn
{
    id<RevenantEngineView> webView = _webView;
    RevenantEngineRunOnWebThread(^{
        id<RevenantDOMInputElement> input = self->_focusedInput;
        if (input)
            RevenantFireDOMEvent(webView, input, @"change");
    });
}

@end
