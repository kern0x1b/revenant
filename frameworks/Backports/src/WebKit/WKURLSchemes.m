#import "RevenantURLSchemes.h"

@interface RevenantSchemeRegistration : NSObject

@property (nonatomic, strong) id<WKURLSchemeHandler> handler;
@property (nonatomic, weak) WKWebView *webView;

@end

@implementation RevenantSchemeRegistration

@synthesize handler = _handler;
@synthesize webView = _webView;

@end

@interface RevenantWebSchemeTask : NSObject <WKURLSchemeTask>

- (instancetype)initWithRequest:(NSURLRequest *)request protocol:(NSURLProtocol *)protocol;
- (BOOL)revenant_active;
- (void)revenant_stop;

@end

@implementation RevenantWebSchemeTask {
    NSURLRequest *_request;
    NSURLProtocol *_protocol;
    BOOL _stopped;
}

- (instancetype)initWithRequest:(NSURLRequest *)request protocol:(NSURLProtocol *)protocol
{
    if ((self = [super init])) {
        _request = request;
        _protocol = protocol;
    }
    return self;
}

- (NSURLRequest *)request
{
    return _request;
}

- (BOOL)revenant_active
{
    return !_stopped;
}

- (void)revenant_stop
{
    _stopped = YES;
    _protocol = nil;
}

- (void)didReceiveResponse:(NSURLResponse *)response
{
    if (!_stopped) {
        [_protocol.client URLProtocol:_protocol didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    }
}

- (void)didReceiveData:(NSData *)data
{
    if (!_stopped) {
        [_protocol.client URLProtocol:_protocol didLoadData:data];
    }
}

- (void)didFinish
{
    if (!_stopped) {
        [_protocol.client URLProtocolDidFinishLoading:_protocol];
        [self revenant_stop];
    }
}

- (void)didFailWithError:(NSError *)error
{
    if (!_stopped) {
        [_protocol.client URLProtocol:_protocol didFailWithError:error];
        [self revenant_stop];
    }
}

@end

static NSMutableDictionary *revenant_schemes;

static NSString *revenant_scheme_key(NSURL *URL)
{
    return URL.scheme.lowercaseString;
}

void revenant_web_bind_scheme(NSString *scheme, id<WKURLSchemeHandler> handler, WKWebView *webView)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_schemes = [NSMutableDictionary dictionary];
    });
    NSString *key = scheme.lowercaseString;
    if (!handler) {
        [revenant_schemes removeObjectForKey:key];
        return;
    }
    RevenantSchemeRegistration *registration = [[RevenantSchemeRegistration alloc] init];
    registration.handler = handler;
    registration.webView = webView;
    revenant_schemes[key] = registration;
    [NSURLProtocol registerClass:[RevenantWebURLProtocol class]];
}

@implementation RevenantWebURLProtocol {
    RevenantSchemeRegistration *_registration;
    RevenantWebSchemeTask *_task;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if (revenant_schemes.count == 0) {
        return NO;
    }
    return revenant_schemes[revenant_scheme_key(request.URL)] != nil;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    _registration = revenant_schemes[revenant_scheme_key(self.request.URL)];
    if (!_registration) {
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnsupportedURL userInfo:nil]];
        return;
    }
    _task = [[RevenantWebSchemeTask alloc] initWithRequest:self.request protocol:self];
    [_registration.handler webView:_registration.webView startURLSchemeTask:_task];
}

- (void)stopLoading
{
    BOOL active = [_task revenant_active];
    [_task revenant_stop];
    if (active) {
        [_registration.handler webView:_registration.webView stopURLSchemeTask:_task];
    }
    _task = nil;
    _registration = nil;
}

@end
