#import "ModernTLSURLProtocol.h"

#import <openssl/ssl.h>
#import <openssl/err.h>
#import <openssl/evp.h>
#import <ctype.h>
#import <dirent.h>
#import <errno.h>
#import <fcntl.h>
#import <limits.h>
#import <netdb.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <poll.h>
#import <pthread.h>
#import <sys/socket.h>
#import <sys/stat.h>
#import <sys/time.h>
#import <time.h>
#import <unistd.h>
#import <zlib.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

static NSString *const kHandledKey = @"ModernTLSHandled";

static const NSTimeInterval kIdleTimeout = 20.0;

static const NSUInteger kIdlePerHost = 6;

static const int kConnectTimeout = 10;
static const int kTransferTimeout = 30;
static const NSTimeInterval kExchangeTimeout = 60.0;

static const unsigned long long kDrainLimit = 262144;

static const unsigned long long kImageTranscodeSizeLimit = 6 * 1024 * 1024;

static NSString *gCertificateAuthorities;
static SSL_CTX *gContext;
static int gHostSlot = -1;
static BOOL gLog;

static pthread_mutex_t gPoolMutex = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary *gIdleConnections;   /* "host:port" -> connections, oldest first */
static NSMutableDictionary *gSessions;

static NSString *headerValue(NSDictionary *headers, NSString *name)
{
    for (NSString *field in headers) {
        if ([field caseInsensitiveCompare:name] == NSOrderedSame)
            return [headers objectForKey:field];
    }
    return nil;
}

static BOOL headerContains(NSDictionary *headers, NSString *name, NSString *token)
{
    NSString *value = headerValue(headers, name);
    if (![value length])
        return NO;
    return [value rangeOfString:token options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static NSString *headerString(const char *bytes)
{
    NSString *text = [NSString stringWithUTF8String:bytes];
    if (!text)
        text = [[[NSString alloc] initWithCString:bytes encoding:NSISOLatin1StringEncoding] autorelease];
    return text;
}

#define kDNSCacheHosts 16
#define kDNSCacheAddresses 6
#define kDNSCacheSeconds 120

typedef struct {
    char host[256];
    char port[8];
    struct sockaddr_storage storage[kDNSCacheAddresses];
    socklen_t length[kDNSCacheAddresses];
    int family[kDNSCacheAddresses];
    int socktype[kDNSCacheAddresses];
    int protocol[kDNSCacheAddresses];
    unsigned count;
    time_t expiry;
} DNSEntry;

static DNSEntry gDNSCache[kDNSCacheHosts];
static pthread_mutex_t gDNSMutex = PTHREAD_MUTEX_INITIALIZER;

static unsigned dnsCacheCopy(const char *host, const char *port, DNSEntry *out)
{
    struct timeval now;
    gettimeofday(&now, NULL);
    unsigned count = 0;
    pthread_mutex_lock(&gDNSMutex);
    for (unsigned i = 0; i < kDNSCacheHosts; i++) {
        if (!gDNSCache[i].count || gDNSCache[i].expiry <= now.tv_sec)
            continue;
        if (strcmp(gDNSCache[i].host, host) || strcmp(gDNSCache[i].port, port))
            continue;
        *out = gDNSCache[i];
        count = out->count;
        break;
    }
    pthread_mutex_unlock(&gDNSMutex);
    return count;
}

static void dnsCacheStore(const char *host, const char *port, struct addrinfo *addresses)
{
    if (strlen(host) >= sizeof(gDNSCache[0].host) || strlen(port) >= sizeof(gDNSCache[0].port))
        return;

    DNSEntry entry;
    memset(&entry, 0, sizeof(entry));
    strcpy(entry.host, host);
    strcpy(entry.port, port);
    for (struct addrinfo *address = addresses; address && entry.count < kDNSCacheAddresses; address = address->ai_next) {
        if (!address->ai_addr || address->ai_addrlen > sizeof(struct sockaddr_storage))
            continue;
        memcpy(&entry.storage[entry.count], address->ai_addr, address->ai_addrlen);
        entry.length[entry.count] = address->ai_addrlen;
        entry.family[entry.count] = address->ai_family;
        entry.socktype[entry.count] = address->ai_socktype;
        entry.protocol[entry.count] = address->ai_protocol;
        entry.count++;
    }
    if (!entry.count)
        return;

    struct timeval now;
    gettimeofday(&now, NULL);
    entry.expiry = now.tv_sec + kDNSCacheSeconds;

    pthread_mutex_lock(&gDNSMutex);
    unsigned slot = kDNSCacheHosts;
    for (unsigned i = 0; i < kDNSCacheHosts; i++) {
        if (gDNSCache[i].count && !strcmp(gDNSCache[i].host, host) && !strcmp(gDNSCache[i].port, port)) {
            slot = i;
            break;
        }
    }
    if (slot == kDNSCacheHosts) {
        for (unsigned i = 0; i < kDNSCacheHosts; i++) {
            if (!gDNSCache[i].count || gDNSCache[i].expiry <= now.tv_sec) {
                slot = i;
                break;
            }
        }
    }
    if (slot == kDNSCacheHosts) {
        time_t oldest = 0;
        slot = 0;
        for (unsigned i = 0; i < kDNSCacheHosts; i++) {
            if (!oldest || gDNSCache[i].expiry < oldest) {
                oldest = gDNSCache[i].expiry;
                slot = i;
            }
        }
    }
    gDNSCache[slot] = entry;
    pthread_mutex_unlock(&gDNSMutex);
}

static int connectToHost(const char *host, const char *port)
{
    DNSEntry cached;
    struct addrinfo nodes[kDNSCacheAddresses];
    struct addrinfo *addresses = NULL;
    struct addrinfo *resolved = NULL;

    unsigned cachedCount = dnsCacheCopy(host, port, &cached);
    if (cachedCount) {
        memset(nodes, 0, sizeof(nodes));
        for (unsigned i = 0; i < cachedCount; i++) {
            nodes[i].ai_family = cached.family[i];
            nodes[i].ai_socktype = cached.socktype[i];
            nodes[i].ai_protocol = cached.protocol[i];
            nodes[i].ai_addrlen = cached.length[i];
            nodes[i].ai_addr = (struct sockaddr *)&cached.storage[i];
            nodes[i].ai_next = (i + 1 < cachedCount) ? &nodes[i + 1] : NULL;
        }
        addresses = nodes;
    } else {
        struct addrinfo hints;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;

        if (getaddrinfo(host, port, &hints, &resolved) || !resolved)
            return -1;
        dnsCacheStore(host, port, resolved);
        addresses = resolved;
    }

    unsigned count = 0;
    for (struct addrinfo *address = addresses; address; address = address->ai_next)
        count++;

    struct pollfd *waiting = malloc(sizeof(struct pollfd) * count);
    int *flagsFor = malloc(sizeof(int) * count);
    unsigned live = 0;
    int handle = -1;
    for (struct addrinfo *address = addresses; address; address = address->ai_next) {
        int candidate = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (candidate < 0)
            continue;
        int flags = fcntl(candidate, F_GETFL, 0);
        fcntl(candidate, F_SETFL, flags | O_NONBLOCK);
        int reached = connect(candidate, address->ai_addr, address->ai_addrlen);
        if (!reached) {
            for (unsigned i = 0; i < live; i++)
                close(waiting[i].fd);
            live = 0;
            fcntl(candidate, F_SETFL, flags);
            handle = candidate;
            break;
        }
        if (errno != EINPROGRESS) {
            close(candidate);
            continue;
        }
        waiting[live].fd = candidate;
        waiting[live].events = POLLOUT;
        waiting[live].revents = 0;
        flagsFor[live] = flags;
        live++;
    }
    if (resolved)
        freeaddrinfo(resolved);

    struct timeval deadline;
    gettimeofday(&deadline, NULL);
    deadline.tv_sec += kConnectTimeout;
    while (live && handle < 0) {
        struct timeval now;
        gettimeofday(&now, NULL);
        long remainingMs = (deadline.tv_sec - now.tv_sec) * 1000
            + (deadline.tv_usec - now.tv_usec) / 1000;
        if (remainingMs <= 0)
            break;

        int ready = poll(waiting, live, (int)remainingMs);
        if (ready <= 0)
            break;

        for (unsigned i = 0; i < live && handle < 0; i++) {
            if (!(waiting[i].revents & (POLLOUT | POLLERR | POLLHUP)))
                continue;
            int failure = 0;
            socklen_t size = sizeof(failure);
            if (!getsockopt(waiting[i].fd, SOL_SOCKET, SO_ERROR, &failure, &size) && !failure) {
                handle = waiting[i].fd;
                fcntl(handle, F_SETFL, flagsFor[i]);
                waiting[i].fd = -1;
            } else {
                close(waiting[i].fd);
                waiting[i].fd = -1;
            }
        }
        unsigned kept = 0;
        for (unsigned i = 0; i < live; i++) {
            if (waiting[i].fd < 0)
                continue;
            waiting[kept] = waiting[i];
            flagsFor[kept] = flagsFor[i];
            kept++;
        }
        live = kept;
    }
    for (unsigned i = 0; i < live; i++)
        close(waiting[i].fd);
    free(waiting);
    free(flagsFor);
    if (handle < 0)
        return -1;

    int on = 1;
    setsockopt(handle, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on));
    setsockopt(handle, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));

    struct timeval limit;
    limit.tv_sec = kTransferTimeout;
    limit.tv_usec = 0;
    setsockopt(handle, SOL_SOCKET, SO_RCVTIMEO, &limit, sizeof(limit));
    setsockopt(handle, SOL_SOCKET, SO_SNDTIMEO, &limit, sizeof(limit));
    return handle;
}

static int rememberSession(SSL *ssl, SSL_SESSION *session)
{
    NSString *host = (NSString *)SSL_get_ex_data(ssl, gHostSlot);
    if (!host)
        return 0;
    SSL_SESSION *copy = SSL_SESSION_dup(session);
    if (!copy)
        return 0;

    pthread_mutex_lock(&gPoolMutex);
    SSL_SESSION *previous = (SSL_SESSION *)[[gSessions objectForKey:host] pointerValue];
    if (previous)
        SSL_SESSION_free(previous);
    [gSessions setObject:[NSValue valueWithPointer:copy] forKey:host];
    pthread_mutex_unlock(&gPoolMutex);

    return 0;
}

static NSTimeInterval nowSeconds(void);

@interface ModernTLSConnection : NSObject
{
    NSString *_key;
    NSString *_host;
    int _handle;
    SSL *_ssl;
    NSTimeInterval _idleSince;
    BOOL _received;
    NSTimeInterval _exchangeDeadline;
    unsigned char _buffer[16384];
    NSUInteger _start;
    NSUInteger _end;
}
+ (ModernTLSConnection *)connectionToHost:(NSString *)host port:(NSString *)port key:(NSString *)key
                                  message:(NSString **)message code:(NSInteger *)code;
- (NSString *)key;
- (NSTimeInterval)idleSince;
- (void)markIdle;
- (BOOL)isUsable;
- (BOOL)hasRead;
- (void)beginExchange;
- (BOOL)writeData:(NSData *)data;
- (NSData *)readUpTo:(NSUInteger)limit;
- (BOOL)readLine:(char *)line size:(size_t)size;
- (void)shutdown;
@end

@implementation ModernTLSConnection

