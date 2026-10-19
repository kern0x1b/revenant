#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>
#include <errno.h>
#include <pthread.h>
#include <string.h>

@implementation NSURLSessionWebSocketMessage {
    NSURLSessionWebSocketMessageType _type;
    NSData *_data;
    NSString *_string;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init
{
    if ((self = [super init]))
        _type = NSURLSessionWebSocketMessageTypeData;
    return self;
}
#pragma clang diagnostic pop

- (instancetype)initWithData:(NSData *)data
{
    if ((self = [super init])) {
        _type = NSURLSessionWebSocketMessageTypeData;
        _data = [data copy];
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string
{
    if ((self = [super init])) {
        _type = NSURLSessionWebSocketMessageTypeString;
        _string = [string copy];
    }
    return self;
}

- (NSURLSessionWebSocketMessageType)type
{
    return _type;
}

- (NSData *)data
{
    return _data;
}

- (NSString *)string
{
    return _string;
}

- (NSString *)description
{
    return _type == NSURLSessionWebSocketMessageTypeString ? _string.description : _data.description;
}

@end

typedef NS_ENUM(NSInteger, CharonSocketPhase) {
    CharonSocketPhaseIdle,
    CharonSocketPhaseHandshake,
    CharonSocketPhaseOpen,
    CharonSocketPhaseClosing,
    CharonSocketPhaseDone
};

static NSString *const CharonSocketGUID = @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

static CFRunLoopRef charon_socket_loop;

static void *charon_socket_main(void *context)
{
    @autoreleasepool {
        dispatch_semaphore_t ready = (__bridge_transfer dispatch_semaphore_t)context;
        charon_socket_loop = CFRunLoopGetCurrent();
        CFRunLoopSourceContext source;
        memset(&source, 0, sizeof(source));
        CFRunLoopSourceRef keepAlive = CFRunLoopSourceCreate(NULL, 0, &source);
        CFRunLoopAddSource(charon_socket_loop, keepAlive, kCFRunLoopDefaultMode);
        dispatch_semaphore_signal(ready);
    }
    CFRunLoopRun();
    return NULL;
}

static void charon_socket_perform(void (^block)(void))
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_semaphore_t ready = dispatch_semaphore_create(0);
        pthread_t thread;
        pthread_create(&thread, NULL, charon_socket_main, (__bridge_retained void *)ready);
        pthread_detach(thread);
        dispatch_semaphore_wait(ready, DISPATCH_TIME_FOREVER);
    });
    CFRunLoopPerformBlock(charon_socket_loop, kCFRunLoopDefaultMode, block);
    CFRunLoopWakeUp(charon_socket_loop);
}

static NSMutableArray *charon_socket_live(void)
{
    static NSMutableArray *live;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        live = [NSMutableArray array];
    });
    return live;
}

@interface NSURLSessionWebSocketTask () <NSStreamDelegate>
- (void)charon_configureWithSession:(NSURLSession *)session identifier:(NSUInteger)identifier request:(NSURLRequest *)request offered:(NSArray *)offered;
- (NSURLSession *)charon_session;
+ (instancetype)charon_make;
@end

static NSArray *charon_socket_tasks(NSURLSession *session)
{
    NSMutableArray *found = [NSMutableArray array];
    NSMutableArray *live = charon_socket_live();
    @synchronized (live) {
        for (NSURLSessionTask *task in live) {
            if ([(NSURLSessionWebSocketTask *)task charon_session] == session)
                [found addObject:task];
        }
    }
    return found;
}

static NSMutableSet *charon_socket_waiting(void)
{
    static NSMutableSet *waiting;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        waiting = [NSMutableSet set];
    });
    return waiting;
}

@implementation NSURLSessionWebSocketTask {
    NSURLSession *_session;
    id _delegate;
    NSData *_sentReason;
    NSUInteger _pingCount;
    NSUInteger _identifier;
    NSURLRequest *_request;
    NSArray *_offered;
    NSString *_description;
    NSURLSessionTaskState _state;
    NSError *_error;
    NSURLResponse *_response;
    NSInteger _maximumMessageSize;
    NSURLSessionWebSocketCloseCode _closeCode;
    NSData *_closeReason;

    CharonSocketPhase _phase;
    NSInputStream *_input;
    NSOutputStream *_output;
    NSString *_key;
    NSMutableData *_head;
    NSMutableData *_incomingBytes;
    NSMutableData *_outgoing;
    NSMutableArray *_acknowledgements;
    NSUInteger _written;
    NSMutableArray *_receivers;
    NSMutableArray *_arrived;
    NSMutableArray *_pings;
    NSMutableArray *_pending;
    NSMutableData *_fragment;
    NSInteger _fragmentOpcode;
    BOOL _started;
    BOOL _sentClose;
    BOOL _cancelled;
    BOOL _closeAfterFlush;
    NSError *_finalError;
    CFRunLoopTimerRef _timer;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)charon_make
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _state = NSURLSessionTaskStateSuspended;
        _maximumMessageSize = 1048576;
        _receivers = [NSMutableArray array];
        _arrived = [NSMutableArray array];
        _pings = [NSMutableArray array];
        _pending = [NSMutableArray array];
        _acknowledgements = [NSMutableArray array];
    }
    return self;
}

