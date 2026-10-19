#import "CharonURLSessionMetrics.h"
#import "CharonTaskDelegate15.h"
#import "CharonNetworkAccess.h"
#include <limits.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <SystemConfiguration/SystemConfiguration.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>

const int64_t NSURLSessionTransferSizeUnknown = -1LL;
NSString * const NSURLSessionDownloadTaskResumeData = @"NSURLSessionDownloadTaskResumeData";

static NSString * const CharonResumeInfoVersion = @"NSURLSessionResumeInfoVersion";
static NSString * const CharonResumeDownloadURL = @"NSURLSessionDownloadURL";
static NSString * const CharonResumeBytesReceived = @"NSURLSessionResumeBytesReceived";
static NSString * const CharonResumeCurrentRequest = @"NSURLSessionResumeCurrentRequest";
static NSString * const CharonResumeOriginalRequest = @"NSURLSessionResumeOriginalRequest";
static NSString * const CharonResumeEntityTag = @"NSURLSessionResumeEntityTag";
static NSString * const CharonResumeServerDownloadDate = @"NSURLSessionResumeServerDownloadDate";
static NSString * const CharonResumeTempFileName = @"NSURLSessionResumeInfoTempFileName";
static NSString * const CharonResumeLocalPath = @"NSURLSessionResumeInfoLocalPath";
static NSString * const CharonCachedDateKey = @"CharonURLSessionStoredDate";

typedef void (^CharonDataHandler)(NSData *data, NSURLResponse *response, NSError *error);
typedef void (^CharonDownloadHandler)(NSURL *location, NSURLResponse *response, NSError *error);

typedef NS_ENUM(NSInteger, CharonTaskBody) {
    CharonTaskBodyNone,
    CharonTaskBodyData,
    CharonTaskBodyFile,
    CharonTaskBodyStream
};

@class CharonURLSessionLoader;

@interface NSURLSession () {
@package
    NSURLSessionConfiguration *_configuration;
    id<NSURLSessionDelegate> _delegate;
    NSOperationQueue *_delegateQueue;
    NSString *_sessionDescription;
    BOOL _shared;
    BOOL _invalidated;
    NSUInteger _lastTaskIdentifier;
    NSMutableArray *_tasks;
    NSMutableArray *_waitingTasks;
    NSMutableDictionary *_connectionsPerHost;
    NSMutableArray *_events;
    BOOL _delivering;
    BOOL _invalidating;
    BOOL _invalidationQueued;
}
@end

@interface NSURLSessionTask () {
@package
    NSURLSession *_session;
    NSUInteger _taskIdentifier;
    NSURLRequest *_originalRequest;
    NSURLRequest *_currentRequest;
    NSURLResponse *_response;
    NSError *_error;
    NSString *_taskDescription;
    NSURLSessionTaskState _state;
    int64_t _countOfBytesReceived;
    int64_t _countOfBytesSent;
    int64_t _countOfBytesExpectedToSend;
    int64_t _countOfBytesExpectedToReceive;

    CharonTaskBody _body;
    NSData *_bodyData;
    NSURL *_bodyFile;
    NSInputStream *_bodyStream;
    CharonDataHandler _dataHandler;
    CharonDownloadHandler _downloadHandler;
    NSMutableData *_receivedData;
    BOOL _started;
    BOOL _paused;
    BOOL _finished;
    BOOL _awaiting;
    BOOL _holdsSlot;
    BOOL _handlerCalled;
    NSString *_hostKey;
    NSMutableArray *_deferredInput;
    CharonURLSessionLoader *_loader;
    NSUInteger _redirects;
    NSTimeInterval _idleInterval;
    CFAbsoluteTime _resourceDeadline;
    CFRunLoopTimerRef _idleTimer;
    CFRunLoopTimerRef _resourceTimer;
    NSCachedURLResponse *_proposedCache;

    NSFileHandle *_file;
    NSURL *_fileURL;
    int64_t _resumeOffset;
    NSString *_entityTag;
    NSString *_lastModified;
    BOOL _resumeInvalid;
    NSData *_producedResumeData;

    NSMutableArray *_metricsTransactions;
    NSDate *_metricsStart;

    NSDate *_earliestBeginDate;
    int64_t _clientExpectsToSend;
    int64_t _clientExpectsToReceive;
    BOOL _prefersIncrementalDelivery;
    BOOL _connectivityNotified;
    CFRunLoopTimerRef _delayTimer;
    SCNetworkReachabilityRef _reachability;
    void (^_pendingBegin)(void);
}
@end

__attribute__((visibility("hidden")))
@interface CharonURLSessionLoader : NSObject <NSURLConnectionDataDelegate, NSURLProtocolClient> {
@package
    NSURLSessionTask *_task;
    NSURLConnection *_connection;
    NSURLProtocol *_protocol;
    NSURLCacheStoragePolicy _protocolCachePolicy;
    NSMutableData *_protocolData;
    NSURLResponse *_protocolResponse;
    BOOL _pendingStart;
    BOOL _stopped;
}
@end

__attribute__((visibility("hidden")))
@interface CharonURLSessionStreamReply : NSObject {
@package
    NSInputStream *_stream;
}
@end

@implementation CharonURLSessionStreamReply
@end

static CFRunLoopRef charon_loader_run_loop;

static void charon_loader_source_perform(void *info)
{
}

#if OS_OBJECT_USE_OBJC
static void *charon_context_of(dispatch_semaphore_t semaphore)
{
    return (__bridge void *)semaphore;
}

static dispatch_semaphore_t charon_semaphore_of(void *context)
{
    return (__bridge dispatch_semaphore_t)context;
}
#else
static void *charon_context_of(dispatch_semaphore_t semaphore)
{
    return semaphore;
}

static dispatch_semaphore_t charon_semaphore_of(void *context)
{
    return (dispatch_semaphore_t)context;
}
#endif

static void *charon_loader_main(void *context)
{
    @autoreleasepool {
        pthread_setname_np("org.charon.NSURLSession");
        charon_loader_run_loop = (CFRunLoopRef)CFRetain(CFRunLoopGetCurrent());
        CFRunLoopSourceContext sourceContext = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, charon_loader_source_perform};
        CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &sourceContext);
        CFRunLoopAddSource(charon_loader_run_loop, source, kCFRunLoopDefaultMode);
        CFRelease(source);
        dispatch_semaphore_signal(charon_semaphore_of(context));
    }
    while (1) {
        @autoreleasepool {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
        }
    }
    return NULL;
}

static void charon_perform(void (^block)(void))
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_semaphore_t ready = dispatch_semaphore_create(0);
        pthread_attr_t attributes;
        pthread_attr_init(&attributes);
        pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
        pthread_t thread;
        pthread_create(&thread, &attributes, charon_loader_main, charon_context_of(ready));
        pthread_attr_destroy(&attributes);
        dispatch_semaphore_wait(ready, DISPATCH_TIME_FOREVER);
    });
    CFRunLoopPerformBlock(charon_loader_run_loop, kCFRunLoopDefaultMode, ^{
        @autoreleasepool {
            block();
        }
    });
    CFRunLoopWakeUp(charon_loader_run_loop);
}

static CFRunLoopTimerRef charon_timer_create(CFAbsoluteTime fireDate, void (^fire)(void))
{
    CFRunLoopTimerRef timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, ^(CFRunLoopTimerRef unused) {
        @autoreleasepool {
            fire();
        }
    });
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
    return timer;
}

static void charon_timer_cancel(CFRunLoopTimerRef *timer)
{
    if (*timer) {
        CFRunLoopTimerInvalidate(*timer);
        CFRelease(*timer);
        *timer = NULL;
    }
}

static id charon_session_delegate(NSURLSession *session)
{
    @synchronized (session) {
        return session->_delegate;
    }
}

static id charon_task_delegate(NSURLSession *session, NSURLSessionTask *task, SEL selector)
{
    if (task) {
        id<NSURLSessionTaskDelegate> own = [task delegate];
        if (own && [own respondsToSelector:selector])
            return own;
    }
    return charon_session_delegate(session);
}

static BOOL charon_delegate_responds(NSURLSession *session, NSURLSessionTask *task, SEL selector)
{
    return [charon_task_delegate(session, task, selector) respondsToSelector:selector];
}

static void charon_session_pump(NSURLSession *session)
{
    if (session->_delivering || session->_events.count == 0)
        return;
    void (^event)(void) = session->_events[0];
    [session->_events removeObjectAtIndex:0];
    session->_delivering = YES;
    [session->_delegateQueue addOperationWithBlock:^{
        @autoreleasepool {
            event();
        }
        charon_perform(^{
            session->_delivering = NO;
            charon_session_pump(session);
        });
    }];
}

static void charon_session_deliver(NSURLSession *session, void (^event)(void))
{
    [session->_events addObject:[event copy]];
    charon_session_pump(session);
}

static void charon_session_check_invalidation(NSURLSession *session)
{
    if (!session->_invalidating || session->_invalidationQueued || session->_tasks.count)
        return;
    session->_invalidationQueued = YES;
    charon_session_deliver(session, ^{
        id delegate = charon_session_delegate(session);
        if ([delegate respondsToSelector:@selector(URLSession:didBecomeInvalidWithError:)])
            [delegate URLSession:session didBecomeInvalidWithError:nil];
        @synchronized (session) {
            session->_delegate = nil;
        }
    });
}

static NSError *charon_task_error(NSURLSessionTask *task, NSInteger code, NSString *description, NSURL *url)
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (description)
        userInfo[NSLocalizedDescriptionKey] = description;
    url = url ?: task->_currentRequest.URL;
    if (url) {
        userInfo[NSURLErrorFailingURLErrorKey] = url;
        userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString;
    }
    return [NSError errorWithDomain:NSURLErrorDomain code:code userInfo:userInfo];
}

static NSError *charon_cancelled_error(NSURLSessionTask *task)
{
    return charon_task_error(task, NSURLErrorCancelled, @"cancelled", nil);
}

static NSString *charon_header(NSURLResponse *response, NSString *name)
{
    if (![response isKindOfClass:[NSHTTPURLResponse class]])
        return nil;
    NSDictionary *fields = [(NSHTTPURLResponse *)response allHeaderFields];
    for (NSString *key in fields) {
        if ([key caseInsensitiveCompare:name] == NSOrderedSame)
            return fields[key];
    }
    return nil;
}

static BOOL charon_is_download(NSURLSessionTask *task)
{
    return [task isKindOfClass:[NSURLSessionDownloadTask class]];
}

