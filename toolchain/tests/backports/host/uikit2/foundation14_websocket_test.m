#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"
#import "wsserver.h"

static NSString *host_selector(NSString *name)
{
    return [@"charonHost" stringByAppendingString:[[name substringToIndex:1].uppercaseString stringByAppendingString:[name substringFromIndex:1]]];
}

static NSString *described(NSError *error)
{
    return error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code] : @"-";
}

@interface Watcher : NSObject <NSURLSessionWebSocketDelegate, NSURLSessionTaskDelegate>
@property (strong) NSMutableArray *events;
@end

@implementation Watcher
- (instancetype)init
{
    self = [super init];
    _events = [NSMutableArray array];
    return self;
}
- (void)add:(NSString *)text
{
    @synchronized (self) {
        [_events addObject:text];
    }
}
- (void)URLSession:(NSURLSession *)session webSocketTask:(id)task didOpenWithProtocol:(NSString *)protocol
{
    [self add:[NSString stringWithFormat:@"open %@", protocol ?: @"-"]];
}
- (void)URLSession:(NSURLSession *)session webSocketTask:(id)task didCloseWithCode:(NSInteger)code reason:(NSData *)reason
{
    [self add:[NSString stringWithFormat:@"close %ld %@", (long)code, reason ? [[NSString alloc] initWithData:reason encoding:NSUTF8StringEncoding] : @"-"]];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self add:[NSString stringWithFormat:@"complete %@ state=%ld", described(error), (long)task.state]];
}
@end

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static NSString *message_text(id message)
{
    if (!message)
        return @"nil";
    NSInteger type = [[message valueForKey:@"type"] integerValue];
    return type == 1 ? [NSString stringWithFormat:@"string(%lu):%@", (unsigned long)[[message valueForKey:@"string"] length], [[[message valueForKey:@"string"] description] substringToIndex:MIN((NSUInteger)20, [[message valueForKey:@"string"] length])]]
                     : [NSString stringWithFormat:@"data(%lu)", (unsigned long)[[message valueForKey:@"data"] length]];
}

static id make_message(BOOL port, id payload)
{
    Class cls = port ? NSClassFromString(@"CharonHostNSURLSessionWebSocketMessage") : [NSURLSessionWebSocketMessage class];
    return [payload isKindOfClass:[NSString class]] ? [[cls alloc] initWithString:payload] : [[cls alloc] initWithData:payload];
}

static id make_task(NSURLSession *session, BOOL port, id target, NSArray *protocols)
{
    if ([target isKindOfClass:[NSURL class]] && protocols)
        return ((id (*)(id, SEL, id, id))objc_msgSend)(session, NSSelectorFromString(port ? host_selector(@"webSocketTaskWithURL:protocols:") : @"webSocketTaskWithURL:protocols:"), target, protocols);
    return ((id (*)(id, SEL, id))objc_msgSend)(session, NSSelectorFromString(port ? ([target isKindOfClass:[NSURL class]] ? host_selector(@"webSocketTaskWithURL:") : host_selector(@"webSocketTaskWithRequest:")) : ([target isKindOfClass:[NSURL class]] ? @"webSocketTaskWithURL:" : @"webSocketTaskWithRequest:")), target);
}

