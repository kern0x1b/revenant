#import "RevenantCookieStorage.h"

static BOOL revenant_domain_matches(NSString *host, NSString *domain)
{
    host = host.lowercaseString;
    domain = domain.lowercaseString;
    if (host.length == 0 || domain.length == 0)
        return NO;
    if ([domain hasPrefix:@"."])
        return [host isEqualToString:[domain substringFromIndex:1]] || [host hasSuffix:domain];
    return [host isEqualToString:domain];
}

static BOOL revenant_path_matches(NSString *path, NSString *cookiePath)
{
    if (cookiePath.length == 0 || [cookiePath isEqualToString:@"/"])
        return YES;
    if (![path hasPrefix:cookiePath])
        return NO;
    return path.length == cookiePath.length || [cookiePath hasSuffix:@"/"] || [path characterAtIndex:cookiePath.length] == '/';
}

static BOOL revenant_same_cookie(NSHTTPCookie *a, NSHTTPCookie *b)
{
    return [a.name isEqualToString:b.name] && [a.domain caseInsensitiveCompare:b.domain] == NSOrderedSame && [(a.path ?: @"/") isEqualToString:(b.path ?: @"/")];
}

static NSDate *revenant_modified(NSURL *file)
{
    NSDate *modified = nil;
    [file getResourceValue:&modified forKey:NSURLContentModificationDateKey error:NULL];
    return modified;
}

@implementation RevenantEphemeralCookieStorage

- (void)revenant_removeExpired
{
    NSDate *now = [NSDate date];
    NSIndexSet *expired = [_storedCookies indexesOfObjectsPassingTest:^BOOL(NSHTTPCookie *cookie, NSUInteger index, BOOL *stop) {
        return cookie.expiresDate && [cookie.expiresDate compare:now] != NSOrderedDescending;
    }];
    [_storedCookies removeObjectsAtIndexes:expired];
}

- (void)revenant_reload
{
    if (!_persistentURL)
        return;
    NSDate *modified = revenant_modified(_persistentURL);
    if (!modified || [modified isEqual:_loaded])
        return;
    NSMutableArray *kept = [NSMutableArray array];
    for (NSHTTPCookie *cookie in _storedCookies) {
        if (!cookie.expiresDate)
            [kept addObject:cookie];
    }
    for (NSDictionary *properties in [NSArray arrayWithContentsOfURL:_persistentURL]) {
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:properties];
        if (cookie)
            [kept addObject:cookie];
    }
    _storedCookies = kept;
    _loaded = modified;
}

- (void)revenant_save
{
    if (!_persistentURL)
        return;
    NSMutableArray *persistent = [NSMutableArray array];
    for (NSHTTPCookie *cookie in _storedCookies) {
        if (cookie.expiresDate && cookie.properties)
            [persistent addObject:cookie.properties];
    }
    [[NSFileManager defaultManager] createDirectoryAtURL:[_persistentURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    [persistent writeToURL:_persistentURL atomically:YES];
    _loaded = revenant_modified(_persistentURL);
}

- (NSArray *)cookies
{
    @synchronized (self) {
        [self revenant_reload];
        [self revenant_removeExpired];
        return [_storedCookies copy];
    }
}

- (void)revenant_notify
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NSHTTPCookieManagerCookiesChangedNotification object:self];
}

- (void)setCookie:(NSHTTPCookie *)cookie
{
    if (!cookie)
        return;
    @synchronized (self) {
        if (_policy == NSHTTPCookieAcceptPolicyNever)
            return;
        [self revenant_reload];
        NSIndexSet *same = [_storedCookies indexesOfObjectsPassingTest:^BOOL(NSHTTPCookie *stored, NSUInteger index, BOOL *stop) {
            return revenant_same_cookie(stored, cookie);
        }];
        [_storedCookies removeObjectsAtIndexes:same];
        if (!cookie.expiresDate || [cookie.expiresDate compare:[NSDate date]] == NSOrderedDescending)
            [_storedCookies addObject:cookie];
        [self revenant_save];
    }
    [self revenant_notify];
}

- (void)deleteCookie:(NSHTTPCookie *)cookie
{
    @synchronized (self) {
        [self revenant_reload];
        NSIndexSet *same = [_storedCookies indexesOfObjectsPassingTest:^BOOL(NSHTTPCookie *stored, NSUInteger index, BOOL *stop) {
            return revenant_same_cookie(stored, cookie);
        }];
        [_storedCookies removeObjectsAtIndexes:same];
        [self revenant_save];
    }
    [self revenant_notify];
}

- (NSArray *)cookiesForURL:(NSURL *)URL
{
    NSString *path = URL.path.length ? URL.path : @"/";
    BOOL secure = [URL.scheme caseInsensitiveCompare:@"https"] == NSOrderedSame;
    NSMutableArray *found = [NSMutableArray array];
    @synchronized (self) {
        [self revenant_reload];
        [self revenant_removeExpired];
        for (NSHTTPCookie *cookie in _storedCookies) {
            if (revenant_domain_matches(URL.host, cookie.domain) && revenant_path_matches(path, cookie.path) && (!cookie.isSecure || secure))
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
        if (_policy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain && mainDocumentURL && !revenant_domain_matches(mainDocumentURL.host, cookie.domain) && !revenant_domain_matches(mainDocumentURL.host, [@"." stringByAppendingString:cookie.domain]))
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

NSHTTPCookieStorage *revenant_ephemeral_cookie_storage(void)
{
    RevenantEphemeralCookieStorage *storage = [RevenantEphemeralCookieStorage alloc];
    storage->_storedCookies = [NSMutableArray array];
    storage->_policy = NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain;
    return storage;
}

NSHTTPCookieStorage *revenant_group_cookie_storage(NSString *identifier, NSURL *container)
{
    static NSMutableDictionary *storages;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        storages = [NSMutableDictionary dictionary];
    });
    NSString *key = [(container.path ?: @"") stringByAppendingFormat:@"\n%@", identifier];
    @synchronized (storages) {
        NSHTTPCookieStorage *found = storages[key];
        if (!found) {
            RevenantEphemeralCookieStorage *storage = (RevenantEphemeralCookieStorage *)revenant_ephemeral_cookie_storage();
            storage->_persistentURL = [container URLByAppendingPathComponent:@"Library/Cookies/Cookies.revenant.plist"];
            found = storage;
            storages[key] = found;
        }
        return found;
    }
}