+ (ModernTLSConnection *)connectionToHost:(NSString *)host port:(NSString *)port key:(NSString *)key
                                  message:(NSString **)message code:(NSInteger *)code
{
    int handle = connectToHost([host UTF8String], [port UTF8String]);
    if (handle < 0) {
        *message = [NSString stringWithFormat:@"Cannot reach %@", host];
        *code = NSURLErrorCannotConnectToHost;
        return nil;
    }

    SSL *ssl = SSL_new(gContext);
    if (!ssl) {
        close(handle);
        *message = @"No TLS context";
        *code = NSURLErrorSecureConnectionFailed;
        return nil;
    }

    ModernTLSConnection *connection = [[ModernTLSConnection alloc] init];
    connection->_key = [key copy];
    connection->_host = [host copy];
    connection->_handle = handle;
    connection->_ssl = ssl;

    SSL_set_fd(ssl, handle);
    SSL_set_tlsext_host_name(ssl, [host UTF8String]);
    SSL_set1_host(ssl, [host UTF8String]);
    SSL_set_ex_data(ssl, gHostSlot, connection->_host);

    pthread_mutex_lock(&gPoolMutex);
    SSL_SESSION *stored = (SSL_SESSION *)[[gSessions objectForKey:host] pointerValue];
    SSL_SESSION *offer = stored ? SSL_SESSION_dup(stored) : NULL;
    pthread_mutex_unlock(&gPoolMutex);
    if (offer) {
        SSL_set_session(ssl, offer);
        SSL_SESSION_free(offer);
    }

    if (SSL_connect(ssl) != 1) {
        unsigned long reason = ERR_get_error();
        char text[256] = {0};
        ERR_error_string_n(reason, text, sizeof(text));
        *message = [NSString stringWithFormat:@"TLS handshake with %@ failed: %s", host, text];
        *code = NSURLErrorSecureConnectionFailed;
        [connection shutdown];
        [connection release];
        return nil;
    }

    if (gLog)
        fprintf(stderr, "[tls] connected %s  %s  %s\n", [key UTF8String],
            SSL_get_version(ssl), SSL_session_reused(ssl) ? "resumed" : "full handshake");
    [connection markIdle];
    return connection;
}

- (void)dealloc
{
    [self shutdown];
    [_key release];
    [_host release];
    [super dealloc];
}

- (NSString *)key
{
    return _key;
}

- (NSTimeInterval)idleSince
{
    return _idleSince;
}

- (void)markIdle
{
    _idleSince = [NSDate timeIntervalSinceReferenceDate];
}

- (BOOL)hasRead
{
    return _received;
}

- (void)beginExchange
{
    _received = NO;
    _exchangeDeadline = nowSeconds() + kExchangeTimeout;
}

- (BOOL)isUsable
{
    if (_handle < 0 || !_ssl)
        return NO;
    if ([NSDate timeIntervalSinceReferenceDate] - _idleSince > kIdleTimeout)
        return NO;
    if (_start < _end || SSL_pending(_ssl) > 0)
        return NO;

    struct pollfd probe;
    probe.fd = _handle;
    probe.events = POLLIN;
    probe.revents = 0;
    int ready = poll(&probe, 1, 0);
    if (ready < 0)
        return NO;
    if (!ready)
        return YES;

    int flags = fcntl(_handle, F_GETFL, 0);
    fcntl(_handle, F_SETFL, flags | O_NONBLOCK);
    unsigned char byte;
    int got = SSL_read(_ssl, &byte, 1);
    int reason = SSL_get_error(_ssl, got);
    fcntl(_handle, F_SETFL, flags);

    if (got > 0)
        return NO;
    return reason == SSL_ERROR_WANT_READ || reason == SSL_ERROR_WANT_WRITE;
}

- (BOOL)writeData:(NSData *)data
{
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSUInteger length = [data length], sent = 0;
    while (sent < length) {
        int wrote = SSL_write(_ssl, bytes + sent, (int)(length - sent));
        if (wrote <= 0)
            return NO;
        sent += wrote;
    }
    return YES;
}

- (BOOL)fill
{
    if (_start < _end)
        return YES;
    if (_exchangeDeadline && nowSeconds() >= _exchangeDeadline)
        return NO;
    _start = _end = 0;
    int read = SSL_read(_ssl, _buffer, sizeof(_buffer));
    if (read <= 0)
        return NO;
    _end = read;
    _received = YES;
    return YES;
}

- (NSData *)readUpTo:(NSUInteger)limit
{
    if (![self fill])
        return nil;
    NSUInteger available = _end - _start;
    if (available > limit)
        available = limit;
    NSData *data = [NSData dataWithBytes:_buffer + _start length:available];
    _start += available;
    return data;
}

- (BOOL)readLine:(char *)line size:(size_t)size
{
    size_t length = 0;
    for (;;) {
        if (![self fill])
            return NO;
        char byte = _buffer[_start++];
        if (byte == '\n') {
            if (length && line[length - 1] == '\r')
                length--;
            line[length] = 0;
            return YES;
        }
        if (length + 1 < size)
            line[length++] = byte;
    }
}

- (void)shutdown
{
    if (_ssl) {
        SSL_shutdown(_ssl);
        SSL_free(_ssl);
        _ssl = NULL;
    }
    if (_handle >= 0) {
        close(_handle);
        _handle = -1;
    }
}

@end

static void expireIdleConnections(void)
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    for (NSString *key in [gIdleConnections allKeys]) {
        NSMutableArray *bucket = [gIdleConnections objectForKey:key];
        while ([bucket count] && now - [[bucket objectAtIndex:0] idleSince] > kIdleTimeout) {
            [[bucket objectAtIndex:0] shutdown];
            [bucket removeObjectAtIndex:0];
        }
        if (![bucket count])
            [gIdleConnections removeObjectForKey:key];
    }
}

static ModernTLSConnection *takeIdleConnection(NSString *key)
{
    for (;;) {
        ModernTLSConnection *connection = nil;

        pthread_mutex_lock(&gPoolMutex);
        expireIdleConnections();
        NSMutableArray *bucket = [gIdleConnections objectForKey:key];
        if ([bucket count]) {
            connection = [[bucket lastObject] retain];
            [bucket removeLastObject];
        }
        pthread_mutex_unlock(&gPoolMutex);

        if (!connection)
            return nil;
        if ([connection isUsable])
            return connection;
        [connection shutdown];
        [connection release];
    }
}

static void returnIdleConnection(ModernTLSConnection *connection)
{
    [connection markIdle];
    if (![connection isUsable]) {
        [connection shutdown];
        return;
    }

    pthread_mutex_lock(&gPoolMutex);
    expireIdleConnections();
    NSMutableArray *bucket = [gIdleConnections objectForKey:[connection key]];
    if (!bucket) {
        bucket = [NSMutableArray array];
        [gIdleConnections setObject:bucket forKey:[connection key]];
    }
    [bucket addObject:connection];
    while ([bucket count] > kIdlePerHost) {
        [[bucket objectAtIndex:0] shutdown];
        [bucket removeObjectAtIndex:0];
    }
    pthread_mutex_unlock(&gPoolMutex);
}

static const unsigned long long kCacheCapacity = 20ULL * 1024 * 1024;

static const unsigned long long kCacheLowWater = 16ULL * 1024 * 1024;

static const unsigned long long kCacheEntryLimit = kCacheCapacity / 8;

static const NSUInteger kCacheEntries = 4000;

static const NSTimeInterval kHeuristicFraction = 0.1;
static const NSTimeInterval kHeuristicCeiling = 86400.0;

static NSString *gCacheDirectory;

static pthread_mutex_t gCacheMutex = PTHREAD_MUTEX_INITIALIZER;
static unsigned long long gCacheBytes;
static unsigned long long gCacheWrittenDuringSweep;
static BOOL gCacheCounted;
static BOOL gCacheSweeping;
static unsigned long gCacheSerial;

static void cacheNoteWrite(unsigned long long bytes);
static BOOL isHopByHop(NSString *field);

static NSTimeInterval nowSeconds(void)
{
    return [NSDate timeIntervalSinceReferenceDate] + NSTimeIntervalSince1970;
}

