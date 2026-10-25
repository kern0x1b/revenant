#import <Foundation/Foundation.h>
#import "../revenant_alias.h"

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
NSString *revenant_url_compose(id components, NSRange *ranges);

static NSString *revenant_url_path_escaping_colon(NSString *path)
{
    if (!path)
        return nil;
    NSRange slash = [path rangeOfString:@"/"];
    NSUInteger end = slash.location == NSNotFound ? path.length : slash.location;
    NSString *first = [[path substringToIndex:end] stringByReplacingOccurrencesOfString:@":" withString:@"%3A"];
    return [first stringByAppendingString:[path substringFromIndex:end]];
}

static const char revenant_port_text_key;
static const char revenant_host_text_key;

static void revenant_url_set_port_text(id components, NSString *text)
{
    objc_setAssociatedObject(components, &revenant_port_text_key, text, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void revenant_url_set_host_text(id components, NSString *text)
{
    objc_setAssociatedObject(components, &revenant_host_text_key, text, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static NSString *revenant_url_substring(NSString *string, NSRange range)
{
    return range.location == NSNotFound ? nil : [string substringWithRange:range];
}

static NSNumber *revenant_url_port(NSString *digits)
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

static void revenant_url_require(BOOL valid, id components, SEL selector, NSString *what)
{
    if (!valid)
        [NSException raise:NSInvalidArgumentException format:@"*** -[%@ %@]: invalid characters in %@", [components class], NSStringFromSelector(selector), what];
}

static BOOL revenant_url_same(NSString *first, NSString *second)
{
    return first == second || [first isEqualToString:second];
}

REVENANT_ALIAS_STATE(NSURLComponents, NSObject,
    NSString *_scheme;
    NSString *_percentEncodedUser;
    NSString *_percentEncodedPassword;
    NSString *_percentEncodedHost;
    NSNumber *_port;
    NSString *_percentEncodedPath;
    NSString *_percentEncodedQuery;
    NSString *_percentEncodedFragment;
)

@implementation REVENANT_ALIAS_CLASS(NSURLComponents) (RevenantComponents)


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
    NSRange ranges[RevenantURLPartCount];
    if (![URLString isKindOfClass:[NSString class]] || !revenant_url_parse(URLString, ranges))
        return nil;
    if ((self = [self init])) {
        _scheme = revenant_url_substring(URLString, ranges[RevenantURLScheme]);
        _percentEncodedUser = revenant_url_component(URLString, ranges[RevenantURLUser], RevenantURLUser);
        _percentEncodedPassword = revenant_url_component(URLString, ranges[RevenantURLPassword], RevenantURLPassword);
        _percentEncodedHost = revenant_url_component(URLString, ranges[RevenantURLHost], RevenantURLHost);
        revenant_url_set_host_text(self, revenant_url_host_text(URLString, ranges[RevenantURLHost]));
        NSString *portText = revenant_url_substring(URLString, ranges[RevenantURLPort]);
        revenant_url_set_port_text(self, portText);
        _port = revenant_url_port(portText);
        _percentEncodedPath = revenant_url_component(URLString, ranges[RevenantURLPath], RevenantURLPath);
        _percentEncodedQuery = revenant_url_component(URLString, ranges[RevenantURLQuery], RevenantURLQuery);
        _percentEncodedFragment = revenant_url_component(URLString, ranges[RevenantURLFragment], RevenantURLFragment);
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    REVENANT_ALIAS_CLASS(NSURLComponents) *copy = [[[self class] allocWithZone:zone] init];
    copy->_scheme = _scheme;
    copy->_percentEncodedUser = _percentEncodedUser;
    copy->_percentEncodedPassword = _percentEncodedPassword;
    copy->_percentEncodedHost = _percentEncodedHost;
    copy->_port = _port;
    revenant_url_set_port_text(copy, self.revenantPortText);
    revenant_url_set_host_text(copy, self.revenantHostText);
    copy->_percentEncodedPath = _percentEncodedPath;
    copy->_percentEncodedQuery = _percentEncodedQuery;
    copy->_percentEncodedFragment = _percentEncodedFragment;
    return copy;
}

- (NSURL *)URL
{
    NSString *string = revenant_url_compose(self, NULL);
    return string ? [NSURL URLWithString:string] : nil;
}

- (NSURL *)URLRelativeToURL:(NSURL *)baseURL
{
    NSString *string = revenant_url_compose(self, NULL);
    return string ? [NSURL URLWithString:string relativeToURL:baseURL] : nil;
}

- (NSString *)scheme
{
    return _scheme;
}

- (void)setScheme:(NSString *)scheme
{
    if (scheme)
        revenant_url_require(revenant_url_valid(RevenantURLScheme, scheme), self, _cmd, @"scheme");
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
    revenant_url_set_host_text(self, nil);
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
    revenant_url_set_port_text(self, nil);
}
- (NSString *)revenantPortText
{
    return objc_getAssociatedObject(self, &revenant_port_text_key);
}

- (NSString *)path
{
    return [_percentEncodedPath stringByRemovingPercentEncoding];
}

- (void)setPath:(NSString *)path
{
    _percentEncodedPath = revenant_url_path_escaping_colon([path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]);
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
        revenant_url_require(revenant_url_valid(RevenantURLUser, percentEncodedUser), self, _cmd, @"percentEncodedUser");
    _percentEncodedUser = [percentEncodedUser copy];
}

- (NSString *)percentEncodedPassword
{
    return _percentEncodedPassword;
}

- (void)setPercentEncodedPassword:(NSString *)percentEncodedPassword
{
    if (percentEncodedPassword)
        revenant_url_require(revenant_url_valid(RevenantURLPassword, percentEncodedPassword), self, _cmd, @"percentEncodedPassword");
    _percentEncodedPassword = [percentEncodedPassword copy];
}

- (NSString *)percentEncodedHost
{
    return _percentEncodedHost;
}

- (void)setPercentEncodedHost:(NSString *)percentEncodedHost
{
    if (percentEncodedHost)
        revenant_url_require(revenant_url_valid(RevenantURLHost, percentEncodedHost), self, _cmd, @"percentEncodedHost");
    _percentEncodedHost = [percentEncodedHost copy];
    revenant_url_set_host_text(self, nil);
}
- (NSString *)revenantHostText
{
    return objc_getAssociatedObject(self, &revenant_host_text_key);
}

- (NSString *)percentEncodedPath
{
    return _percentEncodedPath;
}

- (void)setPercentEncodedPath:(NSString *)percentEncodedPath
{
    if (percentEncodedPath)
        revenant_url_require(revenant_url_valid(RevenantURLPath, percentEncodedPath), self, _cmd, @"percentEncodedPath");
    _percentEncodedPath = [percentEncodedPath copy];
}

- (NSString *)percentEncodedQuery
{
    return _percentEncodedQuery;
}

- (void)setPercentEncodedQuery:(NSString *)percentEncodedQuery
{
    if (percentEncodedQuery)
        revenant_url_require(revenant_url_valid(RevenantURLQuery, percentEncodedQuery), self, _cmd, @"percentEncodedQuery");
    _percentEncodedQuery = [percentEncodedQuery copy];
}

- (NSString *)percentEncodedFragment
{
    return _percentEncodedFragment;
}

- (void)setPercentEncodedFragment:(NSString *)percentEncodedFragment
{
    if (percentEncodedFragment)
        revenant_url_require(revenant_url_valid(RevenantURLFragment, percentEncodedFragment), self, _cmd, @"percentEncodedFragment");
    _percentEncodedFragment = [percentEncodedFragment copy];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSURLComponents class]])
        return NO;
    REVENANT_ALIAS_CLASS(NSURLComponents) *other = object;
    return revenant_url_same(self.scheme, other.scheme) && revenant_url_same(self.percentEncodedUser, other.percentEncodedUser) &&
           revenant_url_same(self.percentEncodedPassword, other.percentEncodedPassword) && revenant_url_same(self.percentEncodedHost, other.percentEncodedHost) &&
           (self.port == other.port || [self.port isEqual:other.port]) && revenant_url_same(self.percentEncodedPath, other.percentEncodedPath) &&
           revenant_url_same(self.percentEncodedQuery, other.percentEncodedQuery) && revenant_url_same(self.percentEncodedFragment, other.percentEncodedFragment);
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