static BOOL charon_cookie_domain_matches(NSString *host, NSString *domain)
{
    host = host.lowercaseString;
    domain = domain.lowercaseString;
    if ([domain hasPrefix:@"."])
        return [host isEqualToString:[domain substringFromIndex:1]] || [host hasSuffix:domain];
    return [host isEqualToString:domain];
}

static void charon_store_cookies(NSURLSessionTask *task, NSURLResponse *response)
{
    NSURLSessionConfiguration *configuration = task->_session->_configuration;
    NSHTTPCookieStorage *storage = configuration.HTTPCookieStorage;
    NSURLRequest *request = task->_currentRequest;
    NSHTTPCookieAcceptPolicy policy = configuration.HTTPCookieAcceptPolicy;
    if (!storage || !request.HTTPShouldHandleCookies || policy == NSHTTPCookieAcceptPolicyNever || ![response isKindOfClass:[NSHTTPURLResponse class]])
        return;
    NSURL *url = response.URL ?: request.URL;
    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[(NSHTTPURLResponse *)response allHeaderFields] forURL:url];
    NSURL *mainDocument = request.mainDocumentURL;
    for (NSHTTPCookie *cookie in cookies) {
        if (policy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain && mainDocument && !charon_cookie_domain_matches(mainDocument.host, cookie.domain))
            continue;
        [storage setCookie:cookie];
    }
}

static NSURLRequestCachePolicy charon_cache_policy(NSURLSessionTask *task, NSURLRequest *request)
{
    return request.cachePolicy == NSURLRequestUseProtocolCachePolicy ? task->_session->_configuration.requestCachePolicy : request.cachePolicy;
}

static BOOL charon_sends_body(NSURLRequest *request)
{
    NSString *method = request.HTTPMethod.uppercaseString;
    return ![method isEqualToString:@"GET"] && ![method isEqualToString:@"HEAD"];
}

static int64_t charon_file_size(NSURL *url)
{
    NSNumber *size = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:NULL][NSFileSize];
    return size ? size.longLongValue : -1;
}

static int64_t charon_expected_body_length(NSURLSessionTask *task, NSURLRequest *request)
{
    switch (task->_body) {
    case CharonTaskBodyData:
        return task->_bodyData.length;
    case CharonTaskBodyFile:
        return MAX(charon_file_size(task->_bodyFile), 0);
    case CharonTaskBodyStream: {
        NSString *length = [request valueForHTTPHeaderField:@"Content-Length"];
        return length ? length.longLongValue : NSURLSessionTransferSizeUnknown;
    }
    case CharonTaskBodyNone:
        if (request.HTTPBody)
            return request.HTTPBody.length;
        return 0;
    }
    return 0;
}

static NSURLRequest *charon_wire_request(NSURLSessionTask *task, NSURLRequest *request)
{
    NSURLSessionConfiguration *configuration = task->_session->_configuration;
    NSMutableURLRequest *wire = [request mutableCopy];
    NSDictionary *additional = configuration.HTTPAdditionalHeaders;
    for (id name in additional) {
        id value = additional[name];
        if ([value isKindOfClass:[NSNumber class]])
            value = [value stringValue];
        if ([name isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]] && ![wire valueForHTTPHeaderField:name])
            [wire setValue:value forHTTPHeaderField:name];
    }
    NSHTTPCookieStorage *storage = configuration.HTTPCookieStorage;
    if (configuration.HTTPShouldSetCookies && request.HTTPShouldHandleCookies && storage && ![wire valueForHTTPHeaderField:@"Cookie"]) {
        NSArray *cookies = [storage cookiesForURL:wire.URL];
        if (cookies.count) {
            NSDictionary *fields = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
            for (NSString *name in fields)
                [wire setValue:fields[name] forHTTPHeaderField:name];
        }
    }
    wire.HTTPShouldHandleCookies = NO;
    wire.allowsCellularAccess = configuration.allowsCellularAccess && request.allowsCellularAccess;
    if ([configuration respondsToSelector:@selector(allowsExpensiveNetworkAccess)] && !configuration.allowsExpensiveNetworkAccess)
        wire.allowsExpensiveNetworkAccess = NO;
    if ([configuration respondsToSelector:@selector(allowsConstrainedNetworkAccess)] && !configuration.allowsConstrainedNetworkAccess)
        wire.allowsConstrainedNetworkAccess = NO;
    if (wire.networkServiceType == NSURLNetworkServiceTypeDefault)
        wire.networkServiceType = configuration.networkServiceType;
    if (configuration.HTTPShouldUsePipelining)
        wire.HTTPShouldUsePipelining = YES;
    if (task->_idleInterval > 0)
        wire.timeoutInterval = task->_idleInterval;
    NSURLRequestCachePolicy policy = charon_cache_policy(task, request);
    wire.cachePolicy = configuration.URLCache == [NSURLCache sharedURLCache] ? policy : NSURLRequestReloadIgnoringLocalCacheData;
    if (charon_sends_body(request)) {
        switch (task->_body) {
        case CharonTaskBodyData:
            wire.HTTPBody = task->_bodyData;
            break;
        case CharonTaskBodyFile:
            wire.HTTPBodyStream = [NSInputStream inputStreamWithURL:task->_bodyFile];
            if (![wire valueForHTTPHeaderField:@"Content-Length"])
                [wire setValue:[NSString stringWithFormat:@"%lld", MAX(charon_file_size(task->_bodyFile), 0)] forHTTPHeaderField:@"Content-Length"];
            break;
        case CharonTaskBodyStream:
            wire.HTTPBodyStream = task->_bodyStream;
            task->_bodyStream = nil;
            break;
        case CharonTaskBodyNone:
            break;
        }
    }
    return wire;
}

static void charon_task_finish(NSURLSessionTask *task, NSError *error);
static void charon_task_stop_watching(NSURLSessionTask *task);
static void charon_task_load(NSURLSessionTask *task, NSURLRequest *request);
static void charon_task_flush_input(NSURLSessionTask *task);

static void charon_loader_stop(CharonURLSessionLoader *loader)
{
    if (!loader || loader->_stopped)
        return;
    loader->_stopped = YES;
    loader->_task = nil;
    NSURLConnection *connection = loader->_connection;
    NSURLProtocol *protocol = loader->_protocol;
    [connection cancel];
    [protocol stopLoading];
    charon_perform(^{
        [loader class];
        [connection class];
        [protocol class];
    });
}