static BOOL parseHTTPDate(NSString *text, NSTimeInterval *out)
{
    if (![text length])
        return NO;
    const char *bytes = [text UTF8String];
    if (!bytes)
        return NO;

    static const char *const months[] = { "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

    char month[8] = {0};
    int day = 0, year = 0, hour = 0, minute = 0, second = 0;
    BOOL twoDigitYear = NO;

    const char *comma = strchr(bytes, ',');
    if (comma) {
        const char *rest = comma + 1;
        while (*rest == ' ')
            rest++;
        if (sscanf(rest, "%2d %3s %4d %2d:%2d:%2d", &day, month, &year, &hour, &minute, &second) != 6) {
            if (sscanf(rest, "%2d-%3s-%2d %2d:%2d:%2d", &day, month, &year, &hour, &minute, &second) != 6)
                return NO;
            twoDigitYear = YES;
        }
    } else {
        char weekday[8] = {0};
        if (sscanf(bytes, "%3s %3s %2d %2d:%2d:%2d %4d",
                weekday, month, &day, &hour, &minute, &second, &year) != 7)
            return NO;
    }

    int index = -1;
    for (int candidate = 0; candidate < 12; candidate++) {
        if (!strncmp(month, months[candidate], 3)) {
            index = candidate;
            break;
        }
    }
    if (index < 0)
        return NO;

    if (twoDigitYear) {
        time_t clock = time(NULL);
        struct tm present;
        gmtime_r(&clock, &present);
        year += 1900;
        while (year > present.tm_year + 1900 + 50)
            year -= 100;
    }

    struct tm parts;
    memset(&parts, 0, sizeof(parts));
    parts.tm_mday = day;
    parts.tm_mon = index;
    parts.tm_year = year - 1900;
    parts.tm_hour = hour;
    parts.tm_min = minute;
    parts.tm_sec = second;

    time_t moment = timegm(&parts);
    if (moment == (time_t)-1)
        return NO;
    *out = (NSTimeInterval)moment;
    return YES;
}

static NSDictionary *parseCacheControl(NSString *text)
{
    NSMutableDictionary *directives = [NSMutableDictionary dictionary];
    if (![text length])
        return directives;
    const char *bytes = [text UTF8String];
    if (!bytes)
        return directives;

    size_t length = strlen(bytes), at = 0;
    while (at < length) {
        while (at < length && (bytes[at] == ',' || isspace((unsigned char)bytes[at])))
            at++;
        size_t nameStart = at;
        while (at < length && bytes[at] != '=' && bytes[at] != ',' && !isspace((unsigned char)bytes[at]))
            at++;
        if (at == nameStart)
            break;
        NSString *name = [[[NSString alloc] initWithBytes:bytes + nameStart length:at - nameStart
            encoding:NSASCIIStringEncoding] autorelease];

        NSString *value = @"";
        while (at < length && isspace((unsigned char)bytes[at]))
            at++;
        if (at < length && bytes[at] == '=') {
            at++;
            while (at < length && isspace((unsigned char)bytes[at]))
                at++;
            if (at < length && bytes[at] == '"') {
                at++;
                char unquoted[256];
                size_t written = 0;
                while (at < length && bytes[at] != '"') {
                    if (bytes[at] == '\\' && at + 1 < length)
                        at++;
                    if (written + 1 < sizeof(unquoted))
                        unquoted[written++] = bytes[at];
                    at++;
                }
                if (at < length)
                    at++;
                value = [[[NSString alloc] initWithBytes:unquoted length:written
                    encoding:NSASCIIStringEncoding] autorelease];
            } else {
                size_t valueStart = at;
                while (at < length && bytes[at] != ',' && !isspace((unsigned char)bytes[at]))
                    at++;
                value = [[[NSString alloc] initWithBytes:bytes + valueStart length:at - valueStart
                    encoding:NSASCIIStringEncoding] autorelease];
            }
        }
        if ([name length] && value)
            [directives setObject:value forKey:[name lowercaseString]];
    }
    return directives;
}

static BOOL parseDeltaSeconds(NSString *value, NSTimeInterval *out)
{
    if (![value length])
        return NO;
    const char *bytes = [value UTF8String];
    if (!bytes)
        return NO;
    for (const char *at = bytes; *at; at++) {
        if (!isdigit((unsigned char)*at))
            return NO;
    }
    unsigned long long seconds = strtoull(bytes, NULL, 10);
    if (seconds > 2147483648ULL)
        seconds = 2147483648ULL;
    *out = (NSTimeInterval)seconds;
    return YES;
}

static BOOL deltaSeconds(NSDictionary *directives, NSString *name, NSTimeInterval *out)
{
    return parseDeltaSeconds([directives objectForKey:name], out);
}

static const char kCacheMagic[8] = { 'M', 'T', 'L', 'S', 'c', 'v', '1', '\0' };
enum { kCacheHeaderSize = 20 };

@interface ModernTLSCacheEntry : NSObject
{
@public
    NSData *file;
    NSString *path;
    NSString *url;
    NSInteger status;
    NSDictionary *headers;
    NSDictionary *selecting;
    NSTimeInterval requested;
    NSTimeInterval received;
    NSUInteger bodyOffset;
    NSUInteger bodyLength;
}
@end

@implementation ModernTLSCacheEntry
- (void)dealloc
{
    [file release];
    [path release];
    [url release];
    [headers release];
    [selecting release];
    [super dealloc];
}
@end

static NSString *cachePathForKey(NSString *key)
{
    if (!gCacheDirectory)
        return nil;
    const char *bytes = [key UTF8String];
    if (!bytes)
        return nil;

    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int size = 0;
    if (!EVP_Digest(bytes, strlen(bytes), digest, &size, EVP_sha256(), NULL))
        return nil;

    char name[2 * EVP_MAX_MD_SIZE + 1];
    for (unsigned int at = 0; at < size; at++)
        snprintf(name + 2 * at, 3, "%02x", digest[at]);
    return [gCacheDirectory stringByAppendingPathComponent:
        [NSString stringWithUTF8String:name]];
}

static ModernTLSCacheEntry *readCacheEntry(NSString *path, NSString *key)
{
    NSData *file = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
    if ([file length] < kCacheHeaderSize)
        return nil;

    const unsigned char *bytes = (const unsigned char *)[file bytes];
    if (memcmp(bytes, kCacheMagic, sizeof(kCacheMagic)))
        return nil;

    uint32_t metadataLength = 0;
    uint64_t bodyLength = 0;
    memcpy(&metadataLength, bytes + 8, sizeof(metadataLength));
    memcpy(&bodyLength, bytes + 12, sizeof(bodyLength));

    if ((unsigned long long)[file length]
        != (unsigned long long)kCacheHeaderSize + metadataLength + bodyLength)
        return nil;

    NSData *encoded = [file subdataWithRange:NSMakeRange(kCacheHeaderSize, metadataLength)];
    NSDictionary *metadata = [NSPropertyListSerialization propertyListWithData:encoded
        options:NSPropertyListImmutable format:NULL error:NULL];
    if (![metadata isKindOfClass:[NSDictionary class]])
        return nil;

    NSString *url = [metadata objectForKey:@"url"];
    NSDictionary *headers = [metadata objectForKey:@"headers"];
    NSDictionary *selecting = [metadata objectForKey:@"vary"];
    NSNumber *status = [metadata objectForKey:@"status"];
    NSNumber *requested = [metadata objectForKey:@"requested"];
    NSNumber *received = [metadata objectForKey:@"received"];
    if (![url isKindOfClass:[NSString class]] || ![headers isKindOfClass:[NSDictionary class]]
        || ![selecting isKindOfClass:[NSDictionary class]] || ![status isKindOfClass:[NSNumber class]]
        || ![requested isKindOfClass:[NSNumber class]] || ![received isKindOfClass:[NSNumber class]])
        return nil;
    if (![url isEqualToString:key])
        return nil;

    ModernTLSCacheEntry *entry = [[[ModernTLSCacheEntry alloc] init] autorelease];
    entry->file = [file retain];
    entry->path = [path copy];
    entry->url = [url copy];
    entry->headers = [headers retain];
    entry->selecting = [selecting retain];
    entry->status = [status integerValue];
    entry->requested = [requested doubleValue];
    entry->received = [received doubleValue];
    entry->bodyOffset = (NSUInteger)(kCacheHeaderSize + metadataLength);
    entry->bodyLength = (NSUInteger)bodyLength;
    return entry;
}

static void removeCacheEntry(NSString *key)
{
    NSString *path = cachePathForKey(key);
    if (path)
        unlink([path fileSystemRepresentation]);
}

@interface ModernTLSCacheWriter : NSObject
{
    NSString *_temporary;
    NSString *_final;
    int _handle;
    unsigned long long _written;
}
- (id)initForKey:(NSString *)key metadata:(NSDictionary *)metadata;
- (BOOL)appendBody:(NSData *)data;
- (BOOL)commit;
- (void)abandon;
@end

@implementation ModernTLSCacheWriter

- (id)initForKey:(NSString *)key metadata:(NSDictionary *)metadata
{
    if (!(self = [super init]))
        return nil;
    _handle = -1;

    NSString *path = cachePathForKey(key);
    NSData *encoded = [NSPropertyListSerialization dataWithPropertyList:metadata
        format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    if (!path || !encoded || [encoded length] > UINT32_MAX) {
        [self release];
        return nil;
    }
    _final = [path copy];

    pthread_mutex_lock(&gCacheMutex);
    unsigned long serial = ++gCacheSerial;
    pthread_mutex_unlock(&gCacheMutex);
    _temporary = [[gCacheDirectory stringByAppendingPathComponent:
        [NSString stringWithFormat:@"partial-%d-%lu", (int)getpid(), serial]] copy];

    _handle = open([_temporary fileSystemRepresentation], O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (_handle < 0) {
        [self release];
        return nil;
    }

    unsigned char head[kCacheHeaderSize];
    uint32_t metadataLength = (uint32_t)[encoded length];
    uint64_t bodyLength = 0;
    memcpy(head, kCacheMagic, sizeof(kCacheMagic));
    memcpy(head + 8, &metadataLength, sizeof(metadataLength));
    memcpy(head + 12, &bodyLength, sizeof(bodyLength));

    if (write(_handle, head, sizeof(head)) != (ssize_t)sizeof(head)
        || write(_handle, [encoded bytes], [encoded length]) != (ssize_t)[encoded length]) {
        [self release];
        return nil;
    }
    return self;
}

- (void)dealloc
{
    [self abandon];
    [_temporary release];
    [_final release];
    [super dealloc];
}

- (BOOL)appendBody:(NSData *)data
{
    if (_handle < 0)
        return NO;
    if (_written + [data length] > kCacheEntryLimit)
        return NO;
    if (write(_handle, [data bytes], [data length]) != (ssize_t)[data length])
        return NO;
    _written += [data length];
    return YES;
}

- (BOOL)commit
{
    if (_handle < 0)
        return NO;

    uint64_t bodyLength = _written;
    if (pwrite(_handle, &bodyLength, sizeof(bodyLength), 12) != (ssize_t)sizeof(bodyLength)) {
        [self abandon];
        return NO;
    }
    fsync(_handle);
    close(_handle);
    _handle = -1;

    if (rename([_temporary fileSystemRepresentation], [_final fileSystemRepresentation])) {
        unlink([_temporary fileSystemRepresentation]);
        return NO;
    }
    cacheNoteWrite(kCacheHeaderSize + _written);
    return YES;
}

- (void)abandon
{
    if (_handle >= 0) {
        close(_handle);
        _handle = -1;
        unlink([_temporary fileSystemRepresentation]);
    }
}

@end

typedef struct {
    char name[80];
    off_t size;
    time_t used;
} ModernTLSCacheFile;

static int compareByUse(const void *left, const void *right)
{
    time_t first = ((const ModernTLSCacheFile *)left)->used;
    time_t second = ((const ModernTLSCacheFile *)right)->used;
    return first < second ? -1 : first > second ? 1 : 0;
}

static unsigned long long sweepOnce(BOOL *removed)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    *removed = NO;
    DIR *directory = opendir([gCacheDirectory fileSystemRepresentation]);
    if (!directory) {
        [pool release];
        return 0;
    }

    ModernTLSCacheFile *files = NULL;
    NSUInteger count = 0, capacity = 0;
    unsigned long long total = 0;

    struct dirent *listing;
    while ((listing = readdir(directory))) {
        if (listing->d_name[0] == '.')
            continue;

        char path[PATH_MAX];
        snprintf(path, sizeof(path), "%s/%s", [gCacheDirectory fileSystemRepresentation], listing->d_name);
        struct stat details;
        if (stat(path, &details) || !S_ISREG(details.st_mode))
            continue;

        if (!strncmp(listing->d_name, "partial-", 8)) {
            char mine[32];
            snprintf(mine, sizeof(mine), "partial-%d-", (int)getpid());
            if (strncmp(listing->d_name, mine, strlen(mine)))
                unlink(path);
            continue;
        }
        if (strlen(listing->d_name) >= sizeof(((ModernTLSCacheFile *)0)->name))
            continue;

        if (count == capacity) {
            NSUInteger wanted = capacity ? capacity * 2 : 256;
            ModernTLSCacheFile *grown = realloc(files, wanted * sizeof(ModernTLSCacheFile));
            if (!grown)
                break;
            files = grown;
            capacity = wanted;
        }
        strlcpy(files[count].name, listing->d_name, sizeof(files[count].name));
        files[count].size = details.st_size;
        files[count].used = details.st_mtime;
        total += (unsigned long long)details.st_size;
        count++;
    }
    closedir(directory);

    unsigned long long held = total;
    NSUInteger kept = count;
    if (total > kCacheCapacity || count > kCacheEntries) {
        qsort(files, count, sizeof(ModernTLSCacheFile), compareByUse);
        for (NSUInteger at = 0; at < count && (held > kCacheLowWater || kept > kCacheEntries); at++) {
            char path[PATH_MAX];
            snprintf(path, sizeof(path), "%s/%s", [gCacheDirectory fileSystemRepresentation], files[at].name);
            if (unlink(path))
                continue;
            held -= (unsigned long long)files[at].size;
            kept--;
            *removed = YES;
        }
    }
    if (gLog)
        fprintf(stderr, "[cache] swept: %lu entries in %llu bytes, kept %lu in %llu\n",
            (unsigned long)count, total, (unsigned long)kept, held);
    free(files);
    [pool release];
    return held;
}

static void sweepCache(void)
{
    pthread_mutex_lock(&gCacheMutex);
    if (gCacheSweeping) {
        pthread_mutex_unlock(&gCacheMutex);
        return;
    }
    gCacheSweeping = YES;
    pthread_mutex_unlock(&gCacheMutex);

    for (;;) {
        BOOL removed = NO;
        unsigned long long held = sweepOnce(&removed);

        pthread_mutex_lock(&gCacheMutex);
        gCacheBytes = held + gCacheWrittenDuringSweep;
        gCacheWrittenDuringSweep = 0;
        gCacheCounted = YES;
        BOOL again = gCacheBytes > kCacheCapacity && removed;
        if (!again)
            gCacheSweeping = NO;
        pthread_mutex_unlock(&gCacheMutex);

        if (!again)
            return;
    }
}

static void scheduleSweep(void)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        sweepCache();
    });
}

