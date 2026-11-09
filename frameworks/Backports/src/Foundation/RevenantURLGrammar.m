#import <Foundation/Foundation.h>
#import "RevenantURLParser.h"

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

@interface NSURLComponents (RevenantRawText)
- (NSString *)revenantPortText;
- (NSString *)revenantHostText;
- (NSString *)revenantParsedString;
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

static BOOL revenant_url_valid_host(const unichar *characters, NSUInteger start, NSUInteger end)
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
            } else if (!revenant_url_alphanumeric(character) && !revenant_url_in(character, "-._~!$&'()*+,;=")) {
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

BOOL revenant_url_parse(NSString *string, NSRange *ranges)
{
    return revenant_url_ranges(string, ranges);
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
        valid = revenant_url_valid_host(characters, 0, length);
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

NSString *revenant_url_host_text(NSString *string, NSRange range)
{
    return range.location == NSNotFound ? nil : [string substringWithRange:range];
}

NSString *revenant_url_host_escaped(NSString *host)
{
    if (!host)
        return nil;
    if (!host.length || [host rangeOfString:@"%"].location != NSNotFound || [host hasPrefix:@"["])
        return host;
    NSString *decoded = revenant_url_host_unicode(host);
    if (!decoded)
        return nil;
    unichar *characters = revenant_url_characters(decoded);
    NSString *escaped = revenant_url_escape(characters, 0, decoded.length, "");
    free(characters);
    return escaped;
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
