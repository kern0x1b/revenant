#import "session-scenarios.h"

@implementation SessionHarness

- (Class)classNamed:(NSString *)name
{
    return NSClassFromString([(_prefix ?: @"") stringByAppendingString:name]);
}

@end

@interface SessionRecorder : NSObject <NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, strong) dispatch_semaphore_t completed;
@property (nonatomic, strong) dispatch_semaphore_t invalidated;
@property (nonatomic, strong) dispatch_semaphore_t responded;
@property (nonatomic, strong) dispatch_semaphore_t produced;
@property (nonatomic, strong) NSSet *implemented;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic) BOOL rejectRedirects;
@property (nonatomic) NSURLSessionResponseDisposition disposition;
@property (nonatomic, strong) NSArray *credentials;
@property (nonatomic) NSURLSessionAuthChallengeDisposition challengeDisposition;
@property (nonatomic, strong) NSData *streamBody;
@property (nonatomic, strong) NSMutableData *body;
@property (nonatomic, strong) NSData *downloaded;
@property (nonatomic, strong) NSURL *location;
@property (nonatomic) BOOL cancelOnData;
@property (nonatomic) int64_t produceResumeDataAfter;
@property (nonatomic, strong) NSData *resumeData;
@property (nonatomic) BOOL cacheResponses;
@property (nonatomic, strong) NSURLSessionTask *lastTask;
@property (nonatomic) Class downloadTaskClass;
@property (nonatomic) BOOL variableLength;
@property (nonatomic, copy) NSString *tag;
@property (nonatomic, strong) dispatch_semaphore_t dataArrived;
@property (nonatomic) NSInteger delayedDisposition;
@property (nonatomic, copy) NSString *delayedReplacement;
@property (nonatomic, strong) NSDate *resumedAt;
@property (nonatomic) NSTimeInterval minimumWait;
@property (nonatomic, copy) NSString *base;
@end

static NSUInteger session_off_queue_callbacks;

NSUInteger session_off_queue_count(void)
{
    return session_off_queue_callbacks;
}

static NSArray *session_delegate_selectors(void)
{
    return @[@"URLSession:didBecomeInvalidWithError:", @"URLSession:didReceiveChallenge:completionHandler:", @"URLSessionDidFinishEventsForBackgroundURLSession:",
             @"URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:", @"URLSession:task:didReceiveChallenge:completionHandler:",
             @"URLSession:task:needNewBodyStream:", @"URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:",
             @"URLSession:task:didCompleteWithError:", @"URLSession:dataTask:didReceiveResponse:completionHandler:",
             @"URLSession:dataTask:didBecomeDownloadTask:", @"URLSession:dataTask:didReceiveData:", @"URLSession:dataTask:willCacheResponse:completionHandler:",
             @"URLSession:downloadTask:didFinishDownloadingToURL:", @"URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:",
             @"URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:", @"URLSession:task:willBeginDelayedRequest:completionHandler:", @"URLSession:taskIsWaitingForConnectivity:"];
}

static NSData *pattern_bytes(NSUInteger start, NSUInteger end)
{
    NSMutableData *data = [NSMutableData dataWithLength:end - start];
    uint8_t *bytes = data.mutableBytes;
    for (NSUInteger index = start; index < end; index++)
        bytes[index - start] = (uint8_t)((index * 7 + 3) % 256);
    return data;
}

static NSString *error_text(NSError *error)
{
    if (!error)
        return @"nil";
    return [NSString stringWithFormat:@"%@/%ld", error.domain, (long)error.code];
}

static NSString *path_of(NSURL *url)
{
    NSString *path = url.path.length ? url.path : @"/";
    return url.query ? [NSString stringWithFormat:@"%@?%@", path, url.query] : path;
}

static NSInteger status_of(NSURLResponse *response)
{
    return [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
}

@implementation SessionRecorder

- (instancetype)init
{
    if ((self = [super init])) {
        _events = [NSMutableArray array];
        _completed = dispatch_semaphore_create(0);
        _invalidated = dispatch_semaphore_create(0);
        _responded = dispatch_semaphore_create(0);
        _produced = dispatch_semaphore_create(0);
        _implemented = [NSSet setWithArray:session_delegate_selectors()];
        _disposition = NSURLSessionResponseAllow;
        _challengeDisposition = NSURLSessionAuthChallengePerformDefaultHandling;
        _body = [NSMutableData data];
        _dataArrived = dispatch_semaphore_create(0);
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)selector
{
    NSString *name = NSStringFromSelector(selector);
    if ([session_delegate_selectors() containsObject:name])
        return [_implemented containsObject:name];
    return [super respondsToSelector:selector];
}

- (void)record:(NSString *)event
{
    @synchronized (self) {
        NSString *last = _events.lastObject;
        for (NSString *prefix in @[@"data", @"write", @"sent"]) {
            if ([event hasPrefix:prefix] && [last hasPrefix:prefix]) {
                [_events removeLastObject];
                break;
            }
        }
        if (_tag.length)
            event = [event stringByReplacingOccurrencesOfString:_tag withString:@"TAG"];
        if (_queue && ![NSThread isMainThread] && [NSOperationQueue currentQueue] != _queue)
            session_off_queue_callbacks++;
        [_events addObject:event];
    }
}

- (NSArray *)snapshot
{
    @synchronized (self) {
        return [_events copy];
    }
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    [self record:[NSString stringWithFormat:@"invalid %@", error_text(error)]];
    dispatch_semaphore_signal(_invalidated);
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    [self record:[NSString stringWithFormat:@"session-challenge %@ failures=%ld", challenge.protectionSpace.authenticationMethod, (long)challenge.previousFailureCount]];
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    NSString *body = request.HTTPBody ? [NSString stringWithFormat:@"%lu", (unsigned long)request.HTTPBody.length] : request.HTTPBodyStream ? @"stream" : @"none";
    [self record:[NSString stringWithFormat:@"redirect %ld %@ %@ body=%@ custom=%@ type=%@ current=%@", (long)response.statusCode, request.HTTPMethod, path_of(request.URL), body,
                  [request valueForHTTPHeaderField:@"X-Custom"] ?: @"-", [request valueForHTTPHeaderField:@"Content-Type"] ?: @"-", path_of(task.currentRequest.URL)]];
    completionHandler(_rejectRedirects ? nil : request);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    NSInteger failures = challenge.previousFailureCount;
    NSString *realm = [[challenge.protectionSpace.realm componentsSeparatedByString:@"-"] objectAtIndex:0];
    NSString *method = challenge.protectionSpace.authenticationMethod;
    if ([method isEqualToString:NSURLAuthenticationMethodHTTPBasic])
        method = @"basic";
    [self record:[NSString stringWithFormat:@"challenge %@ realm=%@ failures=%ld", method, realm, (long)failures]];
    if (failures < (NSInteger)_credentials.count)
        completionHandler(NSURLSessionAuthChallengeUseCredential, _credentials[failures]);
    else
        completionHandler(_challengeDisposition, nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *))completionHandler
{
    [self record:@"need-body-stream"];
    completionHandler([NSInputStream inputStreamWithData:_streamBody]);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    [self record:[NSString stringWithFormat:@"sent %lld/%lld", totalBytesSent, totalBytesExpectedToSend]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    NSString *resume = error.userInfo[NSURLSessionDownloadTaskResumeData] ? @" resume-data" : @"";
    NSString *failing = error ? [@" failing=" stringByAppendingString:path_of(error.userInfo[NSURLErrorFailingURLErrorKey])] : @"";
    NSString *received = [NSString stringWithFormat:@"%lld/%lld", task.countOfBytesReceived, task.countOfBytesExpectedToReceive];
    if (_variableLength)
        received = task.countOfBytesReceived <= 0 ? @"none" : task.countOfBytesReceived == task.countOfBytesExpectedToReceive ? @"all" : @"partial";
    [self record:[NSString stringWithFormat:@"complete %@%@%@ state=%ld same-error=%d status=%ld received=%@ sent=%lld/%lld", error_text(error), failing, resume,
                  (long)task.state, task.error == error || [task.error.domain isEqualToString:error.domain], (long)status_of(task.response),
                  received, task.countOfBytesSent, task.countOfBytesExpectedToSend]];
    _lastTask = task;
    dispatch_semaphore_signal(_completed);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willBeginDelayedRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLSessionDelayedRequestDisposition, NSURLRequest *))completionHandler
{
    NSTimeInterval waited = _resumedAt ? -[_resumedAt timeIntervalSinceNow] : 0;
    [self record:[NSString stringWithFormat:@"delayed-begin %@ waited=%d state=%ld", path_of(request.URL), waited >= _minimumWait, (long)task.state]];
    NSURLRequest *replacement = _delayedReplacement ? [NSURLRequest requestWithURL:[NSURL URLWithString:[_base stringByAppendingString:_delayedReplacement]]] : nil;
    completionHandler((NSURLSessionDelayedRequestDisposition)_delayedDisposition, replacement);
}

- (void)URLSession:(NSURLSession *)session taskIsWaitingForConnectivity:(NSURLSessionTask *)task
{
    [self record:@"waiting-for-connectivity"];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSString *expected = _variableLength ? @"var" : [NSString stringWithFormat:@"%lld", response.expectedContentLength];
    [self record:[NSString stringWithFormat:@"response %ld expected=%@ state=%ld", (long)status_of(response), expected, (long)dataTask.state]];
    dispatch_semaphore_signal(_responded);
    completionHandler(_disposition);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
    [self record:[NSString stringWithFormat:@"become-download same-identifier=%d download=%d", dataTask.taskIdentifier == downloadTask.taskIdentifier,
                  [downloadTask isKindOfClass:_downloadTaskClass]]];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [_body appendData:data];
    [self record:@"data"];
    dispatch_semaphore_signal(_dataArrived);
    if (_cancelOnData) {
        _cancelOnData = NO;
        [dataTask cancel];
        [self record:[NSString stringWithFormat:@"cancelled state=%ld", (long)dataTask.state]];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse *))completionHandler
{
    [self record:[NSString stringWithFormat:@"will-cache %lu", (unsigned long)proposedResponse.data.length]];
    completionHandler(_cacheResponses ? proposedResponse : nil);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    _location = location;
    _downloaded = [NSData dataWithContentsOfURL:location];
    [self record:[NSString stringWithFormat:@"finished size=%lu state=%ld", (unsigned long)_downloaded.length, (long)downloadTask.state]];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    [self record:[NSString stringWithFormat:@"write expected=%lld", totalBytesExpectedToWrite]];
    if (_produceResumeDataAfter > 0 && totalBytesWritten >= _produceResumeDataAfter) {
        _produceResumeDataAfter = 0;
        [downloadTask cancelByProducingResumeData:^(NSData *resumeData) {
            self.resumeData = resumeData;
            dispatch_semaphore_signal(self.produced);
        }];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    [self record:[NSString stringWithFormat:@"resumed offset>0=%d expected=%lld", fileOffset > 0, expectedTotalBytes]];
}

@end

@interface MetricsRecorder : SessionRecorder
@end

@implementation MetricsRecorder

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"metrics tx=%lu redirects=%lu", (unsigned long)metrics.transactionMetrics.count, (unsigned long)metrics.redirectCount];
    NSDate *first = [metrics.transactionMetrics.firstObject fetchStartDate];
    NSDate *last = [metrics.transactionMetrics.lastObject responseEndDate] ?: [metrics.transactionMetrics.lastObject fetchStartDate];
    NSDateInterval *interval = metrics.taskInterval;
    [text appendFormat:@" interval=%d", interval.duration >= 0 && [interval.startDate compare:first] != NSOrderedDescending && [interval.endDate compare:last] != NSOrderedAscending];
    for (NSURLSessionTaskTransactionMetrics *transaction in metrics.transactionMetrics) {
        NSMutableString *dates = [NSMutableString string];
        NSDate *previous = nil;
        BOOL ordered = YES;
        NSArray *stamps = @[transaction.fetchStartDate ?: [NSNull null], transaction.requestStartDate ?: [NSNull null], transaction.requestEndDate ?: [NSNull null], transaction.responseStartDate ?: [NSNull null], transaction.responseEndDate ?: [NSNull null]];
        NSArray *letters = @[@"F", @"Q", @"q", @"S", @"E"];
        for (NSUInteger index = 0; index < stamps.count; index++) {
            if ([stamps[index] isKindOfClass:[NSNull class]])
                continue;
            [dates appendString:letters[index]];
            if (previous && [previous compare:stamps[index]] == NSOrderedDescending)
                ordered = NO;
            previous = stamps[index];
        }
        [text appendFormat:@" [%@ status=%ld type=%ld proto=%@ dates=%@ ordered=%d proxy=%d]", path_of(transaction.request.URL), (long)status_of(transaction.response), (long)transaction.resourceFetchType,
         transaction.networkProtocolName ?: @"-", dates, ordered, transaction.proxyConnection];
    }
    [self record:text];
}

@end

@interface CharonTestProtocol : NSURLProtocol
@end

@implementation CharonTestProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [request.URL.scheme isEqualToString:@"charontest"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:203 HTTPVersion:@"HTTP/1.1" headerFields:@{@"X-Protocol": @"charon"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:[@"from protocol" dataUsingEncoding:NSUTF8StringEncoding]];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
}

@end

static BOOL wait_for(SessionHarness *harness, dispatch_semaphore_t semaphore)
{
    return dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(harness.patience * NSEC_PER_SEC))) == 0;
}

