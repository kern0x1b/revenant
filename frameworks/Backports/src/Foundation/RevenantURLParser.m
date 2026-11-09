#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "RevenantURLParser.h"

typedef struct {
    uint64_t high;
    uint64_t low;
} RevenantMask;

static const RevenantMask revenant_mask_scheme = {0x07fffffe07fffffeULL, 0x03ff680000000000ULL};
static const RevenantMask revenant_mask_user = {0x47fffffe87fffffeULL, 0x2bff7fd200000000ULL};
static const RevenantMask revenant_mask_host_future = {0x47fffffe87fffffeULL, 0x2fff7fd200000000ULL};
static const RevenantMask revenant_mask_host = {0x47fffffe87fffffeULL, 0x2bff7fd200000000ULL};
static const RevenantMask revenant_mask_zone = {0x47fffffe87fffffeULL, 0x03ff600000000000ULL};
static const RevenantMask revenant_mask_path = {0x47fffffe87ffffffULL, 0x2fffffd200000000ULL};
static const RevenantMask revenant_mask_first_segment = {0x47fffffe87ffffffULL, 0x2bffffd200000000ULL};
static const RevenantMask revenant_mask_query = {0x47fffffe87ffffffULL, 0xafffffd200000000ULL};
static const RevenantMask revenant_mask_reserved = {0x47fffffeafffffffULL, 0xafffffda00000000ULL};

enum {
    RevenantParseEmptyScheme = 1 << 0,
    RevenantParseNoHeuristics = 1 << 1,
    RevenantParsePortValid = 1 << 2,
    RevenantParseExactCase = 1 << 3
};

static BOOL revenant_mask_has(RevenantMask mask, uint8_t byte)
{
    if (byte >= 128)
        return NO;
    return byte < 64 ? ((mask.low >> byte) & 1) != 0 : ((mask.high >> (byte - 64)) & 1) != 0;
}

typedef struct {
    long start;
    long end;
} RevenantSpan;

typedef struct {
    RevenantSpan scheme;
    RevenantSpan user;
    RevenantSpan password;
    RevenantSpan host;
    RevenantSpan port;
    RevenantSpan path;
    RevenantSpan query;
    RevenantSpan fragment;
    BOOL ipLiteral;
} RevenantInfo;

typedef struct {
    uint8_t *bytes;
    long length;
    long capacity;
} RevenantBuffer;

static const RevenantSpan revenant_absent = {-1, -1};

static BOOL revenant_present(RevenantSpan span)
{
    return span.start >= 0;
}

static long revenant_span_length(RevenantSpan span)
{
    return span.end - span.start;
}

static void revenant_buffer_append(RevenantBuffer *buffer, const uint8_t *bytes, long length)
{
    if (buffer->length + length > buffer->capacity) {
        long capacity = buffer->capacity ? buffer->capacity : 64;
        while (capacity < buffer->length + length)
            capacity *= 2;
        buffer->bytes = realloc(buffer->bytes, (size_t)capacity);
        buffer->capacity = capacity;
    }
    memcpy(buffer->bytes + buffer->length, bytes, (size_t)length);
    buffer->length += length;
}

static void revenant_buffer_append_text(RevenantBuffer *buffer, const char *text)
{
    revenant_buffer_append(buffer, (const uint8_t *)text, (long)strlen(text));
}

static void revenant_buffer_append_byte(RevenantBuffer *buffer, uint8_t byte)
{
    revenant_buffer_append(buffer, &byte, 1);
}

static void revenant_buffer_append_span(RevenantBuffer *buffer, const uint8_t *bytes, RevenantSpan span)
{
    revenant_buffer_append(buffer, bytes + span.start, revenant_span_length(span));
}

static BOOL revenant_hex_digit(uint8_t byte)
{
    return (byte >= '0' && byte <= '9') || (byte >= 'A' && byte <= 'F') || (byte >= 'a' && byte <= 'f');
}

