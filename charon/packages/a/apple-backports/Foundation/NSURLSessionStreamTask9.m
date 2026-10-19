#import <Foundation/Foundation.h>
#import <CoreFoundation/CFStream.h>
#import "CharonStreamTaskState.h"
#import "CharonURLSessionMetrics.h"
#import "../charon_alias.h"
#import <objc/runtime.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <dlfcn.h>
#include <Security/SecureTransport.h>

@protocol NSURLSessionStreamDelegate <NSObject>
@optional
- (void)URLSession:(NSURLSession *)session
              streamTask:(NSURLSessionStreamTask *)streamTask
    didBecomeInputStream:(NSInputStream *)inputStream
            outputStream:(NSOutputStream *)outputStream;
- (void)URLSession:(NSURLSession *)session betterRouteDiscoveredForStreamTask:(NSURLSessionStreamTask *)streamTask;
- (void)URLSession:(NSURLSession *)session readClosedForStreamTask:(NSURLSessionStreamTask *)streamTask;
- (void)URLSession:(NSURLSession *)session writeClosedForStreamTask:(NSURLSessionStreamTask *)streamTask;
@end

static char CharonStreamTaskStateKey;

static void charon_socket_name(int descriptor, BOOL local, NSString **address, NSNumber **port)
{
    struct sockaddr_in name;
    socklen_t length = sizeof(name);
    int asked = local ? getsockname(descriptor, (struct sockaddr *)&name, &length)
                      : getpeername(descriptor, (struct sockaddr *)&name, &length);
    if (asked != 0 || name.sin_family != AF_INET)
        return;
    char text[INET_ADDRSTRLEN];
    if (!inet_ntop(AF_INET, &name.sin_addr, text, sizeof(text)))
        return;
    if (address)
        *address = @(text);
    if (port)
        *port = @(ntohs(name.sin_port));
}

static CFStringRef charon_ssl_context_key(void)
{
    static CFStringRef key;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *library = dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork", RTLD_LAZY);
        if (!library)
            library = RTLD_DEFAULT;
        key = (CFStringRef)dlsym(library, "kCFStreamPropertySSLContext");
        if (!key)
            key = (CFStringRef)dlsym(RTLD_DEFAULT, "kCFStreamPropertySSLContext");
    });
    return key;
}

typedef OSStatus (*CharonNegotiatedProtocol)(SSLContextRef, SSLProtocol *);
typedef OSStatus (*CharonNegotiatedCipher)(SSLContextRef, SSLCipherSuite *);

static CharonNegotiatedProtocol charon_tls_protocol;
static CharonNegotiatedCipher charon_tls_cipher;

static void charon_load_tls(void)
{
    static dispatch_once_t once;
    static CharonNegotiatedProtocol protocol;
    static CharonNegotiatedCipher cipher;
    dispatch_once(&once, ^{
        void *library = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY);
        if (!library)
            library = RTLD_DEFAULT;
        protocol = (CharonNegotiatedProtocol)dlsym(library, "SSLGetNegotiatedProtocolVersion");
        cipher = (CharonNegotiatedCipher)dlsym(library, "SSLGetNegotiatedCipher");
    });
    charon_tls_protocol = protocol;
    charon_tls_cipher = cipher;
}

static void charon_negotiated_tls(CFReadStreamRef stream, NSNumber **version, NSNumber **cipherValue)
{
    charon_load_tls();
    CFStringRef key = charon_ssl_context_key();
    if (!key)
        return;
    CFTypeRef context = CFReadStreamCopyProperty(stream, key);
    if (!context)
        return;
    SSLProtocol got = kSSLProtocolUnknown;
    if (charon_tls_protocol && charon_tls_protocol((SSLContextRef)context, &got) == noErr && version)
        *version = @(got);
    SSLCipherSuite agreed = 0;
    if (charon_tls_cipher && charon_tls_cipher((SSLContextRef)context, &agreed) == noErr && agreed && cipherValue)
        *cipherValue = @(agreed);
    CFRelease(context);
}

