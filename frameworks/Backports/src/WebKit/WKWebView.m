#import "RevenantWebKit.h"
#import "RevenantDocument.h"
#import "RevenantScriptCodec.h"

static NSString *const RevenantEvaluate =
    @"(function(src){"
    @"var encode=%@;"
    @"var value;"
    @"try{value=(0,eval)(src);}catch(e){return JSON.stringify({'error':String(e&&e.message!==undefined?e.message:e),'line':e&&e.line!==undefined?e.line:0});}"
    @"var text;"
    @"try{text=encode(value);}catch(e){return JSON.stringify({'unsupported':1});}"
    @"return '{\"ok\":'+text+'}';"
    @"})(%@)";

static NSString *literal(NSString *string)
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[string ?: @""] options:0 error:NULL];
    NSString *array = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [array substringWithRange:NSMakeRange(1, array.length - 2)];
}

static NSURL *withoutFragment(NSURL *url)
{
    NSString *string = url.absoluteString;
    NSRange range = [string rangeOfString:@"#"];
    return range.location == NSNotFound ? url : [NSURL URLWithString:[string substringToIndex:range.location]];
}

@interface WKWebView () <UIWebViewDelegate, RevenantWebKitScriptHost, RevenantDocumentSource>
@end

@interface RevenantSubstitute : NSObject
@property (nonatomic, copy) NSString *string;
@property (nonatomic, copy) NSData *data;
@property (nonatomic, copy) NSString *MIMEType;
@property (nonatomic, copy) NSString *encoding;
@property (nonatomic, copy) NSURL *baseURL;
@property (nonatomic, copy) NSURL *fileURL;
- (NSData *)revenant_document;
@end

@implementation RevenantSubstitute

@synthesize string = _string, data = _data, MIMEType = _MIMEType, encoding = _encoding, baseURL = _baseURL, fileURL = _fileURL;

- (NSData *)revenant_document
{
    if (self.fileURL)
        return [NSData dataWithContentsOfURL:self.fileURL] ?: [NSData data];
    return self.data ?: [NSData data];
}

@end

@implementation WKWebView {
    UIWebView *_web;
    WKWebViewConfiguration *_configuration;
    __weak id<WKNavigationDelegate> _navigationDelegate;
    __weak id<WKUIDelegate> _UIDelegate;
    NSURL *_URL;
    NSURL *_committedURL;
    NSString *_title;
    BOOL _loading;
    double _progress;
    NSMutableArray<WKBackForwardListItem *> *_items;
    NSInteger _index;
    WKBackForwardList *_list;
    WKNavigation *_navigation;
    BOOL _accepted;
    BOOL _started;
    WKNavigationType _navigationType;
    NSURLRequest *_approved;
    BOOL _allowsBackForwardNavigationGestures;
    NSString *_customUserAgent;
    BOOL _allowsLinkPreview;
    BOOL _documentReady;
    NSInteger _previousIndex;
    BOOL _decided;
    BOOL _didCommit;
    NSString *_token;
    BOOL _documentInjected;
    RevenantSubstitute *_pendingSubstitute;
    BOOL _substituteHistory;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame configuration:[[WKWebViewConfiguration alloc] init]];
}

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration
{
    self = [super initWithFrame:frame];
    if (self)
        [self revenant_setUpWithConfiguration:configuration];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
        [self revenant_setUpWithConfiguration:[[WKWebViewConfiguration alloc] init]];
    return self;
}

- (void)revenant_setUpWithConfiguration:(WKWebViewConfiguration *)configuration
{
    _token = RevenantDocumentRegister(self);
    [configuration revenant_bindURLSchemeHandlersToWebView:self];
    _configuration = [configuration copy];
    _title = @"";
    _items = [NSMutableArray array];
    _list = [WKBackForwardList alloc];
    [_list revenant_setItems:@[] index:-1];
    _index = -1;
    _allowsLinkPreview = NO;
    _web = [[UIWebView alloc] initWithFrame:self.bounds];
    _web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _web.delegate = self;
    _web.scalesPageToFit = YES;
    _web.suppressesIncrementalRendering = _configuration.suppressesIncrementalRendering;
    _web.allowsInlineMediaPlayback = _configuration.allowsInlineMediaPlayback;
    _web.mediaPlaybackRequiresUserAction = _configuration.mediaTypesRequiringUserActionForPlayback != WKAudiovisualMediaTypeNone;
    _web.mediaPlaybackAllowsAirPlay = _configuration.allowsAirPlayForMediaPlayback;
    _web.dataDetectorTypes = (UIDataDetectorTypes)(_configuration.dataDetectorTypes & 0xF);
    [self addSubview:_web];
    [_configuration.userContentController revenant_attach:self];
}