static void charon_loader_start_pending(CharonURLSessionLoader *loader)
{
    if (!loader || loader->_stopped || !loader->_pendingStart)
        return;
    loader->_pendingStart = NO;
    [loader->_connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [loader->_connection start];
}

static void charon_task_restart_idle_timer(NSURLSessionTask *task)
{
    if (task->_finished || task->_paused || task->_awaiting || !task->_loader || task->_idleInterval <= 0) {
        charon_timer_cancel(&task->_idleTimer);
        return;
    }
    CFAbsoluteTime fireDate = CFAbsoluteTimeGetCurrent() + task->_idleInterval;
    if (task->_idleTimer) {
        CFRunLoopTimerSetNextFireDate(task->_idleTimer, fireDate);
        return;
    }
    task->_idleTimer = charon_timer_create(fireDate, ^{
        charon_task_finish(task, charon_task_error(task, NSURLErrorTimedOut, @"The request timed out.", nil));
    });
}

static void charon_task_start_resource_timer(NSURLSessionTask *task)
{
    charon_timer_cancel(&task->_resourceTimer);
    if (task->_resourceDeadline <= 0)
        return;
    task->_resourceTimer = charon_timer_create(task->_resourceDeadline, ^{
        charon_task_finish(task, charon_task_error(task, NSURLErrorTimedOut, @"The request timed out.", nil));
    });
}

static void charon_task_await(NSURLSessionTask *task)
{
    task->_awaiting = YES;
    charon_timer_cancel(&task->_idleTimer);
}

static BOOL charon_task_resolve(NSURLSessionTask *task)
{
    if (task->_finished || !task->_awaiting)
        return NO;
    task->_awaiting = NO;
    charon_task_restart_idle_timer(task);
    return YES;
}

static void charon_task_input(CharonURLSessionLoader *loader, void (^input)(NSURLSessionTask *task))
{
    NSURLSessionTask *task = loader->_task;
    if (!task || task->_loader != loader || task->_finished)
        return;
    if (task->_awaiting || task->_paused) {
        [task->_deferredInput addObject:[input copy]];
        return;
    }
    input(task);
}

static void charon_task_flush_input(NSURLSessionTask *task)
{
    while (!task->_finished && !task->_awaiting && !task->_paused && task->_deferredInput.count) {
        void (^input)(NSURLSessionTask *) = task->_deferredInput[0];
        [task->_deferredInput removeObjectAtIndex:0];
        input(task);
    }
}

static NSArray *charon_resume_request_headers(void)
{
    return @[@"Range", @"If-Range"];
}

static NSData *charon_download_resume_data(NSURLSessionTask *task)
{
    NSHTTPURLResponse *response = [task->_response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)task->_response : nil;
    if (!task->_fileURL || !response || (response.statusCode != 200 && response.statusCode != 206))
        return nil;
    if (!task->_entityTag && !task->_lastModified)
        return nil;
    if (![task->_currentRequest.HTTPMethod.uppercaseString isEqualToString:@"GET"])
        return nil;
    int64_t size = charon_file_size(task->_fileURL);
    if (size <= 0)
        return nil;
    NSMutableURLRequest *current = [task->_currentRequest mutableCopy];
    for (NSString *name in charon_resume_request_headers())
        [current setValue:nil forHTTPHeaderField:name];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[CharonResumeInfoVersion] = @2;
    info[CharonResumeDownloadURL] = current.URL.absoluteString;
    info[CharonResumeBytesReceived] = @(size);
    info[CharonResumeCurrentRequest] = [NSKeyedArchiver archivedDataWithRootObject:current];
    info[CharonResumeOriginalRequest] = [NSKeyedArchiver archivedDataWithRootObject:task->_originalRequest];
    info[CharonResumeTempFileName] = task->_fileURL.lastPathComponent;
    if (task->_entityTag)
        info[CharonResumeEntityTag] = task->_entityTag;
    if (task->_lastModified)
        info[CharonResumeServerDownloadDate] = task->_lastModified;
    return [NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
}

static id charon_unarchive(id data, Class kind)
{
    if (![data isKindOfClass:[NSData class]])
        return nil;
    @try {
        id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        return [object isKindOfClass:kind] ? object : nil;
    } @catch (NSException *exception) {
        return nil;
    }
}

static void charon_download_adopt_resume_data(NSURLSessionTask *task, NSData *resumeData)
{
    NSDictionary *info = nil;
    if ([resumeData isKindOfClass:[NSData class]])
        info = [NSPropertyListSerialization propertyListWithData:resumeData options:NSPropertyListImmutable format:NULL error:NULL];
    if (![info isKindOfClass:[NSDictionary class]]) {
        task->_resumeInvalid = YES;
        return;
    }
    NSURLRequest *current = charon_unarchive(info[CharonResumeCurrentRequest], [NSURLRequest class]);
    if (!current && [info[CharonResumeDownloadURL] isKindOfClass:[NSString class]])
        current = [NSURLRequest requestWithURL:[NSURL URLWithString:info[CharonResumeDownloadURL]]];
    NSURLRequest *original = charon_unarchive(info[CharonResumeOriginalRequest], [NSURLRequest class]) ?: current;
    NSString *path = nil;
    if ([info[CharonResumeTempFileName] isKindOfClass:[NSString class]])
        path = [NSTemporaryDirectory() stringByAppendingPathComponent:[info[CharonResumeTempFileName] lastPathComponent]];
    else if ([info[CharonResumeLocalPath] isKindOfClass:[NSString class]])
        path = info[CharonResumeLocalPath];
    NSString *entityTag = [info[CharonResumeEntityTag] isKindOfClass:[NSString class]] ? info[CharonResumeEntityTag] : nil;
    NSString *lastModified = [info[CharonResumeServerDownloadDate] isKindOfClass:[NSString class]] ? info[CharonResumeServerDownloadDate] : nil;
    if (!current.URL || !path || (!entityTag && !lastModified)) {
        task->_resumeInvalid = YES;
        return;
    }
    task->_fileURL = [NSURL fileURLWithPath:path];
    task->_entityTag = entityTag;
    task->_lastModified = lastModified;
    int64_t size = charon_file_size(task->_fileURL);
    NSMutableURLRequest *ranged = [current mutableCopy];
    if (size > 0) {
        [ranged setValue:[NSString stringWithFormat:@"bytes=%lld-", size] forHTTPHeaderField:@"Range"];
        [ranged setValue:entityTag ?: lastModified forHTTPHeaderField:@"If-Range"];
    }
    task->_originalRequest = [original copy];
    task->_currentRequest = [ranged copy];
}

static BOOL charon_download_create_file(NSURLSessionTask *task)
{
    NSString *template = [NSTemporaryDirectory() stringByAppendingPathComponent:@"CFNetworkDownload_XXXXXX.tmp"];
    char path[PATH_MAX];
    if (![template getFileSystemRepresentation:path maxLength:sizeof(path)])
        return NO;
    int descriptor = mkstemps(path, 4);
    if (descriptor < 0)
        return NO;
    task->_file = [[NSFileHandle alloc] initWithFileDescriptor:descriptor closeOnDealloc:YES];
    task->_fileURL = [NSURL fileURLWithPath:[[NSFileManager defaultManager] stringWithFileSystemRepresentation:path length:strlen(path)]];
    return YES;
}

static void charon_download_close(NSURLSessionTask *task)
{
    @try {
        [task->_file synchronizeFile];
    } @catch (NSException *exception) {
    }
    task->_file = nil;
}

static void charon_task_release_slot(NSURLSessionTask *task)
{
    NSURLSession *session = task->_session;
    [session->_waitingTasks removeObjectIdenticalTo:task];
    if (!task->_holdsSlot)
        return;
    task->_holdsSlot = NO;
    NSString *host = task->_hostKey;
    NSInteger active = [session->_connectionsPerHost[host] integerValue] - 1;
    session->_connectionsPerHost[host] = @(MAX(active, 0));
    for (NSURLSessionTask *waiting in [session->_waitingTasks copy]) {
        if (![waiting->_hostKey isEqualToString:host])
            continue;
        [session->_waitingTasks removeObjectIdenticalTo:waiting];
        if (waiting->_finished)
            continue;
        waiting->_holdsSlot = YES;
        NSInteger already = [session->_connectionsPerHost[host] integerValue];
        [waiting->_metricsTransactions.lastObject charon_noteConnectionReused:already > 0];
        session->_connectionsPerHost[host] = @(already + 1);
        charon_task_load(waiting, waiting->_currentRequest);
        break;
    }
}

static void charon_metrics_begin(NSURLSessionTask *task, NSURLRequest *request, NSURLSessionTaskMetricsResourceFetchType type)
{
    @synchronized (task) {
        NSURLSessionTaskTransactionMetrics *last = task->_metricsTransactions.lastObject;
        [last charon_finished];
        [task->_metricsTransactions addObject:[[NSURLSessionTaskTransactionMetrics alloc] initCharonWithRequest:request fetchType:type]];
    }
}

static void charon_metrics_response(NSURLSessionTask *task, NSURLResponse *response)
{
    @synchronized (task) {
        NSURLSessionTaskTransactionMetrics *transaction = task->_metricsTransactions.lastObject;
        [transaction charon_receivedResponse:response];
        [transaction charon_noteInterfaceFlags:charon_network_cellular() expensive:NO constrained:NO proxy:NO];
    }
}

static void charon_metrics_finish(NSURLSessionTask *task)
{
    @synchronized (task) {
        [task->_metricsTransactions.lastObject charon_finished];
    }
}

static NSURLSessionTaskMetrics *charon_metrics_collect(NSURLSessionTask *task)
{
    @synchronized (task) {
        [task->_metricsTransactions.lastObject charon_finished];
        return [[NSURLSessionTaskMetrics alloc] initCharonWithTransactions:task->_metricsTransactions start:task->_metricsStart ?: [NSDate date] end:[NSDate date]];
    }
}

static void charon_task_complete_event(NSURLSessionTask *task, NSError *error)
{
    NSURLSession *session = task->_session;
    CharonDataHandler dataHandler = task->_dataHandler;
    CharonDownloadHandler downloadHandler = task->_downloadHandler;
    BOOL handlerCalled = task->_handlerCalled;
    NSURLSessionTaskMetrics *metrics = charon_metrics_collect(task);
    NSData *data = error ? nil : (task->_receivedData ?: [NSData data]);
    NSURLResponse *response = error ? nil : task->_response;
    task->_dataHandler = nil;
    task->_downloadHandler = nil;
    task->_receivedData = nil;
    charon_session_deliver(session, ^{
        @synchronized (task) {
            task->_state = NSURLSessionTaskStateCompleted;
            task->_error = error;
        }
        id metricsDelegate = charon_task_delegate(session, task, @selector(URLSession:task:didFinishCollectingMetrics:));
        if ([metricsDelegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)])
            [metricsDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
        if (dataHandler) {
            dataHandler(data, response, error);
        } else if (downloadHandler) {
            if (!handlerCalled)
                downloadHandler(nil, nil, error);
        } else {
            id delegate = charon_task_delegate(session, task, @selector(URLSession:task:didCompleteWithError:));
            if ([delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)])
                [delegate URLSession:session task:task didCompleteWithError:error];
        }
        [task charon_resetTaskDelegate];
        charon_perform(^{
            [session->_tasks removeObjectIdenticalTo:task];
            charon_session_check_invalidation(session);
        });
    });
}

static void charon_task_finish(NSURLSessionTask *task, NSError *error)
{
    if (task->_finished)
        return;
    task->_finished = YES;
    task->_awaiting = NO;
    charon_timer_cancel(&task->_idleTimer);
    charon_timer_cancel(&task->_resourceTimer);
    charon_timer_cancel(&task->_delayTimer);
    charon_task_stop_watching(task);
    task->_pendingBegin = nil;
    CharonURLSessionLoader *loader = task->_loader;
    task->_loader = nil;
    charon_loader_stop(loader);
    [task->_deferredInput removeAllObjects];
    charon_task_release_slot(task);
    if (charon_is_download(task)) {
        charon_download_close(task);
        if (error) {
            NSData *resumeData = task->_producedResumeData;
            if (!resumeData && error.code != NSURLErrorCancelled)
                resumeData = charon_download_resume_data(task);
            if (resumeData) {
                NSMutableDictionary *userInfo = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
                userInfo[NSURLSessionDownloadTaskResumeData] = resumeData;
                error = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
            } else if (task->_fileURL) {
                [[NSFileManager defaultManager] removeItemAtURL:task->_fileURL error:NULL];
            }
        }
    }
    charon_task_complete_event(task, error);
}

static void charon_task_cancel(NSURLSessionTask *task)
{
    @synchronized (task) {
        if (task->_state == NSURLSessionTaskStateCompleted)
            return;
        task->_state = NSURLSessionTaskStateCanceling;
    }
    charon_task_finish(task, charon_cancelled_error(task));
}

static void charon_download_finished(NSURLSessionTask *task)
{
    NSURLSession *session = task->_session;
    charon_download_close(task);
    NSURL *location = task->_fileURL;
    NSURLResponse *response = task->_response;
    CharonDownloadHandler handler = task->_downloadHandler;
    task->_handlerCalled = handler != nil;
    BOOL notifies = !handler && charon_delegate_responds(session, task, @selector(URLSession:downloadTask:didFinishDownloadingToURL:));
    charon_session_deliver(session, ^{
        if (handler) {
            handler(location, response, nil);
        } else if (notifies) {
            id delegate = charon_task_delegate(session, task, @selector(URLSession:downloadTask:didFinishDownloadingToURL:));
            [delegate URLSession:session downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:location];
        }
        [[NSFileManager defaultManager] removeItemAtURL:location error:NULL];
    });
    task->_fileURL = nil;
    charon_task_finish(task, nil);
}

static NSCachedURLResponse *charon_cache_entry(NSCachedURLResponse *proposal)
{
    NSMutableDictionary *userInfo = [proposal.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
    userInfo[CharonCachedDateKey] = [NSDate date];
    return [[NSCachedURLResponse alloc] initWithResponse:proposal.response data:proposal.data userInfo:userInfo storagePolicy:proposal.storagePolicy];
}

static void charon_data_finished(NSURLSessionTask *task)
{
    NSURLSession *session = task->_session;
    NSURLCache *cache = session->_configuration.URLCache;
    NSCachedURLResponse *proposal = task->_proposedCache;
    task->_proposedCache = nil;
    NSURLRequest *key = task->_currentRequest;
    if (proposal && cache && !task->_dataHandler && charon_delegate_responds(session, task, @selector(URLSession:dataTask:willCacheResponse:completionHandler:))) {
        charon_task_await(task);
        charon_session_deliver(session, ^{
            id delegate = charon_task_delegate(session, task, @selector(URLSession:dataTask:willCacheResponse:completionHandler:));
            [delegate URLSession:session dataTask:(NSURLSessionDataTask *)task willCacheResponse:proposal completionHandler:^(NSCachedURLResponse *chosen) {
                charon_perform(^{
                    if (!charon_task_resolve(task))
                        return;
                    if (chosen)
                        [cache storeCachedResponse:(cache == [NSURLCache sharedURLCache] ? chosen : charon_cache_entry(chosen)) forRequest:key];
                    charon_task_finish(task, nil);
                });
            }];
        });
        return;
    }
    if (proposal && cache)
        [cache storeCachedResponse:charon_cache_entry(proposal) forRequest:key];
    charon_task_finish(task, nil);
}

static void charon_task_finished_loading(NSURLSessionTask *task)
{
    charon_metrics_finish(task);
    if (charon_is_download(task))
        charon_download_finished(task);
    else
        charon_data_finished(task);
}

static void charon_task_become_download(NSURLSessionTask *task)
{
    NSURLSession *session = task->_session;
    NSURLSessionDownloadTask *download = [[NSURLSessionDownloadTask alloc] init];
    download->_session = session;
    download->_taskIdentifier = task->_taskIdentifier;
    @synchronized (task) {
        download->_originalRequest = task->_originalRequest;
        download->_currentRequest = task->_currentRequest;
        download->_response = task->_response;
        download->_taskDescription = task->_taskDescription;
        download->_state = task->_state;
        download->_countOfBytesReceived = task->_countOfBytesReceived;
        download->_countOfBytesSent = task->_countOfBytesSent;
        download->_countOfBytesExpectedToSend = task->_countOfBytesExpectedToSend;
        download->_countOfBytesExpectedToReceive = task->_countOfBytesExpectedToReceive;
    }
    download->_started = YES;
    download->_paused = task->_paused;
    download->_hostKey = task->_hostKey;
    download->_holdsSlot = task->_holdsSlot;
    download->_redirects = task->_redirects;
    download->_idleInterval = task->_idleInterval;
    download->_resourceDeadline = task->_resourceDeadline;
    download->_entityTag = charon_header(task->_response, @"ETag");
    download->_lastModified = charon_header(task->_response, @"Last-Modified");
    download->_deferredInput = task->_deferredInput;
    download->_metricsTransactions = task->_metricsTransactions;
    download->_metricsStart = task->_metricsStart;
    download->_loader = task->_loader;
    download->_loader->_task = download;
    task->_holdsSlot = NO;
    task->_loader = nil;
    task->_deferredInput = [NSMutableArray array];
    task->_finished = YES;
    charon_timer_cancel(&task->_idleTimer);
    charon_timer_cancel(&task->_resourceTimer);
    NSUInteger index = [session->_tasks indexOfObjectIdenticalTo:task];
    if (index != NSNotFound)
        [session->_tasks replaceObjectAtIndex:index withObject:download];
    else
        [session->_tasks addObject:download];
    charon_task_start_resource_timer(download);
    if (!charon_download_create_file(download)) {
        charon_task_finish(download, charon_task_error(download, NSURLErrorCannotCreateFile, @"cannot create file", nil));
        return;
    }
    if (charon_delegate_responds(session, task, @selector(URLSession:dataTask:didBecomeDownloadTask:))) {
        charon_session_deliver(session, ^{
            id delegate = charon_task_delegate(session, task, @selector(URLSession:dataTask:didBecomeDownloadTask:));
            [delegate URLSession:session dataTask:(NSURLSessionDataTask *)task didBecomeDownloadTask:download];
            @synchronized (task) {
                task->_state = NSURLSessionTaskStateCompleted;
            }
        });
    } else {
        @synchronized (task) {
            task->_state = NSURLSessionTaskStateCompleted;
        }
    }
    charon_task_restart_idle_timer(download);
    charon_task_flush_input(download);
}

static void charon_download_response(NSURLSessionTask *task, NSURLResponse *response)
{
    NSURLSession *session = task->_session;
    NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
    int64_t expected = response.expectedContentLength;
    NSString *entityTag = charon_header(response, @"ETag");
    NSString *lastModified = charon_header(response, @"Last-Modified");
    if (task->_resumeOffset > 0) {
        int64_t offset = 0;
        @try {
            if (http.statusCode == 206) {
                offset = task->_resumeOffset;
                [task->_file seekToEndOfFile];
            } else {
                [task->_file truncateFileAtOffset:0];
            }
        } @catch (NSException *exception) {
            charon_task_finish(task, charon_task_error(task, NSURLErrorCannotWriteToFile, @"cannot write to file", nil));
            return;
        }
        task->_resumeOffset = offset;
        int64_t total = expected >= 0 ? offset + expected : NSURLSessionTransferSizeUnknown;
        @synchronized (task) {
            task->_countOfBytesReceived = offset;
            task->_countOfBytesExpectedToReceive = total;
        }
        if (!task->_downloadHandler && charon_delegate_responds(session, task, @selector(URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:))) {
            charon_session_deliver(session, ^{
                id delegate = charon_task_delegate(session, task, @selector(URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:));
                [delegate URLSession:session downloadTask:(NSURLSessionDownloadTask *)task didResumeAtOffset:offset expectedTotalBytes:total];
            });
        }
        if (http.statusCode != 206 || entityTag)
            task->_entityTag = entityTag;
        if (http.statusCode != 206 || lastModified)
            task->_lastModified = lastModified;
        return;
    }
    task->_entityTag = entityTag;
    task->_lastModified = lastModified;
    @synchronized (task) {
        task->_countOfBytesExpectedToReceive = expected;
    }
    if (!task->_file && !charon_download_create_file(task))
        charon_task_finish(task, charon_task_error(task, NSURLErrorCannotCreateFile, @"cannot create file", nil));
}

static void charon_task_response(NSURLSessionTask *task, NSURLResponse *response)
{
    NSURLSession *session = task->_session;
    charon_task_restart_idle_timer(task);
    @synchronized (task) {
        task->_response = [response copy];
        task->_countOfBytesExpectedToReceive = response.expectedContentLength;
    }
    charon_metrics_response(task, response);
    charon_store_cookies(task, response);
    if (charon_is_download(task)) {
        charon_download_response(task, response);
        return;
    }
    if (task->_dataHandler || !charon_delegate_responds(session, task, @selector(URLSession:dataTask:didReceiveResponse:completionHandler:)))
        return;
    charon_task_await(task);
    charon_session_deliver(session, ^{
        id delegate = charon_task_delegate(session, task, @selector(URLSession:dataTask:didReceiveResponse:completionHandler:));
        [delegate URLSession:session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:response completionHandler:^(NSURLSessionResponseDisposition disposition) {
            charon_perform(^{
                if (!charon_task_resolve(task))
                    return;
                if (disposition == NSURLSessionResponseAllow) {
                    charon_task_flush_input(task);
                } else if (disposition == NSURLSessionResponseBecomeDownload) {
                    charon_task_become_download(task);
                } else {
                    charon_task_cancel(task);
                }
            });
        }];
    });
}

static void charon_task_data(NSURLSessionTask *task, NSData *data)
{
    NSURLSession *session = task->_session;
    charon_task_restart_idle_timer(task);
    int64_t received, expected;
    @synchronized (task) {
        task->_countOfBytesReceived += data.length;
        received = task->_countOfBytesReceived;
        expected = task->_countOfBytesExpectedToReceive;
    }
    if (charon_is_download(task)) {
        @try {
            [task->_file writeData:data];
        } @catch (NSException *exception) {
            charon_task_finish(task, charon_task_error(task, NSURLErrorCannotWriteToFile, @"cannot write to file", nil));
            return;
        }
        if (!task->_downloadHandler && charon_delegate_responds(session, task, @selector(URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:))) {
            int64_t written = data.length;
            charon_session_deliver(session, ^{
                if (task.state == NSURLSessionTaskStateCanceling)
                    return;
                id delegate = charon_task_delegate(session, task, @selector(URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:));
                [delegate URLSession:session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:written totalBytesWritten:received totalBytesExpectedToWrite:expected];
            });
        }
        return;
    }
    if (task->_dataHandler) {
        if (!task->_receivedData)
            task->_receivedData = [NSMutableData data];
        [task->_receivedData appendData:data];
        return;
    }
    if (charon_delegate_responds(session, task, @selector(URLSession:dataTask:didReceiveData:))) {
        NSData *chunk = [data copy];
        charon_session_deliver(session, ^{
            if (task.state == NSURLSessionTaskStateCanceling)
                return;
            id delegate = charon_task_delegate(session, task, @selector(URLSession:dataTask:didReceiveData:));
            [delegate URLSession:session dataTask:(NSURLSessionDataTask *)task didReceiveData:chunk];
        });
    }
}

static void charon_task_sent(NSURLSessionTask *task, int64_t written, int64_t total, int64_t expectedByConnection)
{
    NSURLSession *session = task->_session;
    charon_task_restart_idle_timer(task);
    int64_t expected = 0;
    @synchronized (task) {
        task->_countOfBytesSent = total;
        int64_t beforeEncoding = charon_expected_body_length(task, task->_currentRequest);
        [task->_metricsTransactions.lastObject charon_noteBytesSent:total
                                                     beforeEncoding:beforeEncoding
                                                            received:task->_countOfBytesReceived];
        if (expectedByConnection > 0)
            task->_countOfBytesExpectedToSend = expectedByConnection;
        expected = task->_countOfBytesExpectedToSend;
    }
    if (!charon_delegate_responds(session, task, @selector(URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)))
        return;
    charon_session_deliver(session, ^{
        id delegate = charon_task_delegate(session, task, @selector(URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:));
        [delegate URLSession:session task:task didSendBodyData:written totalBytesSent:total totalBytesExpectedToSend:expected];
    });
}

static NSURLRequest *charon_redirect_request(NSURLRequest *current, NSURL *url, NSInteger status)
{
    NSMutableURLRequest *next = [current mutableCopy];
    next.URL = url;
    [next setValue:nil forHTTPHeaderField:@"Authorization"];
    NSString *method = current.HTTPMethod.uppercaseString;
    BOOL becomesGet = (status == 303 && ![method isEqualToString:@"HEAD"]) || ((status == 301 || status == 302) && [method isEqualToString:@"POST"]);
    if (becomesGet && ![method isEqualToString:@"GET"]) {
        next.HTTPMethod = @"GET";
        next.HTTPBody = nil;
        next.HTTPBodyStream = nil;
        [next setValue:nil forHTTPHeaderField:@"Content-Type"];
        [next setValue:nil forHTTPHeaderField:@"Content-Length"];
    }
    return next;
}

static void charon_task_request_body_stream(NSURLSessionTask *task, void (^then)(void))
{
    NSURLSession *session = task->_session;
    if (!charon_delegate_responds(session, task, @selector(URLSession:task:needNewBodyStream:))) {
        charon_task_finish(task, charon_task_error(task, NSURLErrorRequestBodyStreamExhausted, @"request body stream exhausted", nil));
        return;
    }
    charon_task_await(task);
    charon_session_deliver(session, ^{
        id delegate = charon_task_delegate(session, task, @selector(URLSession:task:needNewBodyStream:));
        [delegate URLSession:session task:task needNewBodyStream:^(NSInputStream *stream) {
            charon_perform(^{
                if (!charon_task_resolve(task))
                    return;
                if (!stream) {
                    charon_task_finish(task, charon_task_error(task, NSURLErrorRequestBodyStreamExhausted, @"request body stream exhausted", nil));
                    return;
                }
                task->_bodyStream = stream;
                then();
            });
        }];
    });
}

static void charon_task_follow(NSURLSessionTask *task, NSURLRequest *request)
{
    CharonURLSessionLoader *loader = task->_loader;
    task->_loader = nil;
    charon_loader_stop(loader);
    [task->_deferredInput removeAllObjects];
    @synchronized (task) {
        task->_currentRequest = [request copy];
        task->_response = nil;
    }
    if (task->_body == CharonTaskBodyStream && charon_sends_body(request)) {
        charon_task_request_body_stream(task, ^{
            charon_task_load(task, task->_currentRequest);
        });
        return;
    }
    charon_task_load(task, request);
}

static void charon_task_redirect(NSURLSessionTask *task, NSURLRequest *next, NSURLResponse *response)
{
    NSURLSession *session = task->_session;
    charon_task_restart_idle_timer(task);
    charon_store_cookies(task, response);
    charon_metrics_response(task, response);
    charon_metrics_finish(task);
    if (++task->_redirects > 20) {
        charon_task_finish(task, charon_task_error(task, NSURLErrorHTTPTooManyRedirects, @"too many HTTP redirects", response.URL));
        return;
    }
    if (!charon_delegate_responds(session, task, @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:))) {
        charon_task_follow(task, next);
        return;
    }
    charon_task_await(task);
    charon_session_deliver(session, ^{
        id delegate = charon_task_delegate(session, task, @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:));
        [delegate URLSession:session task:task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:next completionHandler:^(NSURLRequest *chosen) {
            charon_perform(^{
                if (!charon_task_resolve(task))
                    return;
                if (chosen)
                    charon_task_follow(task, chosen);
                else
                    charon_task_flush_input(task);
            });
        }];
    });
}

