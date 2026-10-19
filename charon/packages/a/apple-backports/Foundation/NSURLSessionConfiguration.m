#import <Foundation/Foundation.h>

__attribute__((visibility("hidden")))
@interface CharonEphemeralCookieStorage : NSHTTPCookieStorage {
@package
    NSMutableArray *_storedCookies;
    NSHTTPCookieAcceptPolicy _policy;
}
@end

__attribute__((visibility("hidden")))
@interface CharonEphemeralCredentialStorage : NSURLCredentialStorage {
@package
    NSMutableDictionary *_credentials;
    NSMutableDictionary *_defaultCredentials;
}
@end

static BOOL charon_domain_matches(NSString *host, NSString *domain)
{
    host = host.lowercaseString;
    domain = domain.lowercaseString;
    if (host.length == 0 || domain.length == 0)
        return NO;
    if ([domain hasPrefix:@"."])
        return [host isEqualToString:[domain substringFromIndex:1]] || [host hasSuffix:domain];
    return [host isEqualToString:domain];
}

static BOOL charon_path_matches(NSString *path, NSString *cookiePath)
{
    if (cookiePath.length == 0 || [cookiePath isEqualToString:@"/"])
        return YES;
    if (![path hasPrefix:cookiePath])
        return NO;
    return path.length == cookiePath.length || [cookiePath hasSuffix:@"/"] || [path characterAtIndex:cookiePath.length] == '/';
}

static BOOL charon_same_cookie(NSHTTPCookie *a, NSHTTPCookie *b)
{
    return [a.name isEqualToString:b.name] && [a.domain caseInsensitiveCompare:b.domain] == NSOrderedSame && [(a.path ?: @"/") isEqualToString:(b.path ?: @"/")];
}

@implementation CharonEphemeralCookieStorage

- (void)charon_removeExpired
{
    NSDate *now = [NSDate date];
    NSIndexSet *expired = [_storedCookies indexesOfObjectsPassingTest:^BOOL(NSHTTPCookie *cookie, NSUInteger index, BOOL *stop) {
        return cookie.expiresDate && [cookie.expiresDate compare:now] != NSOrderedDescending;
    }];
    [_storedCookies removeObjectsAtIndexes:expired];
}

- (NSArray *)cookies
{
    @synchronized (self) {
        [self charon_removeExpired];
        return [_storedCookies copy];
    }
}

- (void)setCookie:(NSHTTPCookie *)cookie
{
    if (!cookie)
        return;
    @synchronized (self) {
        if (_policy == NSHTTPCookieAcceptPolicyNever)
            return;
        NSIndexSet *same = [_storedCookies indexesOfObjectsPassingTest:^BOOL(NSHTTPCookie *stored, NSUInteger index, BOOL *stop) {
            return charon_same_cookie(stored, cookie);
        }];
        [_storedCookies removeObjectsAtIndexes:same];
        if (!cookie.expiresDate || [cookie.expiresDate compare:[NSDate date]] == NSOrderedDescending)
            [_storedCookies addObject:cookie];
    }
}

- (void)deleteCookie:(NSHTTPCookie *)cookie
{
    @synchronized (self) {
        NSIndexSet *same = [_storedCookies indexesOfObjectsPassingTest:^BOOL(NSHTTPCookie *stored, NSUInteger index, BOOL *stop) {
            return charon_same_cookie(stored, cookie);
        }];
        [_storedCookies removeObjectsAtIndexes:same];
    }
}

- (NSArray *)cookiesForURL:(NSURL *)URL
{
    NSString *path = URL.path.length ? URL.path : @"/";
    BOOL secure = [URL.scheme caseInsensitiveCompare:@"https"] == NSOrderedSame;
    NSMutableArray *found = [NSMutableArray array];
    @synchronized (self) {
        [self charon_removeExpired];
        for (NSHTTPCookie *cookie in _storedCookies) {
            if (charon_domain_matches(URL.host, cookie.domain) && charon_path_matches(path, cookie.path) && (!cookie.isSecure || secure))
                [found addObject:cookie];
        }
    }
    [found sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(NSHTTPCookie *a, NSHTTPCookie *b) {
        NSUInteger left = a.path.length, right = b.path.length;
        return left > right ? NSOrderedAscending : left < right ? NSOrderedDescending : NSOrderedSame;
    }];
    return found;
}

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)URL mainDocumentURL:(NSURL *)mainDocumentURL
{
    for (NSHTTPCookie *cookie in cookies) {
        if (_policy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain && mainDocumentURL && !charon_domain_matches(mainDocumentURL.host, cookie.domain) && !charon_domain_matches(mainDocumentURL.host, [@"." stringByAppendingString:cookie.domain]))
            continue;
        [self setCookie:cookie];
    }
}