static void cacheNoteWrite(unsigned long long bytes)
{
    pthread_mutex_lock(&gCacheMutex);
    if (gCacheSweeping)
        gCacheWrittenDuringSweep += bytes;
    else
        gCacheBytes += bytes;
    BOOL due = !gCacheCounted || gCacheBytes > kCacheCapacity;
    pthread_mutex_unlock(&gCacheMutex);

    if (due)
        sweepCache();
}

static BOOL installCache(void)
{
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (![directories count])
        return NO;
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier] ?: @"ModernTLS";
    NSString *path = [[[directories objectAtIndex:0] stringByAppendingPathComponent:identifier]
        stringByAppendingPathComponent:@"HTTPCache"];

    if (![[NSFileManager defaultManager] createDirectoryAtPath:path
            withIntermediateDirectories:YES attributes:nil error:NULL])
        return NO;
    gCacheDirectory = [path copy];

    scheduleSweep();
    return YES;
}

static NSString *cacheKeyForURL(NSURL *url)
{
    NSString *text = [url absoluteString];
    NSRange fragment = [text rangeOfString:@"#"];
    if (fragment.location != NSNotFound)
        text = [text substringToIndex:fragment.location];
    return text;
}

static NSString *cacheKeyForRequest(NSURLRequest *request)
{
    return cacheKeyForURL([request URL]);
}

static NSDictionary *selectingHeaders(NSString *vary, NSDictionary *wire)
{
    NSMutableDictionary *selecting = [NSMutableDictionary dictionary];
    for (NSString *field in [vary componentsSeparatedByString:@","]) {
        NSString *name = [[field stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
        if (![name length])
            continue;
        NSString *value = headerValue(wire, name);
        [selecting setObject:value ?: (id)[NSNull null] forKey:name];
    }
    return selecting;
}

static BOOL selectingHeadersMatch(NSDictionary *selecting, NSDictionary *wire)
{
    for (NSString *name in selecting) {
        id stored = [selecting objectForKey:name];
        NSString *value = headerValue(wire, name);
        if (stored == [NSNull null]) {
            if (value)
                return NO;
        } else if (![stored isEqual:value]) {
            return NO;
        }
    }
    return YES;
}

static NSTimeInterval entryAge(ModernTLSCacheEntry *entry)
{
    NSTimeInterval dateValue = entry->received;
    NSTimeInterval parsed = 0;
    if (parseHTTPDate(headerValue(entry->headers, @"Date"), &parsed))
        dateValue = parsed;

    NSTimeInterval ageValue = 0;
    if (!parseDeltaSeconds(headerValue(entry->headers, @"Age"), &ageValue))
        ageValue = 0;

    NSTimeInterval apparent = entry->received - dateValue;
    if (apparent < 0)
        apparent = 0;
    NSTimeInterval corrected = ageValue + (entry->received - entry->requested);
    NSTimeInterval initial = apparent > corrected ? apparent : corrected;
    NSTimeInterval resident = nowSeconds() - entry->received;
    if (resident < 0)
        resident = 0;
    return initial + resident;
}

static NSTimeInterval entryFreshnessLifetime(ModernTLSCacheEntry *entry, NSDictionary *directives)
{
    NSTimeInterval maxAge = 0;
    if (deltaSeconds(directives, @"max-age", &maxAge))
        return maxAge;

    NSString *expires = headerValue(entry->headers, @"Expires");
    if ([expires length]) {
        NSTimeInterval dateValue = entry->received, expiresValue = 0;
        NSTimeInterval parsed = 0;
        if (parseHTTPDate(headerValue(entry->headers, @"Date"), &parsed))
            dateValue = parsed;
        if (!parseHTTPDate(expires, &expiresValue))
            return 0;
        NSTimeInterval lifetime = expiresValue - dateValue;
        return lifetime > 0 ? lifetime : 0;
    }

    NSTimeInterval modified = 0, dateValue = 0;
    if (parseHTTPDate(headerValue(entry->headers, @"Last-Modified"), &modified)
        && parseHTTPDate(headerValue(entry->headers, @"Date"), &dateValue)
        && dateValue > modified) {
        NSTimeInterval lifetime = (dateValue - modified) * kHeuristicFraction;
        return lifetime > kHeuristicCeiling ? kHeuristicCeiling : lifetime;
    }
    return 0;
}

typedef enum {
    ModernTLSCacheUnusable,
    ModernTLSCacheValidate,
    ModernTLSCacheFresh
} ModernTLSCacheVerdict;

static ModernTLSCacheVerdict verdictForEntry(ModernTLSCacheEntry *entry,
    NSDictionary *requestDirectives)
{
    BOOL hasValidator = [headerValue(entry->headers, @"ETag") length]
        || [headerValue(entry->headers, @"Last-Modified") length];
    NSDictionary *responseDirectives = parseCacheControl(headerValue(entry->headers, @"Cache-Control"));

    if ([responseDirectives objectForKey:@"no-cache"] || [requestDirectives objectForKey:@"no-cache"])
        return hasValidator ? ModernTLSCacheValidate : ModernTLSCacheUnusable;

    NSTimeInterval age = entryAge(entry);
    NSTimeInterval lifetime = entryFreshnessLifetime(entry, responseDirectives);

    NSTimeInterval requestMaxAge = 0;
    if (deltaSeconds(requestDirectives, @"max-age", &requestMaxAge) && requestMaxAge < lifetime)
        lifetime = requestMaxAge;

    if (age < lifetime)
        return ModernTLSCacheFresh;
    return hasValidator ? ModernTLSCacheValidate : ModernTLSCacheUnusable;
}

static BOOL responseIsStorable(NSInteger status, NSDictionary *headers, NSDictionary *directives)
{
    if (status < 200 || status == 206 || status == 304)
        return NO;
    if ([directives objectForKey:@"no-store"])
        return NO;

    NSString *vary = headerValue(headers, @"Vary");
    if ([[vary stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]] isEqualToString:@"*"])
        return NO;

    static const NSInteger byDefault[] = { 200, 203, 204, 300, 301, 308, 404, 405, 410, 414, 501 };
    for (size_t at = 0; at < sizeof(byDefault) / sizeof(byDefault[0]); at++) {
        if (status == byDefault[at])
            return YES;
    }

    NSTimeInterval ignored = 0;
    return deltaSeconds(directives, @"max-age", &ignored)
        || [headerValue(headers, @"Expires") length] != 0
        || [directives objectForKey:@"public"] != nil
        || [directives objectForKey:@"private"] != nil;
}

static NSDictionary *cacheMetadata(ModernTLSCacheEntry *entry)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        entry->url, @"url",
        [NSNumber numberWithInteger:entry->status], @"status",
        entry->headers, @"headers",
        entry->selecting, @"vary",
        [NSNumber numberWithDouble:entry->requested], @"requested",
        [NSNumber numberWithDouble:entry->received], @"received", nil];
}

static void mergeStoredHeaders(ModernTLSCacheEntry *entry, NSDictionary *fresh)
{
    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:entry->headers];
    for (NSString *field in fresh) {
        if (isHopByHop(field)
            || [field caseInsensitiveCompare:@"Content-Length"] == NSOrderedSame
            || [field caseInsensitiveCompare:@"Content-Encoding"] == NSOrderedSame
            || [field caseInsensitiveCompare:@"Set-Cookie"] == NSOrderedSame)
            continue;
        for (NSString *existing in [merged allKeys]) {
            if ([existing caseInsensitiveCompare:field] == NSOrderedSame && ![existing isEqualToString:field])
                [merged removeObjectForKey:existing];
        }
        [merged setObject:[fresh objectForKey:field] forKey:field];
    }
    NSDictionary *replacement = [merged copy];
    [entry->headers release];
    entry->headers = replacement;
}

static void rewriteCacheEntry(ModernTLSCacheEntry *entry, NSString *key)
{
    ModernTLSCacheWriter *writer = [[ModernTLSCacheWriter alloc]
        initForKey:key metadata:cacheMetadata(entry)];
    if (!writer)
        return;

    BOOL whole = YES;
    for (NSUInteger at = 0; whole && at < entry->bodyLength; ) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSUInteger chunk = MIN(entry->bodyLength - at, (NSUInteger)65536);
        whole = [writer appendBody:[entry->file
            subdataWithRange:NSMakeRange(entry->bodyOffset + at, chunk)]];
        [pool release];
        at += chunk;
    }
    if (whole)
        [writer commit];
    else
        [writer abandon];
    [writer release];
}

static void invalidateCacheForRequest(NSURLRequest *request, NSDictionary *headers, NSInteger status)
{
    if (!gCacheDirectory || status >= 400)
        return;
    NSString *method = [request HTTPMethod] ?: @"GET";
    if ([method caseInsensitiveCompare:@"GET"] == NSOrderedSame
        || [method caseInsensitiveCompare:@"HEAD"] == NSOrderedSame
        || [method caseInsensitiveCompare:@"OPTIONS"] == NSOrderedSame
        || [method caseInsensitiveCompare:@"TRACE"] == NSOrderedSame)
        return;

    NSURL *url = [request URL];
    removeCacheEntry(cacheKeyForRequest(request));

    NSString *names[] = { @"Location", @"Content-Location" };
    for (size_t at = 0; at < sizeof(names) / sizeof(names[0]); at++) {
        NSString *value = headerValue(headers, names[at]);
        if (![value length])
            continue;
        NSURL *target = [NSURL URLWithString:value relativeToURL:url];
        if (target && [[target host] caseInsensitiveCompare:[url host]] == NSOrderedSame)
            removeCacheEntry(cacheKeyForURL(target));
    }
}

static const NSTimeInterval kShellMaxStale = 7 * 86400.0;

static const NSTimeInterval kShellQuietPeriod = 2.0;
static const NSTimeInterval kShellQuietDeadline = 30.0;
static const NSTimeInterval kShellRevalidateGap = 0.25;
static const NSUInteger kShellQueueLimit = 64;

static pthread_mutex_t gShellMutex = PTHREAD_MUTEX_INITIALIZER;
static BOOL gShellCacheFirst;
static NSSet *gShellHosts;
static NSMutableSet *gShellDeclared;
static NSMutableArray *gShellPending;
static NSMutableSet *gShellInFlight;
static BOOL gShellDraining;
static dispatch_queue_t gShellRunner;
static NSTimeInterval gShellForegroundAt;
static NSString *gShellUserAgent;

@interface ModernTLSDiscardedClient : NSObject <NSURLProtocolClient>
@end

@implementation ModernTLSDiscardedClient
- (void)URLProtocol:(NSURLProtocol *)p wasRedirectedToRequest:(NSURLRequest *)r
    redirectResponse:(NSURLResponse *)response {}
- (void)URLProtocol:(NSURLProtocol *)p cachedResponseIsValid:(NSCachedURLResponse *)c {}
- (void)URLProtocol:(NSURLProtocol *)p didReceiveResponse:(NSURLResponse *)response
    cacheStoragePolicy:(NSURLCacheStoragePolicy)policy {}
- (void)URLProtocol:(NSURLProtocol *)p didLoadData:(NSData *)data {}
- (void)URLProtocolDidFinishLoading:(NSURLProtocol *)p {}
- (void)URLProtocol:(NSURLProtocol *)p didFailWithError:(NSError *)error {}
- (void)URLProtocol:(NSURLProtocol *)p
    didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)c {}
- (void)URLProtocol:(NSURLProtocol *)p
    didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)c {}
@end

@interface ModernTLSURLProtocol (ModernTLSShellPolicy)
+ (void)runShellRequest:(NSURLRequest *)request;
@end

