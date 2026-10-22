#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

NSURLSessionConfiguration *revenant_task_configuration(NSURLSessionTask *task);

static char RevenantCookieLedgerKey;
static NSDate *revenant_ledger_origin;

static NSString *revenant_cookie_key(NSHTTPCookie *cookie)
{
    return [NSString stringWithFormat:@"%@\n%@\n%@", cookie.name, cookie.domain.lowercaseString, cookie.path ?: @"/"];
}

static void revenant_ledger_record(NSHTTPCookieStorage *storage, NSDate *seen)
{
    NSMutableDictionary *ledger = objc_getAssociatedObject(storage, &RevenantCookieLedgerKey);
    if (!ledger) {
        ledger = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(storage, &RevenantCookieLedgerKey, ledger, OBJC_ASSOCIATION_RETAIN);
    }
    NSMutableSet *current = [NSMutableSet set];
    for (NSHTTPCookie *cookie in storage.cookies) {
        NSString *key = revenant_cookie_key(cookie);
        [current addObject:key];
        if (!ledger[key])
            ledger[key] = seen;
    }
    for (NSString *key in [ledger allKeys]) {
        if (![current containsObject:key])
            [ledger removeObjectForKey:key];
    }
}

static NSDate *revenant_cookie_created(NSHTTPCookieStorage *storage, NSHTTPCookie *cookie)
{
    id created = cookie.properties[@"Created"];
    if ([created isKindOfClass:[NSNumber class]] || ([created isKindOfClass:[NSString class]] && [created length]))
        return [NSDate dateWithTimeIntervalSinceReferenceDate:[created doubleValue]];
    @synchronized ([NSHTTPCookieStorage class]) {
        NSMutableDictionary *ledger = objc_getAssociatedObject(storage, &RevenantCookieLedgerKey);
        return ledger[revenant_cookie_key(cookie)] ?: revenant_ledger_origin;
    }
}

__attribute__((constructor)) static void revenant_cookie_ledger_start(void)
{
    revenant_ledger_origin = [NSDate date];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSHTTPCookieManagerCookiesChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        if ([note.object isKindOfClass:[NSHTTPCookieStorage class]]) {
            @synchronized ([NSHTTPCookieStorage class]) {
                revenant_ledger_record(note.object, [NSDate date]);
            }
        }
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized ([NSHTTPCookieStorage class]) {
            revenant_ledger_record([NSHTTPCookieStorage sharedHTTPCookieStorage], revenant_ledger_origin);
        }
    });
}

@implementation NSHTTPCookieStorage (RevenantTask8)

- (void)removeCookiesSinceDate:(NSDate *)date
{
    for (NSHTTPCookie *cookie in [self.cookies copy]) {
        NSDate *created = revenant_cookie_created(self, cookie);
        if (!created || [created compare:date] != NSOrderedAscending)
            [self deleteCookie:cookie];
    }
}

- (void)storeCookies:(NSArray<NSHTTPCookie *> *)cookies forTask:(NSURLSessionTask *)task
{
    NSURLRequest *request = task.currentRequest ?: task.originalRequest;
    if (revenant_task_configuration(task).HTTPCookieAcceptPolicy == NSHTTPCookieAcceptPolicyNever || !request.URL)
        return;
    [self setCookies:cookies forURL:request.URL mainDocumentURL:request.mainDocumentURL];
}

- (void)getCookiesForTask:(NSURLSessionTask *)task completionHandler:(void (^)(NSArray<NSHTTPCookie *> *cookies))completionHandler
{
    NSURLSessionConfiguration *configuration = revenant_task_configuration(task);
    NSURLRequest *request = task.currentRequest ?: task.originalRequest;
    NSArray *cookies = nil;
    if (configuration.HTTPCookieAcceptPolicy != NSHTTPCookieAcceptPolicyNever && configuration.HTTPShouldSetCookies && request.URL)
        cookies = [self cookiesForURL:request.URL];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completionHandler(cookies);
    });
}

@end
