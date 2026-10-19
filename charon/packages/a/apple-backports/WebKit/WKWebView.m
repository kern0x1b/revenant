#import "CharonWebKit.h"

NSString *const CharonWebKitBridgeScheme = @"charon-wkbridge";

static NSString *const CharonEncoder =
    @"function(v){"
    @"var seen=[];"
    @"function walk(x,top,inArray){"
    @"var t=typeof x;"
    @"if(x===undefined){if(top){return {'$charon':'u'};}return inArray?null:undefined;}"
    @"if(x===null||t==='string'||t==='boolean'){return x;}"
    @"if(t==='number'){if(!isFinite(x)){return {'$charon':'n','v':String(x)};}if(x===0&&1/x<0){return {'$charon':'n','v':'-0'};}return x;}"
    @"if(t==='function'){throw {unsupported:1};}"
    @"var tag=Object.prototype.toString.call(x);"
    @"if(tag==='[object Date]'){return isNaN(x.getTime())?null:{'$charon':'d','v':x.getTime()};}"
    @"if(tag==='[object Arguments]'){throw {unsupported:1};}"
    @"var seenAt=seen.indexOf(x);"
    @"if(seenAt>=0){return {'$charon':'r','i':seenAt};}"
    @"seen.push(x);"
    @"if(Array.isArray(x)){var items=[];for(var j=0;j<x.length;j++){items.push(walk(x[j],false,true));}return {'$charon':'a','v':items};}"
    @"var keys=[],values=[];"
    @"for(var k in x){if(Object.prototype.hasOwnProperty.call(x,k)&&typeof x[k]!=='function'){var w=walk(x[k],false,false);if(w!==undefined){keys.push(k);values.push(w);}}}"
    @"return {'$charon':'o','k':keys,'v':values};"
    @"}"
    @"return JSON.stringify(walk(v,true,false));}";

static NSString *const CharonEvaluate =
    @"(function(src){"
    @"var encode=%@;"
    @"var value;"
    @"try{value=(0,eval)(src);}catch(e){return JSON.stringify({'error':String(e&&e.message!==undefined?e.message:e),'line':e&&e.line!==undefined?e.line:0});}"
    @"var text;"
    @"try{text=encode(value);}catch(e){return JSON.stringify({'unsupported':1});}"
    @"return '{\"ok\":'+text+'}';"
    @"})(%@)";

static NSString *const CharonShim =
    @"(function(names){"
    @"if(!names.length){try{delete window.webkit;}catch(e){window.webkit=undefined;}return;}"
    @"var encode=%@;"
    @"var top=window===window.top;"
    @"var handlers={};"
    @"names.forEach(function(name){handlers[name]={postMessage:function(body){"
    @"var text=encode(body);"
    @"var frame=document.createElement('iframe');"
    @"frame.style.display='none';"
    @"frame.src='" @"charon-wkbridge" @"://m/'+encodeURIComponent(JSON.stringify({n:name,b:text,m:top}));"
    @"(document.documentElement||document.body).appendChild(frame);"
    @"setTimeout(function(){if(frame.parentNode){frame.parentNode.removeChild(frame);}},0);"
    @"}};});"
    @"if(!window.webkit){window.webkit={};}"
    @"window.webkit.messageHandlers=handlers;"
    @"})(%@)";