- (void)dealloc
{
    _web.delegate = nil;
}

- (WKWebViewConfiguration *)configuration
{
    return [_configuration copy];
}

- (id<WKNavigationDelegate>)navigationDelegate
{
    return _navigationDelegate;
}

- (void)setNavigationDelegate:(id<WKNavigationDelegate>)delegate
{
    _navigationDelegate = delegate;
}

- (id<WKUIDelegate>)UIDelegate
{
    return _UIDelegate;
}

- (void)setUIDelegate:(id<WKUIDelegate>)delegate
{
    _UIDelegate = delegate;
}

- (WKBackForwardList *)backForwardList
{
    return _list;
}

- (UIScrollView *)scrollView
{
    return _web.scrollView;
}

- (NSURL *)URL
{
    return _URL;
}

- (NSString *)title
{
    return _title;
}

- (BOOL)isLoading
{
    return _loading;
}

- (double)estimatedProgress
{
    return _progress;
}

- (BOOL)hasOnlySecureContent
{
    return [_committedURL.scheme isEqualToString:@"https"];
}

- (BOOL)canGoBack
{
    return _index > 0;
}

- (BOOL)canGoForward
{
    return _index >= 0 && _index + 1 < (NSInteger)_items.count;
}

- (BOOL)allowsBackForwardNavigationGestures
{
    return _allowsBackForwardNavigationGestures;
}

- (void)setAllowsBackForwardNavigationGestures:(BOOL)allows
{
    _allowsBackForwardNavigationGestures = allows;
}

- (NSString *)customUserAgent
{
    return _customUserAgent;
}

- (void)setCustomUserAgent:(NSString *)agent
{
    _customUserAgent = [agent copy];
}

- (BOOL)allowsLinkPreview
{
    return _allowsLinkPreview;
}

- (void)setAllowsLinkPreview:(BOOL)allows
{
    _allowsLinkPreview = allows;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    return NO;
}

- (void)revenant_setURL:(NSURL *)URL
{
    if ((URL == _URL) || [URL isEqual:_URL])
        return;
    [self willChangeValueForKey:@"URL"];
    _URL = URL;
    [self didChangeValueForKey:@"URL"];
}

- (void)revenant_setTitle:(NSString *)title
{
    title = title ?: @"";
    if ([title isEqualToString:_title])
        return;
    [self willChangeValueForKey:@"title"];
    _title = [title copy];
    [self didChangeValueForKey:@"title"];
}

- (void)revenant_setLoading:(BOOL)loading
{
    if (loading == _loading)
        return;
    [self willChangeValueForKey:@"loading"];
    _loading = loading;
    [self didChangeValueForKey:@"loading"];
}

- (void)revenant_setProgress:(double)progress
{
    if (progress == _progress)
        return;
    [self willChangeValueForKey:@"estimatedProgress"];
    _progress = progress;
    [self didChangeValueForKey:@"estimatedProgress"];
}

- (void)revenant_setItems:(NSArray<WKBackForwardListItem *> *)items index:(NSInteger)index
{
    BOOL back = self.canGoBack, forward = self.canGoForward;
    _items = [items mutableCopy];
    _index = index;
    [_list revenant_setItems:_items index:_index];
    if (back != self.canGoBack) {
        [self willChangeValueForKey:@"canGoBack"];
        [self didChangeValueForKey:@"canGoBack"];
    }
    if (forward != self.canGoForward) {
        [self willChangeValueForKey:@"canGoForward"];
        [self didChangeValueForKey:@"canGoForward"];
    }
}

- (WKNavigation *)revenant_beginNavigation:(NSURL *)URL type:(WKNavigationType)type
{
    return [self revenant_beginNavigation:URL type:type index:-1];
}

