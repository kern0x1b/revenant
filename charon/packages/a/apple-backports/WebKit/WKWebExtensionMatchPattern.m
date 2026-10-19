#pragma clang diagnostic ignored "-Wnullability-completeness"
#import "CharonWebExtension.h"

/* The port's own arm of the matching, so the bidirectional option can call the other pattern's side
 * without going back through the public entry point and losing the options. */
@interface WKWebExtensionMatchPattern (CharonMatch)
- (BOOL)charon_matchesPattern:(WKWebExtensionMatchPattern *)pattern
                      options:(WKWebExtensionMatchPatternOptions)options;
@end

/* WKWebExtensionMatchPattern, and the matching WKWebExtension needs for its permission sets.
 *
 * A match pattern is scheme, then "://", then a host, then a path, where a single star stands for
 * "any" in each of the three, and the token <all_urls> stands for every http and https URL.
 * Everything here is measured against the release's own WebKit on this host, by making patterns and
 * asking them; none of it is read off the header, which declares the class and says nothing about how
 * it matches. A star is written S below so that this comment can hold the patterns themselves.
 *
 * Parsing, on the host:
 *
 *   https://example.com      -> scheme https, host example.com, path = slash S
 *   star://S.example.com/S   -> scheme star, host S.example.com, path = slash S
 *   <all_urls>               -> scheme, host and path ALL nil, matchesAllHosts YES, matchesAllURLs YES
 *   http://S/S               -> host S, matchesAllHosts YES, matchesAllURLs NO
 *   ftp://example.com/S      -> parses: any scheme is allowed, not only http and https
 *   a pattern with a PORT    -> nil, WKWebExtensionMatchPatternErrorDomain
 *   https://example.com      -> nil, the same domain: a path is required
 *   "" and "not a pattern"   -> nil, the same domain
 *
 * Matching, for the host pattern scheme S, S.example.com, path = slash api slash S:
 *
 *   https://a.example.com/api/x     YES
 *   https://b.example.com/api/      YES
 *   https://example.com/api/x       YES   <- a leading star matches ZERO labels, not one
 *   https://a.example.com/api/x?q=1 YES   <- the query is not part of the match
 *   https://a.example.com:8443/api/x YES  <- nor is the port
 *   https://a.example.com/other      NO
 *   http://a.example.com/api/x       NO   <- the scheme is not a star
 *
 * and <all_urls> against about:blank and data:text/plain,hi: NO for both, while it answers YES for
 * https. It is the http and https URLs, not every URL a process can name.
 */

NSString *const WKWebExtensionMatchPatternErrorDomain = @"WKWebExtensionMatchPatternErrorDomain";

/* One `*` matches any run of characters, and the pieces between them are literal. A leading piece
 * is an anchor unless the pattern opens with a star, and a trailing piece is an anchor unless the
 * pattern closes with one -- which is what makes the host pattern S.example.com, path
 * api S match both a.example.com and example.com, and not a different path. Measured. */
static BOOL charon_glob(NSString *pattern, NSString *text)
{
    if ([pattern isEqualToString:@"*"])
        return YES;
    if (![pattern containsString:@"*"])
        return [pattern isEqualToString:text];
    NSArray<NSString *> *parts = [pattern componentsSeparatedByString:@"*"];
    NSUInteger at = 0, length = text.length;
    for (NSUInteger index = 0; index < parts.count; index++) {
        NSString *part = parts[index];
        if (part.length == 0)
            continue;
        if (index == 0) {
            /* the first piece is an anchor, unless the pattern opens with a star */
            if (![text hasPrefix:part])
                return NO;
            at = part.length;
            continue;
        }
        if (index == parts.count - 1 && ![pattern hasSuffix:@"*"]) {
            /* the last piece is an anchor too */
            return length >= at + part.length && [text hasSuffix:part];
        }
        NSRange found = [text rangeOfString:part options:0 range:NSMakeRange(at, length - at)];
        if (found.location == NSNotFound)
            return NO;
        at = found.location + found.length;
    }
    return YES;
}

@implementation WKWebExtensionMatchPattern {
    NSString *_string;
    NSString *_scheme;
    NSString *_host;
    NSString *_path;
    BOOL _matchesAllHosts;
    BOOL _matchesAllURLs;
}

