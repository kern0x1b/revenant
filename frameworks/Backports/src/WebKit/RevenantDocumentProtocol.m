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
    if (!token)
        return nil;
    @synchronized(Sources()) {
        return [Sources() objectForKey:token];
    }
}

static NSMutableDictionary *Expectations(void)
{
    static NSMutableDictionary *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMutableDictionary dictionary];
    });
    return table;
}

static NSString *ExpectedToken(NSURLRequest *request, BOOL consume)
{
    if (request.mainDocumentURL && ![request.mainDocumentURL isEqual:request.URL])
        return nil;
    @synchronized(Expectations()) {
        NSString *key = request.URL.absoluteString;
        NSString *token = Expectations()[key];
        if (token && consume)
            [Expectations() removeObjectForKey:key];
        return token;
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

BOOL RevenantDocumentIsWebURL(NSURL *URL)
{
    NSString *scheme = URL.scheme.lowercaseString;
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

BOOL RevenantDocumentIsTagged(NSURLRequest *request)
{
    return [NSURLProtocol propertyForKey:TokenKey inRequest:request] != nil;
}

NSURLRequest *RevenantDocumentTaggedCopy(NSURLRequest *request, NSString *token)
{
    if (!RevenantDocumentIsWebURL(request.URL))
        return request;
    NSMutableURLRequest *tagged = [request mutableCopy];
    RevenantDocumentTagRequest(tagged, token);
    return tagged;
}

NSURLRequest *RevenantDocumentInnerCopy(NSURLRequest *request)
{
    NSMutableURLRequest *inner = [request mutableCopy];
    [NSURLProtocol removePropertyForKey:TokenKey inRequest:inner];
    [NSURLProtocol setProperty:@YES forKey:InnerKey inRequest:inner];
    return inner;
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
    BOOL _deciding;
    BOOL _finished;
    BOOL _stopped;
    NSThread *_thread;
    NSURLAuthenticationChallenge *_challenge;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if (!RevenantDocumentIsWebURL(request.URL) || [NSURLProtocol propertyForKey:InnerKey inRequest:request])
        return NO;
    NSString *token = [NSURLProtocol propertyForKey:TokenKey inRequest:request];
    if (![token isKindOfClass:[NSString class]])
        token = ExpectedToken(request, NO);
    return SourceForToken(token) != nil;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    _token = [NSURLProtocol propertyForKey:TokenKey inRequest:self.request];
    if (![_token isKindOfClass:[NSString class]])
        _token = ExpectedToken(self.request, YES);
    _source = SourceForToken(_token);
    _thread = [NSThread currentThread];
    NSMutableURLRequest *inner = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:InnerKey inRequest:inner];
    _connection = [[NSURLConnection alloc] initWithRequest:inner delegate:self];
}

- (void)stopLoading
{
    _stopped = YES;
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
    if (!_source) {
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
        return;
    }
    _deciding = YES;
    NSThread *thread = _thread;
    [_source revenant_decideResponse:response completion:^(NSInteger policy) {
        [self performSelector:@selector(decided:) onThread:thread withObject:@(policy) waitUntilDone:NO];
    }];
}

- (void)decided:(NSNumber *)answer
{
    NSInteger policy = answer.integerValue;
    if (_stopped || !_deciding)
        return;
    _deciding = NO;
    if (policy == 2) {
        _stopped = YES;
        [_connection cancel];
        _connection = nil;
        [_source revenant_downloadResponse:_response request:self.request];
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSURLErrorFailingURLErrorKey: _response.URL ?: self.request.URL}]];
        return;
    }
    if (policy == 0) {
        [_connection cancel];
        _connection = nil;
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSURLErrorFailingURLErrorKey: _response.URL ?: self.request.URL}]];
        return;
    }
    _buffering = _response.statusCode == 200 && [_response.MIMEType.lowercaseString isEqualToString:@"text/html"];
    if (_buffering) {
        if (_finished)
            [self completeDocument];
        return;
    }
    [self.client URLProtocol:self didReceiveResponse:_response cacheStoragePolicy:NSURLCacheStorageAllowed];
    [self.client URLProtocol:self didLoadData:_body];
    _body = [NSMutableData data];
    if (_finished)
        [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_deciding || _buffering)
        [_body appendData:data];
    else
        [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    _finished = YES;
    if (_deciding)
        return;
    if (_buffering) {
        [self completeDocument];
        return;
    }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)completeDocument
{
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

void RevenantDocumentExpect(NSString *token, NSURL *URL)
{
    @synchronized(Expectations()) {
        Expectations()[URL.absoluteString] = token;
    }
}

void RevenantDocumentForget(NSString *token)
{
    @synchronized(Expectations()) {
        for (NSString *key in [Expectations() allKeysForObject:token])
            [Expectations() removeObjectForKey:key];
    }
}
