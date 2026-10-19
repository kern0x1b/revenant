#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <stdio.h>

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}

@interface Options : NSObject
- (void)revenantSetMinTLS:(tls_protocol_version_t)v;
- (void)revenantSetMaxTLS:(tls_protocol_version_t)v;
@end

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakA = nil, weakB = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"RevenantSecProtocolOptions");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        want("default-min-tls",  sec_protocol_options_get_default_min_tls_protocol_version(),  0x0301);
        want("default-max-tls",  sec_protocol_options_get_default_max_tls_protocol_version(),  0x0303);
        want("default-min-dtls", sec_protocol_options_get_default_min_dtls_protocol_version(), 0xfeff);
        want("default-max-dtls", sec_protocol_options_get_default_max_dtls_protocol_version(), 0xfeff);
        printf("no-tls13\t%d\n", sec_protocol_options_get_default_max_tls_protocol_version() == 0x0304 ? 0 : 1);
        printf("no-dtls12\t%d\n", sec_protocol_options_get_default_max_dtls_protocol_version() == 0xfefd ? 0 : 1);

        sec_protocol_options_t a = (sec_protocol_options_t)[[cls alloc] init];
        sec_protocol_options_t b = (sec_protocol_options_t)[[cls alloc] init];
        printf("both-empty-equal\t%d\n", sec_protocol_options_are_equal(a, b) ? 1 : 0);
        [(Options *)a revenantSetMinTLS:tls_protocol_version_TLSv10];
        [(Options *)b revenantSetMinTLS:tls_protocol_version_TLSv10];
        [(Options *)a revenantSetMaxTLS:tls_protocol_version_TLSv12];
        [(Options *)b revenantSetMaxTLS:tls_protocol_version_TLSv12];
        want("same-range-equal", sec_protocol_options_are_equal(a, b) ? 1 : 0, 1);
        [(Options *)b revenantSetMaxTLS:tls_protocol_version_TLSv10];
        want("different-range", sec_protocol_options_are_equal(a, b) ? 1 : 0, 0);
        want("same-object", sec_protocol_options_are_equal(a, a) ? 1 : 0, 1);
        want("null-a", sec_protocol_options_are_equal(NULL, b) ? 1 : 0, 0);
        want("null-both", sec_protocol_options_are_equal(NULL, NULL) ? 1 : 0, 1);
        weakA = a; weakB = b;
        want("alive-in-scope", (weakA && weakB) ? 1 : 0, 1);
        a = nil; b = nil;
    }
    want("deallocated-after-scope", (weakA || weakB) ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
