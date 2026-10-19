#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "check.h"

extern CFStringRef charon_host_SecCopyErrorMessageString(OSStatus, void *);

static const char *label(NSString *format, ...)
{
    static NSMutableArray *keep;
    if (!keep)
        keep = [NSMutableArray array];
    va_list arguments;
    va_start(arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [keep addObject:string];
    return string.UTF8String;
}

static NSString *taken(CFStringRef string)
{
    return string ? CFBridgingRelease(string) : @"(null)";
}

int main(void)
{
    @autoreleasepool {
        NSMutableArray *codes = [NSMutableArray array];
        for (int status = -70000; status <= 100; status += 1)
            [codes addObject:@(status)];
        for (int status = -9900; status >= -9700; status -= 1)
            [codes addObject:@(status)];
        [codes addObjectsFromArray:@[@(INT_MIN), @(INT_MAX), @1, @-1, @-67000000, @12345, @(-25300), @(-25299), @(-34018), @(-128), @(-108)]];
        NSUInteger known = 0, differing = 0, hostOnlyCount = 0;
        for (NSNumber *number in codes) {
            OSStatus status = number.intValue;
            NSString *port = taken(charon_host_SecCopyErrorMessageString(status, NULL));
            NSString *host = taken(SecCopyErrorMessageString(status, NULL));
            if (![port hasPrefix:@"OSStatus "])
                known++;
            if (![port isEqual:host]) {
                differing++;
                BOOL hostOnly = [port isEqual:[NSString stringWithFormat:@"OSStatus %d", status]] && ![host hasPrefix:@"OSStatus "];
                BOOL apostrophe = status == -34018 && [port isEqual:@"A required entitlement isn't present."] && [host isEqual:@"A required entitlement is not present."];
                CHECK(hostOnly || apostrophe, label(@"%d differs from the host in the two ways the tables are known to", status));
                if (hostOnly)
                    hostOnlyCount++;
            }
        }
        printf("codes=%lu known=%lu differing=%lu hostOnly=%lu\n", (unsigned long)codes.count, (unsigned long)known, (unsigned long)differing, (unsigned long)hostOnlyCount);
        CHECK(hostOnlyCount == 30, "the host's own extra codes are the only ones the port lacks");
        CHECK(known > 500, "the table answers its codes");
        CHECK_EQUAL(taken(charon_host_SecCopyErrorMessageString(-25300, NULL)), @"The specified item could not be found in the keychain.", "the not-found text");
        CHECK_EQUAL(taken(charon_host_SecCopyErrorMessageString(12345, NULL)), @"OSStatus 12345", "an unknown code is named by its number");
        CHECK_EQUAL(taken(charon_host_SecCopyErrorMessageString(-1, NULL)), @"OSStatus -1", "a negative unknown code too");
        CHECK_EQUAL(taken(charon_host_SecCopyErrorMessageString(0, NULL)), taken(SecCopyErrorMessageString(0, NULL)), "success reads as the host's does");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