- (NSURLSession *)charon_session
{
    return _session;
}

- (NSUInteger)taskIdentifier
{
    return _identifier;
}

- (NSURLRequest *)originalRequest
{
    return _request;
}

- (NSURLRequest *)currentRequest
{
    return _request;
}

- (NSURLResponse *)response
{
    @synchronized (self) {
        return _response;
    }
}

- (int64_t)countOfBytesReceived
{
    return 0;
}

- (int64_t)countOfBytesSent
{
    return 0;
}

- (int64_t)countOfBytesExpectedToSend
{
    return 0;
}

- (int64_t)countOfBytesExpectedToReceive
{
    return 0;
}

- (NSString *)taskDescription
{
    @synchronized (self) {
        return _description;
    }
}

- (void)setTaskDescription:(NSString *)taskDescription
{
    @synchronized (self) {
        _description = [taskDescription copy];
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

- (NSInteger)maximumMessageSize
{
    @synchronized (self) {
        return _maximumMessageSize;
    }
}

- (void)setMaximumMessageSize:(NSInteger)maximumMessageSize
{
    @synchronized (self) {
        _maximumMessageSize = maximumMessageSize;
    }
}

- (NSURLSessionWebSocketCloseCode)closeCode
{
    @synchronized (self) {
        return _closeCode;
    }
}

- (NSData *)closeReason
{
    @synchronized (self) {
        return _closeReason;
    }
}

- (void)charon_configureWithSession:(NSURLSession *)session identifier:(NSUInteger)identifier request:(NSURLRequest *)request offered:(NSArray *)offered
{
    _session = session;
    _delegate = session.delegate;
    _identifier = identifier;
    _request = request;
    _offered = offered;
}

- (NSError *)charon_failure:(NSInteger)code description:(NSString *)description
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (description)
        userInfo[NSLocalizedDescriptionKey] = description;
    if (_request.URL) {
        userInfo[NSURLErrorFailingURLErrorKey] = _request.URL;
        userInfo[NSURLErrorFailingURLStringErrorKey] = _request.URL.absoluteString;
    }
    return [NSError errorWithDomain:NSURLErrorDomain code:code userInfo:userInfo];
}

- (NSError *)charon_posix:(int)code withURL:(BOOL)withURL
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (withURL && _request.URL) {
        userInfo[NSURLErrorFailingURLErrorKey] = _request.URL;
        userInfo[NSURLErrorFailingURLStringErrorKey] = _request.URL.absoluteString;
    } else {
        userInfo[@"NSDescription"] = [NSString stringWithUTF8String:strerror(code)];
    }
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:userInfo];
}

