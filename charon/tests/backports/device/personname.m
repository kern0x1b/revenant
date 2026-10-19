#import <Foundation/Foundation.h>
#import "check.h"
#import "personname-cases.h"
#import "personname-expectations.h"

static NSString *tolerance(NSString *name)
{
    return nil;
}

int main(void)
{
    @autoreleasepool {
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:personname_expectations length:strlen(personname_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        personname_run(^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]])
                charon_check(YES, name.UTF8String, nil);
            else if (tolerance(name))
                printf("tolerated %s: %s\n    device %s\n    host   %s\n", tolerance(name).UTF8String, name.UTF8String, [records[name] UTF8String], [expected[name] UTF8String]);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