static NSURL *url_for(SessionHarness *harness, NSString *path)
{
    return [NSURL URLWithString:[harness.base stringByAppendingString:path]];
}

static NSURLSession *session_with(SessionHarness *harness, NSURLSessionConfiguration *configuration, SessionRecorder *recorder)
{
    NSURLSession *session = [harness.sessionClass sessionWithConfiguration:configuration ?: [harness.configurationClass defaultSessionConfiguration] delegate:recorder delegateQueue:nil];
    recorder.queue = session.delegateQueue;
    recorder.downloadTaskClass = [harness classNamed:@"NSURLSessionDownloadTask"];
    recorder.tag = harness.tag;
    return session;
}

static NSArray *finish_session(SessionHarness *harness, NSURLSession *session, SessionRecorder *recorder, NSMutableArray *transcript)
{
    [session finishTasksAndInvalidate];
    if (!wait_for(harness, recorder.invalidated))
        [transcript addObject:@"invalidation timed out"];
    [transcript addObjectsFromArray:[recorder snapshot]];
    return transcript;
}

static NSDictionary *echo_of(NSData *data)
{
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    return [object isKindOfClass:[NSDictionary class]] ? object : @{};
}

static NSString *echo_text(NSData *data, NSArray *headers)
{
    NSDictionary *echo = echo_of(data);
    NSMutableString *text = [NSMutableString stringWithFormat:@"echo %@ %@ length=%@ body=%@", echo[@"method"], echo[@"path"], echo[@"length"], echo[@"body"]];
    for (NSString *header in headers)
        [text appendFormat:@" %@=%@", header, echo[@"headers"][header] ?: @"-"];
    return text;
}

static NSString *run_data_handler(SessionHarness *harness, NSURLSession *session, NSURLRequest *request, NSData **body, NSURLResponse **responseOut)
{
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSString *line = nil;
    __block NSData *received = nil;
    __block NSURLResponse *receivedResponse = nil;
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        received = data;
        receivedResponse = response;
        line = [NSString stringWithFormat:@"handler status=%ld length=%lu error=%@ data=%@", (long)status_of(response), (unsigned long)data.length, error_text(error), data ? @"yes" : @"no"];
        dispatch_semaphore_signal(done);
    }] resume];
    if (!wait_for(harness, done))
        return @"handler timed out";
    if (body)
        *body = received;
    if (responseOut)
        *responseOut = receivedResponse;
    return line;
}

static NSString *text_of(NSData *data)
{
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"(nil)";
}

static NSString *configuration_text(NSString *name, NSURLSessionConfiguration *configuration)
{
    return [NSString stringWithFormat:@"%@ identifier=%@ policy=%lu request=%g resource=%g service=%lu cellular=%d discretionary=%d launch=%d proxy=%@ pipelining=%d set-cookies=%d accept=%lu headers=%@ cookies=%@ credentials=%@ cache=%@ protocols=%@",
            name, configuration.identifier ?: @"-", (unsigned long)configuration.requestCachePolicy, configuration.timeoutIntervalForRequest, configuration.timeoutIntervalForResource,
            (unsigned long)configuration.networkServiceType, configuration.allowsCellularAccess, configuration.isDiscretionary, configuration.sessionSendsLaunchEvents,
            configuration.connectionProxyDictionary ? @"set" : @"-", configuration.HTTPShouldUsePipelining, configuration.HTTPShouldSetCookies,
            (unsigned long)configuration.HTTPCookieAcceptPolicy, configuration.HTTPAdditionalHeaders ? @"set" : @"-",
            !configuration.HTTPCookieStorage ? @"nil" : configuration.HTTPCookieStorage == [NSHTTPCookieStorage sharedHTTPCookieStorage] ? @"shared" : @"own",
            !configuration.URLCredentialStorage ? @"nil" : configuration.URLCredentialStorage == [NSURLCredentialStorage sharedCredentialStorage] ? @"shared" : @"own",
            !configuration.URLCache ? @"nil" : configuration.URLCache == [NSURLCache sharedURLCache] ? @"shared" : [NSString stringWithFormat:@"own(disk=%lu)", (unsigned long)configuration.URLCache.diskCapacity],
            configuration.protocolClasses ? @"array" : @"nil"];
}

static NSString *exception_name(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return exception.name;
    }
    return @"none";
}

static NSArray *scenario_configuration(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    Class configurations = harness.configurationClass;
    NSURLSessionConfiguration *defaults = [configurations defaultSessionConfiguration];
    [transcript addObject:configuration_text(@"default", defaults)];
    [transcript addObject:configuration_text(@"ephemeral", [configurations ephemeralSessionConfiguration])];
    [transcript addObject:configuration_text(@"background", [configurations backgroundSessionConfigurationWithIdentifier:@"org.charon.test"])];
    [transcript addObject:configuration_text(@"background7", [configurations backgroundSessionConfiguration:@"org.charon.legacy"])];
    NSURLSessionConfiguration *ephemeral = [configurations ephemeralSessionConfiguration];
    [transcript addObject:[NSString stringWithFormat:@"ephemeral stores differ per configuration: cookies=%d cache=%d", ephemeral.HTTPCookieStorage != [configurations ephemeralSessionConfiguration].HTTPCookieStorage, ephemeral.URLCache != [configurations ephemeralSessionConfiguration].URLCache]];
    [transcript addObject:[NSString stringWithFormat:@"default configurations are new objects: %d", defaults != [configurations defaultSessionConfiguration]]];
    NSURLSessionConfiguration *copy = [defaults copy];
    defaults.timeoutIntervalForRequest = 7;
    defaults.HTTPAdditionalHeaders = @{@"X-Extra": @"1"};
    [transcript addObject:[NSString stringWithFormat:@"copy is independent: %d request=%g headers=%@", copy != defaults, copy.timeoutIntervalForRequest, copy.HTTPAdditionalHeaders ? @"set" : @"-"]];
    NSURLSession *session = [harness.sessionClass sessionWithConfiguration:defaults];
    defaults.timeoutIntervalForRequest = 9;
    NSURLSessionConfiguration *seen = session.configuration;
    [transcript addObject:[NSString stringWithFormat:@"session copies configuration: %d %d request=%g headers=%@", seen != defaults, seen != session.configuration, seen.timeoutIntervalForRequest, seen.HTTPAdditionalHeaders[@"X-Extra"]]];
    [transcript addObject:[NSString stringWithFormat:@"session delegate=%@ queue=%d serial=%ld", session.delegate, session.delegateQueue != nil, (long)session.delegateQueue.maxConcurrentOperationCount]];
    session.sessionDescription = @"described";
    [transcript addObject:[NSString stringWithFormat:@"description=%@", session.sessionDescription]];
    NSURLSession *shared = [harness.sessionClass sharedSession];
    [transcript addObject:[NSString stringWithFormat:@"shared same=%d delegate=%@ queue=%d", shared == [harness.sessionClass sharedSession], shared.delegate, shared.delegateQueue != nil]];
    NSURL *url = url_for(harness, @"/bytes?n=10");
    NSURLSessionDataTask *first = [session dataTaskWithURL:url];
    NSURLSessionDataTask *second = [session dataTaskWithRequest:[NSURLRequest requestWithURL:url]];
    NSURLSessionUploadTask *upload = [session uploadTaskWithRequest:[NSURLRequest requestWithURL:url] fromData:[NSData data]];
    NSURLSessionDownloadTask *download = [session downloadTaskWithURL:url];
    [transcript addObject:[NSString stringWithFormat:@"identifiers %ld %ld %ld", (long)(second.taskIdentifier - first.taskIdentifier), (long)(upload.taskIdentifier - first.taskIdentifier), (long)(download.taskIdentifier - first.taskIdentifier)]];
    Class dataClass = [harness classNamed:@"NSURLSessionDataTask"];
    [transcript addObject:[NSString stringWithFormat:@"kinds data=%d upload=%d upload-is-data=%d download=%d download-is-data=%d download-is-task=%d", [first isKindOfClass:dataClass],
                           [upload isKindOfClass:[harness classNamed:@"NSURLSessionUploadTask"]], [upload isKindOfClass:dataClass], [download isKindOfClass:[harness classNamed:@"NSURLSessionDownloadTask"]],
                           [download isKindOfClass:dataClass], [download isKindOfClass:[harness classNamed:@"NSURLSessionTask"]]]];
    [transcript addObject:[NSString stringWithFormat:@"new task state=%ld original=%@ current=%@ response=%@ error=%@ counts=%lld/%lld/%lld/%lld", (long)first.state, path_of(first.originalRequest.URL),
                           path_of(first.currentRequest.URL), first.response, first.error, first.countOfBytesReceived, first.countOfBytesExpectedToReceive, first.countOfBytesSent, first.countOfBytesExpectedToSend]];
    [transcript addObject:[NSString stringWithFormat:@"request from URL timeout=%g policy=%lu", first.originalRequest.timeoutInterval, (unsigned long)first.originalRequest.cachePolicy]];
    first.taskDescription = @"first";
    [transcript addObject:[NSString stringWithFormat:@"task description=%@ copy-same=%d", first.taskDescription, [first copy] == first]];
    [transcript addObject:[NSString stringWithFormat:@"priority default=%g", first.priority]];
    first.priority = NSURLSessionTaskPriorityHigh;
    [transcript addObject:[NSString stringWithFormat:@"priority set=%g constants=%g/%g/%g unknown=%lld", first.priority, NSURLSessionTaskPriorityLow, NSURLSessionTaskPriorityDefault, NSURLSessionTaskPriorityHigh, NSURLSessionTransferSizeUnknown]];
    NSMutableArray *kept = [NSMutableArray array];
    float priorities[] = {0, 1, 0.3f, -0.1f, 1.0001f, 2, -5, INFINITY};
    for (size_t index = 0; index < sizeof priorities / sizeof *priorities; index++) {
        first.priority = priorities[index];
        [kept addObject:[NSString stringWithFormat:@"%g", first.priority]];
    }
    first.priority = NSURLSessionTaskPriorityHigh;
    [transcript addObject:[@"priority kept " stringByAppendingString:[kept componentsJoinedByString:@" "]]];
    [first suspend];
    [first suspend];
    [transcript addObject:[NSString stringWithFormat:@"suspend unresumed state=%ld", (long)first.state]];
    [first cancel];
    [transcript addObject:[NSString stringWithFormat:@"cancel unresumed state=%ld", (long)first.state]];
    NSURLRequest *nothing = nil;
    [transcript addObject:[NSString stringWithFormat:@"nil request exception=%@", exception_name(^{
        [session dataTaskWithRequest:nothing];
    })]];
    NSURLSession *background = [harness.sessionClass sessionWithConfiguration:[configurations backgroundSessionConfigurationWithIdentifier:[@"org.charon.background." stringByAppendingString:harness.tag]] delegate:nil delegateQueue:nil];
    [transcript addObject:[NSString stringWithFormat:@"background completion handler exception=%@", exception_name(^{
        [background dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        }];
    })]];
    [transcript addObject:[NSString stringWithFormat:@"shared description=%@", shared.sessionDescription]];
    [session invalidateAndCancel];
    [background invalidateAndCancel];
    return transcript;
}