static NSData *revenant_utf8(NSString *string)
{
    NSUInteger length = string.length;
    NSMutableData *data = [NSMutableData dataWithCapacity:length * 3];
    for (NSUInteger index = 0; index < length; index++) {
        uint32_t code = [string characterAtIndex:index];
        if (code >= 0xD800 && code < 0xDC00 && index + 1 < length) {
            unichar low = [string characterAtIndex:index + 1];
            if (low >= 0xDC00 && low < 0xE000) {
                code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
                index++;
            }
        }
        if (code >= 0xD800 && code < 0xE000)
            code = 0xFFFD;
        uint8_t bytes[4];
        NSUInteger count;
        if (code < 0x80) {
            bytes[0] = (uint8_t)code;
            count = 1;
        } else if (code < 0x800) {
            bytes[0] = (uint8_t)(0xC0 | (code >> 6));
            bytes[1] = (uint8_t)(0x80 | (code & 0x3F));
            count = 2;
        } else if (code < 0x10000) {
            bytes[0] = (uint8_t)(0xE0 | (code >> 12));
            bytes[1] = (uint8_t)(0x80 | ((code >> 6) & 0x3F));
            bytes[2] = (uint8_t)(0x80 | (code & 0x3F));
            count = 3;
        } else {
            bytes[0] = (uint8_t)(0xF0 | (code >> 18));
            bytes[1] = (uint8_t)(0x80 | ((code >> 12) & 0x3F));
            bytes[2] = (uint8_t)(0x80 | ((code >> 6) & 0x3F));
            bytes[3] = (uint8_t)(0x80 | (code & 0x3F));
            count = 4;
        }
        [data appendBytes:bytes length:count];
    }
    return data;
}

static BOOL revenant_valid_run(const uint8_t *bytes, RevenantSpan span, RevenantMask mask, BOOL percentAllowed)
{
    long hexRequired = 0;
    for (long index = span.start; index < span.end; index++) {
        uint8_t byte = bytes[index];
        if (!percentAllowed) {
            if (!revenant_mask_has(mask, byte))
                return NO;
            continue;
        }
        if (byte >= 128)
            return NO;
        if (byte == '%') {
            if (hexRequired != 0)
                return NO;
            hexRequired = 2;
        } else if (!revenant_mask_has(mask, byte)) {
            return NO;
        } else if (hexRequired > 0) {
            if (!revenant_hex_digit(byte))
                return NO;
            hexRequired--;
        }
    }
    return hexRequired == 0;
}

static void revenant_percent_encode(RevenantBuffer *out, const uint8_t *bytes, RevenantSpan span, RevenantMask mask, BOOL skipEncoded)
{
    static const char digits[] = "0123456789ABCDEF";
    for (long index = span.start; index < span.end; index++) {
        uint8_t byte = bytes[index];
        if (revenant_mask_has(mask, byte)) {
            revenant_buffer_append_byte(out, byte);
        } else if (skipEncoded && byte == '%' && index + 2 < span.end && revenant_hex_digit(bytes[index + 1]) && revenant_hex_digit(bytes[index + 2])) {
            revenant_buffer_append(out, bytes + index, 3);
            index += 2;
        } else {
            uint8_t escape[3] = {'%', (uint8_t)digits[byte >> 4], (uint8_t)digits[byte & 0xF]};
            revenant_buffer_append(out, escape, 3);
        }
    }
}

static BOOL revenant_valid_scheme_span(const uint8_t *bytes, RevenantSpan span, BOOL allowEmpty)
{
    if (revenant_span_length(span) == 0)
        return allowEmpty;
    if (bytes[span.start] < 'A')
        return NO;
    return revenant_valid_run(bytes, span, revenant_mask_scheme, NO);
}

static BOOL revenant_span_named(const uint8_t *bytes, RevenantSpan span, const char *name, BOOL exactCase)
{
    long length = (long)strlen(name);
    if (revenant_span_length(span) != length)
        return NO;
    for (long offset = 0; offset < length; offset++) {
        uint8_t byte = bytes[span.start + offset];
        if (!exactCase && byte >= 'A' && byte <= 'Z')
            byte += 32;
        if (byte != (uint8_t)name[offset])
            return NO;
    }
    return YES;
}

static BOOL revenant_valid_port_span(const uint8_t *bytes, RevenantSpan port, RevenantSpan scheme, unsigned options)
{
    BOOL digits = YES;
    for (long index = port.start; index < port.end; index++) {
        if (bytes[index] < '0' || bytes[index] > '9')
            digits = NO;
    }
    if (digits)
        return YES;
    if (!revenant_present(scheme) || !revenant_span_named(bytes, scheme, "addressbook", (options & RevenantParseExactCase) != 0))
        return NO;
    return (options & RevenantParsePortValid) == 0 || revenant_valid_run(bytes, port, revenant_mask_reserved, YES);
}

static long revenant_find(const uint8_t *bytes, long start, long end, uint8_t target)
{
    for (long index = start; index < end; index++) {
        if (bytes[index] == target)
            return index;
    }
    return -1;
}

static long revenant_find_last(const uint8_t *bytes, long start, long end, uint8_t target)
{
    for (long index = end; index > start; index--) {
        if (bytes[index - 1] == target)
            return index - 1;
    }
    return -1;
}

