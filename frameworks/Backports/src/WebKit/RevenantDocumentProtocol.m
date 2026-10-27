#import "RevenantDocument.h"

static NSString *const TokenKey = @"RevenantDocumentToken";
static NSString *const InnerKey = @"RevenantDocumentInner";

static NSMapTable *Sources(void)
{
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMapTable strongToWeakObjectsMapTable];
    });
    return table;
}

static id<RevenantDocumentSource> SourceForToken(NSString *token)
{
    @synchronized(Sources()) {
        return [Sources() objectForKey:token];
    }
}

static NSString *RandomToken(void)
{
    unsigned char bytes[16];
    arc4random_buf(bytes, sizeof bytes);
    NSMutableString *token = [NSMutableString string];
    for (NSUInteger index = 0; index < sizeof bytes; index++)
        [token appendFormat:@"%02x", bytes[index]];
    return token;
}

static NSString *HeaderValue(NSDictionary *headers, NSString *name)
{
    for (NSString *key in headers) {
        if ([key.lowercaseString isEqualToString:name])
            return headers[key];
    }
    return nil;
}

static BOOL IsWebURL(NSURL *URL)
{
    NSString *scheme = URL.scheme.lowercaseString;
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

@interface RevenantDocumentProtocol : NSURLProtocol <NSURLConnectionDataDelegate>
@end

@implementation RevenantDocumentProtocol {
    NSURLConnection *_connection;
    NSString *_token;
    id<RevenantDocumentSource> _source;
    NSHTTPURLResponse *_response;
    NSMutableData *_body;
    BOOL _buffering;
    NSURLAuthenticationChallenge *_challenge;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if (!IsWebURL(request.URL) || [NSURLProtocol propertyForKey:InnerKey inRequest:request])
        return NO;
    NSString *token = [NSURLProtocol propertyForKey:TokenKey inRequest:request];
    return [token isKindOfClass:[NSString class]] && SourceForToken(token) != nil;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    _token = [NSURLProtocol propertyForKey:TokenKey inRequest:self.request];
    _source = SourceForToken(_token);
    NSMutableURLRequest *inner = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:InnerKey inRequest:inner];
    _connection = [[NSURLConnection alloc] initWithRequest:inner delegate:self];
}

- (void)stopLoading
{
    [_connection cancel];
    _connection = nil;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (!response)
        return request;
    NSMutableURLRequest *next = [request mutableCopy];
    [NSURLProtocol removePropertyForKey:InnerKey inRequest:next];
    RevenantDocumentTagRequest(next, _token);
    [connection cancel];
    _connection = nil;
    [self.client URLProtocol:self wasRedirectedToRequest:next redirectResponse:response];
    return nil;
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    return YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    _challenge = challenge;
    NSURLAuthenticationChallenge *outer = [[NSURLAuthenticationChallenge alloc] initWithAuthenticationChallenge:challenge sender:(id<NSURLAuthenticationChallengeSender>)self];
    [self.client URLProtocol:self didReceiveAuthenticationChallenge:outer];
}

- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSURLAuthenticationChallenge *inner = _challenge;
    _challenge = nil;
    [inner.sender useCredential:credential forAuthenticationChallenge:inner];
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSURLAuthenticationChallenge *inner = _challenge;
    _challenge = nil;
    [inner.sender continueWithoutCredentialForAuthenticationChallenge:inner];
}

- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSURLAuthenticationChallenge *inner = _challenge;
    _challenge = nil;
    [inner.sender cancelAuthenticationChallenge:inner];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _response = (NSHTTPURLResponse *)response;
    _body = [NSMutableData data];
    _buffering = _source && _response.statusCode == 200 && [_response.MIMEType.lowercaseString isEqualToString:@"text/html"];
    if (!_buffering)
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_buffering)
        [_body appendData:data];
    else
        [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_buffering)
        [self finishDocument];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)finishDocument
{
    NSArray<NSString *> *scripts = [_source revenant_documentStartScripts];
    NSData *output = RevenantDocumentRewrite(_body, HeaderValue(_response.allHeaderFields, @"content-encoding"), _response.textEncodingName, scripts);
    if (!output) {
        [self.client URLProtocol:self didReceiveResponse:_response cacheStoragePolicy:NSURLCacheStorageAllowed];
        [self.client URLProtocol:self didLoadData:_body];
        return;
    }
    [_source revenant_documentDidInject];
    [self.client URLProtocol:self didReceiveResponse:[self rewrittenResponse:output.length scripts:scripts] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:output];
}

- (NSHTTPURLResponse *)rewrittenResponse:(NSUInteger)length scripts:(NSArray<NSString *> *)scripts
{
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    [_response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
        NSString *lowercase = name.lowercaseString;
        if ([lowercase isEqualToString:@"content-encoding"] || [lowercase isEqualToString:@"content-length"])
            return;
        if ([lowercase isEqualToString:@"content-security-policy"])
            value = RevenantDocumentCSPWithHashes(value, scripts);
        headers[name] = value;
    }];
    headers[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)length];
    return [[NSHTTPURLResponse alloc] initWithURL:_response.URL statusCode:_response.statusCode HTTPVersion:@"HTTP/1.1" headerFields:headers];
}

@end

NSString *RevenantDocumentRegister(id<RevenantDocumentSource> source)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSURLProtocol registerClass:[RevenantDocumentProtocol class]];
    });
    NSString *token = RandomToken();
    @synchronized(Sources()) {
        [Sources() setObject:source forKey:token];
    }
    return token;
}

void RevenantDocumentTagRequest(NSMutableURLRequest *request, NSString *token)
{
    [NSURLProtocol setProperty:token forKey:TokenKey inRequest:request];
}