static BOOL charon_is_session_challenge(NSURLAuthenticationChallenge *challenge)
{
    NSString *method = challenge.protectionSpace.authenticationMethod;
    return [method isEqualToString:NSURLAuthenticationMethodNTLM] || [method isEqualToString:NSURLAuthenticationMethodNegotiate] ||
           [method isEqualToString:NSURLAuthenticationMethodClientCertificate] || [method isEqualToString:NSURLAuthenticationMethodServerTrust];
}

static void charon_challenge_default(NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge)
{
    id<NSURLAuthenticationChallengeSender> sender = challenge.sender;
    NSURLProtectionSpace *space = challenge.protectionSpace;
    NSString *method = space.authenticationMethod;
    if ([method isEqualToString:NSURLAuthenticationMethodServerTrust] || [method isEqualToString:NSURLAuthenticationMethodClientCertificate]) {
        if ([sender respondsToSelector:@selector(performDefaultHandlingForAuthenticationChallenge:)])
            [sender performDefaultHandlingForAuthenticationChallenge:challenge];
        else
            [sender continueWithoutCredentialForAuthenticationChallenge:challenge];
        return;
    }
    if (challenge.previousFailureCount == 0) {
        NSURL *url = task->_currentRequest.URL;
        NSURLCredential *credential = nil;
        if (url.user && url.password)
            credential = [NSURLCredential credentialWithUser:[url.user stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: url.user
                                                    password:[url.password stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: url.password
                                                 persistence:NSURLCredentialPersistenceForSession];
        if (!credential && challenge.proposedCredential.hasPassword)
            credential = challenge.proposedCredential;
        NSURLCredentialStorage *storage = task->_session->_configuration.URLCredentialStorage;
        if (!credential)
            credential = [storage defaultCredentialForProtectionSpace:space];
        if (credential) {
            [sender useCredential:credential forAuthenticationChallenge:challenge];
            return;
        }
    }
    [sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

static void charon_task_challenge(NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge)
{
    NSURLSession *session = task->_session;
    id delegate = charon_task_delegate(session, task, @selector(URLSession:task:didReceiveChallenge:completionHandler:));
    BOOL taskLevel = [delegate respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)];
    BOOL sessionLevel = [delegate respondsToSelector:@selector(URLSession:didReceiveChallenge:completionHandler:)] && charon_is_session_challenge(challenge);
    if (!taskLevel && !sessionLevel) {
        charon_challenge_default(task, challenge);
        return;
    }
    charon_task_await(task);
    void (^decided)(NSURLSessionAuthChallengeDisposition, NSURLCredential *) = ^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential) {
        charon_perform(^{
            if (!charon_task_resolve(task))
                return;
            id<NSURLAuthenticationChallengeSender> sender = challenge.sender;
            switch (disposition) {
            case NSURLSessionAuthChallengeUseCredential:
                if (credential)
                    [sender useCredential:credential forAuthenticationChallenge:challenge];
                else
                    [sender continueWithoutCredentialForAuthenticationChallenge:challenge];
                break;
            case NSURLSessionAuthChallengeCancelAuthenticationChallenge:
                charon_task_cancel(task);
                break;
            case NSURLSessionAuthChallengeRejectProtectionSpace:
                if ([sender respondsToSelector:@selector(rejectProtectionSpaceAndContinueWithChallenge:)])
                    [sender rejectProtectionSpaceAndContinueWithChallenge:challenge];
                else
                    [sender continueWithoutCredentialForAuthenticationChallenge:challenge];
                break;
            default:
                charon_challenge_default(task, challenge);
                break;
            }
            charon_task_flush_input(task);
        });
    };
    charon_session_deliver(session, ^{
        id current = charon_task_delegate(session, task, @selector(URLSession:didReceiveChallenge:completionHandler:));
        if (sessionLevel)
            [current URLSession:session didReceiveChallenge:challenge completionHandler:decided];
        else
            [current URLSession:session task:task didReceiveChallenge:challenge completionHandler:decided];
    });
}

static NSCachedURLResponse *charon_custom_cached_response(NSURLSessionTask *task, NSURLRequest *request, BOOL *dontLoad)
{
    NSURLCache *cache = task->_session->_configuration.URLCache;
    NSURLRequestCachePolicy policy = charon_cache_policy(task, request);
    *dontLoad = NO;
    if (!cache || cache == [NSURLCache sharedURLCache] || charon_is_download(task) || charon_sends_body(request))
        return nil;
    if (policy == NSURLRequestReloadIgnoringLocalCacheData || policy == NSURLRequestReloadIgnoringLocalAndRemoteCacheData || policy == NSURLRequestReloadRevalidatingCacheData)
        return nil;
    *dontLoad = policy == NSURLRequestReturnCacheDataDontLoad;
    NSCachedURLResponse *cached = [cache cachedResponseForRequest:request];
    if (!cached || policy == NSURLRequestReturnCacheDataElseLoad || policy == NSURLRequestReturnCacheDataDontLoad)
        return cached;
    NSString *control = charon_header(cached.response, @"Cache-Control").lowercaseString;
    NSDate *stored = cached.userInfo[CharonCachedDateKey];
    if (!control || !stored || [control rangeOfString:@"no-cache"].location != NSNotFound || [control rangeOfString:@"no-store"].location != NSNotFound)
        return nil;
    NSRange range = [control rangeOfString:@"max-age="];
    if (range.location == NSNotFound)
        return nil;
    double maxAge = [[control substringFromIndex:NSMaxRange(range)] doubleValue];
    return -[stored timeIntervalSinceNow] < maxAge ? cached : nil;
}

static Class charon_protocol_class(NSURLSessionTask *task, NSURLRequest *request)
{
    for (id candidate in task->_session->_configuration.protocolClasses) {
        if ([candidate respondsToSelector:@selector(isSubclassOfClass:)] && [candidate isSubclassOfClass:[NSURLProtocol class]] && [candidate canInitWithRequest:request])
            return candidate;
    }
    return Nil;
}

static void charon_task_load(NSURLSessionTask *task, NSURLRequest *request)
{
    if (task->_finished)
        return;
    CharonURLSessionLoader *loader = [[CharonURLSessionLoader alloc] init];
    loader->_task = task;
    task->_loader = loader;
    [task->_deferredInput removeAllObjects];
    BOOL dontLoad;
    NSCachedURLResponse *cached = charon_custom_cached_response(task, request, &dontLoad);
    if (cached) {
        charon_metrics_begin(task, request, NSURLSessionTaskMetricsResourceFetchTypeLocalCache);
        charon_perform(^{
            charon_task_input(loader, ^(NSURLSessionTask *current) {
                charon_task_response(current, cached.response);
            });
            charon_task_input(loader, ^(NSURLSessionTask *current) {
                if (cached.data.length)
                    charon_task_data(current, cached.data);
            });
            charon_task_input(loader, ^(NSURLSessionTask *current) {
                charon_task_finished_loading(current);
            });
        });
        charon_task_restart_idle_timer(task);
        return;
    }
    if (dontLoad) {
        charon_task_finish(task, charon_task_error(task, NSURLErrorResourceUnavailable, @"resource unavailable", nil));
        return;
    }
    charon_metrics_begin(task, request, NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad);
    NSURLRequest *wire = charon_wire_request(task, request);
    Class protocolClass = charon_protocol_class(task, request);
    if (protocolClass) {
        loader->_protocol = [[protocolClass alloc] initWithRequest:[protocolClass canonicalRequestForRequest:wire] cachedResponse:nil client:loader];
        charon_task_restart_idle_timer(task);
        [loader->_protocol startLoading];
        return;
    }
    loader->_connection = [[NSURLConnection alloc] initWithRequest:wire delegate:loader startImmediately:NO];
    if (!loader->_connection) {
        charon_task_finish(task, charon_task_error(task, NSURLErrorBadURL, @"bad URL", nil));
        return;
    }
    if (task->_paused) {
        loader->_pendingStart = YES;
    } else {
        [loader->_connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [loader->_connection start];
    }
    charon_task_restart_idle_timer(task);
}

static float charon_task_priority(NSURLSessionTask *task)
{
    return [task respondsToSelector:@selector(priority)] ? task.priority : 0.5f;
}

static void charon_task_enqueue(NSURLSessionTask *task)
{
    NSURLSession *session = task->_session;
    NSString *host = task->_currentRequest.URL.host.lowercaseString ?: @"";
    task->_hostKey = host;
    NSInteger limit = MAX(session->_configuration.HTTPMaximumConnectionsPerHost, 1);
    NSInteger active = [session->_connectionsPerHost[host] integerValue];
    if (active < limit) {
        session->_connectionsPerHost[host] = @(active + 1);
        task->_holdsSlot = YES;
        charon_task_load(task, task->_currentRequest);
        return;
    }
    float priority = charon_task_priority(task);
    NSUInteger index = session->_waitingTasks.count;
    for (NSUInteger position = 0; position < session->_waitingTasks.count; position++) {
        if (charon_task_priority(session->_waitingTasks[position]) < priority) {
            index = position;
            break;
        }
    }
    [session->_waitingTasks insertObject:task atIndex:index];
}


static BOOL charon_task_waits_for_connectivity(NSURLSessionTask *task)
{
    NSURLSessionConfiguration *configuration = task->_session->_configuration;
    return configuration.waitsForConnectivity || configuration.identifier != nil;
}

static SCNetworkReachabilityRef charon_reachability_for(NSURLSessionTask *task)
{
    NSString *host = task->_currentRequest.URL.host;
    struct sockaddr_in address;
    struct sockaddr_in6 address6;
    memset(&address, 0, sizeof address);
    memset(&address6, 0, sizeof address6);
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    address6.sin6_len = sizeof address6;
    address6.sin6_family = AF_INET6;
    if ([host caseInsensitiveCompare:@"localhost"] == NSOrderedSame)
        host = @"127.0.0.1";
    if (host.length && inet_pton(AF_INET, host.UTF8String, &address.sin_addr) == 1)
        return SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&address);
    if (host.length && inet_pton(AF_INET6, host.UTF8String, &address6.sin6_addr) == 1)
        return SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&address6);
    memset(&address, 0, sizeof address);
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    return SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&address);
}