- (WKNavigation *)revenant_beginNavigation:(NSURL *)URL type:(WKNavigationType)type index:(NSInteger)index
{
    _navigation = [WKNavigation alloc];
    _accepted = NO;
    _started = NO;
    _decided = NO;
    _didCommit = NO;
    _documentInjected = NO;
    _pendingSubstitute = nil;
    _navigationType = type;
    _previousIndex = -1;
    if (index >= 0 && index != _index) {
        _previousIndex = _index;
        [self revenant_setItems:_items index:index];
    }
    [self revenant_setURL:URL];
    [self revenant_setLoading:YES];
    [self revenant_setProgress:0.1];
    return _navigation;
}

- (void)revenant_abandonNavigation
{
    RevenantDocumentForget(_token);
    if (_previousIndex >= 0)
        [self revenant_setItems:_items index:_previousIndex];
    _previousIndex = -1;
    _navigation = nil;
    _accepted = NO;
    _started = NO;
    _decided = NO;
    _didCommit = NO;
    [self revenant_setURL:_committedURL];
    [self revenant_setLoading:NO];
}

- (WKNavigation *)revenant_navigateWithRequest:(NSURLRequest *)request type:(WKNavigationType)type index:(NSInteger)index perform:(void (^)(void))perform
{
    WKNavigation *navigation = [self revenant_beginNavigation:request.URL type:type index:index];
    navigation.revenant_request = request;
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    if (![delegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        _accepted = YES;
        _decided = YES;
        perform();
        return navigation;
    }
    __block BOOL returned = NO, allowed = NO, answered = NO;
    __weak WKWebView *weak = self;
    WKNavigationAction *action = [WKNavigationAction revenant_actionWithRequest:request type:type mainFrame:YES];
    [delegate webView:self decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) {
        answered = YES;
        allowed = policy == WKNavigationActionPolicyAllow;
        if (returned) {
            dispatch_async(dispatch_get_main_queue(), ^{
                WKWebView *view = weak;
                if (!view || view->_navigation != navigation)
                    return;
                if (allowed) {
                    view->_accepted = YES;
                    view->_decided = YES;
                    perform();
                } else {
                    [view revenant_abandonNavigation];
                }
            });
        }
    }];
    returned = YES;
    if (answered) {
        if (allowed) {
            _accepted = YES;
            _decided = YES;
            perform();
        } else {
            [self revenant_abandonNavigation];
        }
    }
    return navigation;
}

- (NSURLRequest *)revenant_taggedRequest:(NSURLRequest *)request
{
    return RevenantDocumentTaggedCopy(request, _token);
}

static NSString *MIMETypeForLocalURL(NSURL *URL)
{
    if (URL.isFileURL) {
        static NSDictionary *types;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            types = @{@"html": @"text/html", @"htm": @"text/html", @"txt": @"text/plain", @"css": @"text/css",
                      @"js": @"application/javascript", @"json": @"application/json", @"xml": @"text/xml",
                      @"svg": @"image/svg+xml", @"png": @"image/png", @"jpg": @"image/jpeg", @"jpeg": @"image/jpeg",
                      @"gif": @"image/gif", @"pdf": @"application/pdf", @"mp4": @"video/mp4"};
        });
        return types[URL.pathExtension.lowercaseString] ?: @"application/octet-stream";
    }
    if ([URL.scheme.lowercaseString isEqualToString:@"data"]) {
        NSString *specifier = URL.resourceSpecifier;
        NSRange end = [specifier rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@";,"]];
        NSString *type = end.location == NSNotFound ? specifier : [specifier substringToIndex:end.location];
        return type.length ? type : @"text/plain";
    }
    return nil;
}

- (void)revenant_denyNavigation:(WKNavigation *)navigation
{
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    [self revenant_abandonNavigation];
    NSURL *failing = _URL ?: [NSURL URLWithString:@"about:blank"];
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSURLErrorFailingURLErrorKey: failing}];
    if ([delegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)])
        [delegate webView:self didFailProvisionalNavigation:navigation withError:error];
}