static NSString *server_lines(void)
{
    NSMutableArray *kept = [NSMutableArray array];
    for (NSString *line in wsserver_lines()) {
        if ([line hasPrefix:@"header-names"])
            continue;
        if ([line hasPrefix:@"header host"] || [line hasPrefix:@"header origin"])
            continue;
        [kept addObject:line];
    }
    return [kept componentsJoinedByString:@" | "];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        int listener = wsserver_start();
        Class portTask = NSClassFromString(@"CharonHostNSURLSessionWebSocketTask");
        CHECK(portTask != Nil && NSClassFromString(@"CharonHostNSURLSessionWebSocketMessage") != Nil, "the port defines the task and the message");
        NSURL *(^url)(NSString *) = ^NSURL *(NSString *path) {
            return [NSURL URLWithString:[NSString stringWithFormat:@"ws://127.0.0.1:%d%@", listener, path]];
        };
        NSArray *names = @[@"echo, ping and a close with a code", @"protocols and headers through a request", @"a refusal of the handshake", @"an answer that is not an upgrade", @"a wrong accept key", @"a refused connection", @"a close from the server at once",
                           @"a message in fragments with a ping between", @"a message beyond the maximum size", @"a large limit takes it", @"text that is not UTF-8", @"a ping from the server", @"the server drops the connection", @"the server closes on request", @"cancel and use after it", @"cookies", @"an invalidated session", @"wrong schemes and nil arguments"];
        for (int which = 0; which < 18; which++) {
            NSString *transcripts[2];
            for (int pass = 0; pass < 2; pass++) {
                BOOL port = pass == 0;
                Watcher *watcher = [[Watcher alloc] init];
                NSOperationQueue *queue = [[NSOperationQueue alloc] init];
                queue.maxConcurrentOperationCount = 1;
                NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
                NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:watcher delegateQueue:queue];
                NSMutableArray *log = [NSMutableArray array];
                void (^L)(NSString *) = ^(NSString *text) {
                    @synchronized (log) {
                        [log addObject:text];
                    }
                };
                wsserver_reset();
                id task = nil;
                switch (which) {
                case 0: {
                    task = make_task(session, port, url(@"/echo"), nil);
                    [(NSURLSessionTask *)task resume];
                    ((void (*)(id, SEL, id, id))objc_msgSend)(task, @selector(sendMessage:completionHandler:), make_message(port, @"hello"), ^(NSError *e) { L([NSString stringWithFormat:@"send1 %@", described(e)]); });
                    ((void (*)(id, SEL, id, id))objc_msgSend)(task, @selector(sendMessage:completionHandler:), make_message(port, [NSData dataWithBytes:"\x01\x02\x03" length:3]), ^(NSError *e) { L([NSString stringWithFormat:@"send2 %@", described(e)]); });
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"recv1 %@ %@ queue=%d", message_text(m), described(e), [NSOperationQueue currentQueue] == queue]); });
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"recv2 %@ %@", message_text(m), described(e)]); });
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(sendPingWithPongReceiveHandler:), ^(NSError *e) { L([NSString stringWithFormat:@"pong %@", described(e)]); });
                    spin(0.5);
                    L([NSString stringWithFormat:@"response %ld", (long)[(NSHTTPURLResponse *)[(NSURLSessionTask *)task response] statusCode]]);
                    L([NSString stringWithFormat:@"before close: state=%ld closeCode=%ld", (long)[(NSURLSessionTask *)task state], (long)[[task valueForKey:@"closeCode"] integerValue]]);
                    ((void (*)(id, SEL, NSInteger, id))objc_msgSend)(task, @selector(cancelWithCloseCode:reason:), 1000, [@"done" dataUsingEncoding:NSUTF8StringEncoding]);
                    spin(0.5);
                    L([NSString stringWithFormat:@"after close: state=%ld closeCode=%ld reason=%@ error=%@", (long)[(NSURLSessionTask *)task state], (long)[[task valueForKey:@"closeCode"] integerValue], [[NSString alloc] initWithData:[task valueForKey:@"closeReason"] ?: [NSData data] encoding:NSUTF8StringEncoding], described([(NSURLSessionTask *)task error])]);
                    break;
                }
                case 1: {
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url(@"/proto")];
                    [request setValue:@"abc" forHTTPHeaderField:@"X-Custom"];
                    task = make_task(session, port, request, nil);
                    [(NSURLSessionTask *)task resume];
                    spin(0.4);
                    [(NSURLSessionTask *)task cancel];
                    spin(0.3);
                    L([NSString stringWithFormat:@"cancelled: state=%ld error=%@ closeCode=%ld", (long)[(NSURLSessionTask *)task state], described([(NSURLSessionTask *)task error]), (long)[[task valueForKey:@"closeCode"] integerValue]]);
                    id second = make_task(session, port, url(@"/proto"), @[@"chat", @"superchat"]);
                    [(NSURLSessionTask *)second resume];
                    spin(0.4);
                    ((void (*)(id, SEL, NSInteger, id))objc_msgSend)(second, @selector(cancelWithCloseCode:reason:), 1001, nil);
                    spin(0.4);
                    L([NSString stringWithFormat:@"second: state=%ld closeCode=%ld", (long)[(NSURLSessionTask *)second state], (long)[[second valueForKey:@"closeCode"] integerValue]]);
                    break;
                }
                case 2:
                case 3:
                case 4: {
                    task = make_task(session, port, url(which == 2 ? @"/reject" : (which == 3 ? @"/plain" : @"/badaccept")), nil);
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", message_text(m), described(e)]); });
                    ((void (*)(id, SEL, id, id))objc_msgSend)(task, @selector(sendMessage:completionHandler:), make_message(port, @"x"), ^(NSError *e) { L([NSString stringWithFormat:@"send %@", described(e)]); });
                    [(NSURLSessionTask *)task resume];
                    spin(0.6);
                    L([NSString stringWithFormat:@"state=%ld error=%@ status=%ld", (long)[(NSURLSessionTask *)task state], described([(NSURLSessionTask *)task error]), (long)[(NSHTTPURLResponse *)[(NSURLSessionTask *)task response] statusCode]]);
                    break;
                }
                case 5: {
                    task = make_task(session, port, [NSURL URLWithString:@"ws://127.0.0.1:1/x"], nil);
                    [(NSURLSessionTask *)task resume];
                    spin(0.8);
                    L([NSString stringWithFormat:@"state=%ld error=%@ failing=%@", (long)[(NSURLSessionTask *)task state], described([(NSURLSessionTask *)task error]), [[(NSURLSessionTask *)task error] userInfo][NSURLErrorFailingURLStringErrorKey]]);
                    break;
                }
                case 6: {
                    task = make_task(session, port, url(@"/closenow"), nil);
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", message_text(m), described(e)]); });
                    [(NSURLSessionTask *)task resume];
                    spin(0.6);
                    L([NSString stringWithFormat:@"state=%ld closeCode=%ld reason=%@ error=%@", (long)[(NSURLSessionTask *)task state], (long)[[task valueForKey:@"closeCode"] integerValue], [[NSString alloc] initWithData:[task valueForKey:@"closeReason"] ?: [NSData data] encoding:NSUTF8StringEncoding], described([(NSURLSessionTask *)task error])]);
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"late recv %@ %@", message_text(m), described(e)]); });
                    ((void (*)(id, SEL, id, id))objc_msgSend)(task, @selector(sendMessage:completionHandler:), make_message(port, @"x"), ^(NSError *e) { L([NSString stringWithFormat:@"late send %@", described(e)]); });
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(sendPingWithPongReceiveHandler:), ^(NSError *e) { L([NSString stringWithFormat:@"late ping %@", described(e)]); });
                    spin(0.4);
                    break;
                }
                case 7: {
                    task = make_task(session, port, url(@"/frag"), nil);
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", message_text(m), described(e)]); });
                    [(NSURLSessionTask *)task resume];
                    spin(0.5);
                    [(NSURLSessionTask *)task cancel];
                    spin(0.3);
                    break;
                }
                case 8:
                case 9:
                case 10: {
                    task = make_task(session, port, url(which == 8 ? @"/big" : (which == 9 ? @"/big" : @"/badutf8")), nil);
                    if (which == 9)
                        [task setValue:@3000000 forKey:@"maximumMessageSize"];
                    L([NSString stringWithFormat:@"max=%ld", (long)[[task valueForKey:@"maximumMessageSize"] integerValue]]);
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", message_text(m), described(e)]); });
                    [(NSURLSessionTask *)task resume];
                    spin(1.0);
                    L([NSString stringWithFormat:@"state=%ld error=%@ closeCode=%ld", (long)[(NSURLSessionTask *)task state], described([(NSURLSessionTask *)task error]), (long)[[task valueForKey:@"closeCode"] integerValue]]);
                    [(NSURLSessionTask *)task cancel];
                    spin(0.3);
                    break;
                }
                case 11: {
                    task = make_task(session, port, url(@"/ping"), nil);
                    [(NSURLSessionTask *)task resume];
                    spin(0.5);
                    [(NSURLSessionTask *)task cancel];
                    spin(0.3);
                    break;
                }
                case 12: {
                    task = make_task(session, port, url(@"/abort"), nil);
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", message_text(m), described(e)]); });
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(sendPingWithPongReceiveHandler:), ^(NSError *e) { L([NSString stringWithFormat:@"pong %@", described(e)]); });
                    [(NSURLSessionTask *)task resume];
                    spin(0.8);
                    L([NSString stringWithFormat:@"state=%ld error=%@", (long)[(NSURLSessionTask *)task state], described([(NSURLSessionTask *)task error])]);
                    break;
                }
                case 13: {
                    task = make_task(session, port, url(@"/echo"), nil);
                    [(NSURLSessionTask *)task resume];
                    ((void (*)(id, SEL, id, id))objc_msgSend)(task, @selector(sendMessage:completionHandler:), make_message(port, @"__close__"), ^(NSError *e) {});
                    ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", message_text(m), described(e)]); });
                    spin(0.6);
                    L([NSString stringWithFormat:@"state=%ld closeCode=%ld reason=%@ error=%@", (long)[(NSURLSessionTask *)task state], (long)[[task valueForKey:@"closeCode"] integerValue], [[NSString alloc] initWithData:[task valueForKey:@"closeReason"] ?: [NSData data] encoding:NSUTF8StringEncoding], described([(NSURLSessionTask *)task error])]);
                    break;
                }
                case 14: {
                    task = make_task(session, port, url(@"/echo"), nil);
                    [(NSURLSessionTask *)task cancel];
                    spin(0.3);
                    L([NSString stringWithFormat:@"cancelled before resume: state=%ld error=%@", (long)[(NSURLSessionTask *)task state], described([(NSURLSessionTask *)task error])]);
                    id live = make_task(session, port, url(@"/echo"), nil);
                    [(NSURLSessionTask *)live resume];
                    ((void (*)(id, SEL, id))objc_msgSend)(live, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"pending recv %@ %@", message_text(m), described(e)]); });
                    ((void (*)(id, SEL, id))objc_msgSend)(live, @selector(sendPingWithPongReceiveHandler:), ^(NSError *e) { L([NSString stringWithFormat:@"pending ping %@", described(e)]); });
                    spin(0.3);
                    ((void (*)(id, SEL, NSInteger, id))objc_msgSend)(live, @selector(cancelWithCloseCode:reason:), 1001, nil);
                    spin(0.5);
                    ((void (*)(id, SEL, id))objc_msgSend)(live, @selector(receiveMessageWithCompletionHandler:), ^(id m, NSError *e) { L([NSString stringWithFormat:@"recv after %@ %@", message_text(m), described(e)]); });
                    ((void (*)(id, SEL, id, id))objc_msgSend)(live, @selector(sendMessage:completionHandler:), make_message(port, @"z"), ^(NSError *e) { L([NSString stringWithFormat:@"send after %@", described(e)]); });
                    spin(0.3);
                    L([NSString stringWithFormat:@"live state=%ld closeCode=%ld", (long)[(NSURLSessionTask *)live state], (long)[[live valueForKey:@"closeCode"] integerValue]]);
                    id zero = make_task(session, port, url(@"/echo"), nil);
                    [(NSURLSessionTask *)zero resume];
                    spin(0.3);
                    ((void (*)(id, SEL, NSInteger, id))objc_msgSend)(zero, @selector(cancelWithCloseCode:reason:), 0, nil);
                    spin(0.4);
                    L([NSString stringWithFormat:@"code 0: state=%ld error=%@", (long)[(NSURLSessionTask *)zero state], described([(NSURLSessionTask *)zero error])]);
                    break;
                }
                case 15: {
                    task = make_task(session, port, url(@"/cookie"), nil);
                    [(NSURLSessionTask *)task resume];
                    spin(0.5);
                    L([NSString stringWithFormat:@"stored %@", [[configuration.HTTPCookieStorage cookies] valueForKey:@"name"]]);
                    [(NSURLSessionTask *)task cancel];
                    spin(0.2);
                    [configuration.HTTPCookieStorage setCookie:[NSHTTPCookie cookieWithProperties:@{NSHTTPCookieName: @"pre", NSHTTPCookieValue: @"1", NSHTTPCookieDomain: @"127.0.0.1", NSHTTPCookiePath: @"/"}]];
                    wsserver_reset();
                    id again = make_task(session, port, url(@"/echo"), nil);
                    [(NSURLSessionTask *)again resume];
                    spin(0.4);
                    [(NSURLSessionTask *)again cancel];
                    spin(0.2);
                    break;
                }
                case 16: {
                    NSURLSession *other = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration] delegate:watcher delegateQueue:queue];
                    task = make_task(other, port, url(@"/echo"), nil);
                    [(NSURLSessionTask *)task resume];
                    spin(0.3);
                    [other invalidateAndCancel];
                    spin(0.5);
                    L([NSString stringWithFormat:@"state=%ld error=%@", (long)[(NSURLSessionTask *)task state], described([(NSURLSessionTask *)task error])]);
                    NSString *raised = @"nothing";
                    @try {
                        make_task(other, port, url(@"/echo"), nil);
                    } @catch (NSException *exception) {
                        raised = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason];
                    }
                    L([NSString stringWithFormat:@"new task: %@", raised]);
                    break;
                }
                default: {
                    for (NSString *scheme in @[@"http://127.0.0.1:1/x", @"ftp://127.0.0.1:1/x"]) {
                        NSString *raised = @"nothing";
                        @try {
                            make_task(session, port, [NSURL URLWithString:scheme], nil);
                        } @catch (NSException *exception) {
                            raised = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason];
                        }
                        L([NSString stringWithFormat:@"%@: %@", scheme, raised]);
                    }
                    for (int nilKind = 0; nilKind < 2; nilKind++) {
                        NSString *raised = @"nothing";
                        @try {
                            ((id (*)(id, SEL, id))objc_msgSend)(session, NSSelectorFromString(nilKind ? (port ? host_selector(@"webSocketTaskWithRequest:") : @"webSocketTaskWithRequest:") : (port ? host_selector(@"webSocketTaskWithURL:") : @"webSocketTaskWithURL:")), nil);
                        } @catch (NSException *exception) {
                            raised = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason];
                        }
                        L([NSString stringWithFormat:@"nil %d: %@", nilKind, raised]);
                    }
                    Class message = port ? NSClassFromString(@"CharonHostNSURLSessionWebSocketMessage") : [NSURLSessionWebSocketMessage class];
                    id text = [[message alloc] initWithString:@"abc"], data = [[message alloc] initWithData:[NSData dataWithBytes:"ab" length:2]];
                    L([NSString stringWithFormat:@"text type=%ld string=%@ data=%@ desc=%@", (long)[[text valueForKey:@"type"] integerValue], [text valueForKey:@"string"], [text valueForKey:@"data"], text]);
                    L([NSString stringWithFormat:@"data type=%ld string=%@ data=%@", (long)[[data valueForKey:@"type"] integerValue], [data valueForKey:@"string"], [data valueForKey:@"data"]]);
                    NSMutableData *mutable = [NSMutableData dataWithBytes:"ab" length:2];
                    id copy = [[message alloc] initWithData:mutable];
                    [mutable appendBytes:"c" length:1];
                    L([NSString stringWithFormat:@"copied %lu", (unsigned long)[[copy valueForKey:@"data"] length]]);
                    task = make_task(session, port, url(@"/echo"), nil);
                    L([NSString stringWithFormat:@"new: state=%ld max=%ld closeCode=%ld reason=%@ response=%@ error=%@ request=%@", (long)[(NSURLSessionTask *)task state], (long)[[task valueForKey:@"maximumMessageSize"] integerValue], (long)[[task valueForKey:@"closeCode"] integerValue], [task valueForKey:@"closeReason"], [(NSURLSessionTask *)task response], described([(NSURLSessionTask *)task error]), [[[(NSURLSessionTask *)task originalRequest] URL] scheme]]);
                    @try { ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(receiveMessageWithCompletionHandler:), nil); ((void (*)(id, SEL, id))objc_msgSend)(task, @selector(sendPingWithPongReceiveHandler:), nil); L(@"nil handlers accepted"); } @catch (NSException *exception) { L([NSString stringWithFormat:@"nil handlers raise %@", exception.name]); }
                    [(NSURLSessionTask *)task cancel];
                    spin(0.3);
                    break;
                }
                }
                @synchronized (log) {
                    if (which == 6) {
                        NSMutableArray *late = [NSMutableArray array];
                        for (NSString *line in [log copy]) {
                            if ([line hasPrefix:@"late"])
                                [late addObject:line];
                        }
                        [log removeObjectsInArray:late];
                        [log addObjectsFromArray:[late sortedArrayUsingSelector:@selector(compare:)]];
                    }
                    transcripts[pass] = [NSString stringWithFormat:@"%@\n   events: %@\n   server: %@", [log componentsJoinedByString:@"\n   "], [watcher.events componentsJoinedByString:@" ; "], server_lines()];
                }
                [session invalidateAndCancel];
            }
            BOOL same = [transcripts[0] isEqualToString:transcripts[1]];
            if (!same)
                printf("  scenario %d %s\n port:\n   %s\n system:\n   %s\n", which, [names[which] UTF8String], transcripts[0].UTF8String, transcripts[1].UTF8String);
            charon_check(same, [names[which] UTF8String], @"the transcripts differ");
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