static BOOL charon_network_reachable(NSURLSessionTask *task, SCNetworkReachabilityRef reference)
{
    SCNetworkReachabilityFlags flags = 0;
    if (!SCNetworkReachabilityGetFlags(reference, &flags))
        return NO;
    if (!(flags & kSCNetworkReachabilityFlagsReachable) || (flags & kSCNetworkReachabilityFlagsConnectionRequired))
        return NO;
#if TARGET_OS_IPHONE
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) && !(task->_session->_configuration.allowsCellularAccess && task->_currentRequest.allowsCellularAccess))
        return NO;
#endif
    return YES;
}

static void charon_task_stop_watching(NSURLSessionTask *task)
{
    SCNetworkReachabilityRef reference = task->_reachability;
    if (!reference)
        return;
    task->_reachability = NULL;
    SCNetworkReachabilitySetCallback(reference, NULL, NULL);
    SCNetworkReachabilityUnscheduleFromRunLoop(reference, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    CFRelease(reference);
}

static void charon_reachability_changed(SCNetworkReachabilityRef reference, SCNetworkReachabilityFlags flags, void *info)
{
    NSURLSessionTask *task = (__bridge NSURLSessionTask *)info;
    if (task->_finished || task->_reachability != reference || !charon_network_reachable(task, reference))
        return;
    void (^proceed)(void) = task->_pendingBegin;
    task->_pendingBegin = nil;
    charon_task_stop_watching(task);
    if (proceed)
        proceed();
}

static void charon_task_notify_waiting(NSURLSessionTask *task)
{
    if (task->_connectivityNotified)
        return;
    task->_connectivityNotified = YES;
    NSURLSession *session = task->_session;
    charon_session_deliver(session, ^{
        id delegate = charon_task_delegate(session, task, @selector(URLSession:taskIsWaitingForConnectivity:));
        if ([delegate respondsToSelector:@selector(URLSession:taskIsWaitingForConnectivity:)])
            [delegate URLSession:session taskIsWaitingForConnectivity:task];
    });
}

static void charon_task_when_connected(NSURLSessionTask *task, void (^proceed)(void))
{
    if (task->_finished)
        return;
    if (!charon_task_waits_for_connectivity(task)) {
        proceed();
        return;
    }
    SCNetworkReachabilityRef reference = charon_reachability_for(task);
    if (!reference) {
        proceed();
        return;
    }
    if (charon_network_reachable(task, reference)) {
        CFRelease(reference);
        proceed();
        return;
    }
    charon_task_stop_watching(task);
    task->_reachability = reference;
    task->_pendingBegin = [proceed copy];
    SCNetworkReachabilityContext context = {0, (__bridge void *)task, NULL, NULL, NULL};
    if (!SCNetworkReachabilitySetCallback(reference, charon_reachability_changed, &context) || !SCNetworkReachabilityScheduleWithRunLoop(reference, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
        task->_pendingBegin = nil;
        charon_task_stop_watching(task);
        proceed();
        return;
    }
    charon_task_notify_waiting(task);
    if (charon_network_reachable(task, reference))
        charon_reachability_changed(reference, 0, (__bridge void *)task);
}

static void charon_task_await_delegate_begin(NSURLSessionTask *task, void (^proceed)(void))
{
    NSURLSession *session = task->_session;
    NSURLRequest *request = task->_currentRequest;
    charon_session_deliver(session, ^{
        id delegate = charon_task_delegate(session, task, @selector(URLSession:task:willBeginDelayedRequest:completionHandler:));
        if (![delegate respondsToSelector:@selector(URLSession:task:willBeginDelayedRequest:completionHandler:)]) {
            charon_perform(proceed);
            return;
        }
        __block BOOL answered = NO;
        [delegate URLSession:session task:task willBeginDelayedRequest:request completionHandler:^(NSURLSessionDelayedRequestDisposition disposition, NSURLRequest *replacement) {
            charon_perform(^{
                if (answered || task->_finished)
                    return;
                answered = YES;
                if (disposition == NSURLSessionDelayedRequestCancel) {
                    charon_task_finish(task, charon_cancelled_error(task));
                    return;
                }
                if (disposition == NSURLSessionDelayedRequestUseNewRequest && replacement) {
                    @synchronized (task) {
                        task->_currentRequest = replacement;
                    }
                }
                proceed();
            });
        }];
    });
}


static BOOL charon_task_retries_when_connected(NSURLSessionTask *task, NSError *error)
{
    if (!charon_task_waits_for_connectivity(task) || task->_response || task->_body == CharonTaskBodyStream || (charon_is_download(task) && task->_file))
        return NO;
    if (![error.domain isEqualToString:NSURLErrorDomain])
        return NO;
    switch (error.code) {
    case NSURLErrorCannotFindHost:
    case NSURLErrorCannotConnectToHost:
    case NSURLErrorNotConnectedToInternet:
    case NSURLErrorInternationalRoamingOff:
    case NSURLErrorCallIsActive:
    case NSURLErrorDataNotAllowed:
        break;
    default:
        return NO;
    }
    SCNetworkReachabilityRef reference = charon_reachability_for(task);
    if (!reference)
        return NO;
    BOOL reachable = charon_network_reachable(task, reference);
    CFRelease(reference);
    return !reachable;
}

static void charon_task_begin(NSURLSessionTask *task, void (^proceed)(void))
{
    BOOL background = task->_session->_configuration.identifier != nil;
    void (^connect)(void) = ^{
        charon_task_when_connected(task, proceed);
    };
    void (^afterDate)(void) = connect;
    if (background) {
        afterDate = ^{
            charon_task_await_delegate_begin(task, connect);
        };
    }
    NSDate *date = background ? task.earliestBeginDate : nil;
    NSTimeInterval wait = date.timeIntervalSinceNow;
    if (!date || wait <= 0) {
        afterDate();
        return;
    }
    task->_delayTimer = charon_timer_create(CFAbsoluteTimeGetCurrent() + wait, ^{
        charon_timer_cancel(&task->_delayTimer);
        if (!task->_finished)
            afterDate();
    });
}

static void charon_task_start(NSURLSessionTask *task)
{
    NSURLSession *session = task->_session;
    NSURLSessionConfiguration *configuration = session->_configuration;
    if (configuration.timeoutIntervalForResource > 0) {
        task->_resourceDeadline = CFAbsoluteTimeGetCurrent() + configuration.timeoutIntervalForResource;
        charon_task_start_resource_timer(task);
    }
    if (task->_resumeInvalid) {
        charon_task_finish(task, charon_task_error(task, NSURLErrorCannotOpenFile, @"cannot open file", nil));
        return;
    }
    NSURLRequest *request = task->_currentRequest;
    task->_idleInterval = request.timeoutInterval != 60.0 ? request.timeoutInterval : configuration.timeoutIntervalForRequest;
    if (charon_is_download(task) && task->_fileURL) {
        NSError *error = nil;
        task->_file = [NSFileHandle fileHandleForWritingToURL:task->_fileURL error:&error];
        task->_resumeOffset = charon_file_size(task->_fileURL);
        if (!task->_file || task->_resumeOffset <= 0) {
            task->_fileURL = nil;
            charon_task_finish(task, charon_task_error(task, NSURLErrorCannotOpenFile, @"cannot open file", nil));
            return;
        }
        @synchronized (task) {
            task->_countOfBytesReceived = task->_resumeOffset;
        }
    }
    @synchronized (task) {
        task->_countOfBytesExpectedToSend = charon_expected_body_length(task, request);
    }
    void (^enqueue)(void) = ^{
        if (task->_body == CharonTaskBodyStream) {
            charon_task_request_body_stream(task, ^{
                charon_task_enqueue(task);
            });
            return;
        }
        charon_task_enqueue(task);
    };
    charon_task_begin(task, enqueue);
}

@implementation CharonURLSessionLoader

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (!response)
        return request;
    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
    NSURL *url = request.URL;
    charon_task_input(self, ^(NSURLSessionTask *task) {
        charon_task_redirect(task, charon_redirect_request(task->_currentRequest, url, status), response);
    });
    return nil;
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    charon_task_input(self, ^(NSURLSessionTask *task) {
        charon_task_challenge(task, challenge);
    });
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    charon_task_input(self, ^(NSURLSessionTask *task) {
        charon_task_response(task, response);
    });
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    charon_task_input(self, ^(NSURLSessionTask *task) {
        charon_task_data(task, data);
    });
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    charon_task_input(self, ^(NSURLSessionTask *task) {
        charon_task_sent(task, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    });
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    NSURLSessionTask *task = _task;
    if (!task || task->_loader != self || charon_is_download(task))
        return nil;
    NSURLSession *session = task->_session;
    NSURLCache *cache = session->_configuration.URLCache;
    BOOL asks = !task->_dataHandler && charon_delegate_responds(session, task, @selector(URLSession:dataTask:willCacheResponse:completionHandler:));
    if (!asks && cache == [NSURLCache sharedURLCache])
        return cachedResponse;
    if (cache)
        task->_proposedCache = cachedResponse;
    return nil;
}

- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request
{
    NSURLSessionTask *task = _task;
    if (!task || task->_loader != self)
        return nil;
    if (task->_body == CharonTaskBodyData)
        return [NSInputStream inputStreamWithData:task->_bodyData];
    if (task->_body == CharonTaskBodyFile)
        return [NSInputStream inputStreamWithURL:task->_bodyFile];
    NSURLSession *session = task->_session;
    id delegate = charon_task_delegate(session, task, @selector(URLSession:task:needNewBodyStream:));
    NSInputStream *stream = nil;
    if ([delegate respondsToSelector:@selector(URLSession:task:needNewBodyStream:)]) {
        CharonURLSessionStreamReply *reply = [[CharonURLSessionStreamReply alloc] init];
        dispatch_semaphore_t answered = dispatch_semaphore_create(0);
        [session->_delegateQueue addOperationWithBlock:^{
            [delegate URLSession:session task:task needNewBodyStream:^(NSInputStream *provided) {
                @synchronized (reply) {
                    reply->_stream = provided;
                }
                dispatch_semaphore_signal(answered);
            }];
        }];
        NSTimeInterval wait = task->_idleInterval > 0 ? task->_idleInterval : 60;
        dispatch_semaphore_wait(answered, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)));
        @synchronized (reply) {
            stream = reply->_stream;
        }
    }
    if (!stream) {
        charon_perform(^{
            if (task->_loader == self)
                charon_task_finish(task, charon_task_error(task, NSURLErrorRequestBodyStreamExhausted, @"request body stream exhausted", nil));
        });
    }
    return stream;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    charon_task_input(self, ^(NSURLSessionTask *task) {
        charon_task_finished_loading(task);
    });
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    charon_task_input(self, ^(NSURLSessionTask *task) {
        if (charon_task_retries_when_connected(task, error)) {
            CharonURLSessionLoader *stale = task->_loader;
            task->_loader = nil;
            charon_loader_stop(stale);
            [task->_deferredInput removeAllObjects];
            charon_task_restart_idle_timer(task);
            charon_task_when_connected(task, ^{
                charon_task_load(task, task->_currentRequest);
            });
            return;
        }
        charon_task_finish(task, error);
    });
}