- (void)revenant_decideLocal:(NSURL *)URL MIMEType:(NSString *)MIMEType length:(long long)length encoding:(NSString *)encoding load:(void (^)(void))load
{
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:URL MIMEType:MIMEType expectedContentLength:length textEncodingName:encoding];
    WKNavigation *navigation = _navigation;
    [self revenant_decideResponse:response completion:^(NSInteger policy) {
        if (policy == WKNavigationResponsePolicyAllow)
            load();
        else if (policy == WKNavigationResponsePolicyDownload)
            [self revenant_downloadResponse:response request:[NSURLRequest requestWithURL:URL]];
        else
            [self revenant_denyNavigation:navigation];
    }];
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request
{
    NSURL *URL = request.URL;
    NSString *MIMEType = MIMETypeForLocalURL(URL);
    return [self revenant_navigateWithRequest:request type:WKNavigationTypeOther index:-1 perform:^{
        if (!MIMEType) {
            [self->_web loadRequest:[self revenant_taggedRequest:request]];
            return;
        }
        [self revenant_decideLocal:URL MIMEType:MIMEType length:-1 encoding:nil load:^{
            [self->_web loadRequest:[self revenant_taggedRequest:request]];
        }];
    }];
}

- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL
{
    NSString *extension = URL.pathExtension.lowercaseString;
    BOOL page = [extension isEqualToString:@"html"] || [extension isEqualToString:@"htm"];
    NSData *data = URL.isFileURL && page ? [NSData dataWithContentsOfURL:URL] : nil;
    if (!data)
        return [self loadRequest:[NSURLRequest requestWithURL:URL]];
    RevenantSubstitute *substitute = [[RevenantSubstitute alloc] init];
    substitute.fileURL = URL;
    substitute.MIMEType = @"text/html";
    substitute.baseURL = URL;
    return [self revenant_loadSubstitute:substitute URL:URL type:WKNavigationTypeOther index:-1];
}

- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL
{
    RevenantSubstitute *substitute = [[RevenantSubstitute alloc] init];
    substitute.string = string ?: @"";
    substitute.baseURL = baseURL;
    return [self revenant_loadSubstitute:substitute URL:baseURL ?: [NSURL URLWithString:@"about:blank"] type:WKNavigationTypeOther index:-1];
}

- (WKNavigation *)loadData:(NSData *)data MIMEType:(NSString *)MIMEType characterEncodingName:(NSString *)characterEncodingName baseURL:(NSURL *)baseURL
{
    RevenantSubstitute *substitute = [[RevenantSubstitute alloc] init];
    substitute.data = data ?: [NSData data];
    substitute.MIMEType = MIMEType;
    substitute.encoding = characterEncodingName;
    substitute.baseURL = baseURL;
    return [self revenant_loadSubstitute:substitute URL:baseURL ?: [NSURL URLWithString:@"about:blank"] type:WKNavigationTypeOther index:-1];
}

- (WKNavigation *)revenant_loadSubstitute:(RevenantSubstitute *)substitute URL:(NSURL *)URL type:(WKNavigationType)type index:(NSInteger)index
{
    _substituteHistory = YES;
    if (substitute.string) {
        NSString *html = RevenantDocumentInsert(substitute.string, [self revenant_documentStartScripts]);
        return [self revenant_navigateWithRequest:[NSURLRequest requestWithURL:URL] type:type index:index perform:^{
            [self revenant_decideLocal:URL MIMEType:@"text/html" length:html.length encoding:@"utf-8" load:^{
                self->_pendingSubstitute = substitute;
                [self revenant_documentDidInject];
                [self->_web loadHTMLString:html baseURL:substitute.baseURL];
            }];
        }];
    }
    NSData *document = [substitute revenant_document];
    BOOL injected = NO;
    if ([substitute.MIMEType.lowercaseString isEqualToString:@"text/html"]) {
        NSData *rewritten = RevenantDocumentRewrite(document, nil, substitute.encoding, [self revenant_documentStartScripts]);
        if (rewritten) {
            document = rewritten;
            injected = YES;
        }
    }
    return [self revenant_navigateWithRequest:[NSURLRequest requestWithURL:URL] type:type index:index perform:^{
        [self revenant_decideLocal:URL MIMEType:substitute.MIMEType length:document.length encoding:substitute.encoding load:^{
            self->_pendingSubstitute = substitute;
            if (injected)
                [self revenant_documentDidInject];
            [self->_web loadData:document MIMEType:substitute.MIMEType textEncodingName:substitute.encoding baseURL:substitute.baseURL];
        }];
    }];
}