static BOOL revenant_parse_authority(const uint8_t *bytes, long start, long end, RevenantInfo *info, unsigned options)
{
    long hostStart = start;
    long hostEnd = end;
    long at = revenant_find_last(bytes, start, end, '@');
    if (at >= 0) {
        long colon = revenant_find(bytes, start, at, ':');
        if (colon >= 0) {
            info->user = (RevenantSpan){start, colon};
            info->password = (RevenantSpan){colon + 1, at};
        } else {
            info->user = (RevenantSpan){start, at};
        }
        hostStart = at + 1;
    }
    long close = hostStart != end && bytes[hostStart] == '[' ? revenant_find(bytes, hostStart, end, ']') : -1;
    if (close >= 0) {
        info->ipLiteral = YES;
        hostEnd = close + 1;
        if (hostEnd != end) {
            if (bytes[hostEnd] != ':')
                return NO;
            info->port = (RevenantSpan){hostEnd + 1, end};
        }
    } else {
        long colon = revenant_find(bytes, hostStart, end, ':');
        if (colon >= 0) {
            hostEnd = colon;
            if (colon + 1 != end || (options & RevenantParseEmptyScheme))
                info->port = (RevenantSpan){colon + 1, end};
        }
    }
    info->host = (RevenantSpan){hostStart, hostEnd};
    return YES;
}

static BOOL revenant_parse_bytes(const uint8_t *bytes, long length, unsigned options, RevenantInfo *info)
{
    BOOL allowEmptyScheme = (options & RevenantParseEmptyScheme) != 0;
    BOOL heuristics = (options & RevenantParseNoHeuristics) == 0;
    memset(info, 0, sizeof(*info));
    info->scheme = info->user = info->password = info->host = info->port = info->path = info->query = info->fragment = revenant_absent;
    if (length == 0) {
        info->path = (RevenantSpan){0, 0};
        return YES;
    }
    long index = 0;
    while (index != length) {
        uint8_t byte = bytes[index];
        if (byte == ':') {
            if (index != 0 || allowEmptyScheme) {
                info->scheme = (RevenantSpan){0, index};
                index++;
                if (index == length) {
                    if (!revenant_valid_scheme_span(bytes, info->scheme, allowEmptyScheme))
                        return NO;
                    info->path = (RevenantSpan){length, length};
                    return YES;
                }
            }
            break;
        } else if (byte == '/' || byte == '?' || byte == '#' || (heuristics && (byte == '[' || byte == ']' || byte == '@'))) {
            index = 0;
            break;
        }
        index++;
    }
    if (revenant_present(info->scheme) && !revenant_valid_scheme_span(bytes, info->scheme, allowEmptyScheme))
        return NO;
    if (index == length)
        index = 0;
    if (index + 1 < length && bytes[index] == '/' && bytes[index + 1] == '/') {
        index += 2;
        long authorityStart = index;
        while (index != length && bytes[index] != '/' && bytes[index] != '?' && bytes[index] != '#')
            index++;
        if (index == authorityStart) {
            info->host = (RevenantSpan){authorityStart, index};
        } else {
            if (!revenant_parse_authority(bytes, authorityStart, index, info, options))
                return NO;
            if (revenant_present(info->port) && !revenant_valid_port_span(bytes, info->port, info->scheme, options))
                return NO;
        }
    }
    long pathStart = index;
    while (index != length && bytes[index] != '?' && bytes[index] != '#')
        index++;
    info->path = (RevenantSpan){pathStart, index};
    if (index == length)
        return YES;
    if (bytes[index] == '?') {
        long queryStart = index + 1;
        long pound = revenant_find(bytes, queryStart, length, '#');
        if (pound >= 0) {
            info->query = (RevenantSpan){queryStart, pound};
            info->fragment = (RevenantSpan){pound + 1, length};
        } else {
            info->query = (RevenantSpan){queryStart, length};
        }
    } else {
        info->fragment = (RevenantSpan){index + 1, length};
    }
    return YES;
}