static int charon_native_descriptor(CFReadStreamRef stream)
{
    CFTypeRef handle = CFReadStreamCopyProperty(stream, kCFStreamPropertySocketNativeHandle);
    if (!handle)
        return -1;
    int descriptor = -1;
    if (CFGetTypeID(handle) == CFDataGetTypeID() && CFDataGetLength((CFDataRef)handle) >= (CFIndex)sizeof(descriptor))
        memcpy(&descriptor, CFDataGetBytePtr((CFDataRef)handle), sizeof(descriptor));
    CFRelease(handle);
    return descriptor;
}

CHARON_ALIAS_OF(NSURLSessionStreamTask, NSURLSessionTask)

@interface NSURLSessionStreamTask (CharonConstruction)
- (instancetype)initWithSession:(NSURLSession *)session hostName:(NSString *)hostName port:(NSInteger)port;
@end

@implementation CHARON_ALIAS_CLASS(NSURLSessionStreamTask) (CharonStreamTask9)

- (NSURLSessionStreamTaskState *)charon_state
{
    return objc_getAssociatedObject(self, &CharonStreamTaskStateKey);
}

- (NSURLSessionStreamTaskState *)charon_stateMade
{
    NSURLSessionStreamTaskState *state = [self charon_state];
    if (!state) {
        state = [[NSURLSessionStreamTaskState alloc] init];
        state.readOpen = YES;
        state.writeOpen = YES;
        objc_setAssociatedObject(self, &CharonStreamTaskStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithSession:(NSURLSession *)session hostName:(NSString *)hostName port:(NSInteger)port
{
    if ((self = [super init])) {
        NSURLSessionStreamTaskState *state = [self charon_stateMade];
        state.session = session;
        state.hostName = [hostName copy];
        state.hostPort = port;
    }
    return self;
}

- (void)charon_open
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (state.started)
        return;
    state.started = YES;
    NSInputStream *input = nil;
    NSOutputStream *output = nil;
    [NSStream getStreamsToHostWithName:state.hostName ?: @"localhost" port:state.hostPort
                          inputStream:&input outputStream:&output];
    state.openedAt = [NSDate date];
    state.input = input;
    state.output = output;
    [input scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [output scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [input open];
    [output open];
    [self charon_tellDelegate:@selector(URLSession:streamTask:didBecomeInputStream:outputStream:) input:input];
}

- (void)resume
{
    [self charon_open];
    [super resume];
}

- (void)charon_readSocketNames
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    NSInputStream *input = state.input;
    if (!input || state.socketNamesRead)
        return;
    int descriptor = charon_native_descriptor((__bridge CFReadStreamRef)input);
    if (descriptor < 0)
        return;
    state.socketNamesRead = YES;
    NSString *localAddress = nil, *remoteAddress = nil;
    NSNumber *localPort = nil, *remotePort = nil;
    charon_socket_name(descriptor, YES, &localAddress, &localPort);
    charon_socket_name(descriptor, NO, &remoteAddress, &remotePort);
    NSNumber *version = nil, *cipher = nil;
    if (state.secure)
        charon_negotiated_tls((__bridge CFReadStreamRef)input, &version, &cipher);
    state.tlsProtocolVersion = version;
    state.tlsCipherSuite = cipher;
    state.localAddress = localAddress;
    state.localPort = localPort;
    state.remoteAddress = remoteAddress;
    state.remotePort = remotePort;
}

- (void)charon_finishMetrics
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (state.finished)
        return;
    state.finished = YES;
    NSURLSession *session = [self charon_stateMade].session;
    id<NSURLSessionDelegate> sessionDelegate = session.delegate;
    SEL selector = NSSelectorFromString(@"URLSession:task:didFinishCollectingMetrics:");
    if (![sessionDelegate respondsToSelector:selector])
        return;

    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:
                                    [NSString stringWithFormat:@"stream://%@:%@", [self charon_stateMade].hostName ?: @"localhost",
                                     @([self charon_stateMade].hostPort)]]];
    NSURLSessionTaskTransactionMetrics *transaction =
        [[NSURLSessionTaskTransactionMetrics alloc] initCharonWithRequest:request
                                                                fetchType:NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad];
    [transaction charon_noteSocketLocalAddress:state.localAddress port:state.localPort
                                 remoteAddress:state.remoteAddress remotePort:state.remotePort
                             tlsProtocolVersion:state.tlsProtocolVersion cipherSuite:state.tlsCipherSuite];
    [transaction charon_finished];
    NSDate *end = [NSDate date];
    NSURLSessionTaskMetrics *metrics =
        [[NSURLSessionTaskMetrics alloc] initCharonWithTransactions:@[transaction] start:state.openedAt ?: end end:end];

    void (^deliver)(void) = ^{
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                    [(NSObject *)sessionDelegate methodSignatureForSelector:selector]];
        [invocation retainArguments];
        invocation.selector = selector;
        invocation.target = sessionDelegate;
        [invocation setArgument:&session atIndex:2];
        [invocation setArgument:&self atIndex:3];
        [invocation setArgument:&metrics atIndex:4];
        [invocation invoke];
    };
    NSOperationQueue *queue = session.delegateQueue;
    if (queue)
        [queue addOperationWithBlock:deliver];
    else
        dispatch_async(dispatch_get_main_queue(), deliver);
}