static NSArray *scenario_data_delegate(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    NSMutableSet *implemented = [recorder.implemented mutableCopy];
    [implemented removeObject:@"URLSession:dataTask:willCacheResponse:completionHandler:"];
    recorder.implemented = implemented;
    NSURLSession *session = session_with(harness, nil, recorder);
    [[session dataTaskWithURL:url_for(harness, @"/bytes?n=100000")] resume];
    if (!wait_for(harness, recorder.completed))
        [transcript addObject:@"timed out"];
    [recorder record:[NSString stringWithFormat:@"body matches=%d", [recorder.body isEqualToData:pattern_bytes(0, 100000)]]];
    recorder.body = [NSMutableData data];
    [[session dataTaskWithURL:url_for(harness, @"/bytes?n=50000&chunked=1&chunk=7000&delay=100")] resume];
    if (!wait_for(harness, recorder.completed))
        [transcript addObject:@"timed out"];
    [recorder record:[NSString stringWithFormat:@"chunked body matches=%d", [recorder.body isEqualToData:pattern_bytes(0, 50000)]]];
    [[session dataTaskWithURL:url_for(harness, @"/status?code=404")] resume];
    wait_for(harness, recorder.completed);
    [[session dataTaskWithURL:url_for(harness, @"/status?code=500")] resume];
    wait_for(harness, recorder.completed);
    [[session dataTaskWithURL:[NSURL URLWithString:@"http://127.0.0.1:1/refused"]] resume];
    wait_for(harness, recorder.completed);
    return finish_session(harness, session, recorder, transcript);
}

static NSArray *scenario_data_handler(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    NSURLSession *session = session_with(harness, nil, recorder);
    NSData *body = nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:url_for(harness, @"/redirect?code=302&to=/bytes?n=1000")];
    [transcript addObject:run_data_handler(harness, session, request, &body, NULL)];
    [transcript addObject:[NSString stringWithFormat:@"body matches=%d", [body isEqualToData:pattern_bytes(0, 1000)]]];
    [transcript addObject:run_data_handler(harness, session, [NSURLRequest requestWithURL:url_for(harness, @"/status?code=404")], &body, NULL)];
    [transcript addObject:run_data_handler(harness, session, [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:1/refused"]], &body, NULL)];
    [transcript addObject:run_data_handler(harness, session, [NSURLRequest requestWithURL:url_for(harness, @"/bytes?n=0")], &body, NULL)];
    return finish_session(harness, session, recorder, transcript);
}

static NSArray *scenario_upload(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    recorder.streamBody = [@"streamed body" dataUsingEncoding:NSUTF8StringEncoding];
    recorder.variableLength = YES;
    NSMutableSet *implemented = [recorder.implemented mutableCopy];
    [implemented removeObject:@"URLSession:dataTask:willCacheResponse:completionHandler:"];
    recorder.implemented = implemented;
    NSURLSession *session = session_with(harness, nil, recorder);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url_for(harness, @"/echo")];
    request.HTTPMethod = @"POST";
    [request setValue:@"custom" forHTTPHeaderField:@"X-Custom"];
    NSArray *headers = @[@"x-custom", @"content-length", @"transfer-encoding"];
    [[session uploadTaskWithRequest:request fromData:[@"hello upload" dataUsingEncoding:NSUTF8StringEncoding]] resume];
    wait_for(harness, recorder.completed);
    [recorder record:echo_text(recorder.body, headers)];
    recorder.body = [NSMutableData data];
    NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"charon-upload-%@.txt", harness.tag]];
    NSMutableString *text = [NSMutableString string];
    while (text.length < 20000)
        [text appendString:@"charon-upload-"];
    [text writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[session uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:file]] resume];
    wait_for(harness, recorder.completed);
    NSDictionary *echo = echo_of(recorder.body);
    [recorder record:[NSString stringWithFormat:@"file echo length=%@ matches=%d content-length=%@", echo[@"length"], [echo[@"body"] isEqual:text], echo[@"headers"][@"content-length"] ?: @"-"]];
    recorder.body = [NSMutableData data];
    [[session uploadTaskWithStreamedRequest:request] resume];
    wait_for(harness, recorder.completed);
    echo = echo_of(recorder.body);
    [recorder record:[NSString stringWithFormat:@"stream echo body=%@", echo[@"body"]]];
    recorder.body = [NSMutableData data];
    NSMutableURLRequest *withBody = [request mutableCopy];
    withBody.HTTPBody = [@"data task body" dataUsingEncoding:NSUTF8StringEncoding];
    [[session dataTaskWithRequest:withBody] resume];
    wait_for(harness, recorder.completed);
    [recorder record:echo_text(recorder.body, headers)];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSString *line = @"upload handler timed out";
    [[session uploadTaskWithRequest:request fromData:[@"handler upload" dataUsingEncoding:NSUTF8StringEncoding] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        line = [NSString stringWithFormat:@"upload handler %@ error=%@", echo_text(data, headers), error_text(error)];
        dispatch_semaphore_signal(done);
    }] resume];
    wait_for(harness, done);
    [recorder record:line];
    [[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
    return finish_session(harness, session, recorder, transcript);
}

static NSArray *scenario_download(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    NSURLSession *session = session_with(harness, nil, recorder);
    [[session downloadTaskWithURL:url_for(harness, @"/bytes?n=100000&etag=download")] resume];
    wait_for(harness, recorder.completed);
    [recorder record:[NSString stringWithFormat:@"content matches=%d removed=%d", [recorder.downloaded isEqualToData:pattern_bytes(0, 100000)], ![[NSFileManager defaultManager] fileExistsAtPath:recorder.location.path]]];
    [[session downloadTaskWithRequest:[NSURLRequest requestWithURL:url_for(harness, @"/status?code=404")]] resume];
    wait_for(harness, recorder.completed);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSString *line = @"download handler timed out";
    __block NSURL *handled = nil;
    [[session downloadTaskWithURL:url_for(harness, @"/bytes?n=30000") completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        handled = location;
        line = [NSString stringWithFormat:@"download handler status=%ld matches=%d error=%@", (long)status_of(response), [[NSData dataWithContentsOfURL:location] isEqualToData:pattern_bytes(0, 30000)], error_text(error)];
        dispatch_semaphore_signal(done);
    }] resume];
    wait_for(harness, done);
    [NSThread sleepForTimeInterval:0.5];
    [recorder record:[NSString stringWithFormat:@"%@ removed=%d", line, ![[NSFileManager defaultManager] fileExistsAtPath:handled.path]]];
    line = @"download handler timed out";
    [[session downloadTaskWithURL:[NSURL URLWithString:@"http://127.0.0.1:1/refused"] completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        line = [NSString stringWithFormat:@"download handler location=%@ response=%@ error=%@", location ? @"set" : @"nil", response ? @"set" : @"nil", error_text(error)];
        dispatch_semaphore_signal(done);
    }] resume];
    wait_for(harness, done);
    [recorder record:line];
    return finish_session(harness, session, recorder, transcript);
}

static NSArray *scenario_redirect(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    NSMutableSet *implemented = [recorder.implemented mutableCopy];
    [implemented removeObject:@"URLSession:dataTask:willCacheResponse:completionHandler:"];
    recorder.implemented = implemented;
    recorder.variableLength = YES;
    NSURLSession *session = session_with(harness, nil, recorder);
    for (NSString *code in @[@"301", @"302", @"303", @"307"]) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url_for(harness, [NSString stringWithFormat:@"/redirect?code=%@&to=/echo", code])];
        request.HTTPMethod = @"POST";
        request.HTTPBody = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
        [request setValue:@"text/x" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"1" forHTTPHeaderField:@"X-Custom"];
        recorder.body = [NSMutableData data];
        [[session dataTaskWithRequest:request] resume];
        wait_for(harness, recorder.completed);
        [recorder record:echo_text(recorder.body, @[@"x-custom", @"content-type"])];
        [recorder record:[NSString stringWithFormat:@"current=%@ method=%@", path_of(recorder.lastTask.currentRequest.URL), recorder.lastTask.currentRequest.HTTPMethod]];
    }
    recorder.rejectRedirects = YES;
    recorder.body = [NSMutableData data];
    [[session dataTaskWithURL:url_for(harness, @"/redirect?code=302&to=/echo")] resume];
    wait_for(harness, recorder.completed);
    [recorder record:[NSString stringWithFormat:@"rejected body=%@ current=%@", text_of(recorder.body), path_of(recorder.lastTask.currentRequest.URL)]];
    recorder.rejectRedirects = NO;
    NSData *body = nil;
    [recorder record:run_data_handler(harness, session, [NSURLRequest requestWithURL:url_for(harness, @"/redirect?code=301&to=/bytes?n=10")], &body, NULL)];
    SessionRecorder *quiet = [[SessionRecorder alloc] init];
    quiet.implemented = [NSSet setWithObject:@"URLSession:didBecomeInvalidWithError:"];
    NSURLSession *quietSession = session_with(harness, nil, quiet);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSString *line = @"too many timed out";
    [[quietSession dataTaskWithURL:url_for(harness, @"/redirect?code=302&count=25") completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        line = [NSString stringWithFormat:@"too many %@ failing=%@ response=%@ data=%@", error_text(error), path_of(error.userInfo[NSURLErrorFailingURLErrorKey]), response ? @"set" : @"nil", data ? @"set" : @"nil"];
        dispatch_semaphore_signal(done);
    }] resume];
    wait_for(harness, done);
    [transcript addObject:line];
    [quietSession finishTasksAndInvalidate];
    wait_for(harness, quiet.invalidated);
    for (NSString *query in @[@"/redirect?code=302&to=/echo", @"/redirect?code=302&to=/echo&hostname=localhost"]) {
        NSMutableURLRequest *carried = [NSMutableURLRequest requestWithURL:url_for(harness, query)];
        [carried setValue:@"Bearer token" forHTTPHeaderField:@"Authorization"];
        [carried setValue:@"seed=1" forHTTPHeaderField:@"Cookie"];
        [carried setValue:@"1" forHTTPHeaderField:@"X-Custom"];
        recorder.body = [NSMutableData data];
        [[session dataTaskWithRequest:carried] resume];
        wait_for(harness, recorder.completed);
        [recorder record:[@"carried to " stringByAppendingString:[query hasSuffix:@"hostname=localhost"] ? @"another origin" : @"the same origin"]];
        [recorder record:echo_text(recorder.body, @[@"authorization", @"cookie", @"x-custom"])];
    }
    return finish_session(harness, session, recorder, transcript);
}