static BOOL revenant_parse_compatibility(const uint8_t *bytes, long length, RevenantInfo *info)
{
    memset(info, 0, sizeof(*info));
    info->scheme = info->user = info->password = info->host = info->port = info->path = info->query = info->fragment = revenant_absent;
    if (length == 0) {
        info->path = (RevenantSpan){0, 0};
        return YES;
    }
    long index = 0;
    if ((bytes[0] >= 'A' && bytes[0] <= 'Z') || (bytes[0] >= 'a' && bytes[0] <= 'z')) {
        index = 1;
        while (index != length) {
            if (bytes[index] == ':') {
                info->scheme = (RevenantSpan){0, index};
                index++;
                if (index == length) {
                    info->path = (RevenantSpan){length, length};
                    return YES;
                }
                break;
            } else if (!revenant_mask_has(revenant_mask_scheme, bytes[index])) {
                index = 0;
                break;
            }
            index++;
        }
    } else if (bytes[0] == ':') {
        info->scheme = (RevenantSpan){0, 0};
        index = 1;
    }
    if (index == length) {
        info->path = (RevenantSpan){0, length};
        return YES;
    }
    if (index + 1 < length && bytes[index] == '/' && bytes[index + 1] == '/') {
        index += 2;
        long authorityStart = index;
        while (index != length && bytes[index] != '/' && bytes[index] != '?' && bytes[index] != '#')
            index++;
        if (index == authorityStart) {
            info->host = (RevenantSpan){authorityStart, index};
        } else {
            long hostStart = authorityStart;
            long hostEnd = index;
            long at = revenant_find_last(bytes, authorityStart, index, '@');
            if (at >= 0) {
                long colon = revenant_find(bytes, authorityStart, at, ':');
                if (colon >= 0) {
                    info->user = (RevenantSpan){authorityStart, colon};
                    info->password = (RevenantSpan){colon + 1, at};
                } else {
                    info->user = (RevenantSpan){authorityStart, at};
                }
                hostStart = at + 1;
            }
            long close = hostStart != index && bytes[hostStart] == '[' ? revenant_find(bytes, hostStart, index, ']') : -1;
            if (close >= 0) {
                info->ipLiteral = YES;
                hostEnd = close + 1;
                if (hostEnd != index) {
                    if (bytes[hostEnd] != ':')
                        return NO;
                    info->port = (RevenantSpan){hostEnd + 1, index};
                }
            } else {
                long colon = revenant_find(bytes, hostStart, index, ':');
                if (colon >= 0) {
                    hostEnd = colon;
                    info->port = (RevenantSpan){colon + 1, index};
                }
            }
            info->host = (RevenantSpan){hostStart, hostEnd};
            if (revenant_present(info->port)) {
                for (long digit = info->port.start; digit < info->port.end; digit++) {
                    if (bytes[digit] < '0' || bytes[digit] > '9')
                        return NO;
                }
            }
        }
    }
    long pathStart = index;
    while (index != length && bytes[index] != '?' && bytes[index] != '#')
        index++;
    info->path = (RevenantSpan){pathStart, index};
    if (index == length)
        return YES;
    if (bytes[index] == '?') {
        long queryStart = index + 1;
        long pound = revenant_find(bytes, queryStart, length, '#');
        if (pound >= 0) {
            info->query = (RevenantSpan){queryStart, pound};
            info->fragment = (RevenantSpan){pound + 1, length};
        } else {
            info->query = (RevenantSpan){queryStart, length};
        }
    } else {
        info->fragment = (RevenantSpan){index + 1, length};
    }
    return YES;
}

static BOOL revenant_looks_like_literal(const uint8_t *bytes, RevenantSpan host)
{
    return revenant_span_length(host) > 0 && bytes[host.start] == '[' && bytes[host.end - 1] == ']';
}

static BOOL revenant_valid_literal(const uint8_t *bytes, RevenantSpan host)
{
    RevenantSpan inner = {host.start + 1, host.end - 1};
    long percent = revenant_find(bytes, inner.start, inner.end, '%');
    if (percent < 0)
        return revenant_valid_run(bytes, inner, revenant_mask_host_future, NO);
    if (percent + 2 >= host.end || bytes[percent + 1] != '2' || bytes[percent + 2] != '5')
        return NO;
    return revenant_valid_run(bytes, (RevenantSpan){inner.start, percent}, revenant_mask_host_future, NO) && revenant_valid_run(bytes, (RevenantSpan){percent + 3, inner.end}, revenant_mask_zone, YES);
}

static BOOL revenant_valid_host_span(const uint8_t *bytes, RevenantSpan host)
{
    if (revenant_looks_like_literal(bytes, host))
        return revenant_valid_literal(bytes, host);
    return revenant_valid_run(bytes, host, revenant_mask_host, YES);
}

typedef NS_OPTIONS(unsigned, RevenantInvalid) {
    RevenantInvalidUser = 1 << 0,
    RevenantInvalidPassword = 1 << 1,
    RevenantInvalidHost = 1 << 2,
    RevenantInvalidPath = 1 << 3,
    RevenantInvalidQuery = 1 << 4,
    RevenantInvalidFragment = 1 << 5
};

