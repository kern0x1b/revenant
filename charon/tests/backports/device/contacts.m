#import <Foundation/Foundation.h>
#import "check.h"
#import "contacts-cases.h"
#import "contacts-expectations.h"

// PRODID names the platform that wrote the vCard - "iOS 6.1.3" on the device, "macOS 27.0" in the
// host oracle that generated contacts-expectations.h. Both are ABPersonCreateVCardRepresentationWithPeople
// of their own AddressBook.framework, honestly reporting their own platform; holding the device to the
// host's platform string would be holding it to a fact about the host, not about the port. Every other
// byte of the vCard - order, fields, line endings - still has to match exactly.
static NSString *normalizedVCard(NSString *vcard)
{
    if (!vcard)
        return vcard;
    static NSRegularExpression *prodid;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        prodid = [NSRegularExpression regularExpressionWithPattern:@"PRODID:-//Apple Inc.//[^/]+//EN"
                                                             options:0 error:NULL];
    });
    return [prodid stringByReplacingMatchesInString:vcard options:0 range:NSMakeRange(0, vcard.length)
                                         withTemplate:@"PRODID:-//Apple Inc.//<platform>//EN"];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));

        NSData *data = [NSData dataWithBytesNoCopy:(void *)contacts_expectations length:strlen(contacts_expectations) freeWhenDone:NO];
        NSError *error = nil;
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        CHECK(expected != nil, "expectations generated on the host parse");
        if (!expected)
            printf("json error: %s\n", error.description.UTF8String);

        NSMutableDictionary *recorded = [NSMutableDictionary dictionary];
        contacts_run(^(NSString *name, NSString *value) { recorded[name] = value ?: [NSNull null]; });

        for (NSString *key in expected) {
            id want = expected[key];
            id got = recorded[key] ?: [NSNull null];
            if ([key isEqualToString:@"vcard.encoded"] && [want isKindOfClass:[NSString class]] && [got isKindOfClass:[NSString class]]) {
                want = normalizedVCard(want);
                got = normalizedVCard(got);
            }
            CHECK_EQUAL(got, want, key.UTF8String);
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
