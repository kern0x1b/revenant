#import "CharonWebKit.h"

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

+ (instancetype)charon_messageWithBody:(id)body name:(NSString *)name webView:(WKWebView *)webView mainFrame:(BOOL)mainFrame
{
    WKScriptMessage *message = [self alloc];
    message->_body = body;
    message->_name = [name copy];
    message->_webView = webView;
    message->_frameInfo = [WKFrameInfo charon_frameWithMainFrame:mainFrame request:nil];
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

- (void)charon_changed
{
    for (id<CharonWebKitScriptHost> host in _hosts.allObjects)
        [host charon_scriptsDidChange];
}

- (NSArray<WKUserScript *> *)userScripts
{
    return [_scripts copy];
}

- (NSArray<WKUserScript *> *)charon_scripts
{
    return [_scripts copy];
}

- (NSArray<NSString *> *)charon_handlerNames
{
    return _handlers.allKeys;
}

- (id<WKScriptMessageHandler>)charon_handlerNamed:(NSString *)name
{
    return _handlers[name];
}

- (void)charon_attach:(id<CharonWebKitScriptHost>)host
{
    [_hosts addObject:host];
}

- (void)addUserScript:(WKUserScript *)userScript
{
    [_scripts addObject:userScript];
    [self charon_changed];
}

- (void)removeAllUserScripts
{
    [_scripts removeAllObjects];
    [self charon_changed];
}

- (void)addScriptMessageHandler:(id<WKScriptMessageHandler>)scriptMessageHandler name:(NSString *)name
{
    if (_handlers[name])
        [NSException raise:NSInvalidArgumentException format:@"Attempt to add script message handler with name '%@' when one already exists.", name];
    _handlers[name] = scriptMessageHandler;
    [self charon_changed];
}

- (void)removeScriptMessageHandlerForName:(NSString *)name
{
    [_handlers removeObjectForKey:name];
    [self charon_changed];
}

@end