- (WKNavigation *)revenant_moveToIndex:(NSInteger)index
{
    WKBackForwardListItem *item = _items[index];
    NSURL *target = item.URL;
    RevenantHistoryMove move = RevenantHistoryPlanMove(item.revenant_substitute != nil, !_substituteHistory);    if (move == RevenantHistoryMoveReplay)
        return [self revenant_loadSubstitute:item.revenant_substitute URL:target type:WKNavigationTypeBackForward index:index];
    if (move == RevenantHistoryMoveLoad)
        return [self revenant_navigateWithRequest:[NSURLRequest requestWithURL:target] type:WKNavigationTypeBackForward index:index perform:^{
            [self->_web loadRequest:[self revenant_taggedRequest:[NSURLRequest requestWithURL:target]]];
        }];
    NSInteger delta = index - _index;
    return [self revenant_navigateWithRequest:[NSURLRequest requestWithURL:target] type:WKNavigationTypeBackForward index:index perform:^{
        RevenantDocumentExpect(self->_token, target);
        if (delta == -1)
            [self->_web goBack];
        else if (delta == 1)
            [self->_web goForward];
        else
            [self->_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"history.go(%ld)", (long)delta]];
    }];
}

- (WKNavigation *)goBack
{
    if (!self.canGoBack)
        return nil;
    return [self revenant_moveToIndex:_index - 1];
}

- (WKNavigation *)goForward
{
    if (!self.canGoForward)
        return nil;
    return [self revenant_moveToIndex:_index + 1];
}

- (WKNavigation *)goToBackForwardListItem:(WKBackForwardListItem *)item
{
    NSUInteger position = [_items indexOfObjectIdenticalTo:item];
    if (position == NSNotFound || (NSInteger)position == _index)
        return nil;
    return [self revenant_moveToIndex:(NSInteger)position];
}

- (WKNavigation *)reload
{
    if (!_committedURL)
        return nil;
    if (_index >= 0 && _index < (NSInteger)_items.count && _items[_index].revenant_substitute)
        return [self revenant_loadSubstitute:_items[_index].revenant_substitute URL:_committedURL type:WKNavigationTypeReload index:-1];
    NSURL *target = _committedURL;
    return [self revenant_navigateWithRequest:[NSURLRequest requestWithURL:target] type:WKNavigationTypeReload index:-1 perform:^{
        RevenantDocumentExpect(self->_token, target);
        [self->_web reload];
    }];
}

- (WKNavigation *)reloadFromOrigin
{
    return [self reload];
}

- (void)stopLoading
{
    [_web stopLoading];
    if (_navigation)
        [self revenant_abandonNavigation];
}

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler
{
    NSString *script = [NSString stringWithFormat:RevenantEvaluate, RevenantEncoder, literal(javaScriptString)];
    NSString *answer = [_web stringByEvaluatingJavaScriptFromString:script];
    id result = nil;
    NSError *error = nil;
    BOOL valid = NO;
    id envelope = answer.length ? RevenantCodecParsed(answer, &valid) : nil;
    if (!valid || ![envelope isKindOfClass:[NSDictionary class]]) {
        error = [NSError errorWithDomain:WKErrorDomain code:WKErrorUnknown userInfo:nil];
    } else if (envelope[@"error"]) {
        error = [NSError errorWithDomain:WKErrorDomain code:WKErrorJavaScriptExceptionOccurred userInfo:@{@"WKJavaScriptExceptionMessage": envelope[@"error"], @"WKJavaScriptExceptionLineNumber": envelope[@"line"] ?: @0, @"WKJavaScriptExceptionColumnNumber": @0, NSLocalizedDescriptionKey: @"A JavaScript exception occurred"}];
    } else if (envelope[@"unsupported"]) {
        error = [NSError errorWithDomain:WKErrorDomain code:WKErrorJavaScriptResultTypeIsUnsupported userInfo:@{NSLocalizedDescriptionKey: @"JavaScript execution returned a result of an unsupported type"}];
    } else {
        result = RevenantCodecDecoded(envelope[@"ok"]);
    }
    if (_documentReady)
        [self revenant_refreshTitle];
    if (completionHandler) {
        void (^handler)(id, NSError *) = [completionHandler copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(result, error);
        });
    }
}

- (void)revenant_refreshTitle
{
    NSString *title = [_web stringByEvaluatingJavaScriptFromString:@"document.title"];
    [self revenant_setTitle:title];
    if (_index >= 0 && _index < (NSInteger)_items.count)
        _items[_index].revenant_title = title;
}

- (NSString *)revenant_shimWithNames:(NSArray *)names
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:names options:0 error:NULL];
    return [NSString stringWithFormat:RevenantShim, RevenantEncoder, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], _token];
}

