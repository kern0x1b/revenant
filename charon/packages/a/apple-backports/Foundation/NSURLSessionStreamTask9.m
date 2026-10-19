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

/* SecureTransport's own types, because the header's availability of the framework is not the
   question: the question is that this library links no Security, so the two readers below are looked
   up rather than called directly. */

/* The four callbacks of NSURLSessionStreamDelegate that this file makes. The protocol is declared
   here, under the SDK's own spelling, so that the port's library carries it: the band machinery and
   the registry check read a protocol's methods out of the image's Objective-C metadata, and a
   protocol the port only *calls* through `id<...>` is not in that metadata. The methods themselves
   are the application's, not the port's, which is why no one implements them here. */
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

/* A session's stream task: a connection to a host and a port that the application reads and writes
   itself, rather than a request and a response.

   The connection is the release's own, made by `CFStreamCreatePairWithSocketToHost` exactly as
   `+[NSStream getStreamsToHostWithName:port:inputStream:outputStream:]` makes it (see
   NSStream+Socket8.m for the measurement that the release exports it), so reading, writing,
   buffering, timeouts and the native socket are the system's. What is here is the task's own
   bookkeeping: the two streams, the half-closes, the read and the write with their completion
   handlers, the delegate callbacks the header names, and the secure connection.

   The delegate callbacks are three of the four of NSURLSessionStreamDelegate, sent on the session's
   delegate queue when the session has one and on the main queue otherwise, each one only when the
   delegate answers to that selector, and never after -captureStreams: what the header says they are
   for is the read side closing, the streams being handed to the application, and the write side
   closing. The fourth, a better route, the protocol below declares and this file never sends; the
   comment at the end of -startSecureConnection says why.

   The class is an ALIAS and the task's own members are a CATEGORY, not a class implementation, and
   both are because of what the releases carry. CFNetwork's __objc_classlist has carried a class of
   this name since 8.0 with no method and no instance variable of its own -- measured over the held
   armv7 caches with objc.code_map: NSURLSessionStreamTask superclass NSURLSessionTask, 0 own
   ivars, 0 own methods at 8.0 and at 8.4.1, and no class anywhere in either release carrying
   -readDataOfMinLength:maxLength:timeout:completionHandler:, -captureStreams or
   -streamTaskWithHostName:port: -- and nothing below 8.0 carries the class at all. So there is
   nowhere to ask the release for it, and a class implementation here would be a second class of one
   name in every process on every band from 8.0 on. CHARON_ALIAS_OF defines CharonNSURLSessionStreamTask (named
   CHARON_ALIAS_CLASS(NSURLSessionStreamTask) below, which is the class of the release's name on a device and the
   release's name itself in a host differential - see charon_alias.h),
   whose superclass is the SDK's own NSURLSessionTask (which is this package's own below 7.0), and
   exports the release's name to it; the library's loader (attach.c) then hands the release's class
   every member below, so an 8.x task is an instance of CFNetwork's own class carrying them. Where
   the release has no such class the proxy is the class and its own answer is the right one. Either
   way the seven methods, the factories and the delegate protocol are this library's API, and one
   object carries them: it holds the class the release exports from 9.0 and nothing else, so
   tools/release-split.lua is clean on it.

   A category cannot add an instance variable and neither may the class behind it: attach.c lays the
   proxy out from the release's class and takes that write back when the two instance sizes differ, so
   a proxy with an instance variable of its own is never laid out after the class it stands for. The
   task's state -- the two streams, the host and the port, the half-closes, the socket's names and TLS
   values -- is therefore the one object beside this one, NSURLSessionStreamTaskState, reached through
   an associated object. It is made when it is first asked for and not in -init, because on 8.x the
   class the loader hands the members to is the release's own and -init there is the release's, which
   knows nothing of any of this. */

static char CharonStreamTaskStateKey;

/* The address and the port of a socket, in the form the header's properties answer: the address as
   a string and the port as a number. Both come out of the descriptor the release's own stream gives
   us through kCFStreamPropertySocketNativeHandle -- measured in the 6.1.3 armv7 cache as a
   CoreFoundation export -- so nothing here is a second socket stack. */
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