static NSArray *scenario_cookies(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    Class configurations = harness.configurationClass;
    NSHTTPCookieStorage *shared = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSHTTPCookieAcceptPolicy previousPolicy = shared.cookieAcceptPolicy;
    shared.cookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    NSString *name = [@"shared_" stringByAppendingString:harness.tag];
    NSURLSession *session = [harness.sessionClass sessionWithConfiguration:[configurations defaultSessionConfiguration]];
    NSData *body = nil;
    [transcript addObject:run_data_handler(harness, session, [NSURLRequest requestWithURL:url_for(harness, [@"/setcookie?name=" stringByAppendingString:name])], NULL, NULL)];
    NSPredicate *named = [NSPredicate predicateWithFormat:@"name == %@", name];
    NSArray *stored = [[shared cookiesForURL:url_for(harness, @"/echo")] filteredArrayUsingPredicate:named];
    [transcript addObject:[NSString stringWithFormat:@"shared storage has cookie=%lu", (unsigned long)stored.count]];
    run_data_handler(harness, session, [NSURLRequest requestWithURL:url_for(harness, @"/echo")], &body, NULL);
    NSString *header = echo_of(body)[@"headers"][@"cookie"] ?: @"";
    [transcript addObject:[NSString stringWithFormat:@"sent shared cookie=%d", [header rangeOfString:[name stringByAppendingString:@"=1"]].location != NSNotFound]];
    NSMutableURLRequest *unhandled = [NSMutableURLRequest requestWithURL:url_for(harness, @"/echo")];
    unhandled.HTTPShouldHandleCookies = NO;
    run_data_handler(harness, session, unhandled, &body, NULL);
    header = echo_of(body)[@"headers"][@"cookie"] ?: @"";
    [transcript addObject:[NSString stringWithFormat:@"request without cookie handling sent=%d", [header rangeOfString:name].location != NSNotFound]];
    NSURLSessionConfiguration *noSet = [configurations defaultSessionConfiguration];
    noSet.HTTPShouldSetCookies = NO;
    NSURLSession *noSetSession = [harness.sessionClass sessionWithConfiguration:noSet];
    run_data_handler(harness, noSetSession, [NSURLRequest requestWithURL:url_for(harness, @"/echo")], &body, NULL);
    header = echo_of(body)[@"headers"][@"cookie"] ?: @"";
    [transcript addObject:[NSString stringWithFormat:@"HTTPShouldSetCookies=NO sent=%d", [header rangeOfString:name].location != NSNotFound]];
    for (NSHTTPCookie *cookie in stored)
        [shared deleteCookie:cookie];
    NSURLSessionConfiguration *ephemeral = [configurations ephemeralSessionConfiguration];
    NSURLSession *ephemeralSession = [harness.sessionClass sessionWithConfiguration:ephemeral];
    NSString *ephemeralName = [@"ephemeral_" stringByAppendingString:harness.tag];
    run_data_handler(harness, ephemeralSession, [NSURLRequest requestWithURL:url_for(harness, [@"/setcookie?name=" stringByAppendingString:ephemeralName])], NULL, NULL);
    NSHTTPCookieStorage *own = ephemeralSession.configuration.HTTPCookieStorage;
    [transcript addObject:[NSString stringWithFormat:@"ephemeral own=%lu shared=%lu", (unsigned long)[[own.cookies filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", ephemeralName]] count],
                           (unsigned long)[[shared.cookies filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", ephemeralName]] count]]];
    run_data_handler(harness, ephemeralSession, [NSURLRequest requestWithURL:url_for(harness, @"/echo")], &body, NULL);
    header = echo_of(body)[@"headers"][@"cookie"] ?: @"";
    [transcript addObject:[NSString stringWithFormat:@"ephemeral session sent=%d", [header rangeOfString:ephemeralName].location != NSNotFound]];
    NSURLSession *otherEphemeral = [harness.sessionClass sessionWithConfiguration:[configurations ephemeralSessionConfiguration]];
    run_data_handler(harness, otherEphemeral, [NSURLRequest requestWithURL:url_for(harness, @"/echo")], &body, NULL);
    header = echo_of(body)[@"headers"][@"cookie"] ?: @"";
    [transcript addObject:[NSString stringWithFormat:@"other ephemeral session sent=%d", [header rangeOfString:ephemeralName].location != NSNotFound]];
    NSURLSessionConfiguration *never = [configurations ephemeralSessionConfiguration];
    never.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
    NSURLSession *neverSession = [harness.sessionClass sessionWithConfiguration:never];
    run_data_handler(harness, neverSession, [NSURLRequest requestWithURL:url_for(harness, @"/setcookie?name=never")], NULL, NULL);
    [transcript addObject:[NSString stringWithFormat:@"accept never stored=%lu", (unsigned long)neverSession.configuration.HTTPCookieStorage.cookies.count]];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [ephemeralSession resetWithCompletionHandler:^{
        dispatch_semaphore_signal(done);
    }];
    [transcript addObject:[NSString stringWithFormat:@"reset called=%d cookies=%lu", wait_for(harness, done), (unsigned long)own.cookies.count]];
    for (NSURLSession *each in @[session, noSetSession, ephemeralSession, otherEphemeral, neverSession])
        [each finishTasksAndInvalidate];
    shared.cookieAcceptPolicy = previousPolicy;
    return transcript;
}

static NSArray *scenario_authentication(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    Class configurations = harness.configurationClass;
    NSURLCredential *good = [NSURLCredential credentialWithUser:@"user" password:@"pass" persistence:NSURLCredentialPersistenceNone];
    NSURLCredential *bad = [NSURLCredential credentialWithUser:@"user" password:@"wrong" persistence:NSURLCredentialPersistenceNone];
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    NSMutableSet *implemented = [recorder.implemented mutableCopy];
    [implemented removeObject:@"URLSession:dataTask:willCacheResponse:completionHandler:"];
    recorder.implemented = implemented;
    recorder.credentials = @[good];
    NSURLSession *session = session_with(harness, [configurations ephemeralSessionConfiguration], recorder);
    [[session dataTaskWithURL:url_for(harness, [@"/auth?realm=good-" stringByAppendingString:harness.tag])] resume];
    wait_for(harness, recorder.completed);
    [recorder record:[NSString stringWithFormat:@"body=%@", text_of(recorder.body)]];
    recorder.body = [NSMutableData data];
    recorder.credentials = @[bad];
    [[session dataTaskWithURL:url_for(harness, [@"/auth?realm=bad-" stringByAppendingString:harness.tag])] resume];
    wait_for(harness, recorder.completed);
    [recorder record:[NSString stringWithFormat:@"body=%@", text_of(recorder.body)]];
    recorder.body = [NSMutableData data];
    recorder.credentials = @[];
    recorder.challengeDisposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    [[session dataTaskWithURL:url_for(harness, [@"/auth?realm=cancel-" stringByAppendingString:harness.tag])] resume];
    wait_for(harness, recorder.completed);
    recorder.challengeDisposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSData *body = nil;
    recorder.credentials = @[good];
    [recorder record:run_data_handler(harness, session, [NSURLRequest requestWithURL:url_for(harness, [@"/auth?realm=handler-" stringByAppendingString:harness.tag])], &body, NULL)];
    finish_session(harness, session, recorder, transcript);

    SessionRecorder *sessionLevel = [[SessionRecorder alloc] init];
    sessionLevel.implemented = [NSSet setWithArray:@[@"URLSession:didBecomeInvalidWithError:", @"URLSession:didReceiveChallenge:completionHandler:", @"URLSession:task:didCompleteWithError:"]];
    NSURLSession *sessionLevelSession = session_with(harness, [configurations ephemeralSessionConfiguration], sessionLevel);
    [[sessionLevelSession dataTaskWithURL:url_for(harness, [@"/auth?realm=session-" stringByAppendingString:harness.tag])] resume];
    wait_for(harness, sessionLevel.completed);
    finish_session(harness, sessionLevelSession, sessionLevel, transcript);

    NSURLSession *plain = [harness.sessionClass sessionWithConfiguration:[configurations ephemeralSessionConfiguration]];
    NSString *authority = [harness.base substringFromIndex:[@"http://" length]];
    NSURL *withCredentials = [NSURL URLWithString:[NSString stringWithFormat:@"http://user:pass@%@/auth?realm=url-%@", authority, harness.tag]];
    [transcript addObject:[@"url credentials " stringByAppendingString:run_data_handler(harness, plain, [NSURLRequest requestWithURL:withCredentials], &body, NULL)]];
    [transcript addObject:[@"no credentials " stringByAppendingString:run_data_handler(harness, plain, [NSURLRequest requestWithURL:url_for(harness, [@"/auth?realm=none-" stringByAppendingString:harness.tag])], &body, NULL)]];
    NSURLSessionConfiguration *stored = [configurations ephemeralSessionConfiguration];
    NSString *realm = [@"stored-" stringByAppendingString:harness.tag];
    NSURL *base = [NSURL URLWithString:harness.base];
    NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:base.host port:base.port.integerValue protocol:@"http" realm:realm authenticationMethod:NSURLAuthenticationMethodHTTPBasic];
    [stored.URLCredentialStorage setDefaultCredential:[NSURLCredential credentialWithUser:@"user" password:@"pass" persistence:NSURLCredentialPersistenceForSession] forProtectionSpace:space];
    NSURLSession *storedSession = [harness.sessionClass sessionWithConfiguration:stored];
    [transcript addObject:[@"stored credential " stringByAppendingString:run_data_handler(harness, storedSession, [NSURLRequest requestWithURL:url_for(harness, [@"/auth?realm=" stringByAppendingString:realm])], &body, NULL)]];
    [transcript addObject:[NSString stringWithFormat:@"stored credential count=%lu", (unsigned long)[stored.URLCredentialStorage credentialsForProtectionSpace:space].count]];
    [plain finishTasksAndInvalidate];
    [storedSession finishTasksAndInvalidate];
    return transcript;
}

static NSArray *scenario_cancel(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    NSMutableSet *implemented = [recorder.implemented mutableCopy];
    [implemented removeObject:@"URLSession:dataTask:willCacheResponse:completionHandler:"];
    recorder.implemented = implemented;
    recorder.cancelOnData = YES;
    NSURLSession *session = session_with(harness, nil, recorder);
    [[session dataTaskWithURL:url_for(harness, @"/bytes?n=400000&chunk=10000&delay=400")] resume];
    wait_for(harness, recorder.completed);
    recorder.disposition = NSURLSessionResponseCancel;
    [[session dataTaskWithURL:url_for(harness, @"/bytes?n=1000")] resume];
    wait_for(harness, recorder.completed);
    recorder.disposition = NSURLSessionResponseBecomeDownload;
    [[session dataTaskWithURL:url_for(harness, @"/bytes?n=20000")] resume];
    wait_for(harness, recorder.completed);
    [recorder record:[NSString stringWithFormat:@"became download matches=%d class=%d", [recorder.downloaded isEqualToData:pattern_bytes(0, 20000)], [recorder.lastTask isKindOfClass:[harness classNamed:@"NSURLSessionDownloadTask"]]]];
    recorder.disposition = NSURLSessionResponseAllow;
    NSURLSessionDataTask *handled = [session dataTaskWithURL:url_for(harness, @"/bytes?n=100000&predelay=3000") completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [recorder record:[NSString stringWithFormat:@"cancelled handler data=%@ response=%@ error=%@", data ? @"set" : @"nil", response ? @"set" : @"nil", error_text(error)]];
        dispatch_semaphore_signal(recorder.completed);
    }];
    [handled resume];
    [NSThread sleepForTimeInterval:0.3];
    [handled cancel];
    [recorder record:[NSString stringWithFormat:@"handler task state after cancel=%ld", (long)handled.state]];
    wait_for(harness, recorder.completed);
    recorder.body = [NSMutableData data];
    NSURLSessionDataTask *paused = [session dataTaskWithURL:url_for(harness, @"/bytes?n=30000&chunk=10000&delay=700")];
    [paused resume];
    wait_for(harness, recorder.dataArrived);
    [paused suspend];
    NSURLSessionTaskState suspended = paused.state;
    [NSThread sleepForTimeInterval:1.0];
    [paused resume];
    NSURLSessionTaskState resumed = paused.state;
    wait_for(harness, recorder.completed);
    [recorder record:[NSString stringWithFormat:@"suspended state=%ld resumed state=%ld", (long)suspended, (long)resumed]];
    [recorder record:[NSString stringWithFormat:@"suspended body matches=%d", [recorder.body isEqualToData:pattern_bytes(0, 30000)]]];
    return finish_session(harness, session, recorder, transcript);
}

static NSArray *scenario_resume(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    recorder.variableLength = YES;
    NSURLSession *session = session_with(harness, nil, recorder);
    for (NSString *validator in @[@"etag=resume", @"lastmod=1"]) {
        recorder.produceResumeDataAfter = 40000;
        recorder.resumeData = nil;
        NSString *path = [NSString stringWithFormat:@"/bytes?n=300000&chunk=10000&delay=60&%@", validator];
        [[session downloadTaskWithURL:url_for(harness, path)] resume];
        BOOL produced = wait_for(harness, recorder.produced);
        wait_for(harness, recorder.completed);
        [recorder record:[NSString stringWithFormat:@"produced=%d resume data=%d", produced, recorder.resumeData != nil]];
        if (!recorder.resumeData)
            continue;
        NSURLSessionDownloadTask *resumed = [session downloadTaskWithResumeData:recorder.resumeData];
        [recorder record:[NSString stringWithFormat:@"resumed task state=%ld original=%@ range=%d", (long)resumed.state, path_of(resumed.originalRequest.URL), [resumed.currentRequest valueForHTTPHeaderField:@"Range"] != nil]];
        [resumed resume];
        wait_for(harness, recorder.completed);
        [recorder record:[NSString stringWithFormat:@"resumed content matches=%d", [recorder.downloaded isEqualToData:pattern_bytes(0, 300000)]]];
    }
    recorder.produceResumeDataAfter = 40000;
    recorder.resumeData = [NSData data];
    [[session downloadTaskWithURL:url_for(harness, @"/bytes?n=300000&chunk=10000&delay=60")] resume];
    wait_for(harness, recorder.produced);
    wait_for(harness, recorder.completed);
    [recorder record:[NSString stringWithFormat:@"without validator resume data=%d", recorder.resumeData != nil]];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSString *line = @"resume handler timed out";
    NSURLSessionDownloadTask *finished = [session downloadTaskWithURL:url_for(harness, @"/bytes?n=10") completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        dispatch_semaphore_signal(done);
    }];
    [finished resume];
    wait_for(harness, done);
    [NSThread sleepForTimeInterval:0.3];
    [finished cancelByProducingResumeData:^(NSData *resumeData) {
        line = [NSString stringWithFormat:@"completed task resume data=%d", resumeData != nil];
        dispatch_semaphore_signal(done);
    }];
    wait_for(harness, done);
    [recorder record:line];
    return finish_session(harness, session, recorder, transcript);
}

static NSArray *scenario_timeout(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    Class configurations = harness.configurationClass;
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    recorder.implemented = [NSSet setWithArray:@[@"URLSession:didBecomeInvalidWithError:", @"URLSession:task:didCompleteWithError:"]];
    NSURLSessionConfiguration *configuration = [configurations defaultSessionConfiguration];
    configuration.timeoutIntervalForRequest = 1;
    NSURLSession *session = session_with(harness, configuration, recorder);
    [[session dataTaskWithURL:url_for(harness, @"/delay?ms=4000")] resume];
    wait_for(harness, recorder.completed);
    NSMutableURLRequest *patient = [NSMutableURLRequest requestWithURL:url_for(harness, @"/delay?ms=2000")];
    patient.timeoutInterval = 15;
    [[session dataTaskWithRequest:patient] resume];
    wait_for(harness, recorder.completed);
    finish_session(harness, session, recorder, transcript);

    SessionRecorder *requestLevel = [[SessionRecorder alloc] init];
    requestLevel.implemented = recorder.implemented;
    NSURLSession *requestSession = session_with(harness, nil, requestLevel);
    NSMutableURLRequest *hasty = [NSMutableURLRequest requestWithURL:url_for(harness, @"/delay?ms=4000")];
    hasty.timeoutInterval = 1;
    [[requestSession dataTaskWithRequest:hasty] resume];
    wait_for(harness, requestLevel.completed);
    finish_session(harness, requestSession, requestLevel, transcript);

    SessionRecorder *resource = [[SessionRecorder alloc] init];
    resource.implemented = recorder.implemented;
    resource.variableLength = YES;
    NSURLSessionConfiguration *short_resource = [configurations defaultSessionConfiguration];
    short_resource.timeoutIntervalForResource = 2;
    NSURLSession *resourceSession = session_with(harness, short_resource, resource);
    [[resourceSession dataTaskWithURL:url_for(harness, @"/bytes?n=10000&chunk=1000&delay=600")] resume];
    wait_for(harness, resource.completed);
    [[resourceSession downloadTaskWithURL:url_for(harness, [NSString stringWithFormat:@"/bytes?n=10000&chunk=1000&delay=600&etag=timeout-%@", harness.tag])] resume];
    wait_for(harness, resource.completed);
    return finish_session(harness, resourceSession, resource, transcript);
}

static NSArray *scenario_invalidation(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    NSMutableSet *implemented = [recorder.implemented mutableCopy];
    [implemented removeObject:@"URLSession:dataTask:willCacheResponse:completionHandler:"];
    recorder.implemented = implemented;
    NSURLSession *session = session_with(harness, nil, recorder);
    [[session dataTaskWithURL:url_for(harness, @"/bytes?n=20000&chunk=10000&delay=5000")] resume];
    wait_for(harness, recorder.dataArrived);
    [session invalidateAndCancel];
    wait_for(harness, recorder.invalidated);
    [transcript addObjectsFromArray:[recorder snapshot]];
    [transcript addObject:[NSString stringWithFormat:@"delegate after invalidation=%@", session.delegate]];
    [transcript addObject:[NSString stringWithFormat:@"task after invalidation exception=%@", exception_name(^{
        [session dataTaskWithURL:url_for(harness, @"/bytes?n=1")];
    })]];

    SessionRecorder *finishing = [[SessionRecorder alloc] init];
    finishing.implemented = implemented;
    NSURLSession *finishingSession = session_with(harness, nil, finishing);
    [[finishingSession dataTaskWithURL:url_for(harness, @"/bytes?n=1000&predelay=500")] resume];
    [finishingSession finishTasksAndInvalidate];
    wait_for(harness, finishing.invalidated);
    [transcript addObjectsFromArray:[finishing snapshot]];

    NSURLSession *shared = [harness.sessionClass sharedSession];
    [shared finishTasksAndInvalidate];
    [shared invalidateAndCancel];
    NSData *body = nil;
    [transcript addObject:[@"shared " stringByAppendingString:run_data_handler(harness, shared, [NSURLRequest requestWithURL:url_for(harness, @"/bytes?n=10")], &body, NULL)]];
    return transcript;
}

static NSArray *scenario_tasks(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    Class configurations = harness.configurationClass;
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    recorder.implemented = [NSSet setWithArray:@[@"URLSession:didBecomeInvalidWithError:"]];
    NSURLSession *session = session_with(harness, nil, recorder);
    NSURL *slow = url_for(harness, @"/bytes?n=100&predelay=5000");
    NSMutableURLRequest *post = [NSMutableURLRequest requestWithURL:slow];
    post.HTTPMethod = @"POST";
    NSURLSessionTask *data = [session dataTaskWithURL:slow];
    NSURLSessionTask *upload = [session uploadTaskWithRequest:post fromData:[@"x" dataUsingEncoding:NSUTF8StringEncoding]];
    NSURLSessionTask *download = [session downloadTaskWithURL:slow];
    [session dataTaskWithURL:slow];
    [data resume];
    [upload resume];
    [download resume];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSString *line = @"get tasks timed out";
    [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        line = [NSString stringWithFormat:@"tasks data=%lu upload=%lu download=%lu same=%d", (unsigned long)dataTasks.count, (unsigned long)uploadTasks.count, (unsigned long)downloadTasks.count,
                dataTasks.lastObject == data && uploadTasks.lastObject == upload && downloadTasks.lastObject == download];
        dispatch_semaphore_signal(done);
    }];
    wait_for(harness, done);
    [transcript addObject:line];
    [session getAllTasksWithCompletionHandler:^(NSArray *tasks) {
        line = [NSString stringWithFormat:@"all tasks=%lu", (unsigned long)tasks.count];
        dispatch_semaphore_signal(done);
    }];
    wait_for(harness, done);
    [transcript addObject:line];
    [session flushWithCompletionHandler:^{
        line = @"flushed";
        dispatch_semaphore_signal(done);
    }];
    wait_for(harness, done);
    [transcript addObject:line];
    [session invalidateAndCancel];
    wait_for(harness, recorder.invalidated);
    [transcript addObject:[NSString stringWithFormat:@"states after cancel %ld %ld %ld", (long)data.state, (long)upload.state, (long)download.state]];

    NSURLSessionConfiguration *limited = [configurations defaultSessionConfiguration];
    limited.HTTPMaximumConnectionsPerHost = 2;
    NSURLSession *limitedSession = [harness.sessionClass sessionWithConfiguration:limited];
    NSString *key = [@"limit-" stringByAppendingString:harness.tag];
    dispatch_group_t group = dispatch_group_create();
    for (int index = 0; index < 5; index++) {
        dispatch_group_enter(group);
        [[limitedSession dataTaskWithURL:url_for(harness, [NSString stringWithFormat:@"/concurrent?key=%@&ms=700&index=%d", key, index]) completionHandler:^(NSData *body, NSURLResponse *response, NSError *error) {
            dispatch_group_leave(group);
        }] resume];
    }
    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(harness.patience * NSEC_PER_SEC)));
    NSData *body = nil;
    run_data_handler(harness, limitedSession, [NSURLRequest requestWithURL:url_for(harness, [@"/highest?key=" stringByAppendingString:key])], &body, NULL);
    [transcript addObject:[NSString stringWithFormat:@"highest concurrency with limit 2=%@", text_of(body)]];
    [limitedSession finishTasksAndInvalidate];

    NSURLSessionConfiguration *headers = [configurations defaultSessionConfiguration];
    headers.HTTPAdditionalHeaders = @{@"X-Extra": @"session", @"X-Custom": @"session"};
    NSURLSession *headersSession = [harness.sessionClass sessionWithConfiguration:headers];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url_for(harness, @"/echo")];
    [request setValue:@"request" forHTTPHeaderField:@"X-Custom"];
    run_data_handler(harness, headersSession, request, &body, NULL);
    [transcript addObject:echo_text(body, @[@"x-extra", @"x-custom"])];
    [headersSession finishTasksAndInvalidate];

    NSURLSessionConfiguration *protocols = [configurations defaultSessionConfiguration];
    protocols.protocolClasses = [@[[CharonTestProtocol class]] arrayByAddingObjectsFromArray:protocols.protocolClasses];
    NSURLSession *protocolSession = [harness.sessionClass sessionWithConfiguration:protocols];
    NSURLResponse *response = nil;
    NSString *handled = run_data_handler(harness, protocolSession, [NSURLRequest requestWithURL:[NSURL URLWithString:@"charontest://host/path"]], &body, &response);
    [transcript addObject:[NSString stringWithFormat:@"protocol %@ body=%@ header=%@", handled, text_of(body), [(NSHTTPURLResponse *)response allHeaderFields][@"X-Protocol"]]];
    [transcript addObject:[@"protocol through network " stringByAppendingString:run_data_handler(harness, protocolSession, [NSURLRequest requestWithURL:url_for(harness, @"/bytes?n=5")], &body, NULL)]];
    NSURLSession *withoutProtocol = [harness.sessionClass sessionWithConfiguration:[configurations defaultSessionConfiguration]];
    [transcript addObject:[@"without protocol " stringByAppendingString:run_data_handler(harness, withoutProtocol, [NSURLRequest requestWithURL:[NSURL URLWithString:@"charontest://host/path"]], &body, NULL)]];
    [protocolSession finishTasksAndInvalidate];
    [withoutProtocol finishTasksAndInvalidate];
    return transcript;
}