- (NSArray<NSString *> *)revenant_documentStartScripts
{
    WKUserContentController *controller = _configuration.userContentController;
    NSMutableArray<NSString *> *scripts = [NSMutableArray arrayWithObject:[self revenant_shimWithNames:controller.revenant_handlerNames]];
    for (WKUserScript *script in controller.revenant_scripts) {
        if (script.injectionTime == WKUserScriptInjectionTimeAtDocumentStart)
            [scripts addObject:script.source];
    }
    return scripts;
}

- (void)revenant_documentDidInject
{
    _documentInjected = YES;
}

- (void)revenant_decideResponse:(NSURLResponse *)response completion:(void (^)(NSInteger))completion
{
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    if (![delegate respondsToSelector:@selector(webView:decidePolicyForNavigationResponse:decisionHandler:)]) {
        completion(WKNavigationResponsePolicyAllow);
        return;
    }
    WKNavigationResponse *navigationResponse = [WKNavigationResponse revenant_responseWithResponse:response];
    void (^decide)(void) = ^{
        [delegate webView:self decidePolicyForNavigationResponse:navigationResponse decisionHandler:^(WKNavigationResponsePolicy policy) {
            completion(policy);
        }];
    };
    if ([NSThread isMainThread])
        decide();
    else
        dispatch_async(dispatch_get_main_queue(), decide);
}

- (void)revenant_downloadResponse:(NSURLResponse *)response request:(NSURLRequest *)request
{
    [self revenant_abandonNavigation];
    WKDownload *download = [WKDownload revenant_downloadWithRequest:RevenantDocumentInnerCopy(request) webView:self];
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    if ([delegate respondsToSelector:@selector(webView:navigationResponse:didBecomeDownload:)])
        [delegate webView:self navigationResponse:[WKNavigationResponse revenant_responseWithResponse:response] didBecomeDownload:download];
    [download revenant_start];
}

- (void)startDownloadUsingRequest:(NSURLRequest *)request completionHandler:(void (^)(WKDownload *))completionHandler
{
    WKDownload *download = [WKDownload revenant_downloadWithRequest:RevenantDocumentInnerCopy(request) webView:self];
    [download revenant_start];
    if (completionHandler)
        completionHandler(download);
}

- (void)resumeDownloadFromResumeData:(NSData *)resumeData completionHandler:(void (^)(WKDownload *))completionHandler
{
    WKDownload *download = [WKDownload revenant_resumeWithData:resumeData webView:self];
    [download revenant_start];
    if (completionHandler)
        completionHandler(download);
}

- (void)revenant_installScripts:(BOOL)userScripts
{
    WKUserContentController *controller = _configuration.userContentController;
    BOOL started = _documentInjected || [[_web stringByEvaluatingJavaScriptFromString:RevenantDocumentStartedScript(_token)] isEqualToString:@"true"];
    [_web stringByEvaluatingJavaScriptFromString:[self revenant_shimWithNames:controller.revenant_handlerNames]];
    if (userScripts)
        for (WKUserScript *script in controller.revenant_scripts) {
            if (script.injectionTime == WKUserScriptInjectionTimeAtDocumentStart) {
                if (started)
                    continue;
                NSLog(@"WKUserScript: the document rewrite did not reach %@ (navigation type %ld), so a document-start script runs after the page's own scripts.", _web.request.URL.absoluteString ?: @"nil", (long)_navigationType);
            }
            [_web stringByEvaluatingJavaScriptFromString:script.source];
        }
}

- (void)revenant_scriptsDidChange
{
    if (_documentReady)
        [self revenant_installScripts:NO];
}

- (BOOL)revenant_isMainFrameRequest:(NSURLRequest *)request
{
    NSURL *main = request.mainDocumentURL;
    return main == nil || [withoutFragment(main) isEqual:withoutFragment(request.URL)];
}

