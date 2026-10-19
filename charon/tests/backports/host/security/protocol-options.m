#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <stdio.h>

// The four defaults and the comparator, on port objects. The class is reached with NSClassFromString -
// this case links the port's own file, so redeclaring the class would be a second definition.
static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}

@interface Options : NSObject
- (void)charonSetMinTLS:(tls_protocol_version_t)v;
- (void)charonSetMaxTLS:(tls_protocol_version_t)v;
@end

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakA = nil, weakB = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"CharonSecProtocolOptions");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        // the four defaults: the release's stack range, and NEVER a version it cannot negotiate
        want("default-min-tls",  sec_protocol_options_get_default_min_tls_protocol_version(),  0x0301);
        want("default-max-tls",  sec_protocol_options_get_default_max_tls_protocol_version(),  0x0303);
        want("default-min-dtls", sec_protocol_options_get_default_min_dtls_protocol_version(), 0xfeff);
        want("default-max-dtls", sec_protocol_options_get_default_max_dtls_protocol_version(), 0xfeff);
        printf("no-tls13\t%d\n", sec_protocol_options_get_default_max_tls_protocol_version() == 0x0304 ? 0 : 1);
        printf("no-dtls12\t%d\n", sec_protocol_options_get_default_max_dtls_protocol_version() == 0xfefd ? 0 : 1);

        // the comparator: equal when the held settings agree, different when they do not
        sec_protocol_options_t a = (sec_protocol_options_t)[[cls alloc] init];
        sec_protocol_options_t b = (sec_protocol_options_t)[[cls alloc] init];
        printf("both-empty-equal\t%d\n", sec_protocol_options_are_equal(a, b) ? 1 : 0);
        [(Options *)a charonSetMinTLS:tls_protocol_version_TLSv10];
        [(Options *)b charonSetMinTLS:tls_protocol_version_TLSv10];
        [(Options *)a charonSetMaxTLS:tls_protocol_version_TLSv12];
        [(Options *)b charonSetMaxTLS:tls_protocol_version_TLSv12];
        want("same-range-equal", sec_protocol_options_are_equal(a, b) ? 1 : 0, 1);
        [(Options *)b charonSetMaxTLS:tls_protocol_version_TLSv10];
        want("different-range", sec_protocol_options_are_equal(a, b) ? 1 : 0, 0);
        want("same-object", sec_protocol_options_are_equal(a, a) ? 1 : 0, 1);
        want("null-a", sec_protocol_options_are_equal(NULL, b) ? 1 : 0, 0);
        want("null-both", sec_protocol_options_are_equal(NULL, NULL) ? 1 : 0, 1);
        // ALIVE is checked while the scope still holds the strong references. Reading a weak reference
        // after releasing its strong one is nil BY DEFINITION, which is the same inversion that made an
        // earlier version of the metadata case fail: the assertion and the code said opposite things.
        weakA = a; weakB = b;
        want("alive-in-scope", (weakA && weakB) ? 1 : 0, 1);
        a = nil; b = nil;
    }
    // ARC balance by deallocation, the only way an ObjC object can be shown under ARC
    want("deallocated-after-scope", (weakA || weakB) ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