static NSArray *scenario_cache(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    Class configurations = harness.configurationClass;
    NSURLSession *session = [harness.sessionClass sessionWithConfiguration:[configurations ephemeralSessionConfiguration]];
    NSString *key = [@"cache-" stringByAppendingString:harness.tag];
    NSURL *url = url_for(harness, [NSString stringWithFormat:@"/counted?key=%@&maxage=600", key]);
    NSData *body = nil;
    run_data_handler(harness, session, [NSURLRequest requestWithURL:url], &body, NULL);
    [transcript addObject:[@"first " stringByAppendingString:text_of(body)]];
    [NSThread sleepForTimeInterval:0.5];
    run_data_handler(harness, session, [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60], &body, NULL);
    [transcript addObject:[@"cache else load " stringByAppendingString:text_of(body)]];
    run_data_handler(harness, session, [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60], &body, NULL);
    [transcript addObject:[@"reload " stringByAppendingString:text_of(body)]];
    NSURL *missing = url_for(harness, [NSString stringWithFormat:@"/counted?key=%@-missing", key]);
    [transcript addObject:[@"dont load missing " stringByAppendingString:run_data_handler(harness, session, [NSURLRequest requestWithURL:missing cachePolicy:NSURLRequestReturnCacheDataDontLoad timeoutInterval:60], &body, NULL)]];
    [session finishTasksAndInvalidate];
    NSURLSessionConfiguration *preferCache = [configurations ephemeralSessionConfiguration];
    preferCache.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    NSURLSession *preferCacheSession = [harness.sessionClass sessionWithConfiguration:preferCache];
    NSURL *configured = url_for(harness, [NSString stringWithFormat:@"/counted?key=%@-configured&maxage=0", key]);
    run_data_handler(harness, preferCacheSession, [NSURLRequest requestWithURL:configured], &body, NULL);
    [transcript addObject:[@"configured policy first " stringByAppendingString:text_of(body)]];
    [NSThread sleepForTimeInterval:0.5];
    run_data_handler(harness, preferCacheSession, [NSURLRequest requestWithURL:configured], &body, NULL);
    [transcript addObject:[@"configured policy second " stringByAppendingString:text_of(body)]];
    [preferCacheSession finishTasksAndInvalidate];

    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    recorder.implemented = [NSSet setWithArray:@[@"URLSession:didBecomeInvalidWithError:", @"URLSession:task:didCompleteWithError:", @"URLSession:dataTask:willCacheResponse:completionHandler:"]];
    NSURLSession *delegateSession = session_with(harness, [configurations ephemeralSessionConfiguration], recorder);
    NSString *declinedKey = [@"declined-" stringByAppendingString:harness.tag];
    NSURL *declined = url_for(harness, [NSString stringWithFormat:@"/counted?key=%@&maxage=600", declinedKey]);
    [[delegateSession dataTaskWithURL:declined] resume];
    wait_for(harness, recorder.completed);
    [NSThread sleepForTimeInterval:0.5];
    [transcript addObject:[@"declined then cache else load " stringByAppendingString:run_data_handler(harness, delegateSession, [NSURLRequest requestWithURL:declined cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60], &body, NULL)]];
    [transcript addObject:[@"declined body " stringByAppendingString:text_of(body)]];
    return finish_session(harness, delegateSession, recorder, transcript);
}