static id decode(id value, NSMutableArray *ids)
{
    if (![value isKindOfClass:[NSDictionary class]])
        return value;
    NSString *kind = value[@"$charon"];
    if ([kind isEqualToString:@"d"])
        return [NSDate dateWithTimeIntervalSince1970:[value[@"v"] doubleValue] / 1000];
    if ([kind isEqualToString:@"n"]) {
        NSString *name = value[@"v"];
        if ([name isEqualToString:@"NaN"])
            return @(NAN);
        if ([name isEqualToString:@"-0"])
            return @(-0.0);
        return [name hasPrefix:@"-"] ? @(-INFINITY) : @(INFINITY);
    }
    if ([kind isEqualToString:@"r"]) {
        NSUInteger index = [value[@"i"] unsignedIntegerValue];
        return index < ids.count ? ids[index] : nil;
    }
    if ([kind isEqualToString:@"a"]) {
        NSMutableArray *array = [NSMutableArray array];
        [ids addObject:array];
        for (id item in value[@"v"])
            [array addObject:decode(item, ids) ?: [NSNull null]];
        return array;
    }
    if ([kind isEqualToString:@"o"]) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [ids addObject:dictionary];
        NSArray *keys = value[@"k"], *values = value[@"v"];
        for (NSUInteger index = 0; index < keys.count && index < values.count; index++)
            dictionary[keys[index]] = decode(values[index], ids) ?: [NSNull null];
        return dictionary;
    }
    return nil;
}

static id decoded(id value)
{
    return decode(value, [NSMutableArray array]);
}

static id parsed(NSString *text, BOOL *valid)
{
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:NULL] : nil;
    *valid = object != nil;
    return object;
}

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

@interface WKWebView () <UIWebViewDelegate, CharonWebKitScriptHost>
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
    BOOL _shimmed;
    BOOL _didCommit;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame configuration:[[WKWebViewConfiguration alloc] init]];
}

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration
{
    self = [super initWithFrame:frame];
    if (self)
        [self charon_setUpWithConfiguration:configuration];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
        [self charon_setUpWithConfiguration:[[WKWebViewConfiguration alloc] init]];
    return self;
}

