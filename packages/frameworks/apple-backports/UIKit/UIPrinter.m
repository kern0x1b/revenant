#import <UIKit/UIKit.h>
#import <errno.h>
#import <fcntl.h>
#import <netdb.h>
#import <poll.h>
#import <stdlib.h>
#import <sys/socket.h>
#import <unistd.h>

static const NSTimeInterval kRevenantContactTimeout = 30;

static const uint16_t kRevenantIPPGetPrinterAttributes = 0x000B;
static const uint8_t kRevenantIPPOperationGroup = 0x01;
static const uint8_t kRevenantIPPEndOfAttributes = 0x03;
static const uint8_t kRevenantIPPCharset = 0x47;
static const uint8_t kRevenantIPPNaturalLanguage = 0x48;
static const uint8_t kRevenantIPPURI = 0x45;
static const unsigned kRevenantIPPSuccessfulStatusLimit = 0x0100;

static void revenant_appendUInt16(NSMutableData *data, uint16_t value)
{
    uint8_t bytes[2] = { value >> 8, value & 0xFF };
    [data appendBytes:bytes length:2];
}

static void revenant_appendAttribute(NSMutableData *data, uint8_t tag, NSString *name, NSString *value)
{
    NSData *nameBytes = [name dataUsingEncoding:NSUTF8StringEncoding];
    NSData *valueBytes = [value dataUsingEncoding:NSUTF8StringEncoding];
    [data appendBytes:&tag length:1];
    revenant_appendUInt16(data, (uint16_t)[nameBytes length]);
    [data appendData:nameBytes];
    revenant_appendUInt16(data, (uint16_t)[valueBytes length]);
    [data appendData:valueBytes];
}

static NSData *revenant_ippRequest(NSString *printerURI)
{
    NSMutableData *data = [NSMutableData data];
    revenant_appendUInt16(data, 0x0101);
    revenant_appendUInt16(data, kRevenantIPPGetPrinterAttributes);
    uint8_t requestID[4] = { 0, 0, 0, 1 };
    [data appendBytes:requestID length:4];
    [data appendBytes:&kRevenantIPPOperationGroup length:1];
    revenant_appendAttribute(data, kRevenantIPPCharset, @"attributes-charset", @"utf-8");
    revenant_appendAttribute(data, kRevenantIPPNaturalLanguage, @"attributes-natural-language", @"en");
    revenant_appendAttribute(data, kRevenantIPPURI, @"printer-uri", printerURI);
    [data appendBytes:&kRevenantIPPEndOfAttributes length:1];
    return data;
}

