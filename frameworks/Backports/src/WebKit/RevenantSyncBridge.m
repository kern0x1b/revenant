#import <dlfcn.h>

#import "RevenantWebKit.h"
#import "RevenantScriptCodec.h"

@interface RevenantSyncProtocol : NSURLProtocol
@end

static NSMapTable *Views(void)
{
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMapTable strongToWeakObjectsMapTable];
        [NSURLProtocol registerClass:[RevenantSyncProtocol class]];
    });
    return table;
}

void RevenantSyncRegister(NSString *token, WKWebView *webView)
{
    @synchronized(Views()) {
        [Views() setObject:webView forKey:token];
    }
}

static WKWebView *ViewForToken(NSString *token)
{
    if (!token.length)
        return nil;
    @synchronized(Views()) {
        return [Views() objectForKey:token];
    }
}

static NSString *TokenOf(NSURL *URL)
{
    BOOL custom = [URL.scheme isEqualToString:RevenantWebKitBridgeScheme] && [URL.host isEqualToString:@"sync"];
    BOOL page = ([URL.scheme isEqualToString:@"http"] || [URL.scheme isEqualToString:@"https"]) && [URL.path hasPrefix:@"/__revenant_sync/"];
    return custom || page ? URL.lastPathComponent : nil;
}

@implementation RevenantSyncProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return request.URL.query.length > 0 && ViewForToken(TokenOf(request.URL)) != nil;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

+ (NSString *)answerForView:(WKWebView *)view message:(NSDictionary *)message
{
    if ([NSThread isMainThread])
        return [view revenant_answerSynchronously:message] ?: @"0";
    void (*callDelegate)(NSInvocation *) = dlsym(RTLD_DEFAULT, "WebThreadCallDelegate");
    if (!callDelegate)
        return @"0";
    SEL selector = @selector(revenant_answerSynchronously:);
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[WKWebView instanceMethodSignatureForSelector:selector]];
    NSDictionary *argument = message;
    invocation.target = view;
    invocation.selector = selector;
    [invocation setArgument:&argument atIndex:2];
    callDelegate(invocation);
    __unsafe_unretained NSString *result = nil;
    [invocation getReturnValue:&result];
    return result ?: @"0";
}

- (void)startLoading
{
    NSString *token = TokenOf(self.request.URL);
    WKWebView *view = ViewForToken(token);
    BOOL valid = NO;
    NSDictionary *message = RevenantCodecParsed([self.request.URL.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding], &valid);
    NSString *answer = @"0";
    if (view && valid && [message isKindOfClass:[NSDictionary class]] && [message[@"k"] isEqual:token])
        answer = [RevenantSyncProtocol answerForView:view message:message];
    NSData *data = [answer dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"text/plain", @"Cache-Control": @"no-store"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
}

@end