- (void)charon_setUpWithConfiguration:(WKWebViewConfiguration *)configuration
{
    _configuration = [configuration copy];
    _title = @"";
    _items = [NSMutableArray array];
    _list = [WKBackForwardList alloc];
    [_list charon_setItems:@[] index:-1];
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
    [_configuration.userContentController charon_attach:self];
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

- (void)charon_setURL:(NSURL *)URL
{
    if ((URL == _URL) || [URL isEqual:_URL])
        return;
    [self willChangeValueForKey:@"URL"];
    _URL = URL;
    [self didChangeValueForKey:@"URL"];
}

- (void)charon_setTitle:(NSString *)title
{
    title = title ?: @"";
    if ([title isEqualToString:_title])
        return;
    [self willChangeValueForKey:@"title"];
    _title = [title copy];
    [self didChangeValueForKey:@"title"];
}

- (void)charon_setLoading:(BOOL)loading
{
    if (loading == _loading)
        return;
    [self willChangeValueForKey:@"loading"];
    _loading = loading;
    [self didChangeValueForKey:@"loading"];
}

- (void)charon_setProgress:(double)progress
{
    if (progress == _progress)
        return;
    [self willChangeValueForKey:@"estimatedProgress"];
    _progress = progress;
    [self didChangeValueForKey:@"estimatedProgress"];
}

- (void)charon_setItems:(NSArray<WKBackForwardListItem *> *)items index:(NSInteger)index
{
    BOOL back = self.canGoBack, forward = self.canGoForward;
    _items = [items mutableCopy];
    _index = index;
    [_list charon_setItems:_items index:_index];
    if (back != self.canGoBack) {
        [self willChangeValueForKey:@"canGoBack"];
        [self didChangeValueForKey:@"canGoBack"];
    }
    if (forward != self.canGoForward) {
        [self willChangeValueForKey:@"canGoForward"];
        [self didChangeValueForKey:@"canGoForward"];
    }
}

- (WKNavigation *)charon_beginNavigation:(NSURL *)URL type:(WKNavigationType)type
{
    return [self charon_beginNavigation:URL type:type index:-1];
}

- (WKNavigation *)charon_beginNavigation:(NSURL *)URL type:(WKNavigationType)type index:(NSInteger)index
{
    _navigation = [WKNavigation alloc];
    _accepted = NO;
    _started = NO;
    _decided = NO;
    _didCommit = NO;
    _navigationType = type;
    _previousIndex = -1;
    if (index >= 0 && index != _index) {
        _previousIndex = _index;
        [self charon_setItems:_items index:index];
    }
    [self charon_setURL:URL];
    [self charon_setLoading:YES];
    [self charon_setProgress:0.1];
    return _navigation;
}

- (void)charon_abandonNavigation
{
    if (_previousIndex >= 0)
        [self charon_setItems:_items index:_previousIndex];
    _previousIndex = -1;
    _navigation = nil;
    _accepted = NO;
    _started = NO;
    _decided = NO;
    _didCommit = NO;
    [self charon_setURL:_committedURL];
    [self charon_setLoading:NO];
}

- (WKNavigation *)charon_navigateWithRequest:(NSURLRequest *)request type:(WKNavigationType)type index:(NSInteger)index perform:(void (^)(void))perform
{
    WKNavigation *navigation = [self charon_beginNavigation:request.URL type:type index:index];
    navigation.charon_request = request;
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    if (![delegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        _accepted = YES;
        _decided = YES;
        perform();
        return navigation;
    }
    __block BOOL returned = NO, allowed = NO, answered = NO;
    __weak WKWebView *weak = self;
    WKNavigationAction *action = [WKNavigationAction charon_actionWithRequest:request type:type mainFrame:YES];
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
                    [view charon_abandonNavigation];
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
            [self charon_abandonNavigation];
        }
    }
    return navigation;
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request
{
    return [self charon_navigateWithRequest:request type:WKNavigationTypeOther index:-1 perform:^{
        [_web loadRequest:request];
    }];
}

- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL
{
    return [self loadRequest:[NSURLRequest requestWithURL:URL]];
}

- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL
{
    NSURL *URL = baseURL ?: [NSURL URLWithString:@"about:blank"];
    return [self charon_navigateWithRequest:[NSURLRequest requestWithURL:URL] type:WKNavigationTypeOther index:-1 perform:^{
        [_web loadHTMLString:string baseURL:baseURL];
    }];
}

- (WKNavigation *)loadData:(NSData *)data MIMEType:(NSString *)MIMEType characterEncodingName:(NSString *)characterEncodingName baseURL:(NSURL *)baseURL
{
    NSURL *URL = baseURL ?: [NSURL URLWithString:@"about:blank"];
    return [self charon_navigateWithRequest:[NSURLRequest requestWithURL:URL] type:WKNavigationTypeOther index:-1 perform:^{
        [_web loadData:data MIMEType:MIMEType textEncodingName:characterEncodingName baseURL:baseURL];
    }];
}

- (WKNavigation *)goBack
{
    if (!self.canGoBack)
        return nil;
    return [self charon_navigateWithRequest:[NSURLRequest requestWithURL:_items[_index - 1].URL] type:WKNavigationTypeBackForward index:_index - 1 perform:^{
        [_web goBack];
    }];
}

- (WKNavigation *)goForward
{
    if (!self.canGoForward)
        return nil;
    return [self charon_navigateWithRequest:[NSURLRequest requestWithURL:_items[_index + 1].URL] type:WKNavigationTypeBackForward index:_index + 1 perform:^{
        [_web goForward];
    }];
}

- (WKNavigation *)goToBackForwardListItem:(WKBackForwardListItem *)item
{
    NSUInteger position = [_items indexOfObjectIdenticalTo:item];
    if (position == NSNotFound || (NSInteger)position == _index)
        return nil;
    NSInteger delta = (NSInteger)position - _index;
    return [self charon_navigateWithRequest:[NSURLRequest requestWithURL:item.URL] type:WKNavigationTypeBackForward index:(NSInteger)position perform:^{
        [_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"history.go(%ld)", (long)delta]];
    }];
}