- (id<NSURLSessionStreamDelegate>)charon_delegateFor:(SEL)selector
{
    id<NSURLSessionDelegate> sessionDelegate = [self charon_stateMade].session.delegate;
    if (![sessionDelegate respondsToSelector:selector])
        return nil;
    return (id<NSURLSessionStreamDelegate>)sessionDelegate;
}

- (void)charon_tellDelegate:(SEL)selector input:(NSInputStream *)input
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (state.captured)
        return;
    id<NSURLSessionStreamDelegate> delegate = [self charon_delegateFor:selector];
    if (!delegate)
        return;
    NSURLSession *session = [self charon_stateMade].session;
    void (^deliver)(void) = ^{
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                    [(NSObject *)delegate methodSignatureForSelector:selector]];
        [invocation retainArguments];
        invocation.selector = selector;
        invocation.target = delegate;
        [invocation setArgument:&session atIndex:2];
        [invocation setArgument:&self atIndex:3];
        if (selector == @selector(URLSession:streamTask:didBecomeInputStream:outputStream:)) {
            [invocation setArgument:&input atIndex:4];
            NSOutputStream *output = state.output;
            [invocation setArgument:&output atIndex:5];
        }
        [invocation invoke];
    };
    NSOperationQueue *queue = session.delegateQueue;
    if (queue)
        [queue addOperationWithBlock:deliver];
    else
        dispatch_async(dispatch_get_main_queue(), deliver);
}

- (void)readDataOfMinLength:(NSUInteger)minBytes
                   maxLength:(NSUInteger)maxBytes
                     timeout:(NSTimeInterval)timeout
           completionHandler:(void (^)(NSData *, BOOL, NSError *))completionHandler
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (!state.started)
        [self charon_open];
    NSInputStream *input = state.input;
    if (!input || !state.readOpen) {
        if (completionHandler)
            completionHandler(nil, YES, input ? nil : [NSError errorWithDomain:NSURLErrorDomain
                                                                       code:NSURLErrorCannotConnectToHost userInfo:nil]);
        return;
    }

    NSDate *limit = timeout > 0 ? [NSDate dateWithTimeIntervalSinceNow:timeout] : nil;
    if (limit) {
        NSString *key = charon_read_timeout_key();
        if (key)
            [input setProperty:limit forKey:key];
    }
    NSMutableData *held = [NSMutableData data];
    __block BOOL finished = NO;
    void (^finish)(BOOL) = ^(BOOL timedOut) {
        if (finished)
            return;
        finished = YES;
        BOOL atEnd = input.streamStatus == NSStreamStatusAtEnd ||
                     input.streamStatus == NSStreamStatusClosed || input.streamStatus == NSStreamStatusError;
        NSError *error = input.streamError;
        if (timedOut && !error && !atEnd)
            error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
        if (completionHandler)
            completionHandler(held.length ? held : nil, atEnd, error);
        if (atEnd && !error && !state.readClosedReported) {
            state.readClosedReported = YES;
            [self charon_tellDelegate:@selector(URLSession:readClosedForStreamTask:) input:nil];
        }
    };

    while (held.length < maxBytes) {
        if (timeout > 0 && [limit timeIntervalSinceNow] <= 0) {
            finish(YES);
            return;
        }
        NSUInteger wanted = MIN(maxBytes - held.length, 4096);
        uint8_t buffer[4096];
        NSInteger got = [input read:buffer maxLength:wanted];
        if (got > 0) {
            [held appendBytes:buffer length:(NSUInteger)got];
            if (held.length >= minBytes)
                break;
            continue;
        }
        if (got == 0) {
            if (input.streamStatus == NSStreamStatusAtEnd || input.streamStatus == NSStreamStatusClosed ||
                input.streamStatus == NSStreamStatusError) {
                finish(NO);
                return;
            }
            if (timeout > 0 && [limit timeIntervalSinceNow] <= 0) {
                finish(YES);
                return;
            }
            continue;
        }
        finish(NO);
        return;
    }
    finish(NO);
}

