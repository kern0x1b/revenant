#if defined(REVENANT_HOST_BUILD)
#define WKDownload WKDownloadRevenant
#endif

#import <WebKit/WebKit.h>

static NSString *const ResumeURLKey = @"URL";
static NSString *const ResumeOffsetKey = @"Offset";
static NSString *const ResumePathKey = @"Path";

static BOOL AcceptsRanges(NSHTTPURLResponse *response)
{
    for (NSString *name in response.allHeaderFields) {
        if ([name.lowercaseString isEqualToString:@"accept-ranges"])
            return [[response.allHeaderFields[name] lowercaseString] rangeOfString:@"bytes"].location != NSNotFound;
    }
    return NO;
}

@implementation WKDownload {
    __weak id<WKDownloadDelegate> _delegate;
    __weak WKWebView *_webView;
    NSURLRequest *_request;
    NSProgress *_progress;
    NSURLConnection *_connection;
    NSHTTPURLResponse *_response;
    NSFileHandle *_file;
    NSURL *_destination;
    NSString *_resumePath;
    NSMutableData *_pending;
    long long _offset;
    long long _received;
    BOOL _partial;
    BOOL _deciding;
    BOOL _finished;
    BOOL _done;
    void (^_decision)(BOOL allowed);
}

+ (instancetype)revenant_downloadWithRequest:(NSURLRequest *)request webView:(WKWebView *)webView
{
    WKDownload *download = [[self alloc] init];
    download->_request = [request copy];
    download->_webView = webView;
    download->_progress = [NSProgress progressWithTotalUnitCount:0];
    return download;
}

+ (instancetype)revenant_resumeWithData:(NSData *)data webView:(WKWebView *)webView
{
    NSDictionary *state = data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL] : nil;
    NSURL *URL = [NSURL URLWithString:state[ResumeURLKey]];
    NSNumber *offset = state[ResumeOffsetKey];
    if (!URL || ![offset isKindOfClass:[NSNumber class]] || offset.longLongValue <= 0)
        return nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:[NSString stringWithFormat:@"bytes=%lld-", offset.longLongValue] forHTTPHeaderField:@"Range"];
    WKDownload *download = [self revenant_downloadWithRequest:request webView:webView];
    download->_offset = offset.longLongValue;
    download->_resumePath = state[ResumePathKey];
    return download;
}

- (NSURLRequest *)originalRequest
{
    return _request;
}

- (WKWebView *)webView
{
    return _webView;
}

- (id<WKDownloadDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<WKDownloadDelegate>)delegate
{
    _delegate = delegate;
}

- (BOOL)isUserInitiated
{
    return NO;
}

- (WKFrameInfo *)originatingFrame
{
    return nil;
}

- (NSProgress *)progress
{
    return _progress;
}

- (void)cancel:(void (^)(NSData *resumeData))completionHandler
{
    NSData *resumeData = [self revenant_resumeData];
    [self revenant_stop];
    [self revenant_failWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil] resumeData:resumeData];
    if (completionHandler)
        completionHandler(resumeData);
}

- (void)revenant_start
{
    if (_connection || _done)
        return;
    _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self startImmediately:NO];
    [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_connection start];
}

- (void)revenant_stop
{
    _done = YES;
    [_connection cancel];
    _connection = nil;
    [_file closeFile];
    _file = nil;
}

- (void)revenant_failWithError:(NSError *)error resumeData:(NSData *)resumeData
{
    id<WKDownloadDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(download:didFailWithError:resumeData:)])
        [delegate download:self didFailWithError:error resumeData:resumeData];
}

- (void)revenant_finish
{
    _done = YES;
    _connection = nil;
    [_file closeFile];
    _file = nil;
    _progress.totalUnitCount = _offset + _received;
    _progress.completedUnitCount = _offset + _received;
    id<WKDownloadDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(downloadDidFinish:)])
        [delegate downloadDidFinish:self];
}

- (NSData *)revenant_resumeData
{
    if (!_destination || _received == 0 || ![_response isKindOfClass:[NSHTTPURLResponse class]] || !AcceptsRanges(_response))
        return nil;
    NSDictionary *state = @{ResumeURLKey: _request.URL.absoluteString, ResumeOffsetKey: @(_offset + _received), ResumePathKey: _destination.path};
    return [NSPropertyListSerialization dataWithPropertyList:state format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
}

- (void)revenant_updateProgress
{
    _progress.completedUnitCount = _offset + _received;
}

- (void)revenant_setDecision:(void (^)(BOOL allowed))decision
{
    _decision = [decision copy];
}

- (void)revenant_settle:(BOOL)allowed
{
    void (^decision)(BOOL) = _decision;
    _decision = nil;
    if (decision)
        decision(allowed);
}

- (void)revenant_decided:(NSURL *)destination
{
    _deciding = NO;
    if (_done)
        return;
    NSString *path = destination.path;
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL usable = destination != nil;
    if (usable && _offset > 0) {
        long long size = [[manager attributesOfItemAtPath:path error:NULL][NSFileSize] longLongValue];
        usable = [path isEqualToString:_resumePath] && size == _offset;
    } else if (usable) {
        usable = [manager createFileAtPath:path contents:nil attributes:nil];
    }
    if (usable) {
        _file = [NSFileHandle fileHandleForWritingAtPath:path];
        usable = _file != nil;
        [_file seekToEndOfFile];
    }
    if (!usable) {
        [self revenant_settle:NO];
        [self revenant_stop];
        [self revenant_failWithError:[NSError errorWithDomain:NSURLErrorDomain code:destination ? NSURLErrorCannotCreateFile : NSURLErrorCancelled userInfo:nil] resumeData:nil];
        return;
    }
    _destination = destination;
    if (_pending.length) {
        [_file writeData:_pending];
        _pending = nil;
    }
    [self revenant_settle:YES];
    if (_finished)
        [self revenant_finish];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (_done)
        return;
    _response = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
    _partial = _response.statusCode == 206;
    if (_offset > 0 && !_partial)
        _offset = 0;
    if (response.expectedContentLength > 0)
        _progress.totalUnitCount = _offset + response.expectedContentLength;
    NSString *name = response.suggestedFilename.length ? response.suggestedFilename : @"download";
    id<WKDownloadDelegate> delegate = _delegate;
    if (![delegate respondsToSelector:@selector(download:decideDestinationUsingResponse:suggestedFilename:completionHandler:)]) {
        [self revenant_decided:nil];
        return;
    }
    _deciding = YES;
    __weak WKDownload *weak = self;
    [delegate download:self decideDestinationUsingResponse:response suggestedFilename:name completionHandler:^(NSURL *destination) {
        if ([NSThread isMainThread]) {
            [weak revenant_decided:destination];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weak revenant_decided:destination];
            });
        }
    }];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_done)
        return;
    _received += data.length;
    if (_deciding || !_file) {
        if (!_pending)
            _pending = [NSMutableData data];
        [_pending appendData:data];
    } else {
        [_file writeData:data];
    }
    [self revenant_updateProgress];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_done)
        return;
    if (_deciding) {
        _finished = YES;
        return;
    }
    [self revenant_finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (_done)
        return;
    NSData *resumeData = [self revenant_resumeData];
    [self revenant_stop];
    [self revenant_failWithError:error resumeData:resumeData];
}

@end