/* The negotiated version and cipher out of the release's own TLS session, which is the stream's
   kCFStreamPropertySSLContext once -startSecureConnection has made one. Both are read through public
   SecureTransport (measured in the 6.1.3 armv7 cache as Security exports), so nothing here
   negotiates anything: the release's stream did that, and these are the two numbers it agreed on. */
/* kCFStreamPropertySSLContext is a CFNetwork symbol -- measured in the 6.1.3 armv7 cache as a
   CFNetwork export, and the 6.1.3 gate's link says the rest of it: the Foundation backports library
   does not link CFNetwork, so a direct reference to the key does not resolve. The key is looked up by
   name instead, which is what this package does for the release's own symbols elsewhere
   (NSItemProvider.m for the UTType functions, NSOrthography+Default11.m for ICU's). A CFNetwork that
   is not loaded leaves the key nil, and a connection with no TLS session has nothing to report
   anyway. */
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

/* The two SecureTransport readers are in Security.framework, which this library does not link
   either -- the 6.1.3 gate's link names both of them -- so they are looked up by name, the same way
   the CFNetwork key is. Nothing here negotiates: the release's stream made the TLS session, and these
   are the two numbers it agreed on. */
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

/* The descriptor of the socket under a CFStream. CFStream.h says what the property carries, in both
   the SDK this library is built against (iPhoneOS16.4) and the host's own: "Value will be a CFData
   containing the native handle" - so the descriptor is INSIDE the data and the value is the address of
   the data. Reading the value as an int is what this did, and it is the address of a CFData, which is
   no descriptor at all: measured 2026-10-04 on the host, where the property answers a CFData of four
   bytes holding 06 00 00 00 - getsockname on the 6 answers the stream's own 127.0.0.1:port, and
   getsockname on the value's address answers that it is not a descriptor. Every name in the task's
   transaction was nil because of it, on a release whose own CFStream answers a CFData as the header
   says. A value that is not a CFData, or one too short to hold a descriptor, is refused by name here
   rather than read as bytes that are not there. */
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

/* The class the release's name stands for. NSURLSessionTask is the SDK's own, which is this
   package's own below 7.0, and it is the superclass every one of the seven methods below calls
   through [super ...]: -resume and -init are the release's own task. */
CHARON_ALIAS_OF(NSURLSessionStreamTask, NSURLSessionTask)

@interface NSURLSessionStreamTask (CharonConstruction)
- (instancetype)initWithSession:(NSURLSession *)session hostName:(NSString *)hostName port:(NSInteger)port;
@end

/* A category on Charon's own name, which ld64 merges into it, and not a category on the release's
   name: a category on NSURLSessionStreamTask implements the methods the SDK declares there, and the
   compiler's own -Wobjc-protocol-method-implementation says so once per method. What is written on
   the release's name here is the one declaration above, of the seam the session's factory uses. */
@implementation CHARON_ALIAS_CLASS(NSURLSessionStreamTask) (CharonStreamTask9)

/* The task's own state, made when it is first asked for. It is an associated object and not an
   instance variable of the class behind the alias because attach.c lays that class out from the
   release's class and takes the write back when the two instance sizes differ. It is made here rather
   than in -init because on the releases that carry a class of this name the object the loader gives
   the members to is the release's own, whose -init is the release's and knows nothing of this: an
   8.x task built by NSObject's own -init has to work all the same. The two halves start open, which
   is what an object with no -init behind it means by them. */
