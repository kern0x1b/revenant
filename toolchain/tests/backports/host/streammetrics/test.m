#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <CoreFoundation/CFStream.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <poll.h>
#import <stdint.h>
#import <string.h>
#import <sys/socket.h>
#import <unistd.h>
#import "check.h"

void host_attach_prefixed(const char *prefix);
size_t host_attach_members(Class from, Class to);
BOOL host_alloc_from(Class from, Class to);

@interface RevenantMetricsCollector : NSObject <NSURLSessionDelegate, NSURLSessionStreamDelegate>
@property NSURLSessionTaskMetrics *metrics;
@property int read_closed;
@property int write_closed;
@property int completed;
@property NSError *error;
@end

@implementation RevenantMetricsCollector

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
  didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    self.metrics = metrics;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    self.completed++;
    self.error = error;
}

- (void)URLSession:(NSURLSession *)session readClosedForStreamTask:(NSURLSessionStreamTask *)streamTask
{
    self.read_closed++;
}

- (void)URLSession:(NSURLSession *)session writeClosedForStreamTask:(NSURLSessionStreamTask *)streamTask
{
    self.write_closed++;
}

@end

static int failures;
static int checks;
static int divergences;

static int revenant_listener(void)
{
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    if (listener < 0)
        return -1;
    int reuse = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    socklen_t length = sizeof(address);
    if (bind(listener, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(listener, 1) != 0 ||
        getsockname(listener, (struct sockaddr *)&address, &length) != 0) {
        close(listener);
        return -1;
    }
    return listener;
}

static NSUInteger revenant_port_of(int descriptor)
{
    struct sockaddr_in address;
    socklen_t length = sizeof(address);
    if (getsockname(descriptor, (struct sockaddr *)&address, &length) != 0)
        return 0;
    return ntohs(address.sin_port);
}

static void revenant_names_of(int descriptor, char *text, size_t size)
{
    struct sockaddr_in address;
    socklen_t length = sizeof(address);
    if (descriptor < 0 || getsockname(descriptor, (struct sockaddr *)&address, &length) != 0) {
        snprintf(text, size, "not a descriptor: %s", strerror(errno));
        return;
    }
    char host[INET_ADDRSTRLEN] = {0};
    inet_ntop(AF_INET, &address.sin_addr, host, sizeof(host));
    snprintf(text, size, "%s:%d", host, ntohs(address.sin_port));
}

#define REVENANT_MAX_CONNECTIONS 8
static NSString *revenant_peer_address[REVENANT_MAX_CONNECTIONS];
static NSUInteger revenant_peer_port[REVENANT_MAX_CONNECTIONS];
static const char *revenant_peer_answer[REVENANT_MAX_CONNECTIONS];
static int revenant_connections;
static int revenant_expected_connections;

static int revenant_says_http(int connection)
{
    struct pollfd waiting;
    waiting.fd = connection;
    waiting.events = POLLIN;
    waiting.revents = 0;
    if (poll(&waiting, 1, 500) <= 0)
        return 0;
    char first[8] = {0};
    ssize_t got = recv(connection, first, sizeof(first) - 1, MSG_PEEK);
    return got > 0 && (strncmp(first, "GET ", 4) == 0 || strncmp(first, "HEAD ", 5) == 0 ||
                       strncmp(first, "POST ", 5) == 0);
}

static void revenant_accept_connections(int listener)
{
    for (int index = 0; index < revenant_expected_connections; index++) {
        int connection = accept(listener, NULL, NULL);
        if (connection < 0)
            return;
        struct sockaddr_in peer;
        socklen_t length = sizeof(peer);
        char text[INET_ADDRSTRLEN] = {0};
        if (getpeername(connection, (struct sockaddr *)&peer, &length) == 0)
            inet_ntop(AF_INET, &peer.sin_addr, text, sizeof(text));
        revenant_peer_address[revenant_connections] = @(text);
        revenant_peer_port[revenant_connections] = ntohs(peer.sin_port);
        if (revenant_says_http(connection)) {
            static const char response[] = "HTTP/1.1 200 OK\r\nContent-Length: 1\r\nConnection: close\r\n\r\nk";
            write(connection, response, sizeof(response) - 1);
            revenant_peer_answer[revenant_connections] = "was answered HTTP/1.1 200 and closed";
            close(connection);
        } else {
            const char greeting = 'k';
            write(connection, &greeting, 1);
            revenant_peer_answer[revenant_connections] = "was given one byte and held open";
        }
        revenant_connections++;
    }
}

static void revenant_on_alarm(int number)
{
    (void)number;
    fprintf(stderr, "\nFAIL the test ran past its thirty second bound\n");
    _exit(1);
}

static void revenant_bound_the_run(void)
{
    signal(SIGALRM, revenant_on_alarm);
    alarm(30);
}

static id first_transaction(id metrics)
{
    if (![metrics respondsToSelector:NSSelectorFromString(@"transactionMetrics")])
        return nil;
    NSArray *transactions = ((id (*)(id, SEL))objc_msgSend)(metrics, NSSelectorFromString(@"transactionMetrics"));
    return transactions.count ? transactions[0] : nil;
}

static id property_value(id object, const char *name)
{
    SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%s", name]);
    if (![object respondsToSelector:selector])
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSString *shown(id value)
{
    if (!value)
        return @"(nil)";
    return [value description] ?: @"(nil)";
}

static NSString *property(id object, const char *name)
{
    if (![object respondsToSelector:NSSelectorFromString([NSString stringWithFormat:@"%s", name])])
        return @"(no such property)";
    return shown(property_value(object, name));
}

static void compare(const char *label, id system, id ours)
{
    checks++;
    NSString *left = [system description] ?: @"(nil)";
    NSString *right = [ours description] ?: @"(nil)";
    if ([left isEqualToString:right]) {
        printf("ok   %s: %s\n", label, [left UTF8String]);
    } else {
        failures++;
        printf("FAIL %s: the system answers %s, the backport answers %s\n", label, [left UTF8String], [right UTF8String]);
    }
}

static void compare_port(const char *label, id system_value, NSUInteger system_expected,
                         id our_value, NSUInteger our_expected, const char *which)
{
    checks++;
    NSUInteger system_port = [system_value respondsToSelector:@selector(unsignedIntegerValue)]
                             ? [system_value unsignedIntegerValue] : 0;
    NSUInteger our_port = [our_value respondsToSelector:@selector(unsignedIntegerValue)]
                          ? [our_value unsignedIntegerValue] : 0;
    BOOL system_agrees = system_port != 0 && system_port == system_expected;
    BOOL our_agrees = our_port != 0 && our_port == our_expected;
    if (system_agrees && our_agrees) {
        printf("ok   %s: the system answers %lu, the backport answers %lu\n", label,
               (unsigned long)system_port, (unsigned long)our_port);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, %s is %lu; the backport answers %s, %s is %lu\n",
           label, shown(system_value).UTF8String, which, (unsigned long)system_expected,
           shown(our_value).UTF8String, which, (unsigned long)our_expected);
}

int main(void)
{
    @autoreleasepool {
        revenant_bound_the_run();

        int listener = revenant_listener();
        revenant_check(listener >= 0, "the test opens its own listener", @"no socket");
        if (listener < 0)
            return 1;
        NSUInteger port = revenant_port_of(listener);
        printf("note the listener is on the loopback at port %lu\n", (unsigned long)port);

        Class ourTaskClass = NSClassFromString(@"RevenantHostNSURLSessionStreamTask");
        revenant_check(ourTaskClass != Nil, "the port defines a stream task", @"no such class");

        revenant_expected_connections = 3;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            revenant_accept_connections(listener);
        });

        RevenantMetricsCollector *systemDelegate = [[RevenantMetricsCollector alloc] init];
        NSURLSession *systemSession = [NSURLSession sessionWithConfiguration:
            [NSURLSessionConfiguration ephemeralSessionConfiguration]
                                                                     delegate:systemDelegate
                                                                delegateQueue:nil];
        NSURLSessionTask *systemTask = [systemSession streamTaskWithHostName:@"127.0.0.1" port:(NSInteger)port];
        revenant_check(systemTask != nil, "the host makes a stream task", @"nil");
        revenant_check(systemTask && ourTaskClass && ![systemTask isKindOfClass:ourTaskClass],
                     "the host's own stream task is not the port's", @"the port's factory answered it");
        [systemTask resume];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        ((void (*)(id, SEL))objc_msgSend)(systemTask, @selector(closeRead));
        ((void (*)(id, SEL))objc_msgSend)(systemTask, @selector(closeWrite));
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
        printf("note the host's own stream task: state=%ld read closed=%d write closed=%d completed=%d "
               "error=%s transaction=%s\n",
               (long)systemTask.state, systemDelegate.read_closed, systemDelegate.write_closed,
               systemDelegate.completed, systemDelegate.error ? "yes" : "(none)",
               systemDelegate.metrics ? "yes" : "none - the system delivers none for a stream task");

        RevenantMetricsCollector *oracleDelegate = [[RevenantMetricsCollector alloc] init];
        NSURLSession *oracleSession = [NSURLSession sessionWithConfiguration:
            [NSURLSessionConfiguration ephemeralSessionConfiguration]
                                                                    delegate:oracleDelegate
                                                               delegateQueue:nil];
        NSString *url = [NSString stringWithFormat:@"http://127.0.0.1:%lu/", (unsigned long)port];
        NSURLSessionDataTask *oracleTask = [oracleSession dataTaskWithURL:[NSURL URLWithString:url]];
        [oracleTask resume];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
        id systemTransaction = first_transaction(oracleDelegate.metrics);
        revenant_check(systemTransaction != nil,
                     "the system hands its delegate a transaction over this listener",
                     systemDelegate.metrics ? @"that was the stream task's" : @"no metrics arrived at all");

        NSURLSession *probeSession = [NSURLSession sessionWithConfiguration:
            [NSURLSessionConfiguration ephemeralSessionConfiguration]];
        NSURLSessionTask *probeTask = [probeSession streamTaskWithHostName:@"127.0.0.1" port:9];
        Class released = probeTask ? (Class)[probeTask class] : Nil;
        revenant_check(released != Nil && ![released isSubclassOfClass:ourTaskClass] && released != ourTaskClass,
                     "the class of the host's own stream task is not the port's",
                     [NSString stringWithFormat:@"both are %s", class_getName(released)]);
        size_t moved = host_attach_members(ourTaskClass, released);
        revenant_check(moved > 0, "the port's members go on the host's own stream task class",
                     [NSString stringWithFormat:@"%lu of them", (unsigned long)moved]);
        Method ownAlloc = class_getClassMethod(ourTaskClass, sel_registerName("alloc"));
        printf("note the port's own +alloc is typed %s on this host\n",
               ownAlloc ? method_getTypeEncoding(ownAlloc) : "(the port's class has no +alloc to read)");
        revenant_check(host_alloc_from(ourTaskClass, released),
                     "the port's factory hands out one of the host's own",
                     @"+alloc is the port's own");
        host_attach_prefixed("");
        revenant_check([NSURLSession instancesRespondToSelector:NSSelectorFromString(@"revenantHost_streamTaskWithHostName:port:")],
                     "the port's factory is attached to the session", @"the category is not attached");

        SEL ourFactory = NSSelectorFromString(@"revenantHost_streamTaskWithHostName:port:");
        if (!ourTaskClass)
            return 1;

        RevenantMetricsCollector *ourDelegate = [[RevenantMetricsCollector alloc] init];
        NSURLSession *ourSession = [NSURLSession sessionWithConfiguration:
            [NSURLSessionConfiguration ephemeralSessionConfiguration]
                                                                     delegate:ourDelegate
                                                                delegateQueue:nil];
        revenant_check(ourSession != nil, "a session with the collecting delegate", @"nil");
        NSURLSessionTask *ourTask = ((id (*)(id, SEL, id, NSInteger))objc_msgSend)(ourSession,
            ourFactory, @"127.0.0.1", (NSInteger)port);
        revenant_check(ourTask != nil, "and a stream task to the same port", @"nil");
        ((void (*)(id, SEL))objc_msgSend)(ourTask, @selector(resume));
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        ((void (*)(id, SEL))objc_msgSend)(ourTask, @selector(closeRead));
        ((void (*)(id, SEL))objc_msgSend)(ourTask, @selector(closeWrite));
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];

        id ourTransaction = first_transaction(ourDelegate.metrics);
        if (!ourTransaction) {
            failures++;
            printf("FAIL the port handed no transaction to its delegate\n");
        }

        for (int waited = 0; waited < 3 && revenant_connections < revenant_expected_connections; waited++)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        revenant_check(revenant_connections == revenant_expected_connections,
                     "the listener took one connection for each of the three tasks",
                     [NSString stringWithFormat:@"%d of %d", revenant_connections, revenant_expected_connections]);
        for (int index = 0; index < revenant_connections; index++)
            printf("note connection %d from %s:%lu - the listener %s\n", index,
                   [revenant_peer_address[index] UTF8String], (unsigned long)revenant_peer_port[index],
                   revenant_peer_answer[index]);

        {
            NSInputStream *input = nil;
            NSOutputStream *output = nil;
            [NSStream getStreamsToHostWithName:@"127.0.0.1" port:(NSInteger)port inputStream:&input outputStream:&output];
            if (input && output) {
                [input scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
                [output scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
                [input open];
                [output open];
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
                CFTypeRef handle = CFReadStreamCopyProperty((__bridge CFReadStreamRef)input,
                                                            kCFStreamPropertySocketNativeHandle);
                if (handle && CFGetTypeID(handle) == CFDataGetTypeID()) {
                    int cast = (int)(intptr_t)handle;
                    int read = -1;
                    char cast_names[96], read_names[96];
                    if (CFDataGetLength((CFDataRef)handle) >= (CFIndex)sizeof(read))
                        memcpy(&read, CFDataGetBytePtr((CFDataRef)handle), sizeof(read));
                    revenant_names_of(cast, cast_names, sizeof(cast_names));
                    revenant_names_of(read, read_names, sizeof(read_names));
                    printf("note this host's own CFStream pair: kCFStreamPropertySocketNativeHandle is a "
                           "CFData of %lu bytes; the value cast to an int is %d (%s) and the bytes in it are "
                           "%d (%s)\n", (unsigned long)CFDataGetLength((CFDataRef)handle), cast,
                           cast_names, read, read_names);
                } else {
                    printf("note this host's own CFStream pair: kCFStreamPropertySocketNativeHandle is %s\n",
                           handle ? "not a CFData" : "(nothing at all)");
                }
                if (handle)
                    CFRelease(handle);
            }
        }

        for (NSString *name in @[@"localAddress", @"remoteAddress", @"negotiatedTLSProtocolVersion",
                                 @"negotiatedTLSCipherSuite"]) {
            compare([name UTF8String], property(systemTransaction, [name UTF8String]),
                    property(ourTransaction, [name UTF8String]));
        }
        compare_port("remotePort", property_value(systemTransaction, "remotePort"), port,
                     property_value(ourTransaction, "remotePort"), port, "this listener's own port");
        compare_port("localPort", property_value(systemTransaction, "localPort"),
                     revenant_connections > 1 ? revenant_peer_port[1] : 0,
                     property_value(ourTransaction, "localPort"),
                     revenant_connections > 2 ? revenant_peer_port[2] : 0,
                     "the local port the listener read for that side's own connection");

        printf("checks=%d failures=%d divergences=%d\n", checks, failures, divergences);
    }
    return failures ? 1 : 0;
}