static void shellNoteForegroundActivity(void)
{
    if (!gShellCacheFirst)
        return;
    pthread_mutex_lock(&gShellMutex);
    gShellForegroundAt = nowSeconds();
    pthread_mutex_unlock(&gShellMutex);
}

static NSString *shellDestinationForRequest(NSURLRequest *request, NSDictionary *wire)
{
    NSString *destination = headerValue(wire, @"Sec-Fetch-Dest");
    if ([destination length])
        return [destination lowercaseString];

    NSString *accept = headerValue(wire, @"Accept");
    if ([accept hasPrefix:@"text/html,"])
        return @"document";
    if ([accept hasPrefix:@"text/css,"])
        return @"style";

    NSURL *first = [request mainDocumentURL];
    if (first && [[first absoluteString] isEqualToString:[[request URL] absoluteString]])
        return @"document";
    return nil;
}

static BOOL shellEntryMatchesDestination(NSString *destination, ModernTLSCacheEntry *entry)
{
    NSString *type = headerValue(entry->headers, @"Content-Type");
    if (![type length])
        return NO;
    NSRange parameters = [type rangeOfString:@";"];
    if (parameters.location != NSNotFound)
        type = [type substringToIndex:parameters.location];
    type = [[type stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];

    if ([destination isEqualToString:@"document"] || [destination isEqualToString:@"iframe"])
        return [type isEqualToString:@"text/html"] || [type isEqualToString:@"application/xhtml+xml"];

    if ([destination isEqualToString:@"style"])
        return [type isEqualToString:@"text/css"];

    if ([destination isEqualToString:@"script"]) {
        static NSArray *scripts;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            scripts = [[NSArray alloc] initWithObjects:@"text/javascript", @"application/javascript",
                @"application/x-javascript", @"text/ecmascript", @"application/ecmascript", nil];
        });
        return [scripts containsObject:type];
    }

    if ([destination isEqualToString:@"font"])
        return [type hasPrefix:@"font/"] || [type isEqualToString:@"application/font-woff"]
            || [type isEqualToString:@"application/x-font-woff"]
            || [type isEqualToString:@"application/font-sfnt"]
            || [type isEqualToString:@"application/vnd.ms-fontobject"];

    return NO;
}

static BOOL shellPolicyAppliesTo(NSURLRequest *request, NSDictionary *wire,
    ModernTLSCacheEntry *entry, NSString *key)
{
    if (!gShellCacheFirst)
        return NO;

    NSString *host = [[[request URL] host] lowercaseString];
    if (![host length])
        return NO;

    pthread_mutex_lock(&gShellMutex);
    BOOL ours = [gShellHosts containsObject:host];
    BOOL declared = [gShellDeclared containsObject:key];
    pthread_mutex_unlock(&gShellMutex);
    if (!ours)
        return NO;

    if (!declared && !shellEntryMatchesDestination(shellDestinationForRequest(request, wire), entry))
        return NO;

    return entryAge(entry) <= kShellMaxStale;
}

static void shellWaitForQuiet(void)
{
    NSTimeInterval deadline = nowSeconds() + kShellQuietDeadline;
    for (;;) {
        pthread_mutex_lock(&gShellMutex);
        NSTimeInterval last = gShellForegroundAt;
        pthread_mutex_unlock(&gShellMutex);
        NSTimeInterval now = nowSeconds();
        if (now - last >= kShellQuietPeriod || now >= deadline)
            return;
        [NSThread sleepForTimeInterval:0.25];
    }
}

static void shellDrain(void)
{
    for (;;) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSURLRequest *next = nil;
        pthread_mutex_lock(&gShellMutex);
        if ([gShellPending count]) {
            next = [[gShellPending objectAtIndex:0] retain];
            [gShellPending removeObjectAtIndex:0];
        } else {
            gShellDraining = NO;
        }
        pthread_mutex_unlock(&gShellMutex);

        if (!next) {
            [pool release];
            return;
        }

        shellWaitForQuiet();
        if (gLog)
            fprintf(stderr, "[shell] revalidating %s in the background\n",
                [[[next URL] absoluteString] UTF8String]);
        [ModernTLSURLProtocol runShellRequest:next];

        pthread_mutex_lock(&gShellMutex);
        [gShellInFlight removeObject:cacheKeyForRequest(next)];
        pthread_mutex_unlock(&gShellMutex);
        [next release];
        [pool release];
        [NSThread sleepForTimeInterval:kShellRevalidateGap];
    }
}

static void shellStartDrainingLocked(void)
{
    if (gShellDraining || ![gShellPending count])
        return;
    if (!gShellRunner) {
        gShellRunner = dispatch_queue_create("modern-tls-shell", NULL);
        dispatch_set_target_queue(gShellRunner,
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
    }
    gShellDraining = YES;
    dispatch_async(gShellRunner, ^{ shellDrain(); });
}

static void shellQueueRevalidation(NSURLRequest *request, NSString *key)
{
    NSMutableURLRequest *refresh = [[[NSMutableURLRequest alloc] initWithURL:[request URL]] autorelease];
    [refresh setHTTPMethod:@"GET"];
    [refresh setMainDocumentURL:[request mainDocumentURL]];
    [refresh setCachePolicy:NSURLRequestReloadRevalidatingCacheData];
    NSDictionary *headers = [request allHTTPHeaderFields];
    for (NSString *field in headers) {
        if ([field caseInsensitiveCompare:@"If-None-Match"] == NSOrderedSame
            || [field caseInsensitiveCompare:@"If-Modified-Since"] == NSOrderedSame
            || [field caseInsensitiveCompare:@"If-Range"] == NSOrderedSame
            || [field caseInsensitiveCompare:@"Range"] == NSOrderedSame)
            continue;
        [refresh setValue:[headers objectForKey:field] forHTTPHeaderField:field];
    }

    pthread_mutex_lock(&gShellMutex);
    NSString *agent = [headers objectForKey:@"User-Agent"];
    if ([agent length] && ![agent isEqualToString:gShellUserAgent]) {
        [gShellUserAgent release];
        gShellUserAgent = [agent copy];
    }
    if ([gShellInFlight containsObject:key] || [gShellPending count] >= kShellQueueLimit) {
        pthread_mutex_unlock(&gShellMutex);
        return;
    }
    if (!gShellPending) {
        gShellPending = [[NSMutableArray alloc] init];
        gShellInFlight = [[NSMutableSet alloc] init];
    }
    [gShellPending addObject:refresh];
    [gShellInFlight addObject:key];
    shellStartDrainingLocked();
    pthread_mutex_unlock(&gShellMutex);
}

static NSString *requestTarget(NSURL *url)
{
    NSString *text = [url absoluteString];
    NSRange separator = [text rangeOfString:@"://"];
    NSUInteger authority = separator.location == NSNotFound ? 0 : NSMaxRange(separator);
    NSRange rest = NSMakeRange(authority, [text length] - authority);

    NSRange slash = [text rangeOfString:@"/" options:0 range:rest];
    NSRange query = [text rangeOfString:@"?" options:0 range:rest];
    NSUInteger start = MIN(slash.location, query.location);
    if (start == NSNotFound)
        return @"/";

    NSString *target = [text substringFromIndex:start];
    NSRange fragment = [target rangeOfString:@"#"];
    if (fragment.location != NSNotFound)
        target = [target substringToIndex:fragment.location];
    if (![target hasPrefix:@"/"])
        target = [@"/" stringByAppendingString:target];
    return [target length] ? target : @"/";
}

static BOOL isHopByHop(NSString *field)
{
    static NSArray *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = [[NSArray alloc] initWithObjects:@"Connection", @"Keep-Alive", @"Transfer-Encoding",
            @"TE", @"Trailer", @"Upgrade", @"Proxy-Connection", @"Proxy-Authenticate", nil];
    });
    for (NSString *name in names) {
        if ([field caseInsensitiveCompare:name] == NSOrderedSame)
            return YES;
    }
    return NO;
}

typedef enum {
    ModernTLSExchangeReusable,
    ModernTLSExchangeSpent,
    ModernTLSExchangeUnanswered,
    ModernTLSExchangeMismatched
} ModernTLSExchange;

typedef enum {
    ModernTLSFramingNone,
    ModernTLSFramingLength,
    ModernTLSFramingChunked,
    ModernTLSFramingUntilClose
} ModernTLSFraming;

@implementation ModernTLSURLProtocol {
    volatile BOOL _cancelled;
    NSThread *_clientThread;
    z_stream _inflater;
    BOOL _inflating;
    NSString *_cacheKey;
    NSMutableDictionary *_wireHeaders;
    ModernTLSCacheWriter *_writer;
    ModernTLSCacheEntry *_validating;
    NSTimeInterval _requestTime;
    BOOL _background;
    BOOL _transcodingImage;
    NSMutableData *_imageBuffer;
    NSData *_requestBody;
    BOOL _requestBodyRead;
}

+ (BOOL)install
{
    NSString *authorities = [[NSBundle mainBundle] pathForResource:@"cacert" ofType:@"pem"];
    if (![authorities length] || ![[NSFileManager defaultManager] fileExistsAtPath:authorities]) {
        const char *envCA = getenv("MODERN_TLS_CA");
        NSString *fallback = envCA ? [NSString stringWithUTF8String:envCA]
                                   : @"/Library/RevenantWebKit/cacert.pem";
        if ([[NSFileManager defaultManager] fileExistsAtPath:fallback])
            authorities = fallback;
    }
    if (![authorities length] || ![[NSFileManager defaultManager] fileExistsAtPath:authorities])
        return NO;
    gCertificateAuthorities = [authorities copy];
    gLog = getenv("MODERN_TLS_LOG") != NULL;

    SSL_library_init();
    SSL_load_error_strings();

    gContext = SSL_CTX_new(TLS_client_method());
    if (!gContext)
        return NO;
    SSL_CTX_set_min_proto_version(gContext, TLS1_2_VERSION);
    SSL_CTX_set_cipher_list(gContext, "HIGH:!aNULL:!eNULL:!MD5:!RC4:!3DES:!EXPORT");
    SSL_CTX_set_ciphersuites(gContext, "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256");
    SSL_CTX_set_verify(gContext, SSL_VERIFY_PEER, NULL);
    if (!SSL_CTX_load_verify_locations(gContext, [gCertificateAuthorities UTF8String], NULL)) {
        SSL_CTX_free(gContext);
        gContext = NULL;
        return NO;
    }
    SSL_CTX_set_session_cache_mode(gContext, SSL_SESS_CACHE_CLIENT | SSL_SESS_CACHE_NO_INTERNAL_STORE);
    SSL_CTX_sess_set_new_cb(gContext, rememberSession);
    gHostSlot = SSL_get_ex_new_index(0, NULL, NULL, NULL, NULL);

    gIdleConnections = [[NSMutableDictionary alloc] init];
    gSessions = [[NSMutableDictionary alloc] init];

    if (!installCache() && gLog)
        fprintf(stderr, "[cache] no cache directory; running without one\n");

    return [NSURLProtocol registerClass:self];
}

+ (void)setShellCacheFirstEnabled:(BOOL)enabled forHosts:(NSArray *)hosts
{
    NSMutableSet *named = [NSMutableSet set];
    for (NSString *host in hosts) {
        if ([host length])
            [named addObject:[host lowercaseString]];
    }
    pthread_mutex_lock(&gShellMutex);
    [gShellHosts release];
    gShellHosts = [named copy];
    gShellCacheFirst = enabled && [named count] > 0;
    pthread_mutex_unlock(&gShellMutex);
    if (gLog)
        fprintf(stderr, "[shell] cache-first %s for %lu host(s)\n",
            gShellCacheFirst ? "on" : "off", (unsigned long)[named count]);
}

