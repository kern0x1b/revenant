#import "RevenantWebKit.h"

@implementation WKUserScript {
    NSString *_source;
    WKUserScriptInjectionTime _injectionTime;
    BOOL _forMainFrameOnly;
}

- (instancetype)initWithSource:(NSString *)source injectionTime:(WKUserScriptInjectionTime)injectionTime forMainFrameOnly:(BOOL)forMainFrameOnly
{
    self = [super init];
    if (self) {
        _source = [source copy];
        _injectionTime = injectionTime;
        _forMainFrameOnly = forMainFrameOnly;
    }
    return self;
}

- (NSString *)source
{
    return _source;
}

- (WKUserScriptInjectionTime)injectionTime
{
    return _injectionTime;
}

- (BOOL)isForMainFrameOnly
{
    return _forMainFrameOnly;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation WKScriptMessage {
    id _body;
    __weak WKWebView *_webView;
    WKFrameInfo *_frameInfo;
    NSString *_name;
}

+ (instancetype)revenant_messageWithBody:(id)body name:(NSString *)name webView:(WKWebView *)webView mainFrame:(BOOL)mainFrame
{
    WKScriptMessage *message = [self alloc];
    message->_body = body;
    message->_name = [name copy];
    message->_webView = webView;
    message->_frameInfo = [WKFrameInfo revenant_frameWithMainFrame:mainFrame request:nil];
    return message;
}

- (id)body
{
    return _body;
}

- (WKWebView *)webView
{
    return _webView;
}

- (WKFrameInfo *)frameInfo
{
    return _frameInfo;
}

- (NSString *)name
{
    return _name;
}

@end

@implementation WKUserContentController {
    NSMutableArray<WKUserScript *> *_scripts;
    NSMutableDictionary<NSString *, id<WKScriptMessageHandler>> *_handlers;
    NSHashTable *_hosts;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _scripts = [NSMutableArray array];
        _handlers = [NSMutableDictionary dictionary];
        _hosts = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (void)revenant_changed
{
    for (id<RevenantWebKitScriptHost> host in _hosts.allObjects)
        [host revenant_scriptsDidChange];
}

- (NSArray<WKUserScript *> *)userScripts
{
    return [_scripts copy];
}

- (NSArray<WKUserScript *> *)revenant_scripts
{
    return [_scripts copy];
}

- (NSArray<NSString *> *)revenant_handlerNames
{
    return _handlers.allKeys;
}

- (id<WKScriptMessageHandler>)revenant_handlerNamed:(NSString *)name
{
    return _handlers[name];
}

- (void)revenant_attach:(id<RevenantWebKitScriptHost>)host
{
    [_hosts addObject:host];
}

- (void)addUserScript:(WKUserScript *)userScript
{
    [_scripts addObject:userScript];
    [self revenant_changed];
}

- (void)removeAllUserScripts
{
    [_scripts removeAllObjects];
    [self revenant_changed];
}

- (void)addScriptMessageHandler:(id<WKScriptMessageHandler>)scriptMessageHandler name:(NSString *)name
{
    if (_handlers[name])
        [NSException raise:NSInvalidArgumentException format:@"Attempt to add script message handler with name '%@' when one already exists.", name];
    _handlers[name] = scriptMessageHandler;
    [self revenant_changed];
}

- (void)removeScriptMessageHandlerForName:(NSString *)name
{
    [_handlers removeObjectForKey:name];
    [self revenant_changed];
}

@end