- (void)revenant_openWindowFromMessage:(NSDictionary *)message
{
    BOOL valid = NO;
    NSDictionary *request = RevenantCodecMessageBody(message[@"b"], &valid);
    if (!valid || ![request isKindOfClass:[NSDictionary class]])
        return;
    NSString *target = request[@"u"];
    NSString *name = request[@"t"];
    NSString *features = request[@"f"];
    if (![target isKindOfClass:[NSString class]] || ![name isKindOfClass:[NSString class]] || ![features isKindOfClass:[NSString class]])
        return;
    NSURL *URL = [NSURL URLWithString:target];
    if (!URL)
        return;
    id<WKUIDelegate> UIDelegate = self.UIDelegate;
    if (![UIDelegate respondsToSelector:@selector(webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)])
        return;
    NSURLRequest *window = [NSURLRequest requestWithURL:URL];
    WKNavigationAction *action = [WKNavigationAction revenant_actionWithRequest:window type:WKNavigationTypeOther mainFrame:YES];
    WKWindowFeatures *windowFeatures = [WKWindowFeatures revenant_featuresWithString:features];
    WKWebView *created = [UIDelegate webView:self createWebViewWithConfiguration:[_configuration copy] forNavigationAction:action windowFeatures:windowFeatures];
    [created loadRequest:window];
}

- (void)revenant_receiveBridgeURL:(NSURL *)URL
{
    NSDictionary *message = RevenantCodecBridgeMessage(URL, _token);
    if ([message[@"w"] isEqual:@1]) {
        [self revenant_openWindowFromMessage:message];
        return;
    }
    NSString *name = message[@"n"];
    if (![name isKindOfClass:[NSString class]])
        return;
    id<WKScriptMessageHandler> handler = [_configuration.userContentController revenant_handlerNamed:name];
    if (!handler)
        return;
    BOOL bodyValid = NO;
    id body = RevenantCodecMessageBody(message[@"b"], &bodyValid);
    WKScriptMessage *object = [WKScriptMessage revenant_messageWithBody:body name:name webView:self mainFrame:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        [handler userContentController:_configuration.userContentController didReceiveScriptMessage:object];
    });
}

- (void)revenant_replay:(NSURLRequest *)request
{
    _approved = request;
    if (!_navigation)
        [self revenant_beginNavigation:request.URL type:_navigationType];
    [_web loadRequest:[self revenant_taggedRequest:request]];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)type
{
    if ([request.URL.scheme isEqualToString:RevenantWebKitBridgeScheme]) {
        [self revenant_receiveBridgeURL:request.URL];
        return NO;
    }
    BOOL main = [self revenant_isMainFrameRequest:request];
    BOOL inPage = request.URL.fragment && _committedURL && [withoutFragment(request.URL) isEqual:withoutFragment(_committedURL)];
    BOOL engineStarted = type == UIWebViewNavigationTypeLinkClicked || type == UIWebViewNavigationTypeFormSubmitted
        || (type == UIWebViewNavigationTypeOther && !inPage);
    if (!_navigation && main && [request.mainDocumentURL isEqual:request.URL] && !RevenantDocumentIsTagged(request)
        && RevenantDocumentIsWebURL(request.URL) && engineStarted) {
        WKNavigationType replayType = type == UIWebViewNavigationTypeOther ? WKNavigationTypeOther : (WKNavigationType)type;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_navigation) {
                [self->_web loadRequest:request];
                return;
            }
            [self revenant_navigateWithRequest:request type:replayType index:-1 perform:^{
                [self->_web loadRequest:[self revenant_taggedRequest:request]];
            }];
        });
        return NO;
    }
    WKNavigationType wkType = type == UIWebViewNavigationTypeOther ? WKNavigationTypeOther : (WKNavigationType)type;
    if (main && _navigation)
        wkType = _navigationType == WKNavigationTypeOther ? wkType : _navigationType;
    if (main && _decided) {
        _decided = NO;
        [self revenant_setURL:request.URL];
        return YES;
    }
    if (main && _approved && [_approved isEqual:request]) {
        _approved = nil;
        _accepted = YES;
        return YES;
    }
    if (!main && _navigation && _accepted && _started)
        [self revenant_emitCommit];
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    __block BOOL decided = YES, allow = YES, returned = NO;
    if ([delegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        decided = NO;
        WKNavigationAction *action = [WKNavigationAction revenant_actionWithRequest:request type:wkType mainFrame:main];
        __weak WKWebView *weak = self;
        [delegate webView:self decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) {
            if (!returned) {
                decided = YES;
                allow = policy == WKNavigationActionPolicyAllow;
            } else if (policy == WKNavigationActionPolicyAllow && main) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weak revenant_replay:request];
                });
            }
        }];
        returned = YES;
    }
    if (!decided)
        return NO;
    if (!main)
        return allow;
    if (!allow) {
        if (_navigation)
            [self revenant_abandonNavigation];
        return NO;
    }
    NSURL *reference = _committedURL;
    if (!_navigation && reference && request.URL.fragment && [withoutFragment(request.URL) isEqual:withoutFragment(reference)] && wkType != WKNavigationTypeReload) {
        [self revenant_setURL:request.URL];
        _committedURL = request.URL;
        if (_index >= 0)
            [self revenant_setItems:[self revenant_itemsReplacingCurrent:request.URL] index:_index];
        return YES;
    }
    if (!_navigation) {
        NSInteger target = -1;
        if (wkType == WKNavigationTypeBackForward) {
            if (_index >= 1 && [_items[_index - 1].URL isEqual:request.URL])
                target = _index - 1;
            else if (_index + 1 < (NSInteger)_items.count && [_items[_index + 1].URL isEqual:request.URL])
                target = _index + 1;
        }
        [self revenant_beginNavigation:request.URL type:wkType index:target];
    } else {
        [self revenant_setURL:request.URL];
    }
    _accepted = YES;
    return YES;
}

