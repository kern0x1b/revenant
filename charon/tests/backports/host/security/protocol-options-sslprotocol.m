#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <stdio.h>

// The two SSLProtocol setters. The assertion that matters is that the value comes back as the CALLER'S
// OWN number: kTLSProtocol1 is 4 and TLSv10 is 0x0301, so a port that translated would read back 769
// where the caller set 4 - and that is a different value, in a different enum, that no header says is
// the same thing.
@interface CharonSecProtocolSSLProtocol : NSObject <OS_sec_protocol_options>
- (SSLProtocol)charonMin;
- (SSLProtocol)charonMax;
- (BOOL)charonHasRange;
@end

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakOptions = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"CharonSecProtocolSSLProtocol");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];

        // the caller's numbers, held as given
        sec_protocol_options_set_tls_min_version(o, kTLSProtocol1);    // 4
        sec_protocol_options_set_tls_max_version(o, kTLSProtocol12);   // 8
        want("min-as-given", (long)[(id)o charonMin], 4);
        want("max-as-given", (long)[(id)o charonMax], 8);
        // and NOT as the tls_ numbers for the same versions, which is 0x0301 and 0x0303
        printf("min-not-translated\t%d\n", [(id)o charonMin] == 0x0301 ? 0 : 1);
        printf("max-not-translated\t%d\n", [(id)o charonMax] == 0x0303 ? 0 : 1);
        want("has-range", [(id)o charonHasRange] ? 1 : 0, 1);

        // each setter touches only its own end of the range
        sec_protocol_options_set_tls_max_version(o, kTLSProtocol11);   // 7
        want("max-alone", (long)[(id)o charonMax], 7);
        want("min-untouched", (long)[(id)o charonMin], 4);
        // and a second, never-set object has no range at all
        sec_protocol_options_t empty = (sec_protocol_options_t)[[cls alloc] init];
        want("empty-has-no-range", [(id)empty charonHasRange] ? 1 : 0, 0);
        // an object of another class is refused rather than half-written
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