static NSData *revenant_httpRequest(NSURL *url, NSString *host, NSString *port)
{
    NSString *target = [[url path] length] ? [url path] : @"/";
    if ([url query])
        target = [target stringByAppendingFormat:@"?%@", [url query]];
    NSString *authority = [host rangeOfString:@":"].location != NSNotFound ? [NSString stringWithFormat:@"[%@]", host] : host;
    NSData *body = revenant_ippRequest([url absoluteString]);
    NSString *head = [NSString stringWithFormat:@"POST %@ HTTP/1.1\r\nHost: %@:%@\r\nContent-Type: application/ipp\r\n"
                      "Content-Length: %lu\r\nConnection: close\r\n\r\n", target, authority, port, (unsigned long)[body length]];
    NSMutableData *request = [[head dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [request appendData:body];
    return request;
}

static NSData *revenant_ippResponseBody(NSData *response)
{
    NSData *separator = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSRange end = [response rangeOfData:separator options:0 range:NSMakeRange(0, [response length])];
    if (end.location == NSNotFound)
        return nil;
    NSString *head = [[NSString alloc] initWithData:[response subdataWithRange:NSMakeRange(0, end.location)]
                                           encoding:NSUTF8StringEncoding];
    NSArray *statusLine = [[[head componentsSeparatedByString:@"\r\n"] firstObject] componentsSeparatedByString:@" "];
    if ([statusLine count] < 2 || ![[statusLine objectAtIndex:0] hasPrefix:@"HTTP/1."]
        || ![[statusLine objectAtIndex:1] isEqualToString:@"200"])
        return nil;

    NSUInteger bodyStart = NSMaxRange(end);
    NSData *raw = [response subdataWithRange:NSMakeRange(bodyStart, [response length] - bodyStart)];
    if ([[head lowercaseString] rangeOfString:@"transfer-encoding: chunked"].location == NSNotFound)
        return raw;

    NSData *crlf = [@"\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *body = [NSMutableData data];
    NSUInteger at = 0;
    for (;;) {
        NSRange line = [raw rangeOfData:crlf options:0 range:NSMakeRange(at, [raw length] - at)];
        if (line.location == NSNotFound)
            return nil;
        NSString *size = [[NSString alloc] initWithData:[raw subdataWithRange:NSMakeRange(at, line.location - at)]
                                               encoding:NSUTF8StringEncoding];
        char *stop = NULL;
        unsigned long length = strtoul([size UTF8String], &stop, 16);
        if (stop == [size UTF8String] || (*stop != '\0' && *stop != ';'))
            return nil;
        at = NSMaxRange(line);
        if (length == 0)
            return body;
        if ([raw length] < at + length + [crlf length])
            return nil;
        [body appendBytes:(const uint8_t *)[raw bytes] + at length:length];
        at += length + [crlf length];
    }
}

static BOOL revenant_waitReady(int fd, short events, NSDate *deadline)
{
    NSTimeInterval left = [deadline timeIntervalSinceNow];
    if (left <= 0)
        return NO;
    struct pollfd wait = { fd, events, 0 };
    return poll(&wait, 1, (int)(left * 1000)) == 1;
}

static int revenant_connect(NSString *host, NSString *port, NSDate *deadline)
{
    struct addrinfo hints = { 0 }, *addresses = NULL;
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    if (getaddrinfo([host UTF8String], [port UTF8String], &hints, &addresses) != 0)
        return -1;

    int connected = -1;
    for (struct addrinfo *address = addresses; address && connected < 0; address = address->ai_next) {
        int fd = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (fd < 0)
            continue;
        int one = 1;
        if (setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof one) < 0 ||
            fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK) < 0) {
            close(fd);
            continue;
        }
        BOOL ok = connect(fd, address->ai_addr, address->ai_addrlen) == 0;
        if (!ok && errno == EINPROGRESS && revenant_waitReady(fd, POLLOUT, deadline)) {
            int error = -1;
            socklen_t length = sizeof error;
            ok = getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0 && error == 0;
        }
        if (ok)
            connected = fd;
        else
            close(fd);
    }
    freeaddrinfo(addresses);
    return connected;
}

static NSData *revenant_exchange(int fd, NSData *request, NSDate *deadline)
{
    const uint8_t *bytes = [request bytes];
    NSUInteger sent = 0;
    while (sent < [request length]) {
        if (!revenant_waitReady(fd, POLLOUT, deadline))
            return nil;
        ssize_t n = write(fd, bytes + sent, [request length] - sent);
        if (n < 0 && (errno == EAGAIN || errno == EINTR))
            continue;
        if (n <= 0)
            return nil;
        sent += n;
    }

    NSMutableData *response = [NSMutableData data];
    uint8_t buffer[4096];
    for (;;) {
        if (!revenant_waitReady(fd, POLLIN, deadline))
            return nil;
        ssize_t n = read(fd, buffer, sizeof buffer);
        if (n < 0 && (errno == EAGAIN || errno == EINTR))
            continue;
        if (n < 0)
            return nil;
        if (n == 0)
            return response;
        [response appendBytes:buffer length:n];
    }
}

struct revenant_tlsExchange {
    const uint8_t *bytes;
    CFIndex length;
    CFIndex sent;
    NSMutableData *response;
    BOOL finished;
    BOOL failed;
};

static void revenant_readEvent(CFReadStreamRef stream, CFStreamEventType event, void *info)
{
    struct revenant_tlsExchange *exchange = info;
    uint8_t buffer[4096];
    if (event == kCFStreamEventHasBytesAvailable) {
        CFIndex n = CFReadStreamRead(stream, buffer, sizeof buffer);
        if (n > 0)
            [exchange->response appendBytes:buffer length:n];
        else if (n < 0)
            exchange->failed = exchange->finished = YES;
    } else if (event == kCFStreamEventEndEncountered) {
        exchange->finished = YES;
    } else if (event == kCFStreamEventErrorOccurred) {
        exchange->failed = exchange->finished = YES;
    }
}

static void revenant_writeEvent(CFWriteStreamRef stream, CFStreamEventType event, void *info)
{
    struct revenant_tlsExchange *exchange = info;
    if (event == kCFStreamEventCanAcceptBytes && exchange->sent < exchange->length) {
        CFIndex n = CFWriteStreamWrite(stream, exchange->bytes + exchange->sent, exchange->length - exchange->sent);
        if (n < 0)
            exchange->failed = exchange->finished = YES;
        else
            exchange->sent += n;
    } else if (event == kCFStreamEventErrorOccurred) {
        exchange->failed = exchange->finished = YES;
    }
}

static NSData *revenant_tlsExchange(int fd, NSString *host, NSData *request, NSDate *deadline)
{
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, fd, &readStream, &writeStream);
    NSDictionary *ssl = [NSDictionary dictionaryWithObject:host forKey:(__bridge NSString *)kCFStreamSSLPeerName];
    BOOL configured = CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanFalse)
        && CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanFalse)
        && CFReadStreamSetProperty(readStream, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelTLSv1)
        && CFWriteStreamSetProperty(writeStream, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelTLSv1)
        && CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, (__bridge CFDictionaryRef)ssl)
        && CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, (__bridge CFDictionaryRef)ssl);
    if (!configured) {
        CFRelease(readStream);
        CFRelease(writeStream);
        return nil;
    }

    struct revenant_tlsExchange exchange = { [request bytes], [request length], 0, [NSMutableData data], NO, NO };
    CFStreamClientContext context = { 0, &exchange, NULL, NULL, NULL };
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered |
                          kCFStreamEventErrorOccurred, revenant_readEvent, &context);
    CFWriteStreamSetClient(writeStream, kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred, revenant_writeEvent,
                           &context);
    CFRunLoopRef loop = CFRunLoopGetCurrent();
    CFReadStreamScheduleWithRunLoop(readStream, loop, kCFRunLoopDefaultMode);
    CFWriteStreamScheduleWithRunLoop(writeStream, loop, kCFRunLoopDefaultMode);
    CFReadStreamOpen(readStream);
    CFWriteStreamOpen(writeStream);
    while (!exchange.finished && [deadline timeIntervalSinceNow] > 0)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, [deadline timeIntervalSinceNow], YES);

    CFReadStreamSetClient(readStream, 0, NULL, NULL);
    CFWriteStreamSetClient(writeStream, 0, NULL, NULL);
    CFReadStreamUnscheduleFromRunLoop(readStream, loop, kCFRunLoopDefaultMode);
    CFWriteStreamUnscheduleFromRunLoop(writeStream, loop, kCFRunLoopDefaultMode);
    CFReadStreamClose(readStream);
    CFWriteStreamClose(writeStream);
    CFRelease(readStream);
    CFRelease(writeStream);
    return exchange.finished && !exchange.failed ? exchange.response : nil;
}