static RevenantInvalid revenant_invalid_components(const uint8_t *bytes, const RevenantInfo *info, RevenantMask userinfo)
{
    RevenantInvalid invalid = 0;
    if (revenant_present(info->user) && !revenant_valid_run(bytes, info->user, userinfo, YES))
        invalid |= RevenantInvalidUser;
    if (revenant_present(info->password) && !revenant_valid_run(bytes, info->password, userinfo, YES))
        invalid |= RevenantInvalidPassword;
    if (revenant_present(info->host) && !revenant_valid_host_span(bytes, info->host))
        invalid |= RevenantInvalidHost;
    if (!revenant_valid_run(bytes, info->path, revenant_mask_path, YES))
        invalid |= RevenantInvalidPath;
    if (revenant_present(info->query) && !revenant_valid_run(bytes, info->query, revenant_mask_query, YES))
        invalid |= RevenantInvalidQuery;
    if (revenant_present(info->fragment) && !revenant_valid_run(bytes, info->fragment, revenant_mask_query, YES))
        invalid |= RevenantInvalidFragment;
    return invalid;
}

typedef struct {
    void *(*open)(uint32_t options, int32_t *status);
    int32_t (*toASCII)(void *transcoder, const uint16_t *name, int32_t length, uint16_t *destination, int32_t capacity, void *info, int32_t *status);
    int32_t (*toUnicode)(void *transcoder, const uint16_t *name, int32_t length, uint16_t *destination, int32_t capacity, void *info, int32_t *status);
    void *transcoder;
} RevenantIDNA;

typedef struct {
    int16_t size;
    int8_t transitionalDifferent;
    int8_t reservedB3;
    uint32_t errors;
    int32_t reservedI2;
    int32_t reservedI3;
} RevenantIDNAInfo;

static const RevenantIDNA *revenant_idna(void)
{
    static RevenantIDNA functions;
    static BOOL available;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *library = dlopen("/usr/lib/libicucore.dylib", RTLD_LAZY);
        if (!library)
            library = RTLD_DEFAULT;
        functions.open = dlsym(library, "uidna_openUTS46");
        functions.toASCII = dlsym(library, "uidna_nameToASCII");
        functions.toUnicode = dlsym(library, "uidna_nameToUnicode");
        if (!functions.open || !functions.toASCII || !functions.toUnicode)
            return;
        int32_t status = 0;
        functions.transcoder = functions.open(0x4 | 0x8 | 0x10 | 0x20, &status);
        available = status <= 0 && functions.transcoder != NULL;
    });
    return available ? &functions : NULL;
}

static NSString *revenant_idna_convert(NSString *host, BOOL toASCII)
{
    const RevenantIDNA *idna = revenant_idna();
    NSUInteger units = host.length;
    if (!idna || units == 0 || units > 2048)
        return nil;
    uint16_t input[2048];
    uint16_t output[2048];
    [host getCharacters:input range:NSMakeRange(0, units)];
    RevenantIDNAInfo info = {(int16_t)sizeof(RevenantIDNAInfo), 0, 0, 0, 0, 0};
    int32_t status = 0;
    int32_t converted = (toASCII ? idna->toASCII : idna->toUnicode)(idna->transcoder, input, (int32_t)units, output, 2048, &info, &status);
    uint32_t allowed = toASCII ? 0 : (0x1 | 0x2 | 0x4 | 0x8 | 0x10 | 0x20);
    if (status > 0 || (info.errors & ~allowed) != 0 || converted <= 0)
        return nil;
    BOOL equal = converted == (int32_t)units;
    for (int32_t index = 0; equal && index < converted; index++) {
        if (input[index] == output[index])
            continue;
        if (input[index] >= 'A' && input[index] <= 'Z' && input[index] + 32 == output[index])
            continue;
        equal = NO;
    }
    return equal ? host : [NSString stringWithCharacters:output length:(NSUInteger)converted];
}

NSString *revenant_url_host_unicode(NSString *host)
{
    return revenant_idna_convert(host, NO);
}

static NSData *revenant_idna_encode(const uint8_t *bytes, RevenantSpan host)
{
    NSString *text = [[NSString alloc] initWithBytes:bytes + host.start length:(NSUInteger)revenant_span_length(host) encoding:NSUTF8StringEncoding];
    return text ? revenant_utf8(revenant_idna_convert(text, YES) ?: @"") : nil;
}

static BOOL revenant_scheme_listed(const uint8_t *bytes, RevenantSpan scheme, const char *const *names, size_t count)
{
    if (!revenant_present(scheme))
        return NO;
    for (size_t index = 0; index < count; index++) {
        if (revenant_span_named(bytes, scheme, names[index], NO))
            return YES;
    }
    return NO;
}

static BOOL revenant_percent_encodes_host(const uint8_t *bytes, RevenantSpan host, RevenantSpan scheme)
{
    static const char *const names[] = {"tel", "telemergencycall", "telprompt", "callto", "facetime", "facetime-prompt", "facetime-audio", "facetime-audio-prompt", "imap", "pop",
                                        "addressbook", "contact", "phasset", "http+unix", "https+unix", "ws+unix", "wss+unix"};
    if (!revenant_idna())
        return YES;
    if (revenant_looks_like_literal(bytes, host))
        return YES;
    return revenant_scheme_listed(bytes, scheme, names, sizeof(names) / sizeof(names[0]));
}