- (void)URLProtocol:(NSURLProtocol *)protocol wasRedirectedToRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
    charon_perform(^{
        charon_task_input(self, ^(NSURLSessionTask *task) {
            charon_task_redirect(task, request, redirectResponse);
            charon_task_input(self, ^(NSURLSessionTask *current) {
                charon_task_response(current, redirectResponse);
            });
            charon_task_input(self, ^(NSURLSessionTask *current) {
                charon_task_finished_loading(current);
            });
        });
    });
}

- (void)URLProtocol:(NSURLProtocol *)protocol cachedResponseIsValid:(NSCachedURLResponse *)cachedResponse
{
    charon_perform(^{
        charon_task_input(self, ^(NSURLSessionTask *task) {
            charon_task_response(task, cachedResponse.response);
        });
        charon_task_input(self, ^(NSURLSessionTask *task) {
            charon_task_data(task, cachedResponse.data);
        });
        charon_task_input(self, ^(NSURLSessionTask *task) {
            charon_task_finished_loading(task);
        });
    });
}

- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveResponse:(NSURLResponse *)response cacheStoragePolicy:(NSURLCacheStoragePolicy)policy
{
    charon_perform(^{
        self->_protocolCachePolicy = policy;
        self->_protocolResponse = response;
        charon_task_input(self, ^(NSURLSessionTask *task) {
            charon_task_response(task, response);
        });
    });
}

