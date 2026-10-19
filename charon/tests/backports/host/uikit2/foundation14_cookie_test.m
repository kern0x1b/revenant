#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

static uint64_t state = 0xC00C1E5ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *policy_of(NSHTTPCookie *cookie, BOOL port)
{
    return port ? ((id (*)(id, SEL))objc_msgSend)(cookie, NSSelectorFromString(@"charonHostSameSitePolicy")) : cookie.sameSitePolicy;
}

static NSString *describe(NSArray *cookies, BOOL port)
{
    NSMutableString *text = [NSMutableString string];
    for (NSHTTPCookie *cookie in cookies) {
        NSDictionary *properties = port ? ((id (*)(id, SEL, id))objc_msgSend)(cookie, NSSelectorFromString(@"charonHostCharon_properties:"), cookie.properties) : cookie.properties;
        [text appendFormat:@"[%@=%@ %@ %@ %@] ", cookie.name, cookie.value, policy_of(cookie, port), properties[@"SameSite"], cookie.path];
    }
    return text;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSArray *values = @[@"Lax", @"lax", @"STRICT", @"Strict", @"None", @"none", @"bogus", @"", @" lax", @"lax ", @"laxx", @"LaX"];
        NSUInteger wrong = 0, cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 5000;
        NSMutableArray *samples = [NSMutableArray array];
        for (NSUInteger index = 0; index < cases; index++) {
            NSMutableDictionary *properties = [@{NSHTTPCookieName: @"n", NSHTTPCookieValue: @"v", NSHTTPCookieDomain: @"x.com", NSHTTPCookiePath: @"/"} mutableCopy];
            if (next() % 5)
                properties[@"SameSite"] = values[next() % values.count];
            if (next() % 3 == 0)
                properties[NSHTTPCookieSecure] = @"TRUE";
            NSHTTPCookie *system = [NSHTTPCookie cookieWithProperties:properties];
            NSHTTPCookie *port = ((id (*)(id, SEL, id, id))objc_msgSend)([NSHTTPCookie class], NSSelectorFromString(@"charonHostCharon_cookieWithProperties:original:"), properties, ^NSHTTPCookie *(NSDictionary *plain) {
                return [NSHTTPCookie cookieWithProperties:plain];
            });
            NSString *a = describe(port ? @[port] : @[], YES), *b = describe(system ? @[system] : @[], NO);
            if (![a isEqualToString:b]) {
                wrong++;
                if (samples.count < 6)
                    [samples addObject:[NSString stringWithFormat:@"properties %@\n     port   %@\n     system %@", properties, a, b]];
            }
        }
        for (NSUInteger index = 0; index < cases; index++) {
            NSMutableArray *parts = [NSMutableArray array];
            NSUInteger count = 1 + next() % 3;
            for (NSUInteger part = 0; part < count; part++) {
                NSMutableString *cookie = [NSMutableString stringWithFormat:@"c%lu=v%u", (unsigned long)part, next() % 9];
                NSString *spelling = @[@"SameSite", @"samesite", @"SAMESITE"][next() % 3];
                for (NSUInteger attribute = 0; attribute < next() % 4; attribute++) {
                    switch (next() % 6) {
                    case 0: [cookie appendFormat:@"; %@=%@", spelling, values[next() % values.count]]; break;
                    case 1: [cookie appendFormat:@";%@%@=%@", next() % 2 ? @"" : @" ", spelling, values[next() % values.count]]; break;
                    case 2: [cookie appendString:@"; Expires=Wed, 21 Oct 2037 07:28:00 GMT"]; break;
                    case 3: [cookie appendString:@"; Path=/"]; break;
                    case 4: [cookie appendString:@"; HttpOnly"]; break;
                    default: [cookie appendString:@"; Secure"]; break;
                    }
                }
                [parts addObject:cookie];
            }
            NSDictionary *fields = @{next() % 4 ? @"Set-Cookie" : @"set-cookie": [parts componentsJoinedByString:@", "]};
            NSURL *URL = [NSURL URLWithString:@"http://x.com/"];
            NSArray *system = [NSHTTPCookie cookiesWithResponseHeaderFields:fields forURL:URL];
            NSArray *port = ((id (*)(id, SEL, id, id, id))objc_msgSend)([NSHTTPCookie class], NSSelectorFromString(@"charonHostCharon_cookiesWithHeaderFields:forURL:original:"), fields, URL, ^NSArray *{
                return [NSHTTPCookie cookiesWithResponseHeaderFields:fields forURL:URL];
            });
            NSString *a = describe(port, YES), *b = describe(system, NO);
            if (![a isEqualToString:b]) {
                wrong++;
                if (samples.count < 10)
                    [samples addObject:[NSString stringWithFormat:@"header %@\n     port   %@\n     system %@", fields, a, b]];
            }
        }
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        charon_check(wrong == 0, "the SameSite of a cookie made from properties or read from a header is the system's", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)cases * 2]);
        CHECK_EQUAL(NSHTTPCookieSameSiteLax, @"lax", "the lax constant");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
