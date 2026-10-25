#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, RevenantURLPart) {
    RevenantURLScheme,
    RevenantURLUser,
    RevenantURLPassword,
    RevenantURLHost,
    RevenantURLPort,
    RevenantURLPath,
    RevenantURLQuery,
    RevenantURLFragment,
    RevenantURLPartCount
};

BOOL revenant_url_parse(NSString *string, NSRange *ranges);
BOOL revenant_url_valid(RevenantURLPart part, NSString *string);
NSString *revenant_url_component(NSString *string, NSRange range, RevenantURLPart part);
NSString *revenant_url_host_text(NSString *string, NSRange range);
NSString *revenant_url_host_escaped(NSString *host);
NSString *revenant_url_compose(NSURLComponents *components, NSRange *ranges);

// What the URL spelled and macOS keeps in the string even where it has no number: the port, "0080" or the colon of an empty
// port, and the host with its labels written in punycode.
@interface NSURLComponents (RevenantRawText)
- (NSString *)revenantPortText;
- (NSString *)revenantHostText;
@end

static BOOL revenant_url_alphanumeric(unichar character)
{
    return (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z') || (character >= '0' && character <= '9');
}

static BOOL revenant_url_in(unichar character, const char *characters)
{
    return character > 0 && character < 128 && strchr(characters, character) != NULL;
}

static BOOL revenant_url_hex(unichar character)
{
    return (character >= '0' && character <= '9') || (character >= 'A' && character <= 'F') || (character >= 'a' && character <= 'f');
}

static BOOL revenant_url_escape_valid(const unichar *characters, NSUInteger index, NSUInteger end)
{
    return characters[index] == '%' && index + 2 < end && revenant_url_hex(characters[index + 1]) && revenant_url_hex(characters[index + 2]);
}

static NSUInteger revenant_url_find(const unichar *characters, NSUInteger start, NSUInteger end, const char *delimiters)
{
    while (start < end && !revenant_url_in(characters[start], delimiters))
        start++;
    return start;
}

static NSUInteger revenant_url_find_last(const unichar *characters, NSUInteger start, NSUInteger end, unichar target)
{
    NSUInteger index = end;
    while (index > start && characters[index - 1] != target)
        index--;
    return index > start ? index - 1 : end;
}

static BOOL revenant_url_valid_run(const unichar *characters, NSUInteger start, NSUInteger end, const char *delimiters, BOOL subdelimiters)
{
    NSUInteger index = start;
    while (index < end) {
        unichar character = characters[index];
        if (character == '%') {
            if (!revenant_url_escape_valid(characters, index, end))
                return NO;
            index += 3;
        } else if (revenant_url_alphanumeric(character) || revenant_url_in(character, "-._~") || (subdelimiters && revenant_url_in(character, "!$&'()*+,;=")) || revenant_url_in(character, delimiters)) {
            index++;
        } else {
            return NO;
        }
    }
    return YES;
}

static BOOL revenant_url_valid_scheme(const unichar *characters, NSUInteger start, NSUInteger end)
{
    if (start >= end || !((characters[start] >= 'a' && characters[start] <= 'z') || (characters[start] >= 'A' && characters[start] <= 'Z')))
        return NO;
    for (NSUInteger index = start + 1; index < end; index++) {
        if (!revenant_url_alphanumeric(characters[index]) && !revenant_url_in(characters[index], "+-."))
            return NO;
    }
    return YES;
}

// A registered name takes what its grammar allows and a valid escape; the parser also takes non-ASCII characters, which
// macOS writes as UTF-8 escapes and converts to IDNA when it composes the string.
static BOOL revenant_url_valid_host(const unichar *characters, NSUInteger start, NSUInteger end, BOOL international)
{
    if (start >= end)
        return YES;
    if (characters[start] != '[') {
        for (NSUInteger index = start; index < end; index++) {
            unichar character = characters[index];
            if (character == '%') {
                if (!revenant_url_escape_valid(characters, index, end))
                    return NO;
                index += 2;
            } else if (!revenant_url_alphanumeric(character) && !revenant_url_in(character, "-._~!$&'()*+,;=") && !(international && character >= 128)) {
                return NO;
            }
        }
        return YES;
    }
    if (end - start < 2 || characters[end - 1] != ']')
        return NO;
    NSUInteger finish = end - 1;
    NSUInteger index = start + 1;
    for (; index < finish && characters[index] != '%'; index++) {
        if (!revenant_url_alphanumeric(characters[index]) && !revenant_url_in(characters[index], "-._~!$&'()*+,;=:"))
            return NO;
    }
    if (index == finish)
        return YES;
    if (finish - index < 3 || characters[index + 1] != '2' || characters[index + 2] != '5')
        return NO;
    return revenant_url_valid_run(characters, index + 3, finish, "", NO);
}

static unichar *revenant_url_characters(NSString *string)
{
    NSUInteger length = string.length;
    unichar *characters = malloc((length ? length : 1) * sizeof(unichar));
    [string getCharacters:characters range:NSMakeRange(0, length)];
    return characters;
}

static BOOL revenant_url_parse_characters(const unichar *characters, NSUInteger length, NSRange *ranges)
{
    for (NSUInteger part = 0; part < RevenantURLPartCount; part++)
        ranges[part] = NSMakeRange(NSNotFound, 0);
    NSUInteger index = 0;
    NSUInteger delimiter = revenant_url_find(characters, 0, length, ":/?#");
    if (delimiter > 0 && delimiter < length && characters[delimiter] == ':') {
        if (!revenant_url_valid_scheme(characters, 0, delimiter))
            return NO;
        ranges[RevenantURLScheme] = NSMakeRange(0, delimiter);
        index = delimiter + 1;
    }
    if (length - index >= 2 && characters[index] == '/' && characters[index + 1] == '/') {
        NSUInteger authority = index + 2;
        NSUInteger authorityEnd = revenant_url_find(characters, authority, length, "/?#");
        NSUInteger hostStart = authority;
        NSUInteger at = revenant_url_find_last(characters, authority, authorityEnd, '@');
        if (at < authorityEnd) {
            NSUInteger colon = revenant_url_find(characters, authority, at, ":");
            ranges[RevenantURLUser] = NSMakeRange(authority, colon - authority);
            if (colon < at)
                ranges[RevenantURLPassword] = NSMakeRange(colon + 1, at - colon - 1);
            hostStart = at + 1;
        }
        NSUInteger hostEnd;
        if (hostStart < authorityEnd && characters[hostStart] == '[') {
            NSUInteger close = revenant_url_find(characters, hostStart, authorityEnd, "]");
            if (close == authorityEnd)
                return NO;
            hostEnd = close + 1;
            if (hostEnd < authorityEnd && characters[hostEnd] != ':')
                return NO;
        } else {
            hostEnd = revenant_url_find(characters, hostStart, authorityEnd, ":");
        }
        if (!revenant_url_valid_host(characters, hostStart, hostEnd, YES))
            return NO;
        ranges[RevenantURLHost] = NSMakeRange(hostStart, hostEnd - hostStart);
        if (hostEnd < authorityEnd) {
            for (NSUInteger digit = hostEnd + 1; digit < authorityEnd; digit++) {
                if (characters[digit] < '0' || characters[digit] > '9')
                    return NO;
            }
            ranges[RevenantURLPort] = NSMakeRange(hostEnd + 1, authorityEnd - hostEnd - 1);
        }
        index = authorityEnd;
    }
    NSUInteger pathEnd = revenant_url_find(characters, index, length, "?#");
    ranges[RevenantURLPath] = NSMakeRange(index, pathEnd - index);
    index = pathEnd;
    if (index < length && characters[index] == '?') {
        NSUInteger queryEnd = revenant_url_find(characters, index + 1, length, "#");
        ranges[RevenantURLQuery] = NSMakeRange(index + 1, queryEnd - index - 1);
        index = queryEnd;
    }
    if (index < length)
        ranges[RevenantURLFragment] = NSMakeRange(index + 1, length - index - 1);
    return YES;
}

BOOL revenant_url_parse(NSString *string, NSRange *ranges)
{
    unichar *characters = revenant_url_characters(string);
    BOOL parsed = revenant_url_parse_characters(characters, string.length, ranges);
    free(characters);
    return parsed;
}

BOOL revenant_url_valid(RevenantURLPart part, NSString *string)
{
    NSUInteger length = string.length;
    unichar *characters = revenant_url_characters(string);
    BOOL valid;
    switch (part) {
    case RevenantURLScheme:
        valid = revenant_url_valid_scheme(characters, 0, length);
        break;
    case RevenantURLHost:
        valid = revenant_url_valid_host(characters, 0, length, NO);
        break;
    case RevenantURLPath:
        valid = revenant_url_valid_run(characters, 0, length, "/:@", YES);
        break;
    case RevenantURLQuery:
    case RevenantURLFragment:
        valid = revenant_url_valid_run(characters, 0, length, "/:@?", YES);
        break;
    default:
        valid = revenant_url_valid_run(characters, 0, length, "", YES);
        break;
    }
    free(characters);
    return valid;
}

// Writes a code point as the escapes of its UTF-8 bytes.
static void revenant_url_utf8(uint32_t code, NSMutableString *result)
{
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
    for (NSUInteger index = 0; index < count; index++)
        [result appendFormat:@"%%%02X", bytes[index]];
}

// What macOS writes for a component: a character in the component's set stays as it is, sub-delimiters and unreserved characters
// always do, and everything else becomes the escapes of its UTF-8 bytes. The escapes already in the component stay only if every
// '%' in it starts one; a component with a '%' that starts none has each '%' written as %25.
static NSString *revenant_url_escape(const unichar *characters, NSUInteger start, NSUInteger end, const char *allowed)
{
    BOOL escapes = YES;
    for (NSUInteger index = start; index < end && escapes; index++) {
        if (characters[index] == '%' && !revenant_url_escape_valid(characters, index, end))
            escapes = NO;
    }
    NSMutableString *result = [NSMutableString string];
    NSUInteger index = start;
    while (index < end) {
        unichar character = characters[index];
        if (escapes && revenant_url_escape_valid(characters, index, end)) {
            [result appendString:[NSString stringWithCharacters:characters + index length:3]];
            index += 3;
        } else if (character < 128 && (revenant_url_alphanumeric(character) || revenant_url_in(character, "-._~!$&'()*+,;=") || revenant_url_in(character, allowed))) {
            [result appendFormat:@"%C", character];
            index++;
        } else {
            uint32_t code = character;
            NSUInteger width = 1;
            if (character >= 0xD800 && character < 0xDC00 && index + 1 < end && characters[index + 1] >= 0xDC00 && characters[index + 1] < 0xE000) {
                code = 0x10000 + ((character - 0xD800) << 10) + (characters[index + 1] - 0xDC00);
                width = 2;
            }
            revenant_url_utf8(code, result);
            index += width;
        }
    }
    return result;
}

NSString *revenant_url_component(NSString *string, NSRange range, RevenantURLPart part)
{
    if (range.location == NSNotFound)
        return nil;
    if (part == RevenantURLScheme || part == RevenantURLPort)
        return [string substringWithRange:range];
    if (part == RevenantURLHost)
        return revenant_url_host_escaped(revenant_url_host_text(string, range));
    unichar *characters = revenant_url_characters(string);
    NSString *result;
    NSUInteger end = NSMaxRange(range);
    switch (part) {
    case RevenantURLPath:
        result = revenant_url_escape(characters, range.location, end, "/:@");
        break;
    case RevenantURLQuery:
    case RevenantURLFragment:
        result = revenant_url_escape(characters, range.location, end, "/:@?");
        break;
    default:
        result = revenant_url_escape(characters, range.location, end, "");
        break;
    }
    free(characters);
    return result;
}

static uint32_t *revenant_url_code_points(NSString *text, NSUInteger *count)
{
    NSUInteger length = text.length;
    uint32_t *points = malloc((length ? length : 1) * sizeof(uint32_t));
    NSUInteger n = 0;
    for (NSUInteger index = 0; index < length; index++) {
        unichar character = [text characterAtIndex:index];
        if (character >= 0xD800 && character < 0xDC00 && index + 1 < length) {
            unichar low = [text characterAtIndex:index + 1];
            if (low >= 0xDC00 && low < 0xE000) {
                points[n++] = 0x10000 + ((character - 0xD800) << 10) + (low - 0xDC00);
                index++;
                continue;
            }
        }
        points[n++] = character;
    }
    *count = n;
    return points;
}

// RFC 3492 with macOS's base, tmin and tmax.
static uint32_t revenant_punycode_adapt(uint32_t delta, uint32_t points, BOOL first)
{
    delta = first ? delta / 700 : delta / 2;
    delta += delta / points;
    uint32_t k = 0;
    while (delta > 455) {
        delta /= 35;
        k += 36;
    }
    return k + (36 * delta) / (delta + 38);
}

static NSString *revenant_punycode(const uint32_t *points, NSUInteger count)
{
    NSMutableString *output = [NSMutableString string];
    NSUInteger basic = 0;
    for (NSUInteger index = 0; index < count; index++) {
        if (points[index] < 128) {
            [output appendFormat:@"%C", (unichar)points[index]];
            basic++;
        }
    }
    if (basic)
        [output appendString:@"-"];
    uint32_t n = 128, delta = 0, bias = 72;
    NSUInteger handled = basic;
    while (handled < count) {
        uint32_t next = UINT32_MAX;
        for (NSUInteger index = 0; index < count; index++) {
            if (points[index] >= n && points[index] < next)
                next = points[index];
        }
        delta += (next - n) * (uint32_t)(handled + 1);
        n = next;
        for (NSUInteger index = 0; index < count; index++) {
            if (points[index] < n)
                delta++;
            if (points[index] != n)
                continue;
            uint32_t q = delta;
            for (uint32_t k = 36;; k += 36) {
                uint32_t t = k <= bias ? 1 : (k >= bias + 26 ? 26 : k - bias);
                if (q < t)
                    break;
                uint32_t digit = t + (q - t) % (36 - t);
                [output appendFormat:@"%C", (unichar)(digit < 26 ? 'a' + digit : '0' + (digit - 26))];
                q = (q - t) / (36 - t);
            }
            [output appendFormat:@"%C", (unichar)(q < 26 ? 'a' + q : '0' + (q - 26))];
            bias = revenant_punycode_adapt(delta, (uint32_t)handled + 1, handled == basic);
            delta = 0;
            handled++;
        }
        delta++;
        n++;
    }
    return output;
}

// One label of the host as macOS writes it in the string: a label with no non-ASCII character is kept as it is, and any other
// is mapped (compatibility forms, lowercase) and then written in punycode.
static NSString *revenant_url_label(NSString *label)
{
    NSString *decoded = label;
    BOOL international = NO;
    for (NSUInteger index = 0; index < decoded.length; index++) {
        if ([decoded characterAtIndex:index] >= 128)
            international = YES;
    }
    if (!international)
        return label;
    NSString *mapped = [[decoded precomposedStringWithCompatibilityMapping] lowercaseString];
    NSUInteger count;
    uint32_t *points = revenant_url_code_points(mapped, &count);
    BOOL ascii = YES;
    for (NSUInteger index = 0; index < count; index++) {
        if (points[index] >= 128)
            ascii = NO;
    }
    NSString *result = ascii ? mapped : [@"xn--" stringByAppendingString:revenant_punycode(points, count)];
    free(points);
    return result;
}

// The host as macOS's string shows it: each label mapped as above, from what the URL spelled.
NSString *revenant_url_host_text(NSString *string, NSRange range)
{
    if (range.location == NSNotFound)
        return nil;
    NSMutableArray *labels = [NSMutableArray array];
    for (NSString *label in [[string substringWithRange:range] componentsSeparatedByString:@"."])
        [labels addObject:revenant_url_label(label)];
    return [labels componentsJoinedByString:@"."];
}

// RFC 3492, the inverse of revenant_punycode. Nil when the text is not punycode.
static NSString *revenant_punycode_decode(NSString *text)
{
    NSUInteger length = text.length;
    uint32_t *points = malloc((length + 1) * sizeof(uint32_t));
    NSUInteger count = 0;
    NSUInteger index = 0;
    NSRange dash = [text rangeOfString:@"-" options:NSBackwardsSearch];
    if (dash.location != NSNotFound) {
        for (NSUInteger basic = 0; basic < dash.location; basic++) {
            unichar character = [text characterAtIndex:basic];
            if (character >= 128) {
                free(points);
                return nil;
            }
            points[count++] = character;
        }
        index = dash.location + 1;
    }
    uint32_t n = 128, i = 0, bias = 72;
    while (index < length) {
        uint32_t previous = i, weight = 1;
        for (uint32_t k = 36;; k += 36) {
            if (index >= length) {
                free(points);
                return nil;
            }
            unichar character = [text characterAtIndex:index++];
            uint32_t digit;
            if (character >= '0' && character <= '9')
                digit = character - '0' + 26;
            else if (character >= 'a' && character <= 'z')
                digit = character - 'a';
            else if (character >= 'A' && character <= 'Z')
                digit = character - 'A';
            else {
                free(points);
                return nil;
            }
            i += digit * weight;
            uint32_t t = k <= bias ? 1 : (k >= bias + 26 ? 26 : k - bias);
            if (digit < t)
                break;
            weight *= 36 - t;
        }
        bias = revenant_punycode_adapt(i - previous, (uint32_t)count + 1, previous == 0);
        n += i / ((uint32_t)count + 1);
        i %= (uint32_t)count + 1;
        memmove(points + i + 1, points + i, (count - i) * sizeof(uint32_t));
        points[i++] = n;
        count++;
    }
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger point = 0; point < count; point++) {
        if (points[point] >= 0x10000) {
            uint32_t offset = points[point] - 0x10000;
            [result appendFormat:@"%C%C", (unichar)(0xD800 + (offset >> 10)), (unichar)(0xDC00 + (offset & 0x3FF))];
        } else {
            [result appendFormat:@"%C", (unichar)points[point]];
        }
    }
    free(points);
    return result;
}