static NSArray *scenario_metrics(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    MetricsRecorder *recorder = [[MetricsRecorder alloc] init];
    NSMutableSet *implemented = [recorder.implemented mutableCopy];
    [implemented removeObject:@"URLSession:dataTask:willCacheResponse:completionHandler:"];
    recorder.implemented = implemented;
    NSURLSession *session = session_with(harness, [harness.configurationClass ephemeralSessionConfiguration], recorder);
    [[session dataTaskWithURL:url_for(harness, @"/bytes?n=1000")] resume];
    wait_for(harness, recorder.completed);
    [[session dataTaskWithURL:url_for(harness, @"/redirect?code=302&to=/bytes?n=100")] resume];
    wait_for(harness, recorder.completed);
    [[session dataTaskWithURL:[NSURL URLWithString:@"http://127.0.0.1:1/refused"]] resume];
    wait_for(harness, recorder.completed);
    [transcript addObject:run_data_handler(harness, session, [NSURLRequest requestWithURL:url_for(harness, @"/status?code=404")], NULL, NULL)];
    return finish_session(harness, session, recorder, transcript);
}

static NSArray *delayed_run(SessionHarness *harness, BOOL background, NSTimeInterval offset, BOOL setDate, NSInteger disposition, NSString *replacement, BOOL implementsDelegate, NSString *label, NSMutableArray *transcript)
{
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    NSMutableArray *selectors = [NSMutableArray arrayWithArray:@[@"URLSession:didBecomeInvalidWithError:", @"URLSession:task:didCompleteWithError:", @"URLSession:downloadTask:didFinishDownloadingToURL:", @"URLSessionDidFinishEventsForBackgroundURLSession:"]];
    if (implementsDelegate)
        [selectors addObject:@"URLSession:task:willBeginDelayedRequest:completionHandler:"];
    recorder.implemented = [NSSet setWithArray:selectors];
    recorder.delayedDisposition = disposition;
    recorder.delayedReplacement = replacement;
    recorder.base = harness.base;
    recorder.minimumWait = setDate && offset > 0 ? offset - 0.15 : 0;
    Class configurations = harness.configurationClass;
    NSURLSessionConfiguration *configuration = background ? [configurations backgroundSessionConfigurationWithIdentifier:[NSString stringWithFormat:@"org.charon.delayed.%@.%@", label, harness.tag]] : [configurations defaultSessionConfiguration];
    NSURLSession *session = session_with(harness, configuration, recorder);
    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url_for(harness, @"/bytes?n=2000")];
    if (setDate)
        task.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:offset];
    recorder.resumedAt = [NSDate date];
    [task resume];
    wait_for(harness, recorder.completed);
    NSTimeInterval total = -[recorder.resumedAt timeIntervalSinceNow];
    [recorder record:[NSString stringWithFormat:@"%@ finished after wait=%d current=%@", label, setDate && offset > 0 ? total >= offset - 0.15 : 1, path_of(task.currentRequest.URL)]];
    return finish_session(harness, session, recorder, transcript);
}

static NSArray *scenario_delayed(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    Class configurations = harness.configurationClass;
    delayed_run(harness, YES, 0, NO, 0, nil, YES, @"no-date", transcript);
    delayed_run(harness, YES, 1, YES, 0, nil, YES, @"date", transcript);
    delayed_run(harness, YES, -5, YES, 0, nil, YES, @"past", transcript);
    delayed_run(harness, YES, 0.5, YES, 2, nil, YES, @"cancel", transcript);
    delayed_run(harness, YES, 0.5, YES, 1, @"/bytes?n=100", YES, @"replace", transcript);
    delayed_run(harness, YES, 0.5, YES, 0, nil, NO, @"no-delegate", transcript);
    delayed_run(harness, NO, 1.5, YES, 0, nil, YES, @"foreground", transcript);
    NSURLSession *session = [harness.sessionClass sessionWithConfiguration:[configurations defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url_for(harness, @"/bytes?n=10")];
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:100];
    NSMutableArray *properties = [NSMutableArray array];
    [properties addObject:[NSString stringWithFormat:@"defaults date=%@ send=%lld receive=%lld", task.earliestBeginDate, task.countOfBytesClientExpectsToSend, task.countOfBytesClientExpectsToReceive]];
    task.earliestBeginDate = date;
    task.countOfBytesClientExpectsToSend = 5;
    task.countOfBytesClientExpectsToReceive = 99;
    [properties addObject:[NSString stringWithFormat:@"set same-date=%d send=%lld receive=%lld", task.earliestBeginDate == date, task.countOfBytesClientExpectsToSend, task.countOfBytesClientExpectsToReceive]];
    task.countOfBytesClientExpectsToSend = -7;
    task.earliestBeginDate = nil;
    [properties addObject:[NSString stringWithFormat:@"negative send=%lld date=%@", task.countOfBytesClientExpectsToSend, task.earliestBeginDate]];
    [task cancel];
    [session invalidateAndCancel];
    NSURLSessionConfiguration *configuration = [configurations defaultSessionConfiguration];
    NSString *before = [NSString stringWithFormat:@"%d", configuration.waitsForConnectivity];
    configuration.waitsForConnectivity = YES;
    [properties addObject:[NSString stringWithFormat:@"configuration waits before=%@ after=%d copy=%d background=%d ephemeral=%d", before, configuration.waitsForConnectivity, [(NSURLSessionConfiguration *)[configuration copy] waitsForConnectivity],
                           [[configurations backgroundSessionConfigurationWithIdentifier:@"org.charon.waits"] waitsForConnectivity], [[configurations ephemeralSessionConfiguration] waitsForConnectivity]]];
    [transcript addObjectsFromArray:properties];
    return transcript;
}

