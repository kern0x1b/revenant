#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <pthread.h>
#include <sys/socket.h>
#include <unistd.h>

static NSMutableArray *wsserver_log;
static NSLock *wsserver_lock;

static void wsserver_note(NSString *line)
{
    [wsserver_lock lock];
    [wsserver_log addObject:line];
    [wsserver_lock unlock];
}

static NSArray *wsserver_lines(void)
{
    [wsserver_lock lock];
    NSArray *lines = [wsserver_log copy];
    [wsserver_lock unlock];
    return lines;
}

static void wsserver_reset(void)
{
    [wsserver_lock lock];
    [wsserver_log removeAllObjects];
    [wsserver_lock unlock];
}

static BOOL wsserver_read_exact(int fd, void *buffer, size_t length)
{
    unsigned char *bytes = buffer;
    while (length) {
        ssize_t got = read(fd, bytes, length);
        if (got <= 0)
            return NO;
        bytes += got;
        length -= (size_t)got;
    }
    return YES;
}

static void wsserver_write(int fd, const void *buffer, size_t length)
{
    const unsigned char *bytes = buffer;
    while (length) {
        ssize_t put = write(fd, bytes, length);
        if (put <= 0)
            return;
        bytes += put;
        length -= (size_t)put;
    }
}

static void wsserver_frame(int fd, int opcode, BOOL fin, NSData *payload)
{
    NSMutableData *frame = [NSMutableData data];
    unsigned char first = (unsigned char)((fin ? 0x80 : 0) | opcode);
    [frame appendBytes:&first length:1];
    NSUInteger length = payload.length;
    if (length < 126) {
        unsigned char small = (unsigned char)length;
        [frame appendBytes:&small length:1];
    } else if (length < 65536) {
        unsigned char medium[3] = {126, (unsigned char)(length >> 8), (unsigned char)length};
        [frame appendBytes:medium length:3];
    } else {
        unsigned char large[9] = {127, 0, 0, 0, 0, (unsigned char)(length >> 24), (unsigned char)(length >> 16), (unsigned char)(length >> 8), (unsigned char)length};
        [frame appendBytes:large length:9];
    }
    [frame appendData:payload];
    wsserver_write(fd, frame.bytes, frame.length);
}

static NSData *wsserver_close_payload(int code, NSString *reason)
{
    NSMutableData *data = [NSMutableData data];
    unsigned char bytes[2] = {(unsigned char)(code >> 8), (unsigned char)code};
    [data appendBytes:bytes length:2];
    [data appendData:[reason dataUsingEncoding:NSUTF8StringEncoding]];
    return data;
}