+ (BOOL)shellCacheFirstEnabled
{
    return gShellCacheFirst;
}

+ (void)declareShellURLs:(NSArray *)urls
{
    pthread_mutex_lock(&gShellMutex);
    if (!gShellDeclared)
        gShellDeclared = [[NSMutableSet alloc] init];
    for (id url in urls) {
        NSURL *target = [url isKindOfClass:[NSURL class]] ? url : [NSURL URLWithString:url];
        if (target)
            [gShellDeclared addObject:cacheKeyForURL(target)];
    }
    pthread_mutex_unlock(&gShellMutex);
}

+ (void)precacheURLs:(NSArray *)urls
{
    if (!gCacheDirectory)
        return;
    [self declareShellURLs:urls];

    pthread_mutex_lock(&gShellMutex);
    NSString *agent = [[gShellUserAgent retain] autorelease];
    pthread_mutex_unlock(&gShellMutex);

    for (id each in urls) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSURL *url = [each isKindOfClass:[NSURL class]] ? each : [NSURL URLWithString:each];
        if (!url || [[url scheme] caseInsensitiveCompare:@"https"] != NSOrderedSame) {
            [pool release];
            continue;
        }
        NSString *key = cacheKeyForURL(url);
        NSString *path = cachePathForKey(key);
        ModernTLSCacheEntry *entry = path ? readCacheEntry(path, key) : nil;
        if (entry && entryAge(entry) <= kShellMaxStale) {
            [pool release];
            continue;
        }
        NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
        [request setHTTPMethod:@"GET"];
        [request setMainDocumentURL:url];
        if ([agent length])
            [request setValue:agent forHTTPHeaderField:@"User-Agent"];

        pthread_mutex_lock(&gShellMutex);
        if (![gShellInFlight containsObject:key] && [gShellPending count] < kShellQueueLimit) {
            if (!gShellPending) {
                gShellPending = [[NSMutableArray alloc] init];
                gShellInFlight = [[NSMutableSet alloc] init];
            }
            [gShellPending addObject:request];
            [gShellInFlight addObject:key];
            shellStartDrainingLocked();
        }
        pthread_mutex_unlock(&gShellMutex);
        [pool release];
    }
}

+ (void)runShellRequest:(NSURLRequest *)request
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    ModernTLSDiscardedClient *sink = [[ModernTLSDiscardedClient alloc] init];
    ModernTLSURLProtocol *protocol = [[self alloc] initWithRequest:request
        cachedResponse:nil client:sink];
    protocol->_background = YES;
    protocol->_clientThread = [[NSThread currentThread] retain];
    [protocol performRequest:request];
    [protocol release];
    [sink release];
    [pool release];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if ([NSURLProtocol propertyForKey:kHandledKey inRequest:request])
        return NO;
    return [[[request URL] scheme] caseInsensitiveCompare:@"https"] == NSOrderedSame;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    {
        static unsigned started;
        static double firstStart;
        double now = nowSeconds();
        if (!firstStart)
            firstStart = now;
        started++;
        NSURL *u = [[self request] URL];
        fprintf(stderr, "[net] #%u %.2fs %s %s%s\n", started, now - firstStart,
            [[[self request] HTTPMethod] UTF8String] ?: "?",
            [[u host] UTF8String] ?: "?", [[u path] UTF8String] ?: "");
    }

    _clientThread = [[NSThread currentThread] retain];

    NSMutableURLRequest *request = [[self request] mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:kHandledKey inRequest:request];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [self performRequest:request];
        [request release];
        [pool release];
    });
}

- (void)dealloc
{
    [_clientThread release];
    if (_inflating)
        inflateEnd(&_inflater);
    [_writer abandon];
    [_writer release];
    [_validating release];
    [_cacheKey release];
    [_wireHeaders release];
    [_imageBuffer release];
    [_requestBody release];
    [super dealloc];
}

- (void)onClientThread:(SEL)selector with:(id)argument
{
    if (_cancelled)
        return;
    if (_background) {
        [self performSelector:selector withObject:argument];
        return;
    }
    [self performSelector:selector onThread:_clientThread withObject:argument
        waitUntilDone:NO modes:[NSArray arrayWithObjects:NSRunLoopCommonModes, nil]];
}

- (void)deliverResponse:(NSHTTPURLResponse *)response
{
    if (_cancelled)
        return;
    {
        static BOOL first;
        if (!first) {
            first = YES;
            FILE *log = fopen("/tmp/native.log", "a");
            if (log) {
                fprintf(log, "%.3f [start] first byte of %s\n", CFAbsoluteTimeGetCurrent(),
                    [[[response URL] absoluteString] UTF8String] ?: "?");
                fclose(log);
            }
        }
    }
    if ([response statusCode] >= 400) {
        NSURLRequest *sent = [self request];
        NSURL *url = [response URL];
        fprintf(stderr, "[net] HTTP %ld %s %s%s\n", (long)[response statusCode],
            [[sent HTTPMethod] UTF8String] ?: "?",
            [[url host] UTF8String] ?: "?",
            [[url path] UTF8String] ?: "");
        NSDictionary *sentHeaders = [sent allHTTPHeaderFields];
        for (NSString *name in sentHeaders)
            fprintf(stderr, "[net]   > %s: %s\n", [name UTF8String],
                [[sentHeaders objectForKey:name] UTF8String] ?: "");
        NSData *body = [sent HTTPBody];
        if (body) {
            NSString *text = [[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] autorelease];
            fprintf(stderr, "[net]   > body(%u): %s\n", (unsigned)[body length],
                [[text substringToIndex:MIN((NSUInteger)300, [text length])] UTF8String] ?: "?");
        } else if ([sent HTTPBodyStream])
            fprintf(stderr, "[net]   > body: stream\n");
        else
            fprintf(stderr, "[net]   > body: none\n");
        NSDictionary *got = [response allHeaderFields];
        for (NSString *name in got)
            fprintf(stderr, "[net]   < %s: %s\n", [name UTF8String],
                [[[got objectForKey:name] description] UTF8String] ?: "");
    }
    [[self client] URLProtocol:self didReceiveResponse:response
        cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)deliverData:(NSData *)data
{
    if (_cancelled)
        return;
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)deliverFinish:(id)ignored
{
    if (!_background)
        shellNoteForegroundActivity();
    if (_cancelled)
        return;
    [[self client] URLProtocolDidFinishLoading:self];
}

- (void)deliverRedirect:(NSArray *)pair
{
    if (!_background)
        shellNoteForegroundActivity();
    if (_cancelled)
        return;
    [[self client] URLProtocol:self wasRedirectedToRequest:[pair objectAtIndex:0]
        redirectResponse:[pair objectAtIndex:1]];
}

- (void)deliverError:(NSError *)error
{
    if (!_background)
        shellNoteForegroundActivity();
    if (_cancelled)
        return;
    NSURL *url = [[self request] URL];
    fprintf(stderr, "[net] FAIL %s %s%s code %ld: %s\n",
        [[[self request] HTTPMethod] UTF8String] ?: "?",
        [[url host] UTF8String] ?: "?",
        [[url path] UTF8String] ?: "",
        (long)[error code],
        [[error localizedDescription] UTF8String] ?: "?");
    [[self client] URLProtocol:self didFailWithError:error];
}

- (void)stopLoading
{
    _cancelled = YES;
}

- (void)failWithMessage:(NSString *)message code:(NSInteger)code
{
    NSDictionary *info = [NSDictionary dictionaryWithObject:message ?: @"Load failed"
        forKey:NSLocalizedDescriptionKey];
    [self onClientThread:@selector(deliverError:)
        with:[NSError errorWithDomain:NSURLErrorDomain code:code userInfo:info]];
}

- (void)emitDecoded:(NSData *)data
{
    if (![data length])
        return;
    if (_transcodingImage) {
        [_imageBuffer appendData:data];
        return;
    }
    if (_writer && ![_writer appendBody:data]) {
        [_writer abandon];
        [_writer release];
        _writer = nil;
    }
    [self onClientThread:@selector(deliverData:) with:data];
}

- (BOOL)emitRaw:(NSData *)data
{
    if (!_inflating) {
        [self emitDecoded:data];
        return YES;
    }

    _inflater.next_in = (Bytef *)[data bytes];
    _inflater.avail_in = (uInt)[data length];

    unsigned char out[16384];
    int status;
    do {
        _inflater.next_out = out;
        _inflater.avail_out = sizeof(out);
        status = inflate(&_inflater, Z_NO_FLUSH);
        if (status != Z_OK && status != Z_STREAM_END && status != Z_BUF_ERROR) {
            if (gLog)
                fprintf(stderr, "[tls]   inflate failed: %d (%s)\n", status, _inflater.msg ?: "");
            return NO;
        }
        NSUInteger produced = sizeof(out) - _inflater.avail_out;
        if (produced)
            [self emitDecoded:[NSData dataWithBytes:out length:produced]];
    } while (status == Z_OK && (_inflater.avail_in || !_inflater.avail_out));

    return YES;
}

static const NSInteger kEnded = -1;
static const NSInteger kUndecodable = -2;

- (NSInteger)pumpFrom:(ModernTLSConnection *)connection limit:(NSUInteger)limit deliver:(BOOL)deliver
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSData *chunk = [connection readUpTo:limit];
    NSInteger taken = kEnded;
    if (chunk) {
        taken = (NSInteger)[chunk length];
        if (deliver && ![self emitRaw:chunk])
            taken = kUndecodable;
    }
    [pool release];
    return taken;
}

- (BOOL)readBodyFrom:(ModernTLSConnection *)connection
             framing:(ModernTLSFraming)framing
              length:(unsigned long long)length
             deliver:(BOOL)deliver
{
    if (framing == ModernTLSFramingNone)
        return YES;
    if (!deliver && (framing == ModernTLSFramingUntilClose || length > kDrainLimit))
        return NO;

    if (framing == ModernTLSFramingLength) {
        while (length) {
            if (_cancelled)
                return NO;
            NSInteger taken = [self pumpFrom:connection
                limit:(NSUInteger)MIN(length, (unsigned long long)65536) deliver:deliver];
            if (taken < 0)
                return NO;
            length -= taken;
        }
        return YES;
    }

    if (framing == ModernTLSFramingChunked) {
        char line[512];
        unsigned long long drained = 0;
        for (;;) {
            if (_cancelled)
                return NO;
            if (![connection readLine:line size:sizeof(line)])
                return NO;
            unsigned long long size = strtoull(line, NULL, 16);
            if (!size)
                break;
            drained += size;
            if (!deliver && drained > kDrainLimit)
                return NO;
            while (size) {
                NSInteger taken = [self pumpFrom:connection
                    limit:(NSUInteger)MIN(size, (unsigned long long)65536) deliver:deliver];
                if (taken < 0)
                    return NO;
                size -= taken;
            }
            if (![connection readLine:line size:sizeof(line)])
                return NO;
        }
        for (int field = 0; field < 64; field++) {
            if (![connection readLine:line size:sizeof(line)])
                return NO;
            if (!line[0])
                return YES;
        }
        return NO;
    }

    for (;;) {
        if (_cancelled)
            return NO;
        NSInteger taken = [self pumpFrom:connection limit:65536 deliver:deliver];
        if (taken == kEnded)
            return YES;
        if (taken < 0)
            return NO;
    }
}