// The host as macOS's percentEncodedHost shows it: each punycode label decoded and written as the escapes of its UTF-8 bytes,
// every other label as it is.
NSString *revenant_url_host_escaped(NSString *host)
{
    if (!host)
        return nil;
    NSMutableArray *labels = [NSMutableArray array];
    for (NSString *label in [host componentsSeparatedByString:@"."]) {
        NSString *decoded = nil;
        if (label.length > 4 && [[label substringToIndex:4] caseInsensitiveCompare:@"xn--"] == NSOrderedSame)
            decoded = revenant_punycode_decode([label substringFromIndex:4]);
        if (!decoded) {
            [labels addObject:label];
            continue;
        }
        NSMutableString *escaped = [NSMutableString string];
        NSUInteger count;
        uint32_t *points = revenant_url_code_points(decoded, &count);
        for (NSUInteger point = 0; point < count; point++) {
            if (points[point] < 128)
                [escaped appendFormat:@"%C", (unichar)points[point]];
            else
                revenant_url_utf8(points[point], escaped);
        }
        free(points);
        [labels addObject:escaped];
    }
    return [labels componentsJoinedByString:@"."];
}

static void revenant_url_append(NSMutableString *result, NSString *text, NSRange *ranges, RevenantURLPart part)
{
    if (ranges)
        ranges[part] = NSMakeRange(result.length, text.length);
    [result appendString:text];
}