static BOOL revenant_printerAnswers(NSURL *url)
{
    NSString *scheme = [[url scheme] lowercaseString];
    NSString *host = [url host];
    if (![host length])
        return NO;
    BOOL tls = [scheme isEqualToString:@"ipps"] || [scheme isEqualToString:@"https"];
    if (![scheme isEqualToString:@"ipp"] && ![scheme isEqualToString:@"http"] && !tls)
        return NO;

    NSString *port;
    if ([url port])
        port = [[url port] stringValue];
    else if ([scheme isEqualToString:@"ipp"] || [scheme isEqualToString:@"ipps"])
        port = @"631";
    else if ([scheme isEqualToString:@"https"])
        port = @"443";
    else
        port = @"80";

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:kRevenantContactTimeout];
    int fd = revenant_connect(host, port, deadline);
    if (fd < 0)
        return NO;
    NSData *request = revenant_httpRequest(url, host, port);
    NSData *response = tls ? revenant_tlsExchange(fd, host, request, deadline) : revenant_exchange(fd, request, deadline);
    close(fd);
    NSData *body = response ? revenant_ippResponseBody(response) : nil;
    if ([body length] < 4)
        return NO;
    const uint8_t *status = [body bytes];
    unsigned code = (status[2] << 8) | status[3];
    return code < kRevenantIPPSuccessfulStatusLimit;
}

@implementation UIPrinter {
    NSURL *_URL;
}

+ (UIPrinter *)printerWithURL:(NSURL *)url
{
    UIPrinter *printer = [[UIPrinter alloc] init];
    printer->_URL = [url copy];
    return printer;
}

- (NSURL *)URL
{
    return _URL;
}

- (NSString *)displayName
{
    return @"";
}

- (NSString *)displayLocation
{
    return nil;
}

- (NSString *)makeAndModel
{
    return nil;
}

- (UIPrinterJobTypes)supportedJobTypes
{
    return UIPrinterJobTypeUnknown;
}

- (BOOL)supportsColor
{
    return NO;
}

- (BOOL)supportsDuplex
{
    return NO;
}

- (void)contactPrinter:(void (^)(BOOL available))completionHandler
{
    if (!completionHandler)
        return;
    NSURL *url = _URL;
    void (^handler)(BOOL) = [completionHandler copy];
    if (!url) {
        handler(NO);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL available = revenant_printerAnswers(url);
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(available);
        });
    });
}

@end