- (instancetype)initWithString:(NSString *)string error:(NSError **)error
{
    if (![string isKindOfClass:[NSString class]] || string.length == 0) {
        if (error)
            *error = [self charon_error:WKWebExtensionMatchPatternErrorInvalidScheme];
        return nil;
    }
    if ([string isEqualToString:@"<all_urls>"]) {
        if ((self = [super init])) {
            _string = [string copy];
            _matchesAllHosts = YES;
            _matchesAllURLs = YES;
        }
        return self;
    }
    NSRange schemeEnd = [string rangeOfString:@"://"];
    /* Measured: no scheme, no "://", and a port in the host are all refused, in this domain. */
    if (schemeEnd.location == NSNotFound || schemeEnd.location == 0) {
        if (error)
            *error = [self charon_error:WKWebExtensionMatchPatternErrorInvalidScheme];
        return nil;
    }
    NSString *scheme = [string substringToIndex:schemeEnd.location];
    NSString *rest = [string substringFromIndex:NSMaxRange(schemeEnd)];
    if ([rest containsString:@":"]) {
        if (error)
            *error = [self charon_error:WKWebExtensionMatchPatternErrorInvalidHost];
        return nil;
    }
    NSRange slash = [rest rangeOfString:@"/"];
    if (slash.location == NSNotFound) {
        if (error)
            *error = [self charon_error:WKWebExtensionMatchPatternErrorInvalidPath];
        return nil;
    }
    NSString *host = [rest substringToIndex:slash.location];
    NSString *path = [rest substringFromIndex:slash.location];
    if (host.length == 0 || path.length == 0) {
        if (error)
            *error = [self charon_error:WKWebExtensionMatchPatternErrorInvalidHost];
        return nil;
    }
    if ((self = [super init])) {
        _string = [string copy];
        _scheme = [scheme copy];
        _host = [host copy];
        _path = [path copy];
        _matchesAllHosts = [host isEqualToString:@"*"];
    }
    return self;
}

- (instancetype)initWithScheme:(NSString *)scheme host:(NSString *)host path:(NSString *)path error:(NSError **)error
{
    return [self initWithString:[NSString stringWithFormat:@"%@://%@%@", scheme, host, path] error:error];
}

- (NSError *)charon_error:(NSInteger)code
{
    return [NSError errorWithDomain:WKWebExtensionMatchPatternErrorDomain code:code userInfo:nil];
}

- (NSString *)string
{
    return _string;
}

- (NSString *)scheme
{
    return _matchesAllURLs ? nil : _scheme;
}

- (NSString *)host
{
    return _matchesAllURLs ? nil : _host;
}

- (NSString *)path
{
    return _matchesAllURLs ? nil : _path;
}

- (BOOL)matchesAllHosts
{
    return _matchesAllHosts;
}

- (BOOL)matchesAllURLs
{
    return _matchesAllURLs;
}

- (BOOL)charon_matchesURL:(NSURL *)url options:(WKWebExtensionMatchPatternOptions)options
{
    if (url == nil)
        return NO;
    NSString *scheme = url.scheme;
    if (_matchesAllURLs) {
        /* Measured: <all_urls> takes the http and https URLs and nothing else -- about: and data: are
         * both NO on the host. */
        return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
    }
    BOOL ignoreSchemes = (options & WKWebExtensionMatchPatternOptionsIgnoreSchemes) != 0;
    if (!ignoreSchemes && ![_scheme isEqualToString:@"*"] && ![_scheme isEqualToString:scheme])
        return NO;
    BOOL ignorePaths = (options & WKWebExtensionMatchPatternOptionsIgnorePaths) != 0;
    if (ignorePaths)
        return YES;
    /* The host: `*` takes any, and a leading `*` takes any number of labels INCLUDING none, so
     * *.example.com matches example.com as well as a.example.com. Measured. */
    NSString *host = url.host ?: @"";
    if (![_host isEqualToString:@"*"]) {
        if ([_host hasPrefix:@"*."]) {
            NSString *suffix = [_host substringFromIndex:1];   /* keep the dot: ".example.com" */
            if (![host hasSuffix:suffix] && ![host isEqualToString:[suffix substringFromIndex:1]])
                return NO;
        } else if (![_host isEqualToString:host]) {
            return NO;
        }
    }
    /* The path, and neither the port nor the query is part of it: measured, both still match. */
    NSString *path = url.path.length == 0 ? @"/" : url.path;
    return charon_glob(_path, path);
}

- (BOOL)matchesURL:(NSURL *)url
{
    return [self charon_matchesURL:url options:WKWebExtensionMatchPatternOptionsNone];
}

- (BOOL)matchesURL:(NSURL *)url options:(WKWebExtensionMatchPatternOptions)options
{
    return [self charon_matchesURL:url options:options];
}

- (BOOL)matchesPattern:(WKWebExtensionMatchPattern *)pattern
{
    return [self matchesPattern:pattern options:WKWebExtensionMatchPatternOptionsNone];
}

- (BOOL)matchesPattern:(WKWebExtensionMatchPattern *)pattern options:(WKWebExtensionMatchPatternOptions)options
{
    if (pattern == nil)
        return NO;
    BOOL bidirectional = (options & WKWebExtensionMatchPatternOptionsMatchBidirectionally) != 0;
    if (bidirectional)
        return [pattern charon_matchesPattern:self options:(options & ~WKWebExtensionMatchPatternOptionsMatchBidirectionally)];
    NSString *url = _string;
    if (_matchesAllURLs)
        url = @"*://*/*";
    NSError *error = nil;
    WKWebExtensionMatchPattern *asURL = [[WKWebExtensionMatchPattern alloc] initWithString:url error:&error];
    if (asURL == nil)
        return NO;
    return [asURL charon_matchesURL:[NSURL URLWithString:_string] options:options];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;   /* immutable, and the host's copy is the receiver */
}

@end