NSString *revenant_url_compose(NSURLComponents *components, NSRange *ranges)
{
    NSString *scheme = components.scheme;
    NSString *user = components.percentEncodedUser;
    NSString *password = components.percentEncodedPassword;
    NSString *host = components.revenantHostText;
    if (!host)
        host = components.percentEncodedHost;
    NSString *port = components.revenantPortText;
    if (!port)
        port = components.port.stringValue;
    NSString *path = components.percentEncodedPath;
    NSString *query = components.percentEncodedQuery;
    NSString *fragment = components.percentEncodedFragment;
    BOOL authority = user || password || host || port;
    if (authority && path.length && ![path hasPrefix:@"/"])
        return nil;
    if (!authority && [path hasPrefix:@"//"])
        return nil;
    if (ranges) {
        for (NSUInteger part = 0; part < RevenantURLPartCount; part++)
            ranges[part] = NSMakeRange(NSNotFound, 0);
    }
    NSMutableString *result = [NSMutableString string];
    if (scheme) {
        revenant_url_append(result, scheme, ranges, RevenantURLScheme);
        [result appendString:@":"];
    }
    if (authority) {
        [result appendString:@"//"];
        if (user || password) {
            if (user)
                revenant_url_append(result, user, ranges, RevenantURLUser);
            if (password) {
                [result appendString:@":"];
                revenant_url_append(result, password, ranges, RevenantURLPassword);
            }
            [result appendString:@"@"];
        }
        if (host)
            revenant_url_append(result, host, ranges, RevenantURLHost);
        if (port) {
            [result appendString:@":"];
            revenant_url_append(result, port, ranges, RevenantURLPort);
        }
    }
    if (path)
        revenant_url_append(result, path, ranges, RevenantURLPath);
    if (query) {
        [result appendString:@"?"];
        revenant_url_append(result, query, ranges, RevenantURLQuery);
    }
    if (fragment) {
        [result appendString:@"#"];
        revenant_url_append(result, fragment, ranges, RevenantURLFragment);
    }
    return [result copy];
}