- (void)charon_deliver:(void (^)(void))block
{
    NSOperationQueue *queue = _session.delegateQueue;
    if (queue)
        [queue addOperationWithBlock:block];
    else
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

- (void)resume
{
    BOOL first;
    @synchronized (self) {
        if (_state != NSURLSessionTaskStateSuspended)
            return;
        _state = NSURLSessionTaskStateRunning;
        first = !_started;
        _started = YES;
    }
    if (first) {
        NSMutableArray *live = charon_socket_live();
        @synchronized (live) {
            [live addObject:self];
        }
    }
    charon_socket_perform(^{
        if (first) {
            [self charon_connect];
            return;
        }
        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        if (self->_phase != CharonSocketPhaseDone)
            [self->_input scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
    });
}

- (void)suspend
{
    @synchronized (self) {
        if (_state != NSURLSessionTaskStateRunning)
            return;
        _state = NSURLSessionTaskStateSuspended;
    }
    charon_socket_perform(^{
        [self->_input removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    });
}

- (void)cancel
{
    @synchronized (self) {
        if (_state == NSURLSessionTaskStateCompleted || _state == NSURLSessionTaskStateCanceling)
            return;
        _state = NSURLSessionTaskStateCanceling;
        _cancelled = YES;
    }
    charon_socket_perform(^{
        if (self->_phase == CharonSocketPhaseOpen)
            [self charon_sendControl:8 payload:[NSData data]];
        [self charon_finish:[self charon_failure:NSURLErrorCancelled description:@"cancelled"] pendingError:nil];
    });
}

- (void)cancelWithCloseCode:(NSURLSessionWebSocketCloseCode)closeCode reason:(NSData *)reason
{
    if (closeCode == NSURLSessionWebSocketCloseCodeInvalid) {
        [self cancel];
        return;
    }
    charon_socket_perform(^{
        if (self->_phase == CharonSocketPhaseDone || self->_sentClose)
            return;
        if (self->_phase != CharonSocketPhaseOpen) {
            [self charon_finish:[self charon_failure:NSURLErrorCancelled description:@"cancelled"] pendingError:nil];
            return;
        }
        NSMutableData *payload = [NSMutableData data];
        unsigned char code[2] = {(unsigned char)(closeCode >> 8), (unsigned char)closeCode};
        [payload appendBytes:code length:2];
        if (reason.length)
            [payload appendData:[reason subdataWithRange:NSMakeRange(0, MIN(reason.length, (NSUInteger)123))]];
        self->_sentReason = reason.length ? [reason subdataWithRange:NSMakeRange(0, MIN(reason.length, (NSUInteger)123))] : nil;
        [self charon_sendControl:8 payload:payload];
        self->_phase = CharonSocketPhaseClosing;
        [self charon_startTimer:5 error:[self charon_failure:NSURLErrorCancelled description:@"cancelled"]];
    });
}

- (void)sendMessage:(NSURLSessionWebSocketMessage *)message completionHandler:(void (^)(NSError *))completionHandler
{
    void (^handler)(NSError *) = [completionHandler copy];
    NSData *payload = message.type == NSURLSessionWebSocketMessageTypeString ? [message.string dataUsingEncoding:NSUTF8StringEncoding] : message.data;
    NSInteger opcode = message.type == NSURLSessionWebSocketMessageTypeString ? 1 : 2;
    charon_socket_perform(^{
        if (!message) {
            [self charon_call:handler error:[self charon_posix:EINVAL withURL:NO]];
            return;
        }
        if (self->_phase == CharonSocketPhaseDone || self->_phase == CharonSocketPhaseClosing || self->_sentClose) {
            NSError *dead = self->_finalError && self->_finalError.code != NSURLErrorCancelled ? self->_finalError : [self charon_posix:ENOTCONN withURL:YES];
            charon_socket_perform(^{
                [self charon_call:handler error:dead];
            });
            return;
        }
        NSData *frame = [self charon_frame:opcode payload:payload ?: [NSData data]];
        if (self->_phase == CharonSocketPhaseIdle || self->_phase == CharonSocketPhaseHandshake) {
            [self->_pending addObject:@[frame, (id)handler ?: (id)[NSNull null]]];
            return;
        }
        [self charon_write:frame acknowledge:handler];
    });
}

- (void)receiveMessageWithCompletionHandler:(void (^)(NSURLSessionWebSocketMessage *, NSError *))completionHandler
{
    void (^handler)(NSURLSessionWebSocketMessage *, NSError *) = [completionHandler copy];
    charon_socket_perform(^{
        if (!handler)
            return;
        if (self->_arrived.count) {
            NSURLSessionWebSocketMessage *message = self->_arrived[0];
            [self->_arrived removeObjectAtIndex:0];
            [self charon_deliver:^{
                handler(message, nil);
            }];
            return;
        }
        if (self->_phase == CharonSocketPhaseDone || self->_phase == CharonSocketPhaseClosing) {
            NSError *error = self->_finalError && self->_finalError.code != NSURLErrorCancelled ? self->_finalError : [self charon_posix:ENOTCONN withURL:YES];
            [self charon_deliver:^{
                handler(nil, error);
            }];
            return;
        }
        [self->_receivers addObject:handler];
    });
}

- (void)sendPingWithPongReceiveHandler:(void (^)(NSError *))pongReceiveHandler
{
    void (^handler)(NSError *) = [pongReceiveHandler copy];
    charon_socket_perform(^{
        if (self->_phase == CharonSocketPhaseDone || self->_phase == CharonSocketPhaseClosing || self->_sentClose) {
            [self charon_call:handler error:self->_finalError && self->_finalError.code != NSURLErrorCancelled ? self->_finalError : [self charon_posix:ENOTCONN withURL:YES]];
            return;
        }
        unsigned count = (unsigned)++self->_pingCount;
        unsigned char tag[4] = {(unsigned char)(count >> 24), (unsigned char)(count >> 16), (unsigned char)(count >> 8), (unsigned char)count};
        NSData *frame = [self charon_frame:9 payload:[NSData dataWithBytes:tag length:4]];
        [self->_pings addObject:(id)handler ?: (id)[NSNull null]];
        if (self->_phase == CharonSocketPhaseOpen)
            [self charon_write:frame acknowledge:nil];
        else
            [self->_pending addObject:@[frame, [NSNull null], @"ping"]];
    });
}

- (void)charon_call:(id)handler error:(NSError *)error
{
    if (!handler || handler == [NSNull null])
        return;
    void (^block)(NSError *) = handler;
    [self charon_deliver:^{
        block(error);
    }];
}

- (void)charon_startTimer:(NSTimeInterval)interval error:(NSError *)error
{
    [self charon_stopTimer];
    NSURLSessionWebSocketTask *task = self;
    CFRunLoopTimerRef timer = CFRunLoopTimerCreateWithHandler(NULL, CFAbsoluteTimeGetCurrent() + interval, 0, 0, 0, ^(CFRunLoopTimerRef fired) {
        [task charon_finish:error pendingError:nil];
    });
    _timer = timer;
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
}

- (void)charon_stopTimer
{
    if (_timer) {
        CFRunLoopTimerInvalidate(_timer);
        CFRelease(_timer);
        _timer = NULL;
    }
}

- (void)charon_connect
{
    if (_phase != CharonSocketPhaseIdle)
        return;
    if (_cancelled)
        return;
    NSURL *URL = _request.URL;
    BOOL secure = [URL.scheme caseInsensitiveCompare:@"https"] == NSOrderedSame;
    NSString *host = URL.host;
    NSInteger port = URL.port ? URL.port.integerValue : (secure ? 443 : 80);
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, (UInt32)port, &readStream, &writeStream);
    if (!readStream || !writeStream) {
        if (readStream)
            CFRelease(readStream);
        if (writeStream)
            CFRelease(writeStream);
        [self charon_finish:[self charon_failure:NSURLErrorCannotFindHost description:@"A server with the specified hostname could not be found."] pendingError:nil];
        return;
    }
    if (secure) {
        CFReadStreamSetProperty(readStream, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelNegotiatedSSL);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelNegotiatedSSL);
    }
    _input = CFBridgingRelease(readStream);
    _output = CFBridgingRelease(writeStream);
    _input.delegate = self;
    _output.delegate = self;
    NSRunLoop *loop = [NSRunLoop currentRunLoop];
    [_input scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
    [_output scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
    _phase = CharonSocketPhaseHandshake;
    _head = [NSMutableData data];
    _outgoing = [NSMutableData data];
    _incomingBytes = [NSMutableData data];
    uint8_t random[16];
    for (int index = 0; index < 16; index++)
        random[index] = (uint8_t)arc4random_uniform(256);
    _key = [[NSData dataWithBytes:random length:16] base64EncodedStringWithOptions:0];
    [_outgoing appendData:[self charon_handshake]];
    NSTimeInterval timeout = _request.timeoutInterval > 0 ? _request.timeoutInterval : 60;
    [self charon_startTimer:timeout error:[self charon_failure:NSURLErrorTimedOut description:@"The request timed out."]];
    [_input open];
    [_output open];
}

- (NSData *)charon_handshake
{
    NSURL *URL = _request.URL;
    NSString *path = URL.path.length ? URL.path : @"/";
    if (URL.query)
        path = [path stringByAppendingFormat:@"?%@", URL.query];
    BOOL secure = [URL.scheme caseInsensitiveCompare:@"https"] == NSOrderedSame;
    NSString *host = URL.port && URL.port.integerValue != (secure ? 443 : 80) ? [NSString stringWithFormat:@"%@:%@", URL.host, URL.port] : URL.host;
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    NSURLSessionConfiguration *configuration = _session.configuration;
    [fields addEntriesFromDictionary:configuration.HTTPAdditionalHeaders ?: @{}];
    [fields addEntriesFromDictionary:_request.allHTTPHeaderFields ?: @{}];
    NSArray *reserved = @[@"host", @"upgrade", @"connection", @"sec-websocket-key", @"sec-websocket-version", @"sec-websocket-extensions"];
    for (NSString *name in [fields allKeys]) {
        if ([reserved containsObject:name.lowercaseString])
            [fields removeObjectForKey:name];
    }
    BOOL hasAgent = NO;
    for (NSString *name in fields) {
        if ([name caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame)
            hasAgent = YES;
    }
    if (!hasAgent) {
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        fields[@"User-Agent"] = [NSString stringWithFormat:@"%@/%@ CFNetwork", info[@"CFBundleName"] ?: @"App", info[@"CFBundleVersion"] ?: @"1"];
    }
    NSHTTPCookieStorage *storage = configuration.HTTPCookieStorage;
    if (storage && configuration.HTTPShouldSetCookies && _request.HTTPShouldHandleCookies) {
        NSArray *cookies = [storage cookiesForURL:URL];
        if (cookies.count && ![fields objectForKey:@"Cookie"])
            fields[@"Cookie"] = [[NSHTTPCookie requestHeaderFieldsWithCookies:cookies] objectForKey:@"Cookie"];
    }
    NSMutableString *text = [NSMutableString stringWithFormat:@"GET %@ HTTP/1.1\r\nHost: %@\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %@\r\nSec-WebSocket-Version: 13\r\n", path, host, _key];
    for (NSString *name in fields)
        [text appendFormat:@"%@: %@\r\n", name, fields[name]];
    [text appendString:@"\r\n"];
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)charon_frame:(NSInteger)opcode payload:(NSData *)payload
{
    NSMutableData *frame = [NSMutableData data];
    unsigned char first = (unsigned char)(0x80 | opcode);
    [frame appendBytes:&first length:1];
    NSUInteger length = payload.length;
    if (length < 126) {
        unsigned char small = (unsigned char)(0x80 | length);
        [frame appendBytes:&small length:1];
    } else if (length < 65536) {
        unsigned char medium[3] = {0x80 | 126, (unsigned char)(length >> 8), (unsigned char)length};
        [frame appendBytes:medium length:3];
    } else {
        unsigned char large[9] = {0x80 | 127, 0, 0, 0, 0, (unsigned char)(length >> 24), (unsigned char)(length >> 16), (unsigned char)(length >> 8), (unsigned char)length};
        [frame appendBytes:large length:9];
    }
    unsigned char mask[4];
    for (int index = 0; index < 4; index++)
        mask[index] = (unsigned char)arc4random_uniform(256);
    [frame appendBytes:mask length:4];
    NSUInteger start = frame.length;
    [frame appendData:payload];
    unsigned char *bytes = (unsigned char *)frame.mutableBytes + start;
    for (NSUInteger index = 0; index < length; index++)
        bytes[index] ^= mask[index % 4];
    return frame;
}

- (void)charon_sendControl:(NSInteger)opcode payload:(NSData *)payload
{
    if (opcode == 8) {
        if (_sentClose)
            return;
        _sentClose = YES;
    }
    [self charon_write:[self charon_frame:opcode payload:payload] acknowledge:nil];
}

- (void)charon_write:(NSData *)frame acknowledge:(void (^)(NSError *))handler
{
    [_outgoing appendData:frame];
    if (handler)
        [_acknowledgements addObject:@[@(_written + _outgoing.length), handler]];
    [self charon_flush];
}

- (void)charon_flush
{
    while (_outgoing.length && _output.hasSpaceAvailable) {
        NSInteger put = [_output write:_outgoing.bytes maxLength:_outgoing.length];
        if (put <= 0)
            break;
        [_outgoing replaceBytesInRange:NSMakeRange(0, (NSUInteger)put) withBytes:NULL length:0];
        _written += (NSUInteger)put;
    }
    while (_acknowledgements.count && [_acknowledgements[0][0] unsignedIntegerValue] <= _written) {
        void (^handler)(NSError *) = _acknowledgements[0][1];
        [_acknowledgements removeObjectAtIndex:0];
        [self charon_call:handler error:nil];
    }
    if (_closeAfterFlush && !_outgoing.length)
        [self charon_finish:_finalError pendingError:nil];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event
{
    if (_phase == CharonSocketPhaseDone)
        return;
    switch (event) {
    case NSStreamEventHasSpaceAvailable:
        [self charon_flush];
        break;
    case NSStreamEventHasBytesAvailable: {
        uint8_t buffer[16384];
        NSInteger got = [_input read:buffer maxLength:sizeof(buffer)];
        while (got > 0 && _phase != CharonSocketPhaseDone) {
            [self charon_received:[NSData dataWithBytes:buffer length:(NSUInteger)got]];
            got = _phase != CharonSocketPhaseDone && _input.hasBytesAvailable ? [_input read:buffer maxLength:sizeof(buffer)] : 0;
        }
        break;
    }
    case NSStreamEventEndEncountered:
        [self charon_ended];
        break;
    case NSStreamEventErrorOccurred:
        [self charon_streamFailed:stream.streamError];
        break;
    default:
        break;
    }
}

- (void)charon_ended
{
    if (_phase == CharonSocketPhaseHandshake) {
        [self charon_finish:[self charon_failure:NSURLErrorNetworkConnectionLost description:@"The network connection was lost."] pendingError:nil];
        return;
    }
    if (_sentClose && !_closeAfterFlush) {
        [self charon_finish:nil pendingError:nil];
        return;
    }
    [self charon_finish:[self charon_posix:ECONNRESET withURL:NO] pendingError:[self charon_posix:ECONNABORTED withURL:NO]];
}

- (void)charon_streamFailed:(NSError *)error
{
    if (_phase == CharonSocketPhaseHandshake) {
        NSInteger code = NSURLErrorCannotConnectToHost;
        NSString *description = @"Could not connect to the server.";
        if ([error.domain isEqualToString:NSPOSIXErrorDomain] && error.code == ETIMEDOUT) {
            code = NSURLErrorTimedOut;
            description = @"The request timed out.";
        } else if ([error.domain isEqualToString:@"kCFErrorDomainCFNetwork"] && (error.code == 1 || error.code == 2)) {
            code = NSURLErrorCannotFindHost;
            description = @"A server with the specified hostname could not be found.";
        } else if ([error.domain isEqualToString:@"kCFStreamErrorDomainSSL"] || error.code <= -9800) {
            code = error.code >= -9814 && error.code <= -9807 ? NSURLErrorServerCertificateUntrusted : NSURLErrorSecureConnectionFailed;
            description = code == NSURLErrorServerCertificateUntrusted ? @"The certificate for this server is invalid." : @"A TLS error caused the secure connection to fail.";
        }
        [self charon_finish:[self charon_failure:code description:description] pendingError:nil];
        return;
    }
    NSError *reset = [error.domain isEqualToString:NSPOSIXErrorDomain] ? [self charon_posix:(int)error.code withURL:NO] : [self charon_posix:ECONNRESET withURL:NO];
    [self charon_finish:reset pendingError:[self charon_posix:ECONNABORTED withURL:NO]];
}

- (void)charon_received:(NSData *)data
{
    if (_phase == CharonSocketPhaseHandshake) {
        [_head appendData:data];
        NSData *terminator = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
        NSRange end = [_head rangeOfData:terminator options:0 range:NSMakeRange(0, _head.length)];
        if (end.location == NSNotFound)
            return;
        NSData *rest = [_head subdataWithRange:NSMakeRange(NSMaxRange(end), _head.length - NSMaxRange(end))];
        NSString *text = [[NSString alloc] initWithData:[_head subdataWithRange:NSMakeRange(0, end.location)] encoding:NSISOLatin1StringEncoding];
        _head = nil;
        if (![self charon_upgrade:text])
            return;
        data = rest;
        if (!data.length)
            return;
    }
    if (_phase != CharonSocketPhaseOpen && _phase != CharonSocketPhaseClosing)
        return;
    [_incomingBytes appendData:data];
    while (_phase == CharonSocketPhaseOpen || _phase == CharonSocketPhaseClosing) {
        if (![self charon_parseFrame])
            break;
    }
}

- (BOOL)charon_upgrade:(NSString *)text
{
    NSArray *lines = [text componentsSeparatedByString:@"\r\n"];
    NSArray *status = [lines.firstObject componentsSeparatedByString:@" "];
    NSInteger code = status.count > 1 ? [status[1] integerValue] : 0;
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    for (NSString *line in [lines subarrayWithRange:NSMakeRange(1, lines.count - 1)]) {
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound)
            continue;
        NSString *name = [line substringToIndex:colon.location];
        NSString *value = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *existing = headers[name];
        headers[name] = existing ? [NSString stringWithFormat:@"%@, %@", existing, value] : value;
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:_request.URL statusCode:code ?: 0 HTTPVersion:status.firstObject headerFields:headers];
    @synchronized (self) {
        _response = response;
    }
    NSString *(^header)(NSString *) = ^NSString *(NSString *name) {
        for (NSString *key in headers) {
            if ([key caseInsensitiveCompare:name] == NSOrderedSame)
                return headers[key];
        }
        return nil;
    };
    NSData *material = [[_key stringByAppendingString:CharonSocketGUID] dataUsingEncoding:NSASCIIStringEncoding];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(material.bytes, (CC_LONG)material.length, digest);
    NSString *accept = [[NSData dataWithBytes:digest length:sizeof(digest)] base64EncodedStringWithOptions:0];
    NSString *protocol = header(@"Sec-WebSocket-Protocol");
    BOOL valid = code == 101 && [[header(@"Upgrade") lowercaseString] isEqualToString:@"websocket"] &&
                 [[header(@"Connection") lowercaseString] rangeOfString:@"upgrade"].location != NSNotFound &&
                 [header(@"Sec-WebSocket-Accept") isEqualToString:accept] && (!protocol || [_offered containsObject:protocol]) &&
                 !header(@"Sec-WebSocket-Extensions");
    if (!valid) {
        [self charon_finish:[self charon_failure:NSURLErrorBadServerResponse description:@"There was a bad response from the server."] pendingError:nil];
        return NO;
    }
    [self charon_stopTimer];
    NSHTTPCookieStorage *storage = _session.configuration.HTTPCookieStorage;
    if (storage && _session.configuration.HTTPShouldSetCookies && _request.HTTPShouldHandleCookies) {
        NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:headers forURL:_request.URL];
        if (cookies.count)
            [storage setCookies:cookies forURL:_request.URL mainDocumentURL:_request.mainDocumentURL];
    }
    _phase = CharonSocketPhaseOpen;
    NSURLSession *session = _session;
    [self charon_deliver:^{
        id delegate = self->_delegate;
        if ([delegate respondsToSelector:@selector(URLSession:webSocketTask:didOpenWithProtocol:)])
            [delegate URLSession:session webSocketTask:self didOpenWithProtocol:protocol];
    }];
    NSArray *queued = [_pending copy];
    [_pending removeAllObjects];
    for (NSArray *entry in queued) {
        if ([entry.lastObject isEqual:@"ping"])
            [self charon_write:entry[0] acknowledge:nil];
    }
    for (NSArray *entry in queued) {
        if (![entry.lastObject isEqual:@"ping"])
            [self charon_write:entry[0] acknowledge:entry[1] == [NSNull null] ? nil : entry[1]];
    }
    return YES;
}

- (BOOL)charon_parseFrame
{
    const unsigned char *bytes = _incomingBytes.bytes;
    NSUInteger available = _incomingBytes.length;
    if (available < 2)
        return NO;
    BOOL fin = (bytes[0] & 0x80) != 0;
    int reserved = bytes[0] & 0x70;
    NSInteger opcode = bytes[0] & 0x0F;
    BOOL masked = (bytes[1] & 0x80) != 0;
    uint64_t length = bytes[1] & 0x7F;
    NSUInteger offset = 2;
    if (length == 126) {
        if (available < 4)
            return NO;
        length = ((uint64_t)bytes[2] << 8) | bytes[3];
        offset = 4;
    } else if (length == 127) {
        if (available < 10)
            return NO;
        length = 0;
        for (int index = 2; index < 10; index++)
            length = (length << 8) | bytes[index];
        offset = 10;
    }
    if (reserved || masked || (opcode >= 8 && (!fin || length > 125)) || (opcode > 2 && opcode < 8) || opcode > 10) {
        [self charon_protocolError:1002];
        return NO;
    }
    if (opcode < 8 && length > (uint64_t)MAX((NSInteger)0, self.maximumMessageSize) - (_fragment.length && opcode == 0 ? _fragment.length : 0)) {
        [self charon_sendControl:8 payload:[NSData dataWithBytes:(unsigned char[]){0x03, 0xF1} length:2]];
        [self charon_finish:[self charon_posix:EMSGSIZE withURL:NO] pendingError:[self charon_posix:ECONNABORTED withURL:NO]];
        return NO;
    }
    if (available - offset < length)
        return NO;
    NSData *payload = [NSData dataWithBytes:bytes + offset length:(NSUInteger)length];
    [_incomingBytes replaceBytesInRange:NSMakeRange(0, offset + (NSUInteger)length) withBytes:NULL length:0];
    switch (opcode) {
    case 0:
    case 1:
    case 2: {
        if (opcode == 0 && !_fragment) {
            [self charon_protocolError:1002];
            return NO;
        }
        if (opcode != 0) {
            if (_fragment) {
                [self charon_protocolError:1002];
                return NO;
            }
            _fragment = [NSMutableData data];
            _fragmentOpcode = opcode;
        }
        [_fragment appendData:payload];
        if (fin) {
            NSData *whole = _fragment;
            NSInteger kind = _fragmentOpcode;
            _fragment = nil;
            NSURLSessionWebSocketMessage *message = nil;
            if (kind == 1) {
                NSString *string = [[NSString alloc] initWithData:whole encoding:NSUTF8StringEncoding];
                if (!string) {
                    [self charon_protocolError:1002];
                    return NO;
                }
                message = [[NSURLSessionWebSocketMessage alloc] initWithString:string];
            } else {
                message = [[NSURLSessionWebSocketMessage alloc] initWithData:whole];
            }
            [self charon_arrived:message];
        }
        break;
    }
    case 8:
        [self charon_closeFrame:payload];
        return NO;
    case 9:
        if (_phase == CharonSocketPhaseOpen)
            [self charon_sendControl:10 payload:payload];
        break;
    case 10:
        if (_pings.count) {
            void (^handler)(NSError *) = _pings[0];
            [_pings removeObjectAtIndex:0];
            [self charon_call:handler error:nil];
        }
        break;
    }
    return YES;
}

- (void)charon_arrived:(NSURLSessionWebSocketMessage *)message
{
    if (_receivers.count) {
        void (^handler)(NSURLSessionWebSocketMessage *, NSError *) = _receivers[0];
        [_receivers removeObjectAtIndex:0];
        [self charon_deliver:^{
            handler(message, nil);
        }];
        return;
    }
    [_arrived addObject:message];
}

- (void)charon_protocolError:(unsigned)code
{
    unsigned char bytes[2] = {(unsigned char)(code >> 8), (unsigned char)code};
    [self charon_sendControl:8 payload:[NSData dataWithBytes:bytes length:2]];
    [self charon_finish:[self charon_posix:EPROTO withURL:NO] pendingError:[self charon_posix:ECONNABORTED withURL:NO]];
}

- (void)charon_closeFrame:(NSData *)payload
{
    if (payload.length == 1) {
        [self charon_protocolError:1002];
        return;
    }
    NSURLSessionWebSocketCloseCode code = NSURLSessionWebSocketCloseCodeNoStatusReceived;
    NSData *reason = nil;
    if (payload.length >= 2) {
        const unsigned char *bytes = payload.bytes;
        code = (NSURLSessionWebSocketCloseCode)((bytes[0] << 8) | bytes[1]);
        if (payload.length > 2)
            reason = [payload subdataWithRange:NSMakeRange(2, payload.length - 2)];
    }
    @synchronized (self) {
        _closeCode = code;
        _closeReason = reason ?: _sentReason;
    }
    if (!_sentClose)
        [self charon_sendControl:8 payload:payload.length >= 2 ? payload : [NSData data]];
    NSURLSession *session = _session;
    [self charon_deliver:^{
        id delegate = self->_delegate;
        if ([delegate respondsToSelector:@selector(URLSession:webSocketTask:didCloseWithCode:reason:)])
            [delegate URLSession:session webSocketTask:self didCloseWithCode:code reason:reason ?: self->_sentReason];
    }];
    _phase = CharonSocketPhaseClosing;
    _finalError = nil;
    _closeAfterFlush = YES;
    [self charon_flush];
}

- (void)charon_finish:(NSError *)error pendingError:(NSError *)pendingError
{
    if (_phase == CharonSocketPhaseDone)
        return;
    _phase = CharonSocketPhaseDone;
    [self charon_stopTimer];
    _finalError = error;
    [_input close];
    [_output close];
    [_input removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_output removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    _input.delegate = nil;
    _output.delegate = nil;
    NSError *dead = error ?: [self charon_posix:ENOTCONN withURL:YES];
    if (error.code == NSURLErrorCancelled && [error.domain isEqualToString:NSURLErrorDomain])
        dead = error;
    NSError *forPings = pendingError ?: dead;
    for (id handler in _pings)
        [self charon_call:handler error:forPings];
    [_pings removeAllObjects];
    for (void (^handler)(NSURLSessionWebSocketMessage *, NSError *) in _receivers) {
        [self charon_deliver:^{
            handler(nil, dead);
        }];
    }
    [_receivers removeAllObjects];
    for (NSArray *entry in _pending) {
        if (entry[1] != [NSNull null])
            [self charon_call:entry[1] error:dead];
    }
    [_pending removeAllObjects];
    for (NSArray *entry in _acknowledgements)
        [self charon_call:entry[1] error:dead];
    [_acknowledgements removeAllObjects];
    [_arrived removeAllObjects];
    NSURLSession *session = _session;
    [self charon_deliver:^{
        @synchronized (self) {
            self->_state = NSURLSessionTaskStateCompleted;
            self->_error = error;
        }
        id delegate = self->_delegate;
        if ([delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)])
            [delegate URLSession:session task:self didCompleteWithError:error];
        NSMutableArray *live = charon_socket_live();
        BOOL last = NO;
        @synchronized (live) {
            [live removeObjectIdenticalTo:self];
            last = charon_socket_tasks(session).count == 0;
        }
        if (last) {
            NSMutableSet *waiting = charon_socket_waiting();
            NSArray *entry = nil;
            @synchronized (waiting) {
                for (NSArray *candidate in waiting) {
                    if (candidate[0] == session)
                        entry = candidate;
                }
                if (entry)
                    [waiting removeObject:entry];
            }
            if (entry)
                ((void (*)(id, SEL))[entry[1] pointerValue])(session, NSSelectorFromString(entry[2]));
        }
    }];
}

@end

static NSUInteger charon_socket_identifier(NSURLSession *session)
{
    static NSUInteger fallback;
    Ivar ivar = class_getInstanceVariable([NSURLSession class], "_lastTaskIdentifier");
    if (!ivar)
        return ++fallback;
    @synchronized (session) {
        NSUInteger *counter = (NSUInteger *)((char *)(__bridge void *)session + ivar_getOffset(ivar));
        return ++*counter;
    }
}

static char CharonSocketInvalidatedKey;

static BOOL charon_socket_invalidated(NSURLSession *session)
{
    if (objc_getAssociatedObject(session, &CharonSocketInvalidatedKey))
        return YES;
    Ivar ivar = class_getInstanceVariable([NSURLSession class], "_invalidated");
    if (!ivar)
        return NO;
    @synchronized (session) {
        return *(BOOL *)((char *)(__bridge void *)session + ivar_getOffset(ivar));
    }
}

static void charon_socket_hook(SEL selector, IMP (^make)(IMP original, SEL selector))
{
    Class cls = [NSURLSession class];
    Method method = class_getInstanceMethod(cls, selector);
    if (method)
        class_replaceMethod(cls, selector, make(method_getImplementation(method), selector), method_getTypeEncoding(method));
}

static void charon_socket_install(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *name in @[@"invalidateAndCancel", @"finishTasksAndInvalidate"]) {
            SEL selector = NSSelectorFromString(name);
            BOOL cancels = [name isEqualToString:@"invalidateAndCancel"];
            charon_socket_hook(selector, ^IMP(IMP original, SEL selector) {
                return imp_implementationWithBlock(^(NSURLSession *session) {
                    NSArray *mine = charon_socket_tasks(session);
                    if (!mine.count) {
                        ((void (*)(id, SEL))original)(session, selector);
                        return;
                    }
                    objc_setAssociatedObject(session, &CharonSocketInvalidatedKey, @YES, OBJC_ASSOCIATION_RETAIN);
                    NSMutableSet *waiting = charon_socket_waiting();
                    @synchronized (waiting) {
                        [waiting addObject:@[session, [NSValue valueWithPointer:(void *)original], NSStringFromSelector(selector)]];
                    }
                    if (cancels) {
                        for (NSURLSessionTask *task in mine)
                            [task cancel];
                    }
                });
            });
        }
    });
}