- (WKNavigation *)reload
{
    if (!_committedURL)
        return nil;
    return [self charon_navigateWithRequest:[NSURLRequest requestWithURL:_committedURL] type:WKNavigationTypeReload index:-1 perform:^{
        [_web reload];
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
        [self charon_abandonNavigation];
}

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler
{
    NSString *script = [NSString stringWithFormat:CharonEvaluate, CharonEncoder, literal(javaScriptString)];
    NSString *answer = [_web stringByEvaluatingJavaScriptFromString:script];
    id result = nil;
    NSError *error = nil;
    BOOL valid = NO;
    id envelope = answer.length ? parsed(answer, &valid) : nil;
    if (!valid || ![envelope isKindOfClass:[NSDictionary class]]) {
        error = [NSError errorWithDomain:WKErrorDomain code:WKErrorUnknown userInfo:nil];
    } else if (envelope[@"error"]) {
        error = [NSError errorWithDomain:WKErrorDomain code:WKErrorJavaScriptExceptionOccurred userInfo:@{@"WKJavaScriptExceptionMessage": envelope[@"error"], @"WKJavaScriptExceptionLineNumber": envelope[@"line"] ?: @0, @"WKJavaScriptExceptionColumnNumber": @0, NSLocalizedDescriptionKey: @"A JavaScript exception occurred"}];
    } else if (envelope[@"unsupported"]) {
        error = [NSError errorWithDomain:WKErrorDomain code:WKErrorJavaScriptResultTypeIsUnsupported userInfo:@{NSLocalizedDescriptionKey: @"JavaScript execution returned a result of an unsupported type"}];
    } else {
        result = decoded(envelope[@"ok"]);
    }
    if (_documentReady)
        [self charon_refreshTitle];
    if (completionHandler) {
        void (^handler)(id, NSError *) = [completionHandler copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(result, error);
        });
    }
}

- (void)charon_refreshTitle
{
    NSString *title = [_web stringByEvaluatingJavaScriptFromString:@"document.title"];
    [self charon_setTitle:title];
    if (_index >= 0 && _index < (NSInteger)_items.count)
        _items[_index].charon_title = title;
}

- (void)charon_installScripts:(BOOL)userScripts
{
    WKUserContentController *controller = _configuration.userContentController;
    NSArray *names = controller.charon_handlerNames;
    if (names.count || _shimmed) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:names options:0 error:NULL];
        [_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:CharonShim, CharonEncoder, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]];
        _shimmed = names.count > 0;
    }
    if (userScripts)
        for (WKUserScript *script in controller.charon_scripts)
            [_web stringByEvaluatingJavaScriptFromString:script.source];
}

- (void)charon_scriptsDidChange
{
    if (_documentReady)
        [self charon_installScripts:NO];
}

- (BOOL)charon_isMainFrameRequest:(NSURLRequest *)request
{
    NSURL *main = request.mainDocumentURL;
    return main == nil || [withoutFragment(main) isEqual:withoutFragment(request.URL)];
}

- (void)charon_receiveBridgeURL:(NSURL *)URL
{
    NSString *prefix = [CharonWebKitBridgeScheme stringByAppendingString:@"://m/"];
    NSString *encoded = [URL.absoluteString substringFromIndex:MIN(prefix.length, URL.absoluteString.length)];
    BOOL valid = NO;
    NSDictionary *message = parsed([encoded stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding], &valid);
    if (!valid || ![message isKindOfClass:[NSDictionary class]])
        return;
    NSString *name = message[@"n"];
    id<WKScriptMessageHandler> handler = [_configuration.userContentController charon_handlerNamed:name];
    if (!handler)
        return;
    BOOL bodyValid = NO;
    id body = decoded(parsed(message[@"b"], &bodyValid));
    WKScriptMessage *object = [WKScriptMessage charon_messageWithBody:body name:name webView:self mainFrame:[message[@"m"] boolValue]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [handler userContentController:_configuration.userContentController didReceiveScriptMessage:object];
    });
}