- (NSMutableDictionary *)wireHeadersFor:(NSURLRequest *)request
{
    NSURL *url = [request URL];
    NSString *authority = [url port]
        ? [NSString stringWithFormat:@"%@:%@", [url host], [url port]] : [url host];

    NSMutableDictionary *wire = [NSMutableDictionary dictionary];
    [wire setObject:authority ?: @"" forKey:@"Host"];
    [wire setObject:@"keep-alive" forKey:@"Connection"];
    [wire setObject:@"gzip" forKey:@"Accept-Encoding"];

    NSDictionary *headers = [request allHTTPHeaderFields];
    for (NSString *field in headers) {
        if ([field caseInsensitiveCompare:@"Host"] == NSOrderedSame
            || [field caseInsensitiveCompare:@"Accept-Encoding"] == NSOrderedSame
            || [field caseInsensitiveCompare:@"Content-Length"] == NSOrderedSame
            || isHopByHop(field))
            continue;
        [wire setObject:[headers objectForKey:field] forKey:field];
    }

    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url];
    NSString *cookieHeader = [[NSHTTPCookie requestHeaderFieldsWithCookies:cookies] objectForKey:@"Cookie"];
    if ([cookieHeader length])
        [wire setObject:cookieHeader forKey:@"Cookie"];

    NSData *body = [self bodyForRequest:request];
    if (body)
        [wire setObject:[NSString stringWithFormat:@"%lu", (unsigned long)[body length]]
            forKey:@"Content-Length"];
    return wire;
}

static NSData *collectRequestBody(NSURLRequest *request)
{
    NSData *body = [request HTTPBody];
    if (body)
        return body;

    NSInputStream *stream = [request HTTPBodyStream];
    if (!stream)
        return nil;

    NSMutableData *collected = [NSMutableData data];
    [stream open];
    uint8_t buffer[8192];
    for (;;) {
        NSInteger got = [stream read:buffer maxLength:sizeof(buffer)];
        if (got <= 0)
            break;
        [collected appendBytes:buffer length:(NSUInteger)got];
    }
    [stream close];
    return collected;
}

- (NSData *)bodyForRequest:(NSURLRequest *)request
{
    if (!_requestBodyRead) {
        _requestBodyRead = YES;
        _requestBody = [collectRequestBody(request) retain];
    }
    return _requestBody;
}

- (NSData *)messageForRequest:(NSURLRequest *)request target:(NSString *)target
                      headers:(NSDictionary *)wire
{
    NSMutableString *head = [NSMutableString stringWithFormat:@"%@ %@ HTTP/1.1\r\n",
        [request HTTPMethod] ?: @"GET", target];
    [head appendFormat:@"Host: %@\r\n", [wire objectForKey:@"Host"]];
    for (NSString *field in wire) {
        if ([field caseInsensitiveCompare:@"Host"] == NSOrderedSame)
            continue;
        [head appendFormat:@"%@: %@\r\n", field, [wire objectForKey:field]];
    }
    [head appendString:@"\r\n"];

    NSMutableData *message = [NSMutableData dataWithData:[head dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *body = [self bodyForRequest:request];
    if ([body length])
        [message appendData:body];
    return message;
}

- (NSMutableURLRequest *)redirectedRequestTo:(NSURL *)target status:(NSInteger)status
{
    NSMutableURLRequest *next = [[[self request] mutableCopy] autorelease];
    [next setURL:target];
    [NSURLProtocol removePropertyForKey:kHandledKey inRequest:next];

    NSString *method = [next HTTPMethod] ?: @"GET";
    BOOL unsafe = [method caseInsensitiveCompare:@"GET"] != NSOrderedSame
        && [method caseInsensitiveCompare:@"HEAD"] != NSOrderedSame;
    if (status == 303 || ((status == 301 || status == 302) && unsafe)) {
        [next setHTTPMethod:@"GET"];
        [next setHTTPBody:nil];
        [next setValue:nil forHTTPHeaderField:@"Content-Type"];
    }
    return next;
}

- (BOOL)deliverEntry:(ModernTLSCacheEntry *)entry
{
    NSURL *url = [[self request] URL];
    NSHTTPURLResponse *response = [[[NSHTTPURLResponse alloc] initWithURL:url
        statusCode:entry->status HTTPVersion:@"HTTP/1.1" headerFields:entry->headers] autorelease];
    if (!response)
        return NO;

    NSString *location = headerValue(entry->headers, @"Location");
    if (entry->status >= 300 && entry->status < 400 && [location length]) {
        NSURL *target = [NSURL URLWithString:location relativeToURL:url];
        if (!target)
            return NO;
        [self onClientThread:@selector(deliverRedirect:) with:[NSArray arrayWithObjects:
            [self redirectedRequestTo:target status:entry->status], response, nil]];
        return YES;
    }

    utimes([entry->path fileSystemRepresentation], NULL);

    [self onClientThread:@selector(deliverResponse:) with:response];
    for (NSUInteger at = 0; at < entry->bodyLength; ) {
        if (_cancelled)
            return YES;
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSUInteger chunk = MIN(entry->bodyLength - at, (NSUInteger)65536);
        [self onClientThread:@selector(deliverData:)
            with:[entry->file subdataWithRange:NSMakeRange(entry->bodyOffset + at, chunk)]];
        [pool release];
        at += chunk;
    }
    [self onClientThread:@selector(deliverFinish:) with:nil];
    return YES;
}

- (BOOL)answerFromCache:(NSURLRequest *)request wire:(NSMutableDictionary *)wire
{
    if (!gCacheDirectory)
        return NO;
    if ([([request HTTPMethod] ?: @"GET") caseInsensitiveCompare:@"GET"] != NSOrderedSame)
        return NO;
    if (headerValue(wire, @"If-None-Match") || headerValue(wire, @"If-Modified-Since")
        || headerValue(wire, @"Range"))
        return NO;

    NSDictionary *requestDirectives = parseCacheControl(headerValue(wire, @"Cache-Control"));
    if ([requestDirectives objectForKey:@"no-store"])
        return NO;

    _cacheKey = [cacheKeyForRequest(request) copy];

    NSURLRequestCachePolicy policy = [request cachePolicy];
    if (policy == NSURLRequestReloadIgnoringLocalCacheData
        || policy == NSURLRequestReloadIgnoringLocalAndRemoteCacheData)
        return NO;

    NSString *path = cachePathForKey(_cacheKey);
    ModernTLSCacheEntry *entry = path ? readCacheEntry(path, _cacheKey) : nil;
    if (entry && !selectingHeadersMatch(entry->selecting, wire))
        entry = nil;

    if (policy == NSURLRequestReturnCacheDataElseLoad
        || policy == NSURLRequestReturnCacheDataDontLoad) {
        if (entry) {
            if ([self deliverEntry:entry]) {
                if (gLog)
                    fprintf(stderr, "[cache] served on request %s\n", [_cacheKey UTF8String]);
                return YES;
            }
            removeCacheEntry(_cacheKey);
        }
        if (policy == NSURLRequestReturnCacheDataDontLoad) {
            [self failWithMessage:@"Not in the cache, and the request forbids loading it"
                code:NSURLErrorResourceUnavailable];
            return YES;
        }
        return NO;
    }
    if (!entry)
        return NO;

    ModernTLSCacheVerdict verdict = verdictForEntry(entry, requestDirectives);
    if (policy == NSURLRequestReloadRevalidatingCacheData && verdict == ModernTLSCacheFresh)
        verdict = ModernTLSCacheValidate;

    if (verdict == ModernTLSCacheFresh) {
        if ([self deliverEntry:entry]) {
            if (gLog)
                fprintf(stderr, "[cache] hit %s\n", [_cacheKey UTF8String]);
            return YES;
        }
        removeCacheEntry(_cacheKey);
        return NO;
    }

    NSTimeInterval requestedAge = 0;
    BOOL clientWantsOrigin = [requestDirectives objectForKey:@"no-cache"] != nil
        || headerContains(wire, @"Pragma", @"no-cache")
        || (deltaSeconds(requestDirectives, @"max-age", &requestedAge) && requestedAge == 0);
    if (verdict != ModernTLSCacheFresh && !clientWantsOrigin
        && policy == NSURLRequestUseProtocolCachePolicy
        && shellPolicyAppliesTo(request, wire, entry, _cacheKey)) {
        if ([self deliverEntry:entry]) {
            if (gLog)
                fprintf(stderr, "[shell] served stale by policy, age %.0fs: %s\n",
                    entryAge(entry), [_cacheKey UTF8String]);
            shellQueueRevalidation(request, _cacheKey);
            return YES;
        }
        removeCacheEntry(_cacheKey);
        return NO;
    }

    if (verdict == ModernTLSCacheValidate) {
        NSString *tag = headerValue(entry->headers, @"ETag");
        NSString *modified = headerValue(entry->headers, @"Last-Modified");
        if ([tag length])
            [wire setObject:tag forKey:@"If-None-Match"];
        if ([modified length])
            [wire setObject:modified forKey:@"If-Modified-Since"];
        _validating = [entry retain];
        if (gLog)
            fprintf(stderr, "[cache] revalidating %s\n", [_cacheKey UTF8String]);
    }
    return NO;
}

- (NSData *)shrinkImageData:(NSData *)data
{
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data, NULL);
    if (!source)
        return nil;

    NSDictionary *thumbnailOptions = [NSDictionary dictionaryWithObjectsAndKeys:
        (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageAlways,
        (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
        [NSNumber numberWithInt:900], (id)kCGImageSourceThumbnailMaxPixelSize, nil];
    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (CFDictionaryRef)thumbnailOptions);
    CFRelease(source);
    if (!thumbnail)
        return nil;

    NSMutableData *out = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((CFMutableDataRef)out,
        kUTTypeJPEG, 1, NULL);
    if (!destination) {
        CGImageRelease(thumbnail);
        return nil;
    }
    NSDictionary *encodeOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.72f]
        forKey:(id)kCGImageDestinationLossyCompressionQuality];
    CGImageDestinationAddImage(destination, thumbnail, (CFDictionaryRef)encodeOptions);
    BOOL wrote = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(thumbnail);

    if (!wrote || ![out length] || [out length] >= [data length])
        return nil;
    return out;
}