- (void)URLProtocol:(NSURLProtocol *)protocol didLoadData:(NSData *)data
{
    NSData *chunk = [data copy];
    charon_perform(^{
        if (self->_protocolCachePolicy != NSURLCacheStorageNotAllowed) {
            if (!self->_protocolData)
                self->_protocolData = [NSMutableData data];
            [self->_protocolData appendData:chunk];
        }
        charon_task_input(self, ^(NSURLSessionTask *task) {
            charon_task_data(task, chunk);
        });
    });
}

- (void)URLProtocolDidFinishLoading:(NSURLProtocol *)protocol
{
    charon_perform(^{
        charon_task_input(self, ^(NSURLSessionTask *task) {
            if (!charon_is_download(task) && self->_protocolResponse && self->_protocolCachePolicy != NSURLCacheStorageNotAllowed && task->_session->_configuration.URLCache)
                task->_proposedCache = [[NSCachedURLResponse alloc] initWithResponse:self->_protocolResponse data:self->_protocolData ?: [NSData data] userInfo:nil storagePolicy:self->_protocolCachePolicy];
            charon_task_finished_loading(task);
        });
    });
}

- (void)URLProtocol:(NSURLProtocol *)protocol didFailWithError:(NSError *)error
{
    charon_perform(^{
        charon_task_input(self, ^(NSURLSessionTask *task) {
            charon_task_finish(task, error);
        });
    });
}

- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    charon_perform(^{
        charon_task_input(self, ^(NSURLSessionTask *task) {
            charon_task_challenge(task, challenge);
        });
    });
}

- (void)URLProtocol:(NSURLProtocol *)protocol didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
}

@end

static void charon_session_setup(NSURLSession *session, NSURLSessionConfiguration *configuration, id<NSURLSessionDelegate> delegate, NSOperationQueue *queue)
{
    session->_configuration = [configuration ?: [NSURLSessionConfiguration defaultSessionConfiguration] copy];
    session->_delegate = delegate;
    if (!queue) {
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
    }
    session->_delegateQueue = queue;
    session->_tasks = [NSMutableArray array];
    session->_waitingTasks = [NSMutableArray array];
    session->_connectionsPerHost = [NSMutableDictionary dictionary];
    session->_events = [NSMutableArray array];
}

static id charon_session_task(NSURLSession *session, Class kind, NSURLRequest *request, BOOL hasHandler)
{
    if (!request)
        [NSException raise:NSInvalidArgumentException format:@"Cannot create task from nil request"];
    if (hasHandler && session->_configuration.identifier)
        [NSException raise:NSGenericException format:@"Completion handler blocks are not supported in background sessions. Use a delegate instead."];
    NSUInteger identifier;
    @synchronized (session) {
        if (session->_invalidated)
            [NSException raise:NSGenericException format:@"Task created in a session that has been invalidated"];
        identifier = ++session->_lastTaskIdentifier;
    }
    NSURLSessionTask *task = [[kind alloc] init];
    task->_session = session;
    task->_taskIdentifier = identifier;
    task->_originalRequest = [request copy];
    task->_currentRequest = task->_originalRequest;
    task->_state = NSURLSessionTaskStateSuspended;
    task->_deferredInput = [NSMutableArray array];
    task->_metricsTransactions = [NSMutableArray array];
    task->_metricsStart = [NSDate date];
    return task;
}

static NSURLRequest *charon_session_request(NSURLSession *session, NSURL *url)
{
    if (!url)
        [NSException raise:NSInvalidArgumentException format:@"Cannot create task from nil URL"];
    return [NSURLRequest requestWithURL:url];
}

static NSURLSessionUploadTask *charon_upload_task(NSURLSession *session, NSURLRequest *request, NSURL *fileURL, NSData *bodyData, CharonDataHandler handler)
{
    NSURLSessionUploadTask *task = charon_session_task(session, [NSURLSessionUploadTask class], request, handler != nil);
    if (fileURL) {
        task->_body = CharonTaskBodyFile;
        task->_bodyFile = fileURL;
    } else if (bodyData) {
        task->_body = CharonTaskBodyData;
        task->_bodyData = [bodyData copy];
    }
    task->_dataHandler = [handler copy];
    return task;
}

static NSURLSessionDownloadTask *charon_download_task(NSURLSession *session, NSURLRequest *request, CharonDownloadHandler handler)
{
    NSURLSessionDownloadTask *task = charon_session_task(session, [NSURLSessionDownloadTask class], request, handler != nil);
    task->_downloadHandler = [handler copy];
    return task;
}

static NSURLSessionDownloadTask *charon_resumed_download_task(NSURLSession *session, NSData *resumeData, CharonDownloadHandler handler)
{
    NSURLRequest *placeholder = [NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]];
    NSURLSessionDownloadTask *task = charon_session_task(session, [NSURLSessionDownloadTask class], placeholder, handler != nil);
    charon_download_adopt_resume_data(task, resumeData);
    if (task->_resumeInvalid) {
        task->_originalRequest = nil;
        task->_currentRequest = nil;
    }
    task->_downloadHandler = [handler copy];
    return task;
}

@implementation NSURLSession