static BOOL revenant_encode_host(RevenantBuffer *out, const uint8_t *bytes, RevenantSpan host, BOOL skipEncoded)
{
    if (revenant_span_length(host) == 0)
        return YES;
    if (!revenant_looks_like_literal(bytes, host)) {
        revenant_percent_encode(out, bytes, host, revenant_mask_host, skipEncoded);
        return YES;
    }
    if (skipEncoded) {
        revenant_buffer_append_byte(out, '[');
        revenant_percent_encode(out, bytes, (RevenantSpan){host.start + 1, host.end - 1}, revenant_mask_host, YES);
        revenant_buffer_append_byte(out, ']');
        return YES;
    }
    long percent = revenant_find(bytes, host.start, host.end, '%');
    if (percent < 0)
        return revenant_valid_literal(bytes, host) ? (revenant_buffer_append_span(out, bytes, host), YES) : NO;
    revenant_buffer_append(out, bytes + host.start, percent - host.start);
    revenant_percent_encode(out, bytes, (RevenantSpan){percent, host.end - 1}, revenant_mask_zone, NO);
    revenant_buffer_append_byte(out, ']');
    return YES;
}

static void revenant_encode_path(RevenantBuffer *out, const uint8_t *bytes, RevenantSpan path)
{
    if (revenant_span_length(path) == 0)
        return;
    long slash = revenant_find(bytes, path.start, path.end, '/');
    if (slash < 0) {
        revenant_percent_encode(out, bytes, path, revenant_mask_first_segment, NO);
        return;
    }
    if (slash == path.start) {
        revenant_percent_encode(out, bytes, path, revenant_mask_path, NO);
        return;
    }
    revenant_percent_encode(out, bytes, (RevenantSpan){path.start, slash}, revenant_mask_first_segment, NO);
    revenant_percent_encode(out, bytes, (RevenantSpan){slash, path.end}, revenant_mask_path, NO);
}

static BOOL revenant_swift_integer(const uint8_t *bytes, RevenantSpan span, long long *value)
{
    long index = span.start;
    if (index == span.end)
        return NO;
    BOOL negative = NO;
    if (bytes[index] == '+' || bytes[index] == '-') {
        negative = bytes[index] == '-';
        index++;
    }
    if (index == span.end)
        return NO;
    unsigned long long magnitude = 0;
    for (; index < span.end; index++) {
        if (bytes[index] < '0' || bytes[index] > '9')
            return NO;
        unsigned long long digit = bytes[index] - '0';
        if (magnitude > (ULLONG_MAX - digit) / 10)
            return NO;
        magnitude = magnitude * 10 + digit;
    }
    if (negative ? magnitude > (unsigned long long)LLONG_MAX + 1 : magnitude > (unsigned long long)LLONG_MAX)
        return NO;
    *value = negative ? (long long)(0 - magnitude) : (long long)magnitude;
    return YES;
}

