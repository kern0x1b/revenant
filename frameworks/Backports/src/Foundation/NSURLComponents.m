#import <Foundation/Foundation.h>
#import "../revenant_alias.h"
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
static const char revenant_parsed_string_key;

static void revenant_url_set_port_text(id components, NSString *text)
{
    objc_setAssociatedObject(components, &revenant_port_text_key, text, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void revenant_url_set_parsed(id components, NSString *text)
{
    objc_setAssociatedObject(components, &revenant_parsed_string_key, text, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void revenant_url_set_host_text(id components, NSString *text)
{
    objc_setAssociatedObject(components, &revenant_host_text_key, text, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static NSString *revenant_url_substring(NSString *string, NSRange range)
{
    return range.location == NSNotFound ? nil : [string substringWithRange:range];
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

- (instancetype)initWithString:(NSString *)source
{
    NSString *URLString = revenant_url_standard(source, YES, NO);
    NSRange ranges[RevenantURLPartCount];
    if (!URLString || !revenant_url_parse(URLString, ranges))
        return nil;
    if ((self = [self init])) {
        _scheme = revenant_url_substring(URLString, ranges[RevenantURLScheme]);
        _percentEncodedUser = revenant_url_component(URLString, ranges[RevenantURLUser], RevenantURLUser);
        _percentEncodedPassword = revenant_url_component(URLString, ranges[RevenantURLPassword], RevenantURLPassword);
        _percentEncodedHost = revenant_url_component(URLString, ranges[RevenantURLHost], RevenantURLHost);
        NSString *portText = revenant_url_substring(URLString, ranges[RevenantURLPort]);
        _port = revenant_url_integer(portText);
        if (!_percentEncodedHost && (_port || _percentEncodedUser))
            _percentEncodedHost = @"";
        revenant_url_set_host_text(self, revenant_url_host_text(URLString, ranges[RevenantURLHost]));
        revenant_url_set_port_text(self, portText);
        revenant_url_set_parsed(self, URLString);
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
    revenant_url_set_parsed(copy, self.revenantParsedString);
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
    revenant_url_set_parsed(self, nil);
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
    revenant_url_set_parsed(self, nil);
    _percentEncodedUser = [user stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLUserAllowedCharacterSet]];
}

- (NSString *)password
{
    return [_percentEncodedPassword stringByRemovingPercentEncoding];
}

- (void)setPassword:(NSString *)password
{
    revenant_url_set_parsed(self, nil);
    _percentEncodedPassword = [password stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPasswordAllowedCharacterSet]];
}

- (NSString *)host
{
    return [_percentEncodedHost stringByRemovingPercentEncoding];
}

- (void)setHost:(NSString *)host
{
    revenant_url_set_parsed(self, nil);
    _percentEncodedHost = [host stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    revenant_url_set_host_text(self, nil);
}

- (NSNumber *)port
{
    return _port;
}

- (void)setPort:(NSNumber *)port
{
    revenant_url_set_parsed(self, nil);
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
    revenant_url_set_parsed(self, nil);
    _percentEncodedPath = revenant_url_path_escaping_colon([path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]);
}

- (NSString *)query
{
    return [_percentEncodedQuery stringByRemovingPercentEncoding];
}

- (void)setQuery:(NSString *)query
{
    revenant_url_set_parsed(self, nil);
    _percentEncodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

- (NSString *)fragment
{
    return [_percentEncodedFragment stringByRemovingPercentEncoding];
}

- (void)setFragment:(NSString *)fragment
{
    revenant_url_set_parsed(self, nil);
    _percentEncodedFragment = [fragment stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
}

- (NSString *)percentEncodedUser
{
    return _percentEncodedUser;
}

- (void)setPercentEncodedUser:(NSString *)percentEncodedUser
{
    revenant_url_set_parsed(self, nil);
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
    revenant_url_set_parsed(self, nil);
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
    revenant_url_set_parsed(self, nil);
    if (percentEncodedHost)
        revenant_url_require(revenant_url_valid(RevenantURLHost, percentEncodedHost), self, _cmd, @"percentEncodedHost");
    _percentEncodedHost = [percentEncodedHost copy];
    revenant_url_set_host_text(self, nil);
}

- (NSString *)encodedHost
{
    return self.revenantHostText ?: _percentEncodedHost;
}

- (void)setEncodedHost:(NSString *)encodedHost
{
    revenant_url_set_parsed(self, nil);
    if (encodedHost)
        revenant_url_require(revenant_url_valid(RevenantURLHost, encodedHost), self, _cmd, @"encodedHost");
    _percentEncodedHost = [encodedHost copy];
    revenant_url_set_host_text(self, nil);
}

- (NSString *)revenantParsedString
{
    return objc_getAssociatedObject(self, &revenant_parsed_string_key);
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
    revenant_url_set_parsed(self, nil);
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
    revenant_url_set_parsed(self, nil);
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
    revenant_url_set_parsed(self, nil);
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