- (NSArray *)revenant_itemsReplacingCurrent:(NSURL *)URL
{
    NSMutableArray *items = [_items mutableCopy];
    items[_index] = [WKBackForwardListItem revenant_itemWithURL:URL title:_title];
    return items;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if (!_navigation || !_accepted || _started)
        return;
    _started = YES;
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    if ([delegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)])
        [delegate webView:self didStartProvisionalNavigation:_navigation];
}

- (void)revenant_commit
{
    NSURL *URL = _URL;
    NSMutableArray<WKBackForwardListItem *> *items = [_items mutableCopy];
    NSInteger index = _index;
    WKBackForwardListItem *item = [WKBackForwardListItem revenant_itemWithURL:URL title:@""];
    if (_navigationType == WKNavigationTypeReload && index >= 0) {
        items[index] = item;
    } else if (_navigationType == WKNavigationTypeBackForward && index >= 0) {
        if (_previousIndex < 0)
            items[index] = item;
    } else {
        if (index + 1 < (NSInteger)items.count)
            [items removeObjectsInRange:NSMakeRange(index + 1, items.count - index - 1)];
        [items addObject:item];
        index = (NSInteger)items.count - 1;
    }
    _previousIndex = -1;
    _committedURL = URL;
    item.revenant_substitute = _pendingSubstitute;
    _pendingSubstitute = nil;
    [self revenant_setTitle:@""];
    [self revenant_setItems:items index:index];
}

- (void)revenant_emitCommit
{
    if (_didCommit || !_navigation)
        return;
    _didCommit = YES;
    [self revenant_commit];
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    if ([delegate respondsToSelector:@selector(webView:didCommitNavigation:)])
        [delegate webView:self didCommitNavigation:_navigation];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!_navigation || !_accepted || webView.loading)
        return;
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    WKNavigation *navigation = _navigation;
    WKNavigationType type = _navigationType;
    if (!_started) {
        _started = YES;
        if ([delegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)])
            [delegate webView:self didStartProvisionalNavigation:navigation];
    }
    _documentReady = YES;
    [self revenant_installScripts:YES];
    RevenantDocumentForget(_token);
    [self revenant_emitCommit];
    _navigation = nil;
    _didCommit = NO;
    _accepted = NO;
    _started = NO;
    _decided = NO;
    if (type == WKNavigationTypeBackForward && _index >= 0 && _index < (NSInteger)_items.count)
        [self revenant_setTitle:_items[_index].revenant_title];
    [self revenant_setProgress:1];
    [self revenant_setLoading:NO];
    if ([delegate respondsToSelector:@selector(webView:didFinishNavigation:)])
        [delegate webView:self didFinishNavigation:navigation];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self revenant_refreshTitle];
    });
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (!_navigation || !_accepted)
        return;
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102)
        return;
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    WKNavigation *navigation = _navigation;
    if (!_started) {
        _started = YES;
        if ([delegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)])
            [delegate webView:self didStartProvisionalNavigation:navigation];
    }
    [self revenant_abandonNavigation];
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 101) {
        NSMutableDictionary *info = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
        error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnsupportedURL userInfo:info];
    }
    if ([delegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)])
        [delegate webView:self didFailProvisionalNavigation:navigation withError:error];
}

@end
