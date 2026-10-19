#pragma clang diagnostic ignored "-Wnullability-completeness"
#import "CharonWebExtension.h"

@interface WKWebExtensionMatchPattern (CharonMatch)
- (BOOL)charon_matchesPattern:(WKWebExtensionMatchPattern *)pattern
                      options:(WKWebExtensionMatchPatternOptions)options;
@end

NSString *const WKWebExtensionMatchPatternErrorDomain = @"WKWebExtensionMatchPatternErrorDomain";

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
            if (![text hasPrefix:part])
                return NO;
            at = part.length;
            continue;
        }
        if (index == parts.count - 1 && ![pattern hasSuffix:@"*"]) {
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
        return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
    }
    BOOL ignoreSchemes = (options & WKWebExtensionMatchPatternOptionsIgnoreSchemes) != 0;
    if (!ignoreSchemes && ![_scheme isEqualToString:@"*"] && ![_scheme isEqualToString:scheme])
        return NO;
    BOOL ignorePaths = (options & WKWebExtensionMatchPatternOptionsIgnorePaths) != 0;
    if (ignorePaths)
        return YES;
    NSString *host = url.host ?: @"";
    if (![_host isEqualToString:@"*"]) {
        if ([_host hasPrefix:@"*."]) {
            NSString *suffix = [_host substringFromIndex:1];
            if (![host hasSuffix:suffix] && ![host isEqualToString:[suffix substringFromIndex:1]])
                return NO;
        } else if (![_host isEqualToString:host]) {
            return NO;
        }
    }
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
    return self;
}

@end
