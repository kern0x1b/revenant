#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSHTTPCookiePropertyKey const NSHTTPCookieSameSitePolicy = @"SameSite";
NSHTTPCookieStringPolicy const NSHTTPCookieSameSiteLax = @"lax";
NSHTTPCookieStringPolicy const NSHTTPCookieSameSiteStrict = @"strict";

static char RevenantCookiePolicyKey;

static NSMutableDictionary *revenant_cookie_policies(void)
{
    static NSMutableDictionary *policies;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        policies = [NSMutableDictionary dictionary];
    });
    return policies;
}

static NSString *revenant_cookie_key(NSHTTPCookie *cookie)
{
    return [NSString stringWithFormat:@"%@\n%@\n%@", cookie.name, cookie.domain.lowercaseString, cookie.path];
}

static NSString *revenant_cookie_policy(id value)
{
    if (![value isKindOfClass:[NSString class]])
        return nil;
    NSString *policy = [value lowercaseString];
    return [@[@"lax", @"strict", @"none"] containsObject:policy] ? policy : nil;
}

static NSHTTPCookie *revenant_cookie_mark(NSHTTPCookie *cookie, NSString *policy)
{
    if (!cookie)
        return nil;
    objc_setAssociatedObject(cookie, &RevenantCookiePolicyKey, policy ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN);
    NSMutableDictionary *policies = revenant_cookie_policies();
    @synchronized (policies) {
        if (policy)
            policies[revenant_cookie_key(cookie)] = policy;
        else
            [policies removeObjectForKey:revenant_cookie_key(cookie)];
    }
    return cookie;
}

@implementation NSHTTPCookie (RevenantSameSite)

- (NSHTTPCookieStringPolicy)sameSitePolicy
{
    id marked = objc_getAssociatedObject(self, &RevenantCookiePolicyKey);
    if (marked)
        return marked == [NSNull null] ? nil : marked;
    NSMutableDictionary *policies = revenant_cookie_policies();
    @synchronized (policies) {
        return policies[revenant_cookie_key(self)];
    }
}

+ (NSHTTPCookie *)revenant_cookieWithProperties:(NSDictionary *)properties original:(NSHTTPCookie *(^)(NSDictionary *))original
{
    NSString *policy = revenant_cookie_policy(properties[NSHTTPCookieSameSitePolicy]);
    NSMutableDictionary *plain = [properties mutableCopy];
    [plain removeObjectForKey:NSHTTPCookieSameSitePolicy];
    return revenant_cookie_mark(original(plain), policy);
}