NSString *revenant_url_standard(NSString *string, BOOL encoding, BOOL nsurl)
{
    unsigned options = nsurl ? RevenantParseEmptyScheme | RevenantParsePortValid : 0;
    if (![string isKindOfClass:[NSString class]])
        return nil;
    NSData *data = revenant_utf8(string);
    const uint8_t *bytes = data.bytes;
    long length = (long)data.length;
    RevenantInfo info;
    if (!revenant_parse_bytes(bytes, length, options, &info))
        return nil;
    RevenantInvalid invalid = revenant_invalid_components(bytes, &info, revenant_mask_user);
    if (invalid == 0)
        return string;
    if (!encoding)
        return nil;
    RevenantBuffer out = {NULL, 0, 0};
    NSString *result = nil;
    BOOL failed = NO;
    if (revenant_present(info.scheme)) {
        revenant_buffer_append_span(&out, bytes, info.scheme);
        revenant_buffer_append_byte(&out, ':');
    }
    BOOL authority = revenant_present(info.user) || revenant_present(info.password) || revenant_present(info.host) || revenant_present(info.port);
    if (authority)
        revenant_buffer_append_text(&out, "//");
    if (revenant_present(info.user)) {
        if (invalid & RevenantInvalidUser)
            revenant_percent_encode(&out, bytes, info.user, revenant_mask_user, NO);
        else
            revenant_buffer_append_span(&out, bytes, info.user);
        if (revenant_present(info.password)) {
            revenant_buffer_append_byte(&out, ':');
            if (invalid & RevenantInvalidPassword)
                revenant_percent_encode(&out, bytes, info.password, revenant_mask_user, NO);
            else
                revenant_buffer_append_span(&out, bytes, info.password);
        }
        revenant_buffer_append_byte(&out, '@');
    }
    if (revenant_present(info.host)) {
        if (!(invalid & RevenantInvalidHost)) {
            revenant_buffer_append_span(&out, bytes, info.host);
        } else if (info.ipLiteral || revenant_percent_encodes_host(bytes, info.host, info.scheme)) {
            RevenantBuffer host = {NULL, 0, 0};
            failed = !revenant_encode_host(&host, bytes, info.host, NO);
            if (!failed && info.ipLiteral)
                failed = !revenant_valid_host_span(host.bytes, (RevenantSpan){0, host.length});
            if (!failed)
                revenant_buffer_append(&out, host.bytes, host.length);
            free(host.bytes);
        } else {
            NSData *ascii = revenant_idna_encode(bytes, info.host);
            if (ascii.length) {
                RevenantSpan span = {0, (long)ascii.length};
                if (revenant_valid_host_span(ascii.bytes, span))
                    revenant_buffer_append(&out, ascii.bytes, (long)ascii.length);
                else
                    failed = YES;
            } else {
                failed = YES;
            }
        }
    }
    long long port;
    if (!failed && revenant_present(info.port) && revenant_swift_integer(bytes, info.port, &port)) {
        char digits[32];
        snprintf(digits, sizeof(digits), ":%lld", port);
        revenant_buffer_append_text(&out, digits);
    }
    if (!failed) {
        if (invalid & RevenantInvalidPath)
            revenant_encode_path(&out, bytes, info.path);
        else
            revenant_buffer_append_span(&out, bytes, info.path);
        if (revenant_present(info.query)) {
            revenant_buffer_append_byte(&out, '?');
            if (invalid & RevenantInvalidQuery)
                revenant_percent_encode(&out, bytes, info.query, revenant_mask_query, NO);
            else
                revenant_buffer_append_span(&out, bytes, info.query);
        }
        if (revenant_present(info.fragment)) {
            revenant_buffer_append_byte(&out, '#');
            if (invalid & RevenantInvalidFragment)
                revenant_percent_encode(&out, bytes, info.fragment, revenant_mask_query, NO);
            else
                revenant_buffer_append_span(&out, bytes, info.fragment);
        }
        RevenantInfo reparsed;
        if (revenant_parse_bytes(out.bytes, out.length, options, &reparsed))
            result = [[NSString alloc] initWithBytes:out.bytes length:(NSUInteger)out.length encoding:NSUTF8StringEncoding];
    }
    free(out.bytes);
    return result;
}

BOOL revenant_url_ranges(NSString *string, NSRange *ranges)
{
    NSData *data = revenant_utf8(string);
    RevenantInfo info;
    if (!revenant_parse_bytes(data.bytes, (long)data.length, 0, &info))
        return NO;
    const uint8_t *bytes = data.bytes;
    long *units = malloc(((size_t)data.length + 1) * sizeof(long));
    long unit = 0;
    for (long offset = 0; offset <= (long)data.length; offset++) {
        units[offset] = unit;
        if (offset == (long)data.length)
            break;
        if ((bytes[offset] & 0xC0) != 0x80)
            unit += bytes[offset] >= 0xF0 ? 2 : 1;
    }
    RevenantSpan spans[] = {info.scheme, info.user, info.password, info.host, info.port, info.path, info.query, info.fragment};
    for (size_t index = 0; index < sizeof(spans) / sizeof(spans[0]); index++)
        ranges[index] = revenant_present(spans[index]) ? NSMakeRange((NSUInteger)units[spans[index].start], (NSUInteger)(units[spans[index].end] - units[spans[index].start])) : NSMakeRange(NSNotFound, 0);
    free(units);
    return YES;
}

NSNumber *revenant_url_integer(NSString *text)
{
    NSData *data = revenant_utf8(text);
    long long value;
    if (!revenant_swift_integer(data.bytes, (RevenantSpan){0, (long)data.length}, &value))
        return nil;
    return [NSNumber numberWithLongLong:value];
}

static BOOL revenant_special_scheme(const uint8_t *bytes, RevenantSpan scheme)
{
    static const char *const names[] = {"http", "https", "ftp", "ws", "wss", "file"};
    return revenant_scheme_listed(bytes, scheme, names, sizeof(names) / sizeof(names[0]));
}