static NSURLSessionWebSocketTask *charon_socket_task(NSURLSession *session, NSURLRequest *request, NSArray *protocols)
{
    if (!request)
        [NSException raise:NSInvalidArgumentException format:@"Cannot create task from nil request"];
    NSString *scheme = request.URL.scheme.lowercaseString;
    if (![scheme isEqualToString:@"ws"] && ![scheme isEqualToString:@"wss"])
        [NSException raise:NSGenericException format:@"WebSocket tasks can only be created with ws or wss schemes"];
    if (charon_socket_invalidated(session))
        [NSException raise:NSGenericException format:@"Task created in a session that has been invalidated"];
    charon_socket_install();
    NSMutableURLRequest *wire = [request mutableCopy];
    NSString *text = request.URL.absoluteString;
    wire.URL = [NSURL URLWithString:[text stringByReplacingCharactersInRange:NSMakeRange(0, scheme.length) withString:[scheme isEqualToString:@"ws"] ? @"http" : @"https"]];
    NSMutableArray *offered = [NSMutableArray arrayWithArray:protocols];
    NSString *existing = [wire valueForHTTPHeaderField:@"Sec-WebSocket-Protocol"];
    if (protocols.count)
        [wire setValue:[protocols componentsJoinedByString:@", "] forHTTPHeaderField:@"Sec-WebSocket-Protocol"];
    else if (existing) {
        for (NSString *name in [existing componentsSeparatedByString:@","])
            [offered addObject:[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    }
    NSURLSessionWebSocketTask *task = [NSURLSessionWebSocketTask charon_make];
    [task charon_configureWithSession:session identifier:charon_socket_identifier(session) request:wire offered:offered];
    return task;
}

@implementation NSURLSession (CharonWebSocket)

- (NSURLSessionWebSocketTask *)webSocketTaskWithURL:(NSURL *)url
{
    return [self webSocketTaskWithURL:url protocols:@[]];
}

- (NSURLSessionWebSocketTask *)webSocketTaskWithURL:(NSURL *)url protocols:(NSArray<NSString *> *)protocols
{
    if (!url)
        [NSException raise:NSInvalidArgumentException format:@"*** +[NSURLComponents initWithURL:resolvingAgainstBaseURL:]: nil URL parameter"];
    return charon_socket_task(self, [NSURLRequest requestWithURL:url], protocols);
}

- (NSURLSessionWebSocketTask *)webSocketTaskWithRequest:(NSURLRequest *)request
{
    return charon_socket_task(self, request, @[]);
}

@end