+ (NSURLSession *)sharedSession
{
    static NSURLSession *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[NSURLSession alloc] init];
        shared->_shared = YES;
    });
    return shared;
}

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
{
    return [self sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
}

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id<NSURLSessionDelegate>)delegate delegateQueue:(NSOperationQueue *)queue
{
    NSURLSession *session = [[self alloc] init];
    charon_session_setup(session, configuration, delegate, queue);
    return session;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init]))
        charon_session_setup(self, nil, nil, nil);
    return self;
}

- (NSOperationQueue *)delegateQueue
{
    return _delegateQueue;
}

- (id<NSURLSessionDelegate>)delegate
{
    return charon_session_delegate(self);
}

- (NSURLSessionConfiguration *)configuration
{
    return [_configuration copy];
}

- (NSString *)sessionDescription
{
    @synchronized (self) {
        return _sessionDescription;
    }
}

- (void)setSessionDescription:(NSString *)sessionDescription
{
    NSString *copy = [sessionDescription copy];
    @synchronized (self) {
        _sessionDescription = copy;
    }
}

- (void)finishTasksAndInvalidate
{
    if (_shared)
        return;
    @synchronized (self) {
        _invalidated = YES;
    }
    charon_perform(^{
        self->_invalidating = YES;
        charon_session_check_invalidation(self);
    });
}

- (void)invalidateAndCancel
{
    if (_shared)
        return;
    @synchronized (self) {
        _invalidated = YES;
    }
    charon_perform(^{
        self->_invalidating = YES;
        for (NSURLSessionTask *task in [self->_tasks copy])
            charon_task_cancel(task);
        charon_session_check_invalidation(self);
    });
}

- (void)resetWithCompletionHandler:(void (^)(void))completionHandler
{
    void (^handler)(void) = [completionHandler copy];
    charon_perform(^{
        NSURLSessionConfiguration *configuration = self->_configuration;
        NSHTTPCookieStorage *cookies = configuration.HTTPCookieStorage;
        for (NSHTTPCookie *cookie in cookies.cookies)
            [cookies deleteCookie:cookie];
        [configuration.URLCache removeAllCachedResponses];
        NSURLCredentialStorage *credentials = configuration.URLCredentialStorage;
        NSDictionary *all = credentials.allCredentials;
        for (NSURLProtectionSpace *space in all) {
            NSDictionary *byUser = all[space];
            for (NSString *user in byUser)
                [credentials removeCredential:byUser[user] forProtectionSpace:space];
        }
        charon_session_deliver(self, ^{
            if (handler)
                handler();
        });
    });
}

- (void)flushWithCompletionHandler:(void (^)(void))completionHandler
{
    void (^handler)(void) = [completionHandler copy];
    charon_perform(^{
        charon_session_deliver(self, ^{
            if (handler)
                handler();
        });
    });
}

- (void)getTasksWithCompletionHandler:(void (^)(NSArray<NSURLSessionDataTask *> *, NSArray<NSURLSessionUploadTask *> *, NSArray<NSURLSessionDownloadTask *> *))completionHandler
{
    void (^handler)(NSArray *, NSArray *, NSArray *) = [completionHandler copy];
    charon_perform(^{
        NSMutableArray *dataTasks = [NSMutableArray array];
        NSMutableArray *uploadTasks = [NSMutableArray array];
        NSMutableArray *downloadTasks = [NSMutableArray array];
        for (NSURLSessionTask *task in self->_tasks) {
            if (task->_finished)
                continue;
            if ([task isKindOfClass:[NSURLSessionUploadTask class]])
                [uploadTasks addObject:task];
            else if ([task isKindOfClass:[NSURLSessionDataTask class]])
                [dataTasks addObject:task];
            else if ([task isKindOfClass:[NSURLSessionDownloadTask class]])
                [downloadTasks addObject:task];
        }
        charon_session_deliver(self, ^{
            if (handler)
                handler(dataTasks, uploadTasks, downloadTasks);
        });
    });
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
{
    return charon_session_task(self, [NSURLSessionDataTask class], request, NO);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
{
    return [self dataTaskWithRequest:charon_session_request(self, url)];
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL
{
    return charon_upload_task(self, request, fileURL, nil, nil);
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData
{
    return charon_upload_task(self, request, nil, bodyData, nil);
}

- (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSURLRequest *)request
{
    NSURLSessionUploadTask *task = charon_session_task(self, [NSURLSessionUploadTask class], request, NO);
    task->_body = CharonTaskBodyStream;
    return task;
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request
{
    return charon_download_task(self, request, nil);
}

- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url
{
    return charon_download_task(self, charon_session_request(self, url), nil);
}

- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData
{
    return charon_resumed_download_task(self, resumeData, nil);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    NSURLSessionDataTask *task = charon_session_task(self, [NSURLSessionDataTask class], request, completionHandler != nil);
    task->_dataHandler = [completionHandler copy];
    return task;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    return [self dataTaskWithRequest:charon_session_request(self, url) completionHandler:completionHandler];
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    return charon_upload_task(self, request, fileURL, nil, completionHandler);
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    return charon_upload_task(self, request, nil, bodyData, completionHandler);
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completionHandler
{
    return charon_download_task(self, request, completionHandler);
}

- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completionHandler
{
    return charon_download_task(self, charon_session_request(self, url), completionHandler);
}

- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completionHandler
{
    return charon_resumed_download_task(self, resumeData, completionHandler);
}

@end

@implementation NSURLSessionTask

@dynamic delegate;
@dynamic progress;
@dynamic priority;

+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _clientExpectsToSend = NSURLSessionTransferSizeUnknown;
        _clientExpectsToReceive = NSURLSessionTransferSizeUnknown;
        _prefersIncrementalDelivery = YES;
    }
    return self;
}

- (NSDate *)earliestBeginDate
{
    @synchronized (self) {
        return _earliestBeginDate;
    }
}

- (void)setEarliestBeginDate:(NSDate *)date
{
    NSDate *copy = [date copy];
    @synchronized (self) {
        _earliestBeginDate = copy;
    }
}

- (BOOL)prefersIncrementalDelivery
{
    @synchronized (self) {
        return _prefersIncrementalDelivery;
    }
}

- (void)setPrefersIncrementalDelivery:(BOOL)prefersIncrementalDelivery
{
    @synchronized (self) {
        _prefersIncrementalDelivery = prefersIncrementalDelivery;
    }
}

- (int64_t)countOfBytesClientExpectsToSend
{
    @synchronized (self) {
        return _clientExpectsToSend;
    }
}

- (void)setCountOfBytesClientExpectsToSend:(int64_t)count
{
    @synchronized (self) {
        _clientExpectsToSend = count;
    }
}

- (int64_t)countOfBytesClientExpectsToReceive
{
    @synchronized (self) {
        return _clientExpectsToReceive;
    }
}

- (void)setCountOfBytesClientExpectsToReceive:(int64_t)count
{
    @synchronized (self) {
        _clientExpectsToReceive = count;
    }
}

- (NSUInteger)taskIdentifier
{
    return _taskIdentifier;
}

- (NSURLRequest *)originalRequest
{
    @synchronized (self) {
        return _originalRequest;
    }
}

- (NSURLRequest *)currentRequest
{
    @synchronized (self) {
        return _currentRequest;
    }
}

- (NSURLResponse *)response
{
    @synchronized (self) {
        return _response;
    }
}

- (int64_t)countOfBytesReceived
{
    @synchronized (self) {
        return _countOfBytesReceived;
    }
}

- (int64_t)countOfBytesSent
{
    @synchronized (self) {
        return _countOfBytesSent;
    }
}

- (int64_t)countOfBytesExpectedToSend
{
    @synchronized (self) {
        return _countOfBytesExpectedToSend;
    }
}

- (int64_t)countOfBytesExpectedToReceive
{
    @synchronized (self) {
        return _countOfBytesExpectedToReceive;
    }
}

- (NSString *)taskDescription
{
    @synchronized (self) {
        return _taskDescription;
    }
}

- (void)setTaskDescription:(NSString *)taskDescription
{
    NSString *copy = [taskDescription copy];
    @synchronized (self) {
        _taskDescription = copy;
    }
}

- (NSURLSessionTaskState)state
{
    @synchronized (self) {
        return _state;
    }
}

- (NSError *)error
{
    @synchronized (self) {
        return _error;
    }
}

- (void)cancel
{
    @synchronized (self) {
        if (_state == NSURLSessionTaskStateCompleted || _state == NSURLSessionTaskStateCanceling)
            return;
        _state = NSURLSessionTaskStateCanceling;
    }
    charon_perform(^{
        charon_task_finish(self, charon_cancelled_error(self));
    });
}

- (void)suspend
{
    @synchronized (self) {
        if (_state != NSURLSessionTaskStateRunning)
            return;
        _state = NSURLSessionTaskStateSuspended;
    }
    charon_perform(^{
        if (self->_finished || !self->_started)
            return;
        self->_paused = YES;
        charon_timer_cancel(&self->_idleTimer);
    });
}

- (void)resume
{
    @synchronized (self) {
        if (_state != NSURLSessionTaskStateSuspended)
            return;
        _state = NSURLSessionTaskStateRunning;
    }
    charon_perform(^{
        if (self->_finished)
            return;
        self->_paused = NO;
        if (!self->_started) {
            self->_started = YES;
            [self->_session->_tasks addObject:self];
            charon_task_start(self);
            return;
        }
        charon_loader_start_pending(self->_loader);
        charon_task_restart_idle_timer(self);
        charon_task_flush_input(self);
    });
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation NSURLSessionDataTask

+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    return [super init];
}

@end

@implementation NSURLSessionUploadTask

+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    return [super init];
}

@end

@implementation NSURLSessionDownloadTask

+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    return [super init];
}

- (void)cancelByProducingResumeData:(void (^)(NSData *))completionHandler
{
    BOOL cancels;
    @synchronized (self) {
        cancels = _state == NSURLSessionTaskStateRunning || _state == NSURLSessionTaskStateSuspended;
        if (cancels)
            _state = NSURLSessionTaskStateCanceling;
    }
    void (^handler)(NSData *) = [completionHandler copy];
    charon_perform(^{
        NSData *resumeData = nil;
        if (cancels && !self->_finished) {
            CharonURLSessionLoader *loader = self->_loader;
            self->_loader = nil;
            charon_loader_stop(loader);
            charon_download_close(self);
            resumeData = charon_download_resume_data(self);
            self->_producedResumeData = resumeData;
            charon_task_finish(self, charon_cancelled_error(self));
        }
        if (handler) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                handler(resumeData);
            });
        }
    });
}

@end