- (NSHTTPCookieAcceptPolicy)cookieAcceptPolicy
{
    @synchronized (self) {
        return _policy;
    }
}

- (void)setCookieAcceptPolicy:(NSHTTPCookieAcceptPolicy)policy
{
    @synchronized (self) {
        _policy = policy;
    }
}

- (NSArray *)sortedCookiesUsingDescriptors:(NSArray *)sortOrder
{
    return [self.cookies sortedArrayUsingDescriptors:sortOrder];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> {cookies = %lu}", [self class], self, (unsigned long)self.cookies.count];
}

@end

@implementation CharonEphemeralCredentialStorage

- (NSDictionary *)credentialsForProtectionSpace:(NSURLProtectionSpace *)space
{
    @synchronized (self) {
        NSDictionary *found = _credentials[space];
        return found.count ? [found copy] : nil;
    }
}

- (NSDictionary *)allCredentials
{
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    @synchronized (self) {
        for (NSURLProtectionSpace *space in _credentials)
            all[space] = [_credentials[space] copy];
    }
    return all;
}

- (void)setCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space
{
    if (!credential.user || !space || credential.persistence == NSURLCredentialPersistenceNone)
        return;
    @synchronized (self) {
        NSMutableDictionary *byUser = _credentials[space];
        if (!byUser) {
            byUser = [NSMutableDictionary dictionary];
            _credentials[space] = byUser;
        }
        byUser[credential.user] = credential;
    }
}

- (void)removeCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space
{
    if (!credential.user || !space)
        return;
    @synchronized (self) {
        NSMutableDictionary *byUser = _credentials[space];
        [byUser removeObjectForKey:credential.user];
        if (byUser.count == 0)
            [_credentials removeObjectForKey:space];
        NSURLCredential *current = _defaultCredentials[space];
        if ([current.user isEqualToString:credential.user])
            [_defaultCredentials removeObjectForKey:space];
    }
}

- (void)removeCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space options:(NSDictionary *)options
{
    [self removeCredential:credential forProtectionSpace:space];
}

- (NSURLCredential *)defaultCredentialForProtectionSpace:(NSURLProtectionSpace *)space
{
    @synchronized (self) {
        return _defaultCredentials[space];
    }
}