- (void)writeData:(NSData *)data timeout:(NSTimeInterval)timeout completionHandler:(void (^)(NSError *))completionHandler
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (!state.started)
        [self charon_open];
    NSOutputStream *output = state.output;
    if (!output || !state.writeOpen) {
        if (completionHandler)
            completionHandler(output ? nil : [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]);
        return;
    }
    const uint8_t *bytes = data.bytes;
    NSUInteger left = data.length;
    NSError *error = nil;
    while (left) {
        NSInteger written = [output write:bytes maxLength:left];
        if (written > 0) {
            bytes += written;
            left -= (NSUInteger)written;
            continue;
        }
        error = output.streamError;
        break;
    }
    if (completionHandler)
        completionHandler(left ? (error ?: [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]) : nil);
}

- (void)captureStreams
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (state.captured)
        return;
    if (!state.started)
        [self charon_open];
    [state.input removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [state.output removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self charon_tellDelegate:@selector(URLSession:streamTask:didBecomeInputStream:outputStream:) input:state.input];
    state.captured = YES;
}

- (void)closeRead
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (!state.readOpen)
        return;
    state.readOpen = NO;
    [self charon_readSocketNames];
    [state.input close];
    if (!state.writeOpen)
        [self charon_finishMetrics];
    [self charon_tellDelegate:@selector(URLSession:readClosedForStreamTask:) input:nil];
}

- (void)closeWrite
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (!state.writeOpen)
        return;
    state.writeOpen = NO;
    [self charon_readSocketNames];
    [state.output close];
    if (!state.readOpen)
        [self charon_finishMetrics];
    [self charon_tellDelegate:@selector(URLSession:writeClosedForStreamTask:) input:nil];
}

static NSString *charon_ssl_settings_key(void)
{
    static NSString *key;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork", RTLD_LAZY);
        if (!handle)
            handle = RTLD_DEFAULT;
        key = (__bridge NSString *)dlsym(handle, "kCFStreamPropertySSLSettings");
    });
    return key;
}

static NSString *charon_read_timeout_key(void)
{
    static NSString *key;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork", RTLD_LAZY);
        if (!handle)
            handle = RTLD_DEFAULT;
        key = (__bridge NSString *)dlsym(handle, "kCFStreamPropertyReadTimeout");
    });
    return key;
}

static NSString *charon_ssl_level_key(void)
{
    static NSString *key;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork", RTLD_LAZY);
        if (!handle)
            handle = RTLD_DEFAULT;
        key = (__bridge NSString *)dlsym(handle, "kCFStreamSSLLevel");
    });
    return key;
}

- (void)startSecureConnection
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (state.secure)
        return;
    state.secure = YES;
    NSString *settings = charon_ssl_settings_key();
    NSString *level = charon_ssl_level_key();
    if (settings && level) {
        NSDictionary *negotiated = @{level: @"kCFStreamSocketSecurityLevelNegotiatedSSL"};
        if (state.input)
            [state.input setProperty:negotiated forKey:settings];
        if (state.output)
            [state.output setProperty:negotiated forKey:settings];
    }
}

- (void)charon_inert:(NSString *)api why:(NSString *)why
{
    static NSMutableSet *told;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        told = [[NSMutableSet alloc] init];
    });
    @synchronized(told) {
        if ([told containsObject:api])
            return;
        [told addObject:api];
        NSLog(@"FoundationBackports: %s does nothing on this release, and %@", [api UTF8String], why);
    }
}

- (void)stopSecureConnection
{
    [self charon_inert:@"-stopSecureConnection"
                   why:@"TLS cannot be taken off a connection that has it, and the SDK deprecates the method for that reason"];
}

@end