+ (NSArray *)revenant_cookiesWithHeaderFields:(NSDictionary *)headerFields forURL:(NSURL *)URL original:(NSArray *(^)(void))original
{
    NSMutableArray *cookies = [NSMutableArray array];
    for (NSHTTPCookie *cookie in original()) {
        if (cookie.isSecure && ![URL.scheme.lowercaseString isEqualToString:@"https"])
            continue;
        [cookies addObject:cookie];
    }
    NSString *header = nil;
    for (NSString *name in headerFields) {
        if ([name caseInsensitiveCompare:@"Set-Cookie"] == NSOrderedSame)
            header = headerFields[name];
    }
    NSMutableDictionary *byName = [NSMutableDictionary dictionary];
    NSRegularExpression *split = [NSRegularExpression regularExpressionWithPattern:@",\\s+(?=[A-Za-z0-9_\\-\\.]+=)" options:0 error:NULL];
    NSMutableArray *segments = [NSMutableArray array];
    NSUInteger from = 0;
    for (NSTextCheckingResult *match in [split matchesInString:header ?: @"" options:0 range:NSMakeRange(0, header.length)]) {
        [segments addObject:[header substringWithRange:NSMakeRange(from, match.range.location - from)]];
        from = NSMaxRange(match.range);
    }
    if (header)
        [segments addObject:[header substringFromIndex:from]];
    NSCharacterSet *blank = [NSCharacterSet whitespaceCharacterSet];
    for (NSString *segment in segments) {
        NSArray *attributes = [segment componentsSeparatedByString:@";"];
        NSString *name = [[attributes.firstObject componentsSeparatedByString:@"="].firstObject stringByTrimmingCharactersInSet:blank];
        NSMutableDictionary *spellings = [NSMutableDictionary dictionary];
        for (NSString *attribute in [attributes subarrayWithRange:NSMakeRange(1, attributes.count - 1)]) {
            NSRange equals = [attribute rangeOfString:@"="];
            NSString *key = [(equals.location == NSNotFound ? attribute : [attribute substringToIndex:equals.location]) stringByTrimmingCharactersInSet:blank];
            if ([key caseInsensitiveCompare:@"SameSite"] == NSOrderedSame)
                spellings[key] = equals.location == NSNotFound ? (id)[NSNull null] : (revenant_cookie_policy([[attribute substringFromIndex:NSMaxRange(equals)] stringByTrimmingCharactersInSet:blank]) ?: (id)[NSNull null]);
        }
        id policy = spellings.count ? spellings[[[spellings allKeys] sortedArrayUsingSelector:@selector(compare:)].firstObject] : nil;
        byName[name] = policy ?: (id)[NSNull null];
    }
    for (NSHTTPCookie *cookie in cookies) {
        id policy = byName[cookie.name];
        revenant_cookie_mark(cookie, policy == [NSNull null] ? nil : policy);
    }
    return cookies;
}

- (NSDictionary *)revenant_properties:(NSDictionary *)original
{
    NSString *policy = self.sameSitePolicy;
    if (!policy)
        return original;
    NSMutableDictionary *merged = [original mutableCopy];
    merged[NSHTTPCookieSameSitePolicy] = policy;
    return merged;
}

@end

@interface RevenantSameSiteInstaller : NSObject
@end

@implementation RevenantSameSiteInstaller

+ (void)load
{
#ifdef REVENANT_HOST_DIFFERENTIAL
    return;
#endif
    Class meta = object_getClass([NSHTTPCookie class]);
    SEL make = @selector(cookieWithProperties:);
    IMP makeOriginal = method_getImplementation(class_getClassMethod([NSHTTPCookie class], make));
    class_replaceMethod(meta, make, imp_implementationWithBlock(^NSHTTPCookie *(Class cls, NSDictionary *properties) {
        return [NSHTTPCookie revenant_cookieWithProperties:properties original:^NSHTTPCookie *(NSDictionary *plain) {
            return ((id (*)(id, SEL, id))makeOriginal)(cls, make, plain);
        }];
    }), method_getTypeEncoding(class_getClassMethod([NSHTTPCookie class], make)));
    SEL parse = @selector(cookiesWithResponseHeaderFields:forURL:);
    IMP parseOriginal = method_getImplementation(class_getClassMethod([NSHTTPCookie class], parse));
    class_replaceMethod(meta, parse, imp_implementationWithBlock(^NSArray *(Class cls, NSDictionary *fields, NSURL *URL) {
        return [NSHTTPCookie revenant_cookiesWithHeaderFields:fields forURL:URL original:^NSArray *{
            return ((id (*)(id, SEL, id, id))parseOriginal)(cls, parse, fields, URL);
        }];
    }), method_getTypeEncoding(class_getClassMethod([NSHTTPCookie class], parse)));
    SEL properties = @selector(properties);
    IMP propertiesOriginal = method_getImplementation(class_getInstanceMethod([NSHTTPCookie class], properties));
    class_replaceMethod([NSHTTPCookie class], properties, imp_implementationWithBlock(^NSDictionary *(NSHTTPCookie *cookie) {
        return [cookie revenant_properties:((id (*)(id, SEL))propertiesOriginal)(cookie, properties)];
    }), method_getTypeEncoding(class_getInstanceMethod([NSHTTPCookie class], properties)));
}

@end
