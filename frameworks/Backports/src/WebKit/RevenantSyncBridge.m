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

- (void)startLoading
{
    NSString *token = TokenOf(self.request.URL);
    WKWebView *view = ViewForToken(token);
    BOOL valid = NO;
    NSDictionary *message = RevenantCodecParsed([self.request.URL.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding], &valid);
    __block NSString *answer = @"0";
    void (^answerMessage)(void) = ^{
        if (view && valid && [message isKindOfClass:[NSDictionary class]] && [message[@"k"] isEqual:token])
            answer = [view revenant_answerSynchronously:message] ?: @"0";
    };
    if ([NSThread isMainThread])
        answerMessage();
    else
        dispatch_sync(dispatch_get_main_queue(), answerMessage);
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