static NSString *revenant_url_nsurl_relative(NSString *string, const uint8_t *bytes, long length)
{
    RevenantInfo info;
    if (!revenant_parse_compatibility(bytes, length, &info))
        return nil;
    RevenantInvalid invalid = revenant_invalid_components(bytes, &info, revenant_mask_host_future);
    if (invalid & (RevenantInvalidUser | RevenantInvalidPassword | RevenantInvalidHost | RevenantInvalidPath))
        return nil;
    if (invalid == 0)
        return string;
    RevenantBuffer out = {NULL, 0, 0};
    revenant_buffer_append(&out, bytes, info.path.end);
    if (revenant_present(info.query)) {
        revenant_buffer_append_byte(&out, '?');
        revenant_percent_encode(&out, bytes, info.query, revenant_mask_query, YES);
    }
    if (revenant_present(info.fragment)) {
        revenant_buffer_append_byte(&out, '#');
        revenant_percent_encode(&out, bytes, info.fragment, revenant_mask_query, YES);
    }
    NSString *result = [[NSString alloc] initWithBytes:out.bytes length:(NSUInteger)out.length encoding:NSUTF8StringEncoding];
    free(out.bytes);
    return result;
}

NSString *revenant_url_nsurl(NSString *string, BOOL encoding)
{
    if (![string isKindOfClass:[NSString class]])
        return nil;
    if (!encoding)
        return revenant_url_standard(string, NO, YES);
    NSData *data = revenant_utf8(string);
    const uint8_t *bytes = data.bytes;
    long length = (long)data.length;
    RevenantInfo info;
    if (!revenant_parse_bytes(bytes, length, RevenantParseEmptyScheme | RevenantParseNoHeuristics | RevenantParseExactCase, &info))
        return revenant_url_nsurl_relative(string, bytes, length);
    RevenantInvalid invalid = revenant_invalid_components(bytes, &info, revenant_mask_host_future);
    if (invalid == 0)
        return string;
    RevenantBuffer out = {NULL, 0, 0};
    NSString *result = nil;
    BOOL failed = NO;
    if (revenant_present(info.scheme)) {
        revenant_buffer_append_span(&out, bytes, info.scheme);
        revenant_buffer_append_byte(&out, ':');
    }
    BOOL authority = revenant_present(info.user) || revenant_present(info.password) || revenant_present(info.host) || revenant_present(info.port);
    if (authority)
        revenant_buffer_append_text(&out, "//");
    if (revenant_present(info.user)) {
        revenant_percent_encode(&out, bytes, info.user, revenant_mask_host_future, YES);
        if (revenant_present(info.password)) {
            revenant_buffer_append_byte(&out, ':');
            revenant_percent_encode(&out, bytes, info.password, revenant_mask_host_future, YES);
        }
        revenant_buffer_append_byte(&out, '@');
    }
    if (revenant_present(info.host)) {
        if (!(invalid & RevenantInvalidHost)) {
            revenant_buffer_append_span(&out, bytes, info.host);
        } else if (info.ipLiteral) {
            RevenantBuffer host = {NULL, 0, 0};
            failed = !revenant_encode_host(&host, bytes, info.host, NO) || !revenant_valid_host_span(host.bytes, (RevenantSpan){0, host.length});
            if (!failed)
                revenant_buffer_append(&out, host.bytes, host.length);
            free(host.bytes);
        } else if (bytes[info.host.start] == '[') {
            failed = YES;
        } else if (revenant_special_scheme(bytes, info.scheme) && revenant_idna()) {
            NSData *ascii = revenant_idna_encode(bytes, info.host);
            RevenantSpan span = {0, (long)ascii.length};
            failed = !ascii.length || !revenant_valid_host_span(ascii.bytes, span) || memchr(ascii.bytes, '%', ascii.length) != NULL;
            if (!failed)
                revenant_buffer_append(&out, ascii.bytes, (long)ascii.length);
        } else {
            revenant_percent_encode(&out, bytes, info.host, revenant_mask_host, YES);
        }
    }
    if (!failed && revenant_present(info.port)) {
        revenant_buffer_append_byte(&out, ':');
        revenant_percent_encode(&out, bytes, info.port, revenant_mask_reserved, YES);
    }
    if (!failed) {
        revenant_percent_encode(&out, bytes, info.path, revenant_mask_path, YES);
        if (revenant_present(info.query)) {
            revenant_buffer_append_byte(&out, '?');
            revenant_percent_encode(&out, bytes, info.query, revenant_mask_query, YES);
        }
        if (revenant_present(info.fragment)) {
            revenant_buffer_append_byte(&out, '#');
            revenant_percent_encode(&out, bytes, info.fragment, revenant_mask_query, YES);
        }
        RevenantInfo reparsed;
        if (revenant_parse_bytes(out.bytes, out.length, RevenantParseEmptyScheme | RevenantParseNoHeuristics | RevenantParseExactCase, &reparsed))
            result = [[NSString alloc] initWithBytes:out.bytes length:(NSUInteger)out.length encoding:NSUTF8StringEncoding];
    }
    free(out.bytes);
    return result;
}
