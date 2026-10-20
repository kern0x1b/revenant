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
NSString *revenant_url_compose(NSURLComponents *components, NSRange *ranges);

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

static NSUInteger revenant_url_find(const unichar *characters, NSUInteger start, NSUInteger end, const char *delimiters)
{
    while (start < end && !revenant_url_in(characters[start], delimiters))
        start++;
    return start;
}

static BOOL revenant_url_valid_run(const unichar *characters, NSUInteger start, NSUInteger end, const char *delimiters, BOOL subdelimiters)
{
    NSUInteger index = start;
    while (index < end) {
        unichar character = characters[index];
        if (character == '%') {
            if (index + 2 >= end || !revenant_url_hex(characters[index + 1]) || !revenant_url_hex(characters[index + 2]))
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
    if (start >= end || characters[start] != '[')
        return revenant_url_valid_run(characters, start, end, "", YES);
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
    if (delimiter < length && characters[delimiter] == ':') {
        if (!revenant_url_valid_scheme(characters, 0, delimiter))
            return NO;
        ranges[RevenantURLScheme] = NSMakeRange(0, delimiter);
        index = delimiter + 1;
    }
    if (length - index >= 2 && characters[index] == '/' && characters[index + 1] == '/') {
        NSUInteger authority = index + 2;
        NSUInteger authorityEnd = revenant_url_find(characters, authority, length, "/?#");
        NSUInteger hostStart = authority;
        NSUInteger at = revenant_url_find(characters, authority, authorityEnd, "@");
        if (at < authorityEnd) {
            NSUInteger colon = revenant_url_find(characters, authority, at, ":");
            if (!revenant_url_valid_run(characters, authority, colon, "", YES))
                return NO;
            ranges[RevenantURLUser] = NSMakeRange(authority, colon - authority);
            if (colon < at) {
                if (!revenant_url_valid_run(characters, colon + 1, at, "", YES))
                    return NO;
                ranges[RevenantURLPassword] = NSMakeRange(colon + 1, at - colon - 1);
            }
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
        if (!revenant_url_valid_host(characters, hostStart, hostEnd) && hostEnd > hostStart)
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
    if (!revenant_url_valid_run(characters, index, pathEnd, "/:@", YES))
        return NO;
    ranges[RevenantURLPath] = NSMakeRange(index, pathEnd - index);
    index = pathEnd;
    if (index < length && characters[index] == '?') {
        NSUInteger queryEnd = revenant_url_find(characters, index + 1, length, "#");
        if (!revenant_url_valid_run(characters, index + 1, queryEnd, "/:@?", YES))
            return NO;
        ranges[RevenantURLQuery] = NSMakeRange(index + 1, queryEnd - index - 1);
        index = queryEnd;
    }
    if (index < length) {
        if (!revenant_url_valid_run(characters, index + 1, length, "/:@?", YES))
            return NO;
        ranges[RevenantURLFragment] = NSMakeRange(index + 1, length - index - 1);
    }
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
        valid = length == 0 || revenant_url_valid_host(characters, 0, length);
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
    NSString *host = components.percentEncodedHost;
    NSNumber *port = components.port;
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
            revenant_url_append(result, port.stringValue, ranges, RevenantURLPort);
        }
    }
    if (path && !scheme && !authority) {
        NSRange segment = [path rangeOfString:@"/"];
        NSUInteger end = segment.location == NSNotFound ? path.length : segment.location;
        NSString *first = [[path substringToIndex:end] stringByReplacingOccurrencesOfString:@":" withString:@"%3A"];
        path = [first stringByAppendingString:[path substringFromIndex:end]];
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
