#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, CharonURLPart) {
    CharonURLScheme,
    CharonURLUser,
    CharonURLPassword,
    CharonURLHost,
    CharonURLPort,
    CharonURLPath,
    CharonURLQuery,
    CharonURLFragment,
    CharonURLPartCount
};

BOOL charon_url_parse(NSString *string, NSRange *ranges);
BOOL charon_url_valid(CharonURLPart part, NSString *string);
NSString *charon_url_compose(NSURLComponents *components, NSRange *ranges);

static NSString *charon_url_substring(NSString *string, NSRange range)
{
    return range.location == NSNotFound ? nil : [string substringWithRange:range];
}

static NSNumber *charon_url_port(NSString *digits)
{
    if (!digits.length)
        return nil;
    unsigned long long value = 0;
    for (NSUInteger index = 0; index < digits.length; index++) {
        unsigned long long digit = [digits characterAtIndex:index] - '0';
        if (value > (LLONG_MAX - digit) / 10)
            return nil;
        value = value * 10 + digit;
    }
    return [NSNumber numberWithLongLong:(long long)value];
}

static void charon_url_require(BOOL valid, NSURLComponents *components, SEL selector, NSString *what)
{
    if (!valid)
        [NSException raise:NSInvalidArgumentException format:@"*** -[%@ %@]: invalid characters in %@", [components class], NSStringFromSelector(selector), what];
}

static BOOL charon_url_same(NSString *first, NSString *second)
{
    return first == second || [first isEqualToString:second];
}

@implementation NSURLComponents {
    NSString *_scheme;
    NSString *_percentEncodedUser;
    NSString *_percentEncodedPassword;
    NSString *_percentEncodedHost;
    NSNumber *_port;
    NSString *_percentEncodedPath;
    NSString *_percentEncodedQuery;
    NSString *_percentEncodedFragment;
}

@dynamic string, queryItems, percentEncodedQueryItems, encodedHost;
@dynamic rangeOfScheme, rangeOfUser, rangeOfPassword, rangeOfHost, rangeOfPort, rangeOfPath, rangeOfQuery, rangeOfFragment;

+ (instancetype)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve
{
    return [[self alloc] initWithURL:url resolvingAgainstBaseURL:resolve];
}

+ (instancetype)componentsWithString:(NSString *)URLString
{
    return [[self alloc] initWithString:URLString];
}

- (instancetype)initWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve
{
    NSURL *source = resolve ? url.absoluteURL : url;
    return [self initWithString:source.relativeString];
}

- (instancetype)initWithString:(NSString *)URLString
{
    NSRange ranges[CharonURLPartCount];
    if (![URLString isKindOfClass:[NSString class]] || !charon_url_parse(URLString, ranges))
        return nil;
    if ((self = [self init])) {
        _scheme = charon_url_substring(URLString, ranges[CharonURLScheme]);
        _percentEncodedUser = charon_url_substring(URLString, ranges[CharonURLUser]);
        _percentEncodedPassword = charon_url_substring(URLString, ranges[CharonURLPassword]);
        _percentEncodedHost = charon_url_substring(URLString, ranges[CharonURLHost]);
        _port = charon_url_port(charon_url_substring(URLString, ranges[CharonURLPort]));
        _percentEncodedPath = charon_url_substring(URLString, ranges[CharonURLPath]);
        _percentEncodedQuery = charon_url_substring(URLString, ranges[CharonURLQuery]);
        _percentEncodedFragment = charon_url_substring(URLString, ranges[CharonURLFragment]);
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSURLComponents *copy = [[[self class] allocWithZone:zone] init];
    copy->_scheme = _scheme;
    copy->_percentEncodedUser = _percentEncodedUser;
    copy->_percentEncodedPassword = _percentEncodedPassword;
    copy->_percentEncodedHost = _percentEncodedHost;
    copy->_port = _port;
    copy->_percentEncodedPath = _percentEncodedPath;
    copy->_percentEncodedQuery = _percentEncodedQuery;
    copy->_percentEncodedFragment = _percentEncodedFragment;
    return copy;
}

- (NSURL *)URL
{
    NSString *string = charon_url_compose(self, NULL);
    return string ? [NSURL URLWithString:string] : nil;
}

- (NSURL *)URLRelativeToURL:(NSURL *)baseURL
{
    NSString *string = charon_url_compose(self, NULL);
    return string ? [NSURL URLWithString:string relativeToURL:baseURL] : nil;
}

- (NSString *)scheme
{
    return _scheme;
}

- (void)setScheme:(NSString *)scheme
{
    if (scheme)
        charon_url_require(charon_url_valid(CharonURLScheme, scheme), self, _cmd, @"scheme");
    _scheme = [scheme copy];
}

- (NSString *)user
{
    return [_percentEncodedUser stringByRemovingPercentEncoding];
}

- (void)setUser:(NSString *)user
{
    _percentEncodedUser = [user stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLUserAllowedCharacterSet]];
}

