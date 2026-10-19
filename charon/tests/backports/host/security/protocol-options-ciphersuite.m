#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <Security/CipherSuite.h>
#import <stdio.h>

// The two SSLCipherSuite setters. The assertions are that each value comes back as the CALLER'S OWN
// number, and that the two lists do not interfere: the group enum and the ciphersuite list are separate
// settings and reading one must not report the other.
@interface CharonSecProtocolCiphersuite : NSObject <OS_sec_protocol_options>
- (SSLCipherSuite)charonCiphersuiteAt:(size_t)index;
- (size_t)charonCiphersuiteCount;
- (SSLCiphersuiteGroup)charonGroup;
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
        Class cls = NSClassFromString(@"CharonSecProtocolCiphersuite");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];

        // the caller's wire values, held as given: 0x0001 and 0x002F are TLS_RSA_WITH_AES_128_CBC_SHA
        // and TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA in the IANA set, and both are plain uint16 wire values
        sec_protocol_options_add_tls_ciphersuite(o, (SSLCipherSuite)0x0001);
        sec_protocol_options_add_tls_ciphersuite(o, (SSLCipherSuite)0x002F);
        want("count", (long)[(id)o charonCiphersuiteCount], 2);
        want("first-as-given", (long)[(id)o charonCiphersuiteAt:0], 0x0001);
        want("second-as-given", (long)[(id)o charonCiphersuiteAt:1], 0x002F);
        // and NOT as the tls_ciphersuite_t numbers, which are a different set of values
        printf("first-not-translated\t%d\n", [(id)o charonCiphersuiteAt:0] == 0x1301 ? 0 : 1);
        printf("second-not-translated\t%d\n", [(id)o charonCiphersuiteAt:1] == 0xC02F ? 0 : 1);
        // past the end is not a crash and not a value
        want("past-end", (long)[(id)o charonCiphersuiteAt:9], 0);

        // the group is an ORDINAL, held as given, and it is a separate setting from the list
        sec_protocol_options_add_tls_ciphersuite_group(o, kSSLCiphersuiteGroupCompatibility);
        want("group-as-given", (long)[(id)o charonGroup], kSSLCiphersuiteGroupCompatibility);
        want("list-unchanged-by-group", (long)[(id)o charonCiphersuiteCount], 2);
        want("first-unchanged-by-group", (long)[(id)o charonCiphersuiteAt:0], 0x0001);
        // a third ciphersuite after the group was set, so the two setters are seen to interleave
        sec_protocol_options_add_tls_ciphersuite(o, (SSLCipherSuite)0xC02F);
        want("count-after-third", (long)[(id)o charonCiphersuiteCount], 3);
        want("third-as-given", (long)[(id)o charonCiphersuiteAt:2], 0xC02F);
        want("group-after-third", (long)[(id)o charonGroup], kSSLCiphersuiteGroupCompatibility);

        // growing past the initial capacity, so the realloc path is exercised rather than assumed
        for (int i = 0; i < 20; i++)
            sec_protocol_options_add_tls_ciphersuite(o, (SSLCipherSuite)(0x0100 + i));
        want("count-after-growth", (long)[(id)o charonCiphersuiteCount], 23);
        want("last-after-growth", (long)[(id)o charonCiphersuiteAt:22], 0x0100 + 19);

        sec_protocol_options_add_tls_ciphersuite(NULL, (SSLCipherSuite)0x0001);
        printf("null-options\t1\n");

        weakOptions = o;
        want("alive-in-scope", weakOptions ? 1 : 0, 1);
        o = nil;
    }
    want("deallocated-after-scope", weakOptions ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