- (ModernTLSExchange)exchangeOn:(ModernTLSConnection *)connection
                        message:(NSData *)message
                        request:(NSURLRequest *)request
{
    NSURL *url = [request URL];
    [connection beginExchange];
    _requestTime = nowSeconds();
    if (![connection writeData:message])
        return ModernTLSExchangeUnanswered;

    char line[8192];
    NSInteger status = 0;
    int major = 1, minor = 1;
    NSMutableDictionary *headers = nil;

    for (int interim = 0; interim < 8; interim++) {
        if (![connection readLine:line size:sizeof(line)]) {
            if (![connection hasRead])
                return ModernTLSExchangeUnanswered;
            [self failWithMessage:[NSString stringWithFormat:@"No reply from %@", [url host]]
                code:NSURLErrorNetworkConnectionLost];
            return ModernTLSExchangeSpent;
        }

        long code = 0;
        if (sscanf(line, "HTTP/%d.%d %ld", &major, &minor, &code) < 3) {
            [self failWithMessage:@"Malformed response" code:NSURLErrorBadServerResponse];
            return ModernTLSExchangeSpent;
        }
        status = code;

        headers = [NSMutableDictionary dictionary];
        BOOL complete = NO;
        for (int field = 0; field < 256; field++) {
            if (![connection readLine:line size:sizeof(line)])
                break;
            if (!line[0]) {
                complete = YES;
                break;
            }
            char *colon = strchr(line, ':');
            if (!colon)
                continue;
            *colon = 0;
            NSString *name = headerString(line);
            NSString *value = [headerString(colon + 1)
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (!name || !value)
                continue;
            NSString *existing = [headers objectForKey:name];
            [headers setObject:existing ? [existing stringByAppendingFormat:@", %@", value] : value
                forKey:name];
        }
        if (!complete) {
            [self failWithMessage:@"Malformed response" code:NSURLErrorBadServerResponse];
            return ModernTLSExchangeSpent;
        }

        if (status < 100 || status >= 200 || status == 101)
            break;
    }
    if (status >= 100 && status < 200 && status != 101) {
        [self failWithMessage:@"Nothing but interim replies" code:NSURLErrorBadServerResponse];
        return ModernTLSExchangeSpent;
    }
    NSTimeInterval receivedTime = nowSeconds();

    BOOL isHead = [[request HTTPMethod] caseInsensitiveCompare:@"HEAD"] == NSOrderedSame;
    BOOL bodiless = isHead || status == 204 || status == 304 || (status >= 100 && status < 200);

    ModernTLSFraming framing = ModernTLSFramingNone;
    unsigned long long length = 0;
    NSString *contentLength = headerValue(headers, @"Content-Length");
    if (bodiless)
        framing = ModernTLSFramingNone;
    else if (headerContains(headers, @"Transfer-Encoding", @"chunked"))
        framing = ModernTLSFramingChunked;
    else if ([contentLength length] && isdigit([contentLength characterAtIndex:0])) {
        framing = ModernTLSFramingLength;
        length = strtoull([contentLength UTF8String], NULL, 10);
    } else
        framing = ModernTLSFramingUntilClose;

    BOOL keepable = (major == 1 && minor >= 1)
        && !headerContains(headers, @"Connection", @"close")
        && framing != ModernTLSFramingUntilClose;

    if (gLog) {
        fprintf(stderr, "[tls] %s -> %ld  %s  %s\n", [[url absoluteString] UTF8String], (long)status,
            framing == ModernTLSFramingChunked ? "chunked"
                : framing == ModernTLSFramingLength ? [contentLength UTF8String]
                : framing == ModernTLSFramingNone ? "no body" : "until close",
            keepable ? "keep-alive" : "closing");
        fflush(stderr);
    }

    NSArray *setCookies = [NSHTTPCookie cookiesWithResponseHeaderFields:headers forURL:url];
    if ([setCookies count])
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:setCookies forURL:url mainDocumentURL:nil];

    invalidateCacheForRequest(request, headers, status);

    if (status == 304 && _validating) {
        NSString *tag = headerValue(headers, @"ETag");
        NSString *stored = headerValue(_validating->headers, @"ETag");
        ModernTLSCacheEntry *entry = [[_validating retain] autorelease];
        [_validating release];
        _validating = nil;

        if ([tag length] && [stored length] && ![tag isEqualToString:stored]) {
            removeCacheEntry(_cacheKey);
            return ModernTLSExchangeMismatched;
        }

        mergeStoredHeaders(entry, headers);
        entry->requested = _requestTime;
        entry->received = receivedTime;
        if (![self deliverEntry:entry]) {
            removeCacheEntry(_cacheKey);
            return ModernTLSExchangeMismatched;
        }
        if (gLog)
            fprintf(stderr, "[cache] validated %s\n", [_cacheKey UTF8String]);
        rewriteCacheEntry(entry, _cacheKey);
        return keepable ? ModernTLSExchangeReusable : ModernTLSExchangeSpent;
    }
    [_validating release];
    _validating = nil;

    BOOL encoded = !bodiless && headerContains(headers, @"Content-Encoding", @"gzip");

    NSMutableDictionary *visible = [NSMutableDictionary dictionaryWithCapacity:[headers count]];
    for (NSString *field in headers) {
        if (isHopByHop(field))
            continue;
        if (encoded && ([field caseInsensitiveCompare:@"Content-Encoding"] == NSOrderedSame
            || [field caseInsensitiveCompare:@"Content-Length"] == NSOrderedSame))
            continue;
        [visible setObject:[headers objectForKey:field] forKey:field];
    }

    if (_cacheKey) {
        NSDictionary *directives = parseCacheControl(headerValue(headers, @"Cache-Control"));
        if (responseIsStorable(status, headers, directives)) {
            NSMutableDictionary *kept = [NSMutableDictionary dictionaryWithDictionary:visible];
            for (NSString *field in [kept allKeys]) {
                if ([field caseInsensitiveCompare:@"Set-Cookie"] == NSOrderedSame)
                    [kept removeObjectForKey:field];
            }
            _writer = [[ModernTLSCacheWriter alloc] initForKey:_cacheKey
                metadata:[NSDictionary dictionaryWithObjectsAndKeys:
                    _cacheKey, @"url",
                    [NSNumber numberWithInteger:status], @"status",
                    kept, @"headers",
                    selectingHeaders(headerValue(headers, @"Vary"), _wireHeaders), @"vary",
                    [NSNumber numberWithDouble:_requestTime], @"requested",
                    [NSNumber numberWithDouble:receivedTime], @"received", nil]];
        } else if (status >= 200 && status < 400) {
            removeCacheEntry(_cacheKey);
        }
    }

    NSString *location = headerValue(headers, @"Location");
    if (status >= 300 && status < 400 && [location length]) {
        NSURL *target = [NSURL URLWithString:location relativeToURL:url];
        if (!target) {
            [self failWithMessage:@"Unusable redirect" code:NSURLErrorBadServerResponse];
            return ModernTLSExchangeSpent;
        }
        if (_writer) {
            [_writer commit];
            [_writer release];
            _writer = nil;
        }
        if (keepable)
            keepable = [self readBodyFrom:connection framing:framing length:length deliver:NO];

        NSHTTPURLResponse *response = [[[NSHTTPURLResponse alloc] initWithURL:url statusCode:status
            HTTPVersion:@"HTTP/1.1" headerFields:visible] autorelease];
        [self onClientThread:@selector(deliverRedirect:)
            with:[NSArray arrayWithObjects:[self redirectedRequestTo:target status:status], response, nil]];
        return keepable ? ModernTLSExchangeReusable : ModernTLSExchangeSpent;
    }

    if (encoded) {
        memset(&_inflater, 0, sizeof(_inflater));
        if (inflateInit2(&_inflater, 16 + MAX_WBITS) != Z_OK) {
            [self failWithMessage:@"Cannot decode gzip" code:NSURLErrorCannotDecodeContentData];
            return ModernTLSExchangeSpent;
        }
        _inflating = YES;
    }

    NSString *contentType = headerValue(headers, @"Content-Type");
    NSString *method = [[self request] HTTPMethod] ?: @"GET";
    BOOL transcodable = status == 200
        && [method caseInsensitiveCompare:@"GET"] == NSOrderedSame
        && framing == ModernTLSFramingLength
        && [[contentType lowercaseString] hasPrefix:@"image/"]
        && !headerContains(headers, @"Content-Type", @"svg")
        && length > 4096
        && length <= kImageTranscodeSizeLimit;

    if (transcodable) {
        _transcodingImage = YES;
        _imageBuffer = [[NSMutableData alloc] initWithCapacity:(NSUInteger)length];
        if (_writer) {
            [_writer abandon];
            [_writer release];
            _writer = nil;
        }
    } else {
        NSHTTPURLResponse *response = [[[NSHTTPURLResponse alloc] initWithURL:url statusCode:status
            HTTPVersion:@"HTTP/1.1" headerFields:visible] autorelease];
        [self onClientThread:@selector(deliverResponse:) with:response];
    }

    BOOL whole = [self readBodyFrom:connection framing:framing length:length deliver:YES];

    if (_inflating) {
        if (gLog)
            fprintf(stderr, "[tls]   inflated %lu -> %lu bytes\n",
                (unsigned long)_inflater.total_in, (unsigned long)_inflater.total_out);
        inflateEnd(&_inflater);
        _inflating = NO;
    }

    if (_transcodingImage) {
        NSData *original = [_imageBuffer autorelease];
        _imageBuffer = nil;
        _transcodingImage = NO;

        NSData *shrunk = (whole && !_cancelled) ? [self shrinkImageData:original] : nil;
        NSMutableDictionary *finalHeaders = [NSMutableDictionary dictionaryWithDictionary:visible];
        NSData *deliverable = original;
        if (shrunk) {
            [finalHeaders setObject:@"image/jpeg" forKey:@"Content-Type"];
            [finalHeaders setObject:[NSString stringWithFormat:@"%lu", (unsigned long)[shrunk length]]
                forKey:@"Content-Length"];
            deliverable = shrunk;
        }
        NSHTTPURLResponse *response = [[[NSHTTPURLResponse alloc] initWithURL:url statusCode:status
            HTTPVersion:@"HTTP/1.1" headerFields:finalHeaders] autorelease];
        [self onClientThread:@selector(deliverResponse:) with:response];
        if ([deliverable length])
            [self onClientThread:@selector(deliverData:) with:deliverable];
    }

    if (_writer) {
        if (whole && !_cancelled)
            [_writer commit];
        else
            [_writer abandon];
        [_writer release];
        _writer = nil;
    }

    if (!whole) {
        if (!_cancelled)
            [self failWithMessage:[NSString stringWithFormat:@"Reply from %@ ended early", [url host]]
                code:NSURLErrorNetworkConnectionLost];
        return ModernTLSExchangeSpent;
    }

    [self onClientThread:@selector(deliverFinish:) with:nil];
    return keepable ? ModernTLSExchangeReusable : ModernTLSExchangeSpent;
}

- (void)performRequest:(NSURLRequest *)request
{
    if (!_background)
        shellNoteForegroundActivity();
    NSURL *url = [request URL];
    NSString *host = [url host];
    if (![host length]) {
        [self failWithMessage:@"No host in URL" code:NSURLErrorBadURL];
        return;
    }
    NSString *port = [url port] ? [[url port] stringValue] : @"443";
    NSString *key = [NSString stringWithFormat:@"%@:%@", [host lowercaseString], port];

    _wireHeaders = [[self wireHeadersFor:request] retain];
    if ([self answerFromCache:request wire:_wireHeaders])
        return;

    NSData *message = [self messageForRequest:request target:requestTarget(url)
        headers:_wireHeaders];

    ModernTLSConnection *connection = takeIdleConnection(key);
    BOOL pooled = connection != nil;

    for (;;) {
        if (!connection) {
            NSString *reason = nil;
            NSInteger code = NSURLErrorCannotConnectToHost;
            connection = [ModernTLSConnection connectionToHost:host port:port key:key
                message:&reason code:&code];
            if (!connection) {
                [self failWithMessage:reason code:code];
                return;
            }
        }

        ModernTLSExchange outcome = [self exchangeOn:connection message:message request:request];
        if (outcome == ModernTLSExchangeMismatched) {
            [connection shutdown];
            [connection release];
            connection = nil;
            pooled = NO;
            [_wireHeaders removeObjectForKey:@"If-None-Match"];
            [_wireHeaders removeObjectForKey:@"If-Modified-Since"];
            message = [self messageForRequest:request target:requestTarget(url)
                headers:_wireHeaders];
            continue;
        }
        if (outcome == ModernTLSExchangeUnanswered) {
            [connection shutdown];
            [connection release];
            connection = nil;
            if (pooled) {
                if (gLog)
                    fprintf(stderr, "[tls] %s was closed; retrying on a new connection\n", [key UTF8String]);
                pooled = NO;
                continue;
            }
            [self failWithMessage:[NSString stringWithFormat:@"Connection to %@ closed before a reply", host]
                code:NSURLErrorNetworkConnectionLost];
            return;
        }

        if (outcome == ModernTLSExchangeReusable && !_cancelled)
            returnIdleConnection(connection);
        else
            [connection shutdown];
        [connection release];
        return;
    }
}

@end