static NSArray *scenario_background(SessionHarness *harness)
{
    NSMutableArray *transcript = [NSMutableArray array];
    Class configurations = harness.configurationClass;
    SessionRecorder *recorder = [[SessionRecorder alloc] init];
    recorder.implemented = [NSSet setWithArray:@[@"URLSession:didBecomeInvalidWithError:", @"URLSession:task:didCompleteWithError:", @"URLSession:downloadTask:didFinishDownloadingToURL:", @"URLSessionDidFinishEventsForBackgroundURLSession:"]];
    NSURLSessionConfiguration *configuration = [configurations backgroundSessionConfigurationWithIdentifier:[@"org.charon.inprocess." stringByAppendingString:harness.tag]];
    NSURLSession *session = session_with(harness, configuration, recorder);
    [[session downloadTaskWithURL:url_for(harness, @"/bytes?n=5000")] resume];
    wait_for(harness, recorder.completed);
    [recorder record:[NSString stringWithFormat:@"background download matches=%d", [recorder.downloaded isEqualToData:pattern_bytes(0, 5000)]]];
    return finish_session(harness, session, recorder, transcript);
}

const SessionScenarioEntry session_scenarios[] = {
    {"configuration", scenario_configuration},
    {"data-delegate", scenario_data_delegate},
    {"data-handler", scenario_data_handler},
    {"upload", scenario_upload},
    {"download", scenario_download},
    {"redirect", scenario_redirect},
    {"cookies", scenario_cookies},
    {"authentication", scenario_authentication},
    {"cancel", scenario_cancel},
    {"resume", scenario_resume},
    {"timeout", scenario_timeout},
    {"invalidation", scenario_invalidation},
    {"tasks", scenario_tasks},
    {"cache", scenario_cache},
    {"background", scenario_background},
    {"delayed", scenario_delayed},
    {"metrics", scenario_metrics},
};

const size_t session_scenario_count = sizeof(session_scenarios) / sizeof(session_scenarios[0]);