- (void)setDefaultCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space
{
    if (!credential.user || !space || credential.persistence == NSURLCredentialPersistenceNone)
        return;
    [self setCredential:credential forProtectionSpace:space];
    @synchronized (self) {
        _defaultCredentials[space] = credential;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>", [self class], self];
}

@end

static NSHTTPCookieStorage *charon_ephemeral_cookie_storage(void)
{
    CharonEphemeralCookieStorage *storage = [CharonEphemeralCookieStorage alloc];
    storage->_storedCookies = [NSMutableArray array];
    storage->_policy = NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain;
    return storage;
}

static NSURLCredentialStorage *charon_ephemeral_credential_storage(void)
{
    CharonEphemeralCredentialStorage *storage = [CharonEphemeralCredentialStorage alloc];
    storage->_credentials = [NSMutableDictionary dictionary];
    storage->_defaultCredentials = [NSMutableDictionary dictionary];
    return storage;
}

@implementation NSURLSessionConfiguration {
@private
    SSLProtocol _TLSMinimumSupportedProtocol;
    SSLProtocol _TLSMaximumSupportedProtocol;
    BOOL _waitsForConnectivity;
}

@synthesize waitsForConnectivity = _waitsForConnectivity;
@synthesize identifier = _identifier;
@synthesize requestCachePolicy = _requestCachePolicy;
@synthesize timeoutIntervalForRequest = _timeoutIntervalForRequest;
@synthesize timeoutIntervalForResource = _timeoutIntervalForResource;
@synthesize networkServiceType = _networkServiceType;
@synthesize allowsCellularAccess = _allowsCellularAccess;
@synthesize discretionary = _discretionary;
@synthesize sessionSendsLaunchEvents = _sessionSendsLaunchEvents;
@synthesize connectionProxyDictionary = _connectionProxyDictionary;
@synthesize HTTPShouldUsePipelining = _HTTPShouldUsePipelining;
@synthesize HTTPShouldSetCookies = _HTTPShouldSetCookies;
@synthesize HTTPCookieAcceptPolicy = _HTTPCookieAcceptPolicy;
@synthesize HTTPAdditionalHeaders = _HTTPAdditionalHeaders;
@synthesize HTTPMaximumConnectionsPerHost = _HTTPMaximumConnectionsPerHost;
@synthesize HTTPCookieStorage = _HTTPCookieStorage;
@synthesize URLCredentialStorage = _URLCredentialStorage;
@synthesize URLCache = _URLCache;
@synthesize protocolClasses = _protocolClasses;

- (SSLProtocol)TLSMinimumSupportedProtocol
{
    return _TLSMinimumSupportedProtocol;
}

- (SSLProtocol)TLSMaximumSupportedProtocol
{
    return _TLSMaximumSupportedProtocol;
}

@dynamic allowsExpensiveNetworkAccess;
@dynamic allowsConstrainedNetworkAccess;
@dynamic requiresDNSSECValidation;
@dynamic TLSMinimumSupportedProtocol, TLSMaximumSupportedProtocol;
@dynamic TLSMinimumSupportedProtocolVersion;
@dynamic TLSMaximumSupportedProtocolVersion;
@dynamic shouldUseExtendedBackgroundIdleMode;
#if TARGET_OS_IPHONE
@dynamic multipathServiceType;
#endif

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (NSURLSessionConfiguration *)defaultSessionConfiguration
{
    return [[self alloc] init];
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration
{
    NSURLSessionConfiguration *configuration = [[self alloc] init];
    configuration->_HTTPCookieStorage = charon_ephemeral_cookie_storage();
    configuration->_URLCredentialStorage = charon_ephemeral_credential_storage();
    configuration->_URLCache = [[NSURLCache alloc] initWithMemoryCapacity:512000 diskCapacity:0 diskPath:nil];
    return configuration;
}

+ (NSURLSessionConfiguration *)backgroundSessionConfiguration:(NSString *)identifier
{
    NSURLSessionConfiguration *configuration = [[self alloc] init];
    configuration->_identifier = [identifier copy];
    configuration->_sessionSendsLaunchEvents = YES;
    configuration->_URLCache = nil;
    return configuration;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
        _timeoutIntervalForRequest = 60;
        _timeoutIntervalForResource = 604800;
        _networkServiceType = NSURLNetworkServiceTypeDefault;
        _allowsCellularAccess = YES;
        _TLSMinimumSupportedProtocol = kSSLProtocol3;
        _TLSMaximumSupportedProtocol = kTLSProtocol12;
        _HTTPShouldSetCookies = YES;
        _HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain;
#if TARGET_OS_IPHONE
        _HTTPMaximumConnectionsPerHost = 4;
#else
        _HTTPMaximumConnectionsPerHost = 6;
#endif
        _HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        _URLCredentialStorage = [NSURLCredentialStorage sharedCredentialStorage];
        _URLCache = [NSURLCache sharedURLCache];
        _protocolClasses = @[];
    }
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [self copyWithZone:zone];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSURLSessionConfiguration *copy = [[[self class] alloc] init];
    copy->_identifier = self.identifier;
    copy->_requestCachePolicy = self.requestCachePolicy;
    copy->_timeoutIntervalForRequest = self.timeoutIntervalForRequest;
    copy->_timeoutIntervalForResource = self.timeoutIntervalForResource;
    copy->_networkServiceType = self.networkServiceType;
    copy->_allowsCellularAccess = self.allowsCellularAccess;
    copy->_discretionary = self.isDiscretionary;
    copy->_sessionSendsLaunchEvents = self.sessionSendsLaunchEvents;
    copy->_waitsForConnectivity = self.waitsForConnectivity;
    copy->_connectionProxyDictionary = self.connectionProxyDictionary;
    copy->_TLSMinimumSupportedProtocol = self.TLSMinimumSupportedProtocol;
    copy->_TLSMaximumSupportedProtocol = self.TLSMaximumSupportedProtocol;
    copy->_HTTPShouldUsePipelining = self.HTTPShouldUsePipelining;
    copy->_HTTPShouldSetCookies = self.HTTPShouldSetCookies;
    copy->_HTTPCookieAcceptPolicy = self.HTTPCookieAcceptPolicy;
    copy->_HTTPAdditionalHeaders = self.HTTPAdditionalHeaders;
    copy->_HTTPMaximumConnectionsPerHost = self.HTTPMaximumConnectionsPerHost;
    copy->_HTTPCookieStorage = self.HTTPCookieStorage;
    copy->_URLCredentialStorage = self.URLCredentialStorage;
    copy->_URLCache = self.URLCache;
    copy->_protocolClasses = self.protocolClasses;
    copy.sharedContainerIdentifier = self.sharedContainerIdentifier;
    return copy;
}

@end
