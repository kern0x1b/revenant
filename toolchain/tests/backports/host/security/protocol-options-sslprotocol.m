#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <stdio.h>

@interface RevenantSecProtocolSSLProtocol : NSObject <OS_sec_protocol_options>
- (SSLProtocol)revenantMin;
- (SSLProtocol)revenantMax;
- (BOOL)revenantHasRange;
@end

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakOptions = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"RevenantSecProtocolSSLProtocol");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];

        sec_protocol_options_set_tls_min_version(o, kTLSProtocol1);
        sec_protocol_options_set_tls_max_version(o, kTLSProtocol12);
        want("min-as-given", (long)[(id)o revenantMin], 4);
        want("max-as-given", (long)[(id)o revenantMax], 8);
        printf("min-not-translated\t%d\n", [(id)o revenantMin] == 0x0301 ? 0 : 1);
        printf("max-not-translated\t%d\n", [(id)o revenantMax] == 0x0303 ? 0 : 1);
        want("has-range", [(id)o revenantHasRange] ? 1 : 0, 1);

        sec_protocol_options_set_tls_max_version(o, kTLSProtocol11);
        want("max-alone", (long)[(id)o revenantMax], 7);
        want("min-untouched", (long)[(id)o revenantMin], 4);
        sec_protocol_options_t empty = (sec_protocol_options_t)[[cls alloc] init];
        want("empty-has-no-range", [(id)empty revenantHasRange] ? 1 : 0, 0);
        sec_protocol_options_set_tls_min_version(NULL, kTLSProtocol1);
        printf("null-options\t1\n");

        weakOptions = o;
        want("alive-in-scope", weakOptions ? 1 : 0, 1);
        o = nil;
    }
    want("deallocated-after-scope", weakOptions ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