static void wsserver_serve(int fd)
{
    NSMutableData *request = [NSMutableData data];
    unsigned char byte;
    while (![[[NSString alloc] initWithData:request encoding:NSISOLatin1StringEncoding] hasSuffix:@"\r\n\r\n"]) {
        if (!wsserver_read_exact(fd, &byte, 1)) {
            close(fd);
            return;
        }
        [request appendBytes:&byte length:1];
    }
    NSString *text = [[NSString alloc] initWithData:request encoding:NSISOLatin1StringEncoding];
    NSArray *lines = [text componentsSeparatedByString:@"\r\n"];
    NSString *path = [[lines[0] componentsSeparatedByString:@" "] objectAtIndex:1];
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    NSMutableArray *names = [NSMutableArray array];
    for (NSString *line in [lines subarrayWithRange:NSMakeRange(1, lines.count - 1)]) {
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound)
            continue;
        NSString *name = [line substringToIndex:colon.location];
        headers[name.lowercaseString] = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        [names addObject:name.lowercaseString];
    }
    wsserver_note([NSString stringWithFormat:@"request %@", lines[0]]);
    wsserver_note([NSString stringWithFormat:@"header-names %@", [[names sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]]);
    for (NSString *name in @[@"upgrade", @"connection", @"sec-websocket-version", @"sec-websocket-protocol", @"x-custom", @"cookie", @"host", @"origin"]) {
        if (headers[name])
            wsserver_note([NSString stringWithFormat:@"header %@: %@", name, [name isEqualToString:@"cookie"] ? [[[headers[name] componentsSeparatedByString:@"; "] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@"; "] : headers[name]]);
    }
    if ([path hasPrefix:@"/reject"]) {
        NSString *response = @"HTTP/1.1 403 Forbidden\r\nContent-Length: 4\r\nConnection: close\r\n\r\nnope";
        wsserver_write(fd, response.UTF8String, response.length);
        close(fd);
        return;
    }
    if ([path hasPrefix:@"/plain"]) {
        NSString *response = @"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok";
        wsserver_write(fd, response.UTF8String, response.length);
        close(fd);
        return;
    }
    NSString *key = headers[@"sec-websocket-key"];
    NSData *material = [[key stringByAppendingString:@"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"] dataUsingEncoding:NSASCIIStringEncoding];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(material.bytes, (CC_LONG)material.length, digest);
    NSString *accept = [[NSData dataWithBytes:digest length:sizeof(digest)] base64EncodedStringWithOptions:0];
    if ([path hasPrefix:@"/badaccept"])
        accept = @"AAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    NSMutableString *response = [NSMutableString stringWithFormat:@"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %@\r\n", accept];
    if ([path hasPrefix:@"/proto"] && headers[@"sec-websocket-protocol"])
        [response appendString:@"Sec-WebSocket-Protocol: chat\r\n"];
    if ([path hasPrefix:@"/cookie"])
        [response appendString:@"Set-Cookie: wsid=42; Path=/\r\n"];
    [response appendString:@"\r\n"];
    wsserver_write(fd, response.UTF8String, response.length);
    if ([path hasPrefix:@"/closenow"]) {
        wsserver_frame(fd, 8, YES, wsserver_close_payload(4000, @"bye"));
    } else if ([path hasPrefix:@"/frag"]) {
        wsserver_frame(fd, 1, NO, [@"Hel" dataUsingEncoding:NSUTF8StringEncoding]);
        wsserver_frame(fd, 9, YES, [@"mid" dataUsingEncoding:NSUTF8StringEncoding]);
        wsserver_frame(fd, 0, NO, [@"lo, " dataUsingEncoding:NSUTF8StringEncoding]);
        wsserver_frame(fd, 0, YES, [@"world" dataUsingEncoding:NSUTF8StringEncoding]);
    } else if ([path hasPrefix:@"/big"]) {
        NSMutableData *big = [NSMutableData dataWithLength:2000000];
        memset(big.mutableBytes, 'x', big.length);
        wsserver_frame(fd, 2, YES, big);
    } else if ([path hasPrefix:@"/badutf8"]) {
        unsigned char bad[2] = {0xC3, 0x28};
        wsserver_frame(fd, 1, YES, [NSData dataWithBytes:bad length:2]);
    } else if ([path hasPrefix:@"/ping"]) {
        wsserver_frame(fd, 9, YES, [@"srv" dataUsingEncoding:NSUTF8StringEncoding]);
    } else if ([path hasPrefix:@"/abort"]) {
        usleep(100000);
        close(fd);
        return;
    } else if ([path hasPrefix:@"/mediumtext"]) {
        NSMutableData *text = [NSMutableData dataWithLength:70000];
        memset(text.mutableBytes, 'y', text.length);
        wsserver_frame(fd, 1, YES, text);
    }
    NSMutableData *assembling = nil;
    int assemblingOpcode = 0;
    for (;;) {
        unsigned char head[2];
        if (!wsserver_read_exact(fd, head, 2))
            break;
        BOOL fin = (head[0] & 0x80) != 0;
        int opcode = head[0] & 0x0F;
        BOOL masked = (head[1] & 0x80) != 0;
        uint64_t length = head[1] & 0x7F;
        if (length == 126) {
            unsigned char extra[2];
            if (!wsserver_read_exact(fd, extra, 2))
                break;
            length = ((uint64_t)extra[0] << 8) | extra[1];
        } else if (length == 127) {
            unsigned char extra[8];
            if (!wsserver_read_exact(fd, extra, 8))
                break;
            length = 0;
            for (int i = 0; i < 8; i++)
                length = (length << 8) | extra[i];
        }
        unsigned char mask[4] = {0, 0, 0, 0};
        if (masked && !wsserver_read_exact(fd, mask, 4))
            break;
        NSMutableData *payload = [NSMutableData dataWithLength:(NSUInteger)length];
        if (length && !wsserver_read_exact(fd, payload.mutableBytes, (size_t)length))
            break;
        unsigned char *raw = payload.mutableBytes;
        for (uint64_t i = 0; i < length; i++)
            raw[i] ^= mask[i % 4];
        wsserver_note([NSString stringWithFormat:@"frame op=%d fin=%d masked=%d len=%llu", opcode, fin, masked, length]);
        if (opcode == 8) {
            NSString *reason = payload.length > 2 ? [[NSString alloc] initWithData:[payload subdataWithRange:NSMakeRange(2, payload.length - 2)] encoding:NSUTF8StringEncoding] : @"";
            wsserver_note([NSString stringWithFormat:@"close code=%d reason=%@", payload.length >= 2 ? (raw[0] << 8) | raw[1] : -1, reason]);
            if (![path hasPrefix:@"/closenow"])
                wsserver_frame(fd, 8, YES, payload.length >= 2 ? [payload subdataWithRange:NSMakeRange(0, 2)] : [NSData data]);
            break;
        } else if (opcode == 9) {
            wsserver_frame(fd, 10, YES, payload);
        } else if (opcode == 10) {
            wsserver_note([NSString stringWithFormat:@"pong %@", [[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding]]);
        } else if (opcode == 1 || opcode == 2 || opcode == 0) {
            if (opcode != 0) {
                assembling = [NSMutableData data];
                assemblingOpcode = opcode;
            }
            [assembling appendData:payload];
            if (fin) {
                NSString *string = [[NSString alloc] initWithData:assembling encoding:NSUTF8StringEncoding];
                if (assemblingOpcode == 1 && [string isEqualToString:@"__close__"]) {
                    wsserver_frame(fd, 8, YES, wsserver_close_payload(1001, @"server closing"));
                } else if (assemblingOpcode == 1 && [string isEqualToString:@"__abort__"]) {
                    close(fd);
                    return;
                } else {
                    wsserver_frame(fd, assemblingOpcode, YES, assembling);
                }
                assembling = nil;
            }
        }
    }
    close(fd);
}

static void *wsserver_accept(void *context)
{
    int listener = (int)(intptr_t)context;
    for (;;) {
        int fd = accept(listener, NULL, NULL);
        if (fd < 0)
            return NULL;
        int one = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            wsserver_serve(fd);
        });
    }
}

static int wsserver_start(void)
{
    wsserver_log = [NSMutableArray array];
    wsserver_lock = [[NSLock alloc] init];
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    int one = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    bind(listener, (struct sockaddr *)&address, sizeof(address));
    listen(listener, 16);
    socklen_t size = sizeof(address);
    getsockname(listener, (struct sockaddr *)&address, &size);
    pthread_t thread;
    pthread_create(&thread, NULL, wsserver_accept, (void *)(intptr_t)listener);
    return ntohs(address.sin_port);
}