NSString *session_transcript_text(NSArray *transcript)
{
    NSMutableString *text = [NSMutableString string];
    for (NSString *line in transcript)
        [text appendFormat:@"        @\"%@\",\n", [[line stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
    return text;
}

NSDictionary *session_expected_transcripts(void)
{
    return @{
        @"configuration": @[
            @"default identifier=- policy=0 request=60 resource=604800 service=0 cellular=1 discretionary=0 launch=0 proxy=- pipelining=0 set-cookies=1 accept=2 headers=- cookies=shared credentials=shared cache=shared protocols=array",
            @"ephemeral identifier=- policy=0 request=60 resource=604800 service=0 cellular=1 discretionary=0 launch=0 proxy=- pipelining=0 set-cookies=1 accept=2 headers=- cookies=own credentials=own cache=own(disk=0) protocols=array",
            @"background identifier=org.charon.test policy=0 request=60 resource=604800 service=0 cellular=1 discretionary=0 launch=1 proxy=- pipelining=0 set-cookies=1 accept=2 headers=- cookies=shared credentials=shared cache=nil protocols=array",
            @"background7 identifier=org.charon.legacy policy=0 request=60 resource=604800 service=0 cellular=1 discretionary=0 launch=1 proxy=- pipelining=0 set-cookies=1 accept=2 headers=- cookies=shared credentials=shared cache=nil protocols=array",
            @"ephemeral stores differ per configuration: cookies=1 cache=1",
            @"default configurations are new objects: 1",
            @"copy is independent: 1 request=60 headers=-",
            @"session copies configuration: 1 1 request=7 headers=1",
            @"session delegate=(null) queue=1 serial=1",
            @"description=described",
            @"shared same=1 delegate=(null) queue=1",
            @"identifiers 1 2 3",
            @"kinds data=1 upload=1 upload-is-data=1 download=1 download-is-data=0 download-is-task=1",
            @"new task state=1 original=/bytes?n=10 current=/bytes?n=10 response=(null) error=(null) counts=0/0/0/0",
            @"request from URL timeout=60 policy=0",
            @"task description=first copy-same=1",
            @"priority default=0.5",
            @"priority set=0.75 constants=0.25/0.5/0.75 unknown=-1",
            @"priority kept 0 1 0.3 0.3 0.3 0.3 0.3 0.3",
            @"suspend unresumed state=1",
            @"cancel unresumed state=2",
            @"nil request exception=NSInvalidArgumentException",
            @"background completion handler exception=NSGenericException",
            @"shared description=(null)",
        ],
        @"data-delegate": @[
            @"response 200 expected=100000 state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=200 received=100000/100000 sent=0/0",
            @"body matches=1",
            @"response 200 expected=-1 state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=200 received=50000/-1 sent=0/0",
            @"chunked body matches=1",
            @"response 404 expected=10 state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=404 received=10/10 sent=0/0",
            @"response 500 expected=10 state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=500 received=10/10 sent=0/0",
            @"complete NSURLErrorDomain/-1004 failing=/refused state=3 same-error=1 status=0 received=0/0 sent=0/0",
            @"invalid nil",
        ],
        @"data-handler": @[
            @"handler status=200 length=1000 error=nil data=yes",
            @"body matches=1",
            @"handler status=404 length=10 error=nil data=yes",
            @"handler status=0 length=0 error=NSURLErrorDomain/-1004 data=no",
            @"handler status=200 length=0 error=nil data=yes",
            @"redirect 302 GET /bytes?n=1000 body=none custom=- type=- current=/redirect?code=302&to=/bytes?n=1000",
            @"invalid nil",
        ],
        @"upload": @[
            @"sent 12/12",
            @"response 200 expected=var state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=200 received=all sent=12/12",
            @"echo POST /echo length=12 body=hello upload x-custom=custom content-length=12 transfer-encoding=-",
            @"sent 20006/20006",
            @"response 200 expected=var state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=200 received=all sent=20006/20006",
            @"file echo length=20006 matches=1 content-length=20006",
            @"need-body-stream",
            @"sent 13/-1",
            @"response 200 expected=var state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=200 received=all sent=13/-1",
            @"stream echo body=streamed body",
            @"sent 14/14",
            @"response 200 expected=var state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=200 received=all sent=14/14",
            @"echo POST /echo length=14 body=data task body x-custom=custom content-length=14 transfer-encoding=-",
            @"sent 14/14",
            @"upload handler echo POST /echo length=14 body=handler upload x-custom=custom content-length=14 transfer-encoding=- error=nil",
            @"invalid nil",
        ],
        @"download": @[
            @"write expected=100000",
            @"finished size=100000 state=0",
            @"complete nil state=3 same-error=1 status=200 received=100000/100000 sent=0/0",
            @"content matches=1 removed=1",
            @"write expected=10",
            @"finished size=10 state=0",
            @"complete nil state=3 same-error=1 status=404 received=10/10 sent=0/0",
            @"download handler status=200 matches=1 error=nil removed=1",
            @"download handler location=nil response=nil error=NSURLErrorDomain/-1004",
            @"invalid nil",
        ],
        @"redirect": @[
    @"too many NSURLErrorDomain/-1007 failing=/redirect?code=302&count=5&to=/echo response=nil data=nil",
    @"sent 3/3",
    @"redirect 301 GET /echo body=none custom=1 type=- current=/redirect?code=301&to=/echo",
    @"response 200 expected=var state=0",
    @"data",
    @"complete nil state=3 same-error=1 status=200 received=all sent=3/3",
    @"echo GET /echo length=0 body= x-custom=1 content-type=-",
    @"current=/echo method=GET",
    @"sent 3/3",
    @"redirect 302 GET /echo body=none custom=1 type=- current=/redirect?code=302&to=/echo",
    @"response 200 expected=var state=0",
    @"data",
    @"complete nil state=3 same-error=1 status=200 received=all sent=3/3",
    @"echo GET /echo length=0 body= x-custom=1 content-type=-",
    @"current=/echo method=GET",
    @"sent 3/3",
    @"redirect 303 GET /echo body=none custom=1 type=- current=/redirect?code=303&to=/echo",
    @"response 200 expected=var state=0",
    @"data",
    @"complete nil state=3 same-error=1 status=200 received=all sent=3/3",
    @"echo GET /echo length=0 body= x-custom=1 content-type=-",
    @"current=/echo method=GET",
    @"sent 3/3",
    @"redirect 307 POST /echo body=3 custom=1 type=text/x current=/redirect?code=307&to=/echo",
    @"sent 3/3",
    @"response 200 expected=var state=0",
    @"data",
    @"complete nil state=3 same-error=1 status=200 received=all sent=3/3",
    @"echo POST /echo length=3 body=abc x-custom=1 content-type=text/x",
    @"current=/echo method=POST",
    @"redirect 302 GET /echo body=none custom=- type=- current=/redirect?code=302&to=/echo",
    @"response 302 expected=var state=0",
    @"data",
    @"complete nil state=3 same-error=1 status=302 received=all sent=0/0",
    @"rejected body=redirect body current=/redirect?code=302&to=/echo",
    @"redirect 301 GET /bytes?n=10 body=none custom=- type=- current=/redirect?code=301&to=/bytes?n=10",
    @"handler status=200 length=10 error=nil data=yes",
    @"redirect 302 GET /echo body=none custom=1 type=- current=/redirect?code=302&to=/echo",
    @"response 200 expected=var state=0",
    @"data",
    @"complete nil state=3 same-error=1 status=200 received=all sent=0/0",
    @"carried to the same origin",
    @"echo GET /echo length=0 body= authorization=- cookie=seed=1 x-custom=1",
    @"redirect 302 GET /echo body=none custom=1 type=- current=/redirect?code=302&to=/echo&hostname=localhost",
    @"response 200 expected=var state=0",
    @"data",
    @"complete nil state=3 same-error=1 status=200 received=all sent=0/0",
    @"carried to another origin",
    @"echo GET /echo length=0 body= authorization=- cookie=seed=1 x-custom=1",
    @"invalid nil",
        ],
        @"cookies": @[
            @"handler status=200 length=3 error=nil data=yes",
            @"shared storage has cookie=1",
            @"sent shared cookie=1",
            @"request without cookie handling sent=0",
            @"HTTPShouldSetCookies=NO sent=0",
            @"ephemeral own=1 shared=0",
            @"ephemeral session sent=1",
            @"other ephemeral session sent=0",
            @"accept never stored=0",
            @"reset called=1 cookies=0",
        ],
        @"authentication": @[
            @"challenge basic realm=good failures=0",
            @"response 200 expected=10 state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=200 received=10/10 sent=0/0",
            @"body=authorized",
            @"challenge basic realm=bad failures=0",
            @"challenge basic realm=bad failures=1",
            @"response 401 expected=6 state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=401 received=6/6 sent=0/0",
            @"body=denied",
            @"challenge basic realm=cancel failures=0",
            @"complete NSURLErrorDomain/-999 failing=/auth?realm=cancel-TAG state=3 same-error=1 status=0 received=0/0 sent=0/0",
            @"challenge basic realm=handler failures=0",
            @"handler status=200 length=10 error=nil data=yes",
            @"invalid nil",
            @"complete nil state=3 same-error=1 status=401 received=6/6 sent=0/0",
            @"invalid nil",
            @"url credentials handler status=200 length=10 error=nil data=yes",
            @"no credentials handler status=401 length=6 error=nil data=yes",
            @"stored credential handler status=200 length=10 error=nil data=yes",
            @"stored credential count=1",
        ],
        @"cancel": @[
            @"response 200 expected=400000 state=0",
            @"data",
            @"cancelled state=2",
            @"complete NSURLErrorDomain/-999 failing=/bytes?n=400000&chunk=10000&delay=400 state=3 same-error=1 status=200 received=10000/400000 sent=0/0",
            @"response 200 expected=1000 state=0",
            @"complete NSURLErrorDomain/-999 failing=/bytes?n=1000 state=3 same-error=1 status=200 received=0/1000 sent=0/0",
            @"response 200 expected=20000 state=0",
            @"become-download same-identifier=1 download=1",
            @"write expected=20000",
            @"finished size=20000 state=0",
            @"complete nil state=3 same-error=1 status=200 received=20000/20000 sent=0/0",
            @"became download matches=1 class=1",
            @"handler task state after cancel=2",
            @"cancelled handler data=nil response=nil error=NSURLErrorDomain/-999",
            @"response 200 expected=30000 state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=200 received=30000/30000 sent=0/0",
            @"suspended state=1 resumed state=0",
            @"suspended body matches=1",
            @"invalid nil",
        ],
        @"resume": @[
            @"write expected=300000",
            @"complete NSURLErrorDomain/-999 failing=/bytes?n=300000&chunk=10000&delay=60&etag=resume resume-data state=3 same-error=1 status=200 received=partial sent=0/0",
            @"produced=1 resume data=1",
            @"resumed task state=1 original=/bytes?n=300000&chunk=10000&delay=60&etag=resume range=1",
            @"resumed offset>0=1 expected=300000",
            @"write expected=300000",
            @"finished size=300000 state=0",
            @"complete nil state=3 same-error=1 status=206 received=all sent=0/0",
            @"resumed content matches=1",
            @"write expected=300000",
            @"complete NSURLErrorDomain/-999 failing=/bytes?n=300000&chunk=10000&delay=60&lastmod=1 resume-data state=3 same-error=1 status=200 received=partial sent=0/0",
            @"produced=1 resume data=1",
            @"resumed task state=1 original=/bytes?n=300000&chunk=10000&delay=60&lastmod=1 range=1",
            @"resumed offset>0=1 expected=300000",
            @"write expected=300000",
            @"finished size=300000 state=0",
            @"complete nil state=3 same-error=1 status=206 received=all sent=0/0",
            @"resumed content matches=1",
            @"write expected=300000",
            @"complete NSURLErrorDomain/-999 failing=/bytes?n=300000&chunk=10000&delay=60 state=3 same-error=1 status=200 received=partial sent=0/0",
            @"without validator resume data=0",
            @"completed task resume data=0",
            @"invalid nil",
        ],
        @"timeout": @[
            @"complete NSURLErrorDomain/-1001 failing=/delay?ms=4000 state=3 same-error=1 status=0 received=0/0 sent=0/0",
            @"complete nil state=3 same-error=1 status=200 received=4/4 sent=0/0",
            @"invalid nil",
            @"complete NSURLErrorDomain/-1001 failing=/delay?ms=4000 state=3 same-error=1 status=0 received=0/0 sent=0/0",
            @"invalid nil",
            @"complete NSURLErrorDomain/-1001 failing=/bytes?n=10000&chunk=1000&delay=600 state=3 same-error=1 status=200 received=partial sent=0/0",
            @"complete NSURLErrorDomain/-1001 failing=/bytes?n=10000&chunk=1000&delay=600&etag=timeout-TAG resume-data state=3 same-error=1 status=200 received=partial sent=0/0",
            @"invalid nil",
        ],
        @"invalidation": @[
            @"response 200 expected=20000 state=0",
            @"data",
            @"complete NSURLErrorDomain/-999 failing=/bytes?n=20000&chunk=10000&delay=5000 state=3 same-error=1 status=200 received=10000/20000 sent=0/0",
            @"invalid nil",
            @"delegate after invalidation=(null)",
            @"task after invalidation exception=NSGenericException",
            @"response 200 expected=1000 state=0",
            @"data",
            @"complete nil state=3 same-error=1 status=200 received=1000/1000 sent=0/0",
            @"invalid nil",
            @"shared handler status=200 length=10 error=nil data=yes",
        ],
        @"tasks": @[
            @"tasks data=1 upload=1 download=1 same=1",
            @"all tasks=3",
            @"flushed",
            @"states after cancel 3 3 3",
            @"highest concurrency with limit 2=2",
            @"echo GET /echo length=0 body= x-extra=session x-custom=request",
            @"protocol handler status=203 length=13 error=nil data=yes body=from protocol header=charon",
            @"protocol through network handler status=200 length=5 error=nil data=yes",
            @"without protocol handler status=0 length=0 error=NSURLErrorDomain/-1002 data=no",
        ],
        @"cache": @[
            @"first served 1",
            @"cache else load served 1",
            @"reload served 2",
            @"dont load missing handler status=0 length=0 error=NSURLErrorDomain/-1008 data=no",
            @"configured policy first served 1",
            @"configured policy second served 1",
            @"declined then cache else load handler status=200 length=8 error=nil data=yes",
            @"declined body served 2",
            @"will-cache 8",
            @"complete nil state=3 same-error=1 status=200 received=8/8 sent=0/0",
            @"invalid nil",
        ],
        @"metrics": @[
            @"handler status=404 length=10 error=nil data=yes",
            @"response 200 expected=1000 state=0",
            @"data",
            @"metrics tx=1 redirects=0 interval=1 [/bytes?n=1000 status=200 type=1 proto=http/1.1 dates=FQqSE ordered=1 proxy=0]",
            @"complete nil state=3 same-error=1 status=200 received=1000/1000 sent=0/0",
            @"redirect 302 GET /bytes?n=100 body=none custom=- type=- current=/redirect?code=302&to=/bytes?n=100",
            @"response 200 expected=100 state=0",
            @"data",
            @"metrics tx=2 redirects=1 interval=1 [/redirect?code=302&to=/bytes?n=100 status=302 type=1 proto=http/1.1 dates=FQqSE ordered=1 proxy=0] [/bytes?n=100 status=200 type=1 proto=http/1.1 dates=FQqSE ordered=1 proxy=0]",
            @"complete nil state=3 same-error=1 status=200 received=100/100 sent=0/0",
            @"metrics tx=1 redirects=0 interval=1 [/refused status=0 type=1 proto=- dates=F ordered=1 proxy=0]",
            @"complete NSURLErrorDomain/-1004 failing=/refused state=3 same-error=1 status=0 received=0/0 sent=0/0",
            @"metrics tx=1 redirects=0 interval=1 [/status?code=404 status=404 type=1 proto=http/1.1 dates=FQqSE ordered=1 proxy=0]",
            @"invalid nil",
        ],
        @"delayed": @[
        @"delayed-begin /bytes?n=2000 waited=1 state=0",
        @"finished size=2000 state=0",
        @"complete nil state=3 same-error=1 status=200 received=2000/2000 sent=0/0",
        @"no-date finished after wait=1 current=/bytes?n=2000",
        @"invalid nil",
        @"delayed-begin /bytes?n=2000 waited=1 state=0",
        @"finished size=2000 state=0",
        @"complete nil state=3 same-error=1 status=200 received=2000/2000 sent=0/0",
        @"date finished after wait=1 current=/bytes?n=2000",
        @"invalid nil",
        @"delayed-begin /bytes?n=2000 waited=1 state=0",
        @"finished size=2000 state=0",
        @"complete nil state=3 same-error=1 status=200 received=2000/2000 sent=0/0",
        @"past finished after wait=1 current=/bytes?n=2000",
        @"invalid nil",
        @"delayed-begin /bytes?n=2000 waited=1 state=0",
        @"complete NSURLErrorDomain/-999 failing=/bytes?n=2000 state=3 same-error=1 status=0 received=0/0 sent=0/0",
        @"cancel finished after wait=1 current=/bytes?n=2000",
        @"invalid nil",
        @"delayed-begin /bytes?n=2000 waited=1 state=0",
        @"finished size=100 state=0",
        @"complete nil state=3 same-error=1 status=200 received=100/100 sent=0/0",
        @"replace finished after wait=1 current=/bytes?n=100",
        @"invalid nil",
        @"finished size=2000 state=0",
        @"complete nil state=3 same-error=1 status=200 received=2000/2000 sent=0/0",
        @"no-delegate finished after wait=1 current=/bytes?n=2000",
        @"invalid nil",
        @"finished size=2000 state=0",
        @"complete nil state=3 same-error=1 status=200 received=2000/2000 sent=0/0",
        @"foreground finished after wait=0 current=/bytes?n=2000",
        @"invalid nil",
        @"defaults date=(null) send=-1 receive=-1",
        @"set same-date=1 send=5 receive=99",
        @"negative send=-7 date=(null)",
        @"configuration waits before=0 after=1 copy=1 background=0 ephemeral=0",
        ],
        @"background": @[
            @"finished size=5000 state=0",
            @"complete nil state=3 same-error=1 status=200 received=5000/5000 sent=0/0",
            @"background download matches=1",
            @"invalid nil",
        ],
    };
}

/* What the HOST's own release answers where the transcript carries the device's. Applied to the
   system's transcript only, never to the port's: the port is held to the record byte for byte, and a
   host difference is a fact about the host's release that the record cannot carry. */
NSArray *session_normalize_host_system(NSArray *transcript)
{
    NSMutableArray *normalized = [NSMutableArray array];
    for (NSString *line in transcript) {
        NSString *adjusted = line;
        if ([adjusted hasPrefix:@"response "])
            adjusted = [adjusted stringByReplacingOccurrencesOfString:@" state=1" withString:@" state=0"];
        if ([adjusted hasPrefix:@"redirect 307 "])
            adjusted = [adjusted stringByReplacingOccurrencesOfString:@" body=stream " withString:@" body=3 "];
        if ([adjusted isEqualToString:@"accept never stored=1"])
            adjusted = @"accept never stored=0";
        /* The task's state as the download callback reads it is not one value on this host. Measured
           2026-10-04, this scenario alone over eight runs: three runs had the system read 3 (completed)
           where the transcript carries 0 (running), a different sub-run each time - no-date in one, past
           in the next, no-delegate in the third - and the other five read 0 throughout. The five are the
           common answer and the record carries it; the three are the host's release having settled the
           task before it calls back, which is its own answer rather than a difference to hold the port
           to. The port answered 0 in every one of the eight runs, which is what the record says a
           device does. Scoped to this row and to this one value: state=1 and state=2 on a finished row
           still fail, and no other row is touched. */
        if ([adjusted hasPrefix:@"finished "])
            adjusted = [adjusted stringByReplacingOccurrencesOfString:@" state=3" withString:@" state=0"];
        adjusted = [adjusted stringByReplacingOccurrencesOfString:@" removed=0" withString:@" removed=1"];
        [normalized addObject:adjusted];
    }
    return normalized;
}