- (void)charon_replay:(NSURLRequest *)request
{
    _approved = request;
    if (!_navigation)
        [self charon_beginNavigation:request.URL type:_navigationType];
    [_web loadRequest:request];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)type
{
    if ([request.URL.scheme isEqualToString:CharonWebKitBridgeScheme]) {
        [self charon_receiveBridgeURL:request.URL];
        return NO;
    }
    BOOL main = [self charon_isMainFrameRequest:request];
    WKNavigationType wkType = type == UIWebViewNavigationTypeOther ? WKNavigationTypeOther : (WKNavigationType)type;
    if (main && _navigation)
        wkType = _navigationType == WKNavigationTypeOther ? wkType : _navigationType;
    if (main && _decided) {
        _decided = NO;
        [self charon_setURL:request.URL];
        return YES;
    }
    if (main && _approved && [_approved isEqual:request]) {
        _approved = nil;
        _accepted = YES;
        return YES;
    }
    if (!main && _navigation && _accepted && _started)
        [self charon_emitCommit];
    id<WKNavigationDelegate> delegate = _navigationDelegate;
    __block BOOL decided = YES, allow = YES, returned = NO;
    if ([delegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        decided = NO;
        WKNavigationAction *action = [WKNavigationAction charon_actionWithRequest:request type:wkType mainFrame:main];
        __weak WKWebView *weak = self;
        [delegate webView:self decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) {
            if (!returned) {
                decided = YES;
                allow = policy == WKNavigationActionPolicyAllow;
            } else if (policy == WKNavigationActionPolicyAllow && main) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weak charon_replay:request];
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
            [self charon_abandonNavigation];
        return NO;
    }
    NSURL *reference = _committedURL;
    if (!_navigation && reference && request.URL.fragment && [withoutFragment(request.URL) isEqual:withoutFragment(reference)] && wkType != WKNavigationTypeReload) {
        [self charon_setURL:request.URL];
        _committedURL = request.URL;
        if (_index >= 0)
            [self charon_setItems:[self charon_itemsReplacingCurrent:request.URL] index:_index];
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
        [self charon_beginNavigation:request.URL type:wkType index:target];
    } else {
        [self charon_setURL:request.URL];
    }
    _accepted = YES;
    return YES;
}

- (NSArray *)charon_itemsReplacingCurrent:(NSURL *)URL
{
    NSMutableArray *items = [_items mutableCopy];
    items[_index] = [WKBackForwardListItem charon_itemWithURL:URL title:_title];
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

- (void)charon_commit
{
    NSURL *URL = _URL;
    NSMutableArray<WKBackForwardListItem *> *items = [_items mutableCopy];
    NSInteger index = _index;
    WKBackForwardListItem *item = [WKBackForwardListItem charon_itemWithURL:URL title:@""];
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
    [self charon_setTitle:@""];
    [self charon_setItems:items index:index];
}

- (void)charon_emitCommit
{
    if (_didCommit || !_navigation)
        return;
    _didCommit = YES;
    [self charon_commit];
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
    [self charon_installScripts:YES];
    [self charon_emitCommit];
    _navigation = nil;
    _didCommit = NO;
    _accepted = NO;
    _started = NO;
    _decided = NO;
    if (type == WKNavigationTypeBackForward && _index >= 0 && _index < (NSInteger)_items.count)
        [self charon_setTitle:_items[_index].charon_title];
    [self charon_setProgress:1];
    [self charon_setLoading:NO];
    if ([delegate respondsToSelector:@selector(webView:didFinishNavigation:)])
        [delegate webView:self didFinishNavigation:navigation];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self charon_refreshTitle];
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
    [self charon_abandonNavigation];
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 101) {
        NSMutableDictionary *info = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
        error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnsupportedURL userInfo:info];
    }
    if ([delegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)])
        [delegate webView:self didFailProvisionalNavigation:navigation withError:error];
}

@end
