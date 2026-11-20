#import "check.h"
#import "RevenantCookieStorage.h"

enum {
    STORE_COOKIES,
    STORE_CREDENTIALS,
    STORE_CACHE,
    STORE_COUNT
};

static int revenant_calls[STORE_COUNT];

static void revenant_count(Class base, SEL selector, int index)
{
    Method method = class_getClassMethod(base, selector);
    IMP original = method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^id(id self) {
        revenant_calls[index]++;
        return ((id (*)(id, SEL))original)(self, selector);
    }));
}

static void revenant_forget_calls(void)
{
    memset(revenant_calls, 0, sizeof(revenant_calls));
}

static NSString *revenant_asked(void)
{
    return [NSString stringWithFormat:@"cookies %d, credentials %d, cache %d", revenant_calls[STORE_COOKIES], revenant_calls[STORE_CREDENTIALS], revenant_calls[STORE_CACHE]];
}

static NSHTTPCookie *revenant_cookie(NSString *name)
{
    return [NSHTTPCookie cookieWithProperties:@{NSHTTPCookieName: name, NSHTTPCookieValue: @"v", NSHTTPCookieDomain: @"example.com", NSHTTPCookiePath: @"/",
                                                NSHTTPCookieExpires: [NSDate dateWithTimeIntervalSinceNow:3600]}];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    revenant_count([NSHTTPCookieStorage class], @selector(sharedHTTPCookieStorage), STORE_COOKIES);
    revenant_count([NSURLCredentialStorage class], @selector(sharedCredentialStorage), STORE_CREDENTIALS);
    revenant_count([NSURLCache class], @selector(sharedURLCache), STORE_CACHE);

    revenant_forget_calls();
    NSURLSessionConfiguration *first = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    revenant_check(revenant_calls[STORE_COOKIES] == 0, "an ephemeral configuration does not ask for the shared cookie store", revenant_asked());
    revenant_check(revenant_calls[STORE_CREDENTIALS] == 0, "an ephemeral configuration does not ask for the shared credential store", revenant_asked());
    revenant_check(revenant_calls[STORE_CACHE] == 0, "an ephemeral configuration does not ask for the shared URL cache", revenant_asked());

    NSHTTPCookieStorage *sharedCookies = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSURLCredentialStorage *sharedCredentials = [NSURLCredentialStorage sharedCredentialStorage];
    NSURLCache *sharedCache = [NSURLCache sharedURLCache];
    revenant_check(first.HTTPCookieStorage != nil && first.HTTPCookieStorage != sharedCookies, "its cookie store is not the shared one", @"same or missing");
    revenant_check(first.URLCredentialStorage != nil && first.URLCredentialStorage != sharedCredentials, "its credential store is not the shared one", @"same or missing");
    revenant_check(first.URLCache != nil && first.URLCache != sharedCache, "its URL cache is not the shared one", @"same or missing");

    revenant_forget_calls();
    NSURLSessionConfiguration *second = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    revenant_check(second.HTTPCookieStorage != first.HTTPCookieStorage, "two ephemeral configurations have cookie stores of their own", @"same store");
    revenant_check(second.URLCredentialStorage != first.URLCredentialStorage, "two ephemeral configurations have credential stores of their own", @"same store");
    revenant_check(second.URLCache != first.URLCache, "two ephemeral configurations have URL caches of their own", @"same cache");

    NSUInteger sharedBefore = sharedCookies.cookies.count;
    [first.HTTPCookieStorage setCookie:revenant_cookie(@"ephemeral")];
    revenant_check(first.HTTPCookieStorage.cookies.count == 1, "a cookie set in an ephemeral store stays there", [NSString stringWithFormat:@"%lu", (unsigned long)first.HTTPCookieStorage.cookies.count]);
    revenant_check(second.HTTPCookieStorage.cookies.count == 0, "another ephemeral store does not see it", [NSString stringWithFormat:@"%lu", (unsigned long)second.HTTPCookieStorage.cookies.count]);
    revenant_check(sharedCookies.cookies.count == sharedBefore, "the shared store does not see it", [NSString stringWithFormat:@"%lu then %lu", (unsigned long)sharedBefore, (unsigned long)sharedCookies.cookies.count]);

    revenant_forget_calls();
    NSURLSessionConfiguration *copy = [first copy];
    revenant_check(revenant_calls[STORE_COOKIES] == 0 && revenant_calls[STORE_CREDENTIALS] == 0 && revenant_calls[STORE_CACHE] == 0, "copying an ephemeral configuration asks for no shared store", revenant_asked());
    revenant_check(copy.HTTPCookieStorage == first.HTTPCookieStorage && copy.URLCredentialStorage == first.URLCredentialStorage && copy.URLCache == first.URLCache, "a copy keeps the stores of its source", @"different stores");

    revenant_forget_calls();
    NSURLSessionConfiguration *standard = [NSURLSessionConfiguration defaultSessionConfiguration];
    BOOL asksAll = revenant_calls[STORE_COOKIES] > 0 && revenant_calls[STORE_CREDENTIALS] > 0 && revenant_calls[STORE_CACHE] > 0;
    NSString *asked = revenant_asked();
    BOOL standardShares = standard.HTTPCookieStorage == sharedCookies && standard.URLCredentialStorage == sharedCredentials && standard.URLCache == sharedCache;
    revenant_check(standardShares == (revenant_negative ? NO : YES), "a default configuration uses the shared stores", @"not the shared stores");
    revenant_check(asksAll, "a default configuration asks for the shared stores", asked);
    return revenant_finish();
}