- (NSURLSessionStreamTaskState *)charon_state
{
    // The state already beside the task, or nil. This is the READER and it used to be written as a
    // call to itself - `NSURLSessionStreamTaskState *state = [self charon_state];` - which is
    // unbounded recursion, measured on 2026-10-04: the host differential of this family, built for the
    // first time since the alias landed, walked the stack until it ran out of it
    // (test`-[CharonHostNSURLSessionStreamTask(CharonStreamTask9) charon_state] + 4, EXC_BAD_ACCESS at
    // 0x16f603fc0). Nothing reached it before: the file could not be compiled by a host differential
    // (the -D renaming and the ##-built proxy name) and no device test ran this family, so the two
    // halves below are the reader and the maker, which is the shape CarPlay's row and ModelIO's zone
    // use.
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

/* The header deprecates -init with "please use -[NSURLSession streamTaskWithHostName:port:]", and a
   deprecation is a warning rather than a refusal: this answers what the release's own
   -[NSURLSessionTask init] answers, which is NSObject's, and the state is there when it is asked
   for. On 9.0 and later the band does not carry this file at all: the release exports the class. */
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
    /* The streams are read and written on the run loop of the thread that resumed the task, which is
       where CFStream's own callbacks want to be delivered. */
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

/* What the release's own stream knows about the socket underneath it, read once when the task is
   finishing - which is the one moment when both halves of that are true: the descriptor exists only
   after the connect has completed, and the stream is closed by the caller on the next line. Measured on
   the host 2026-10-04, kCFStreamPropertySocketNativeHandle answering nothing at all 5 ms after -open and
   a CFData carrying the descriptor at 62 ms, so reading it where this used to be read - in the same
   statement as -open - answered nil for every name in the transaction, on any platform, because the
   connect is asynchronous everywhere. The two negotiated TLS values come out of the same read and were
   nil there for the same reason: the handshake has not happened yet when the streams are opened. */
- (void)charon_readSocketNames
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    NSInputStream *input = state.input;
    if (!input || state.socketNamesRead)
        return;
    int descriptor = charon_native_descriptor((__bridge CFReadStreamRef)input);
    if (descriptor < 0)
        return; /* not connected yet: the other half-close asks again */
    state.socketNamesRead = YES;
    /* The four are written through the setters, not into the properties, so the two reads are the
       only place that knows the order the descriptor is asked in. */
    NSString *localAddress = nil, *remoteAddress = nil;
    NSNumber *localPort = nil, *remotePort = nil;
    charon_socket_name(descriptor, YES, &localAddress, &localPort);
    charon_socket_name(descriptor, NO, &remoteAddress, &remotePort);
    /* The two negotiated TLS values are asked of the release's own TLS session, and only when this task
       started one. The property IS the stream's SSL context, so a stream that never negotiated has none
       to hand back, and asking anyway does not answer nil: measured 2026-10-04 on the host, where
       CFReadStreamCopyProperty(kCFStreamPropertySSLContext) on an open stream with no TLS session takes
       the process down before it returns, with the key that the same flat lookup finds here (the probe
       and its output are named in the facts page). A connection with no TLS has nothing to report, and
       the system's own transaction about one says nil for both values. */
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

/* The task's metrics, handed to the delegate the way a data task's arrive.

   A stream task runs no loader, so there is nothing else that would build them: this is the whole
   delivery. One transaction, carrying the request the task was made with, the four names of the
   socket and the two negotiated TLS values the release's own stream and TLS session hold, and the
   dates the transaction's own initializer writes. It goes to the delegate on the session's delegate
   queue -- the session's own queue when it has one, the main queue otherwise -- because that is where
   every other delegate call of this session arrives. */
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

/* The session's delegate, when it answers to this one message. All four of the protocol's methods
   are @optional and independent of each other, so each is asked for by its own name: a delegate
   that implements only -URLSession:readClosedForStreamTask: is called for that one and not for the
   other three. */
- (id<NSURLSessionStreamDelegate>)charon_delegateFor:(SEL)selector
{
    id<NSURLSessionDelegate> sessionDelegate = [self charon_stateMade].session.delegate;
    if (![sessionDelegate respondsToSelector:selector])
        return nil;
    return (id<NSURLSessionStreamDelegate>)sessionDelegate;
}

/* One of the four, on the session's delegate queue where the session has one, as every other
   delegate message of this session arrives. The invocation is the port's own because the port
   declares the protocol and the caller's class implements the method: the arguments are the
   session, the task and, for the one message that names them, the two streams, at the indices the
   header's signatures give them. */
- (void)charon_tellDelegate:(SEL)selector input:(NSInputStream *)input
{
    NSURLSessionStreamTaskState *state = [self charon_stateMade];
    if (state.captured)
        return; /* the task is completed, and the header says no more messages go to the delegate */
    id<NSURLSessionStreamDelegate> delegate = [self charon_delegateFor:selector];
    if (!delegate)
        return;
    NSURLSession *session = [self charon_stateMade].session;
    /* The selector the protocol in this file declares, asked for by that same name. A device build
       has no other prefix to ask for, and the host differential renames the declaration and the call
       site together, which is what prefix_selectors.py exists for. */
    void (^deliver)(void) = ^{
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                    [(NSObject *)delegate methodSignatureForSelector:selector]];
        /* -setArgument:atIndex: copies the pointer and not the object, so the invocation has to hold
           what it is given: the output stream below is a local whose scope ends before -invoke runs,
           and the crash of a delegate that stores it would land in the delegate's own ARC prologue,
           nowhere near this line. */
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

    /* All three answers come off the stream, which is where the release keeps them: atEOF is the
       stream's own status rather than a guess from the length we happen to have, the error is the
       stream's own error rather than nil whenever there is data, and the timeout is the stream's read
       timeout rather than a loop condition. */
    NSDate *limit = timeout > 0 ? [NSDate dateWithTimeIntervalSinceNow:timeout] : nil;
    if (limit) {
        /* The read timeout is a CFStream key and a CFNetwork one at that, so it is reached by name
           like the TLS settings are. */
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
        /* The header's own case for the two close messages is the one the port never looked for: the
           *read side* of a connection closing, which is the peer's end arriving -- not this object
           being told to close. It is sent from here, once, and whether or not any read is in progress. */
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
            continue; /* nothing yet, and no end: the stream will call us when there is */
        }
        finish(NO); /* a real error, and the stream has it */
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
    /* Once, and then the task is finished: the header says the message is what completes the task
       and that it will not receive any more delegate messages. So the streams leave this object's
       run loop -- the application owns them from here and the task does not touch them again -- and
       every callback this file sends is answered from now on by the flag below. The flag is set
       after the call and not before it, because the call is the guard's own first test: set first,
       the handover this method exists to make is the one message it would swallow. */
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
    [self charon_readSocketNames]; /* while the socket is still open: charon_readSocketNames says why */
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
    [self charon_readSocketNames]; /* while the socket is still open: charon_readSocketNames says why */
    [state.output close];
    if (!state.readOpen)
        [self charon_finishMetrics];
    [self charon_tellDelegate:@selector(URLSession:writeClosedForStreamTask:) input:nil];
}

/* The two CFNetwork keys TLS is asked for with, reached by name because this library links no
   CFNetwork -- the gate's own linker says so. kCFStreamSocketSecurityLevelNegotiatedSSL is
   CoreFoundation's and is named by value here rather than by symbol, because a string constant can be
   written out and a data symbol cannot be linked. */
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
    /* TLS is the release's own, asked for the release's way: the SSL settings go on both streams
       *before* they are opened, and CFNetwork negotiates and judges the certificate. That is the
       whole of what the method promises, and this used to set a flag about closing the native
       socket instead, which is not what a secure connection is. The key and the level are the two
       CFNetwork strings, looked up by name; the level's own value is written out, because
       kCFStreamSocketSecurityLevelNegotiatedSSL is a CoreFoundation data symbol this library cannot
       link either. */
    NSString *settings = charon_ssl_settings_key();
    NSString *level = charon_ssl_level_key();
    if (settings && level) {
        NSDictionary *negotiated = @{level: @"kCFStreamSocketSecurityLevelNegotiatedSSL"};
        if (state.input)
            [state.input setProperty:negotiated forKey:settings];
        if (state.output)
            [state.output setProperty:negotiated forKey:settings];
    }
    /* No route message, and the reason is not that this release has nothing to ask with: it carries
       SystemConfiguration, whose reachability this same library already reads for a task that waits
       for connectivity (NSURLSession.m, charon_task_when_connected). What those flags report is
       whether the host is reachable and over which kind of interface; the header's message says the
       *system* now holds a better route to the host. A change in those flags is
       this port's own inference from a reachability answer, and sending it under the system's name
       would be a false report to the application, which is what the header warns the caller about
       when it says a new task may still fail. */
}

/* The tree's own idiom for a row that is stored and does nothing, from
   MKMapView+Transform.m: say it once per api, in the log, and not every time. */
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
    /* Deprecated by the SDK, and rightly: TLS cannot be taken off a connection that has it. On a
       connection that never started it there is nothing to stop, which is the answer the header's own
       deprecation text describes -- so this does nothing, and says so once rather than every time. */
    [self charon_inert:@"-stopSecureConnection"
                   why:@"TLS cannot be taken off a connection that has it, and the SDK deprecates the method for that reason"];
}

@end