- (NSString *)password
{
    return [_percentEncodedPassword stringByRemovingPercentEncoding];
}

- (void)setPassword:(NSString *)password
{
    _percentEncodedPassword = [password stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPasswordAllowedCharacterSet]];
}

- (NSString *)host
{
    return [_percentEncodedHost stringByRemovingPercentEncoding];
}

- (void)setHost:(NSString *)host
{
    _percentEncodedHost = [host stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
}

- (NSNumber *)port
{
    return _port;
}

- (void)setPort:(NSNumber *)port
{
    if (port && port.longLongValue < 0)
        [NSException raise:NSInvalidArgumentException format:@"*** -[%@ %@]: negative port number", [self class], NSStringFromSelector(_cmd)];
    _port = port ? [NSNumber numberWithLongLong:port.longLongValue] : nil;
}

- (NSString *)path
{
    return [_percentEncodedPath stringByRemovingPercentEncoding];
}

- (void)setPath:(NSString *)path
{
    _percentEncodedPath = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
}

- (NSString *)query
{
    return [_percentEncodedQuery stringByRemovingPercentEncoding];
}

- (void)setQuery:(NSString *)query
{
    _percentEncodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

- (NSString *)fragment
{
    return [_percentEncodedFragment stringByRemovingPercentEncoding];
}

- (void)setFragment:(NSString *)fragment
{
    _percentEncodedFragment = [fragment stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
}

- (NSString *)percentEncodedUser
{
    return _percentEncodedUser;
}

- (void)setPercentEncodedUser:(NSString *)percentEncodedUser
{
    if (percentEncodedUser)
        charon_url_require(charon_url_valid(CharonURLUser, percentEncodedUser), self, _cmd, @"percentEncodedUser");
    _percentEncodedUser = [percentEncodedUser copy];
}

- (NSString *)percentEncodedPassword
{
    return _percentEncodedPassword;
}

- (void)setPercentEncodedPassword:(NSString *)percentEncodedPassword
{
    if (percentEncodedPassword)
        charon_url_require(charon_url_valid(CharonURLPassword, percentEncodedPassword), self, _cmd, @"percentEncodedPassword");
    _percentEncodedPassword = [percentEncodedPassword copy];
}

- (NSString *)percentEncodedHost
{
    return _percentEncodedHost;
}

- (void)setPercentEncodedHost:(NSString *)percentEncodedHost
{
    if (percentEncodedHost)
        charon_url_require(charon_url_valid(CharonURLHost, percentEncodedHost), self, _cmd, @"percentEncodedHost");
    _percentEncodedHost = [percentEncodedHost copy];
}

- (NSString *)percentEncodedPath
{
    return _percentEncodedPath;
}

- (void)setPercentEncodedPath:(NSString *)percentEncodedPath
{
    if (percentEncodedPath)
        charon_url_require(charon_url_valid(CharonURLPath, percentEncodedPath), self, _cmd, @"percentEncodedPath");
    _percentEncodedPath = [percentEncodedPath copy];
}

- (NSString *)percentEncodedQuery
{
    return _percentEncodedQuery;
}

- (void)setPercentEncodedQuery:(NSString *)percentEncodedQuery
{
    if (percentEncodedQuery)
        charon_url_require(charon_url_valid(CharonURLQuery, percentEncodedQuery), self, _cmd, @"percentEncodedQuery");
    _percentEncodedQuery = [percentEncodedQuery copy];
}

- (NSString *)percentEncodedFragment
{
    return _percentEncodedFragment;
}

- (void)setPercentEncodedFragment:(NSString *)percentEncodedFragment
{
    if (percentEncodedFragment)
        charon_url_require(charon_url_valid(CharonURLFragment, percentEncodedFragment), self, _cmd, @"percentEncodedFragment");
    _percentEncodedFragment = [percentEncodedFragment copy];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSURLComponents class]])
        return NO;
    NSURLComponents *other = object;
    return charon_url_same(self.scheme, other.scheme) && charon_url_same(self.percentEncodedUser, other.percentEncodedUser) &&
           charon_url_same(self.percentEncodedPassword, other.percentEncodedPassword) && charon_url_same(self.percentEncodedHost, other.percentEncodedHost) &&
           (self.port == other.port || [self.port isEqual:other.port]) && charon_url_same(self.percentEncodedPath, other.percentEncodedPath) &&
           charon_url_same(self.percentEncodedQuery, other.percentEncodedQuery) && charon_url_same(self.percentEncodedFragment, other.percentEncodedFragment);
}

- (NSUInteger)hash
{
    return self.scheme.hash ^ self.percentEncodedHost.hash ^ self.port.hash ^ self.percentEncodedPath.hash ^ self.percentEncodedQuery.hash ^ self.percentEncodedFragment.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> {scheme = %@, user = %@, password = %@, host = %@, port = %@, path = %@, query = %@, fragment = %@}",
            [self class], self, self.scheme, self.user, self.password, self.host, self.port, self.path, self.query, self.fragment];
}

@end
