#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <dispatch/dispatch.h>
#import <stdio.h>

@interface RevenantSecProtocolBlocks : NSObject <OS_sec_protocol_options>
- (BOOL)revenantHasKeyUpdate;
- (BOOL)revenantHasChallenge;
- (BOOL)revenantHasVerify;
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
        Class cls = NSClassFromString(@"RevenantSecProtocolBlocks");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];
        sec_protocol_options_t p = (sec_protocol_options_t)[[cls alloc] init];

        sec_protocol_options_set_key_update_block(o,
            ^(sec_protocol_metadata_t m, sec_protocol_key_update_complete_t c) { (void)m; (void)c; }, NULL);
        want("key-update-alone", [(id)o revenantHasKeyUpdate] ? 1 : 0, 1);
        want("challenge-still-unset", [(id)o revenantHasChallenge] ? 1 : 0, 0);
        want("verify-still-unset", [(id)o revenantHasVerify] ? 1 : 0, 0);

        sec_protocol_options_set_challenge_block(o,
            ^(sec_protocol_metadata_t m, sec_protocol_challenge_complete_t c) { (void)m; (void)c; }, NULL);
        sec_protocol_options_set_verify_block(o,
            ^(sec_protocol_metadata_t m, sec_trust_t t, sec_protocol_verify_complete_t c) { (void)m; (void)t; (void)c; }, NULL);
        want("all-three-set", [(id)o revenantHasKeyUpdate] + [(id)o revenantHasChallenge] + [(id)o revenantHasVerify], 3);

        dispatch_queue_t q = dispatch_queue_create("revenant.blocks", DISPATCH_QUEUE_SERIAL);
        sec_protocol_options_set_verify_block(p,
            ^(sec_protocol_metadata_t m, sec_trust_t t, sec_protocol_verify_complete_t c) { (void)m; (void)t; (void)c; }, q);
        want("p-has-verify", [(id)p revenantHasVerify] ? 1 : 0, 1);
        want("p-has-no-key-update", [(id)p revenantHasKeyUpdate] ? 1 : 0, 0);
        want("p-has-no-challenge", [(id)p revenantHasChallenge] ? 1 : 0, 0);

        sec_protocol_options_set_verify_block(o, NULL, NULL);
        want("after-null-verify", [(id)o revenantHasVerify] ? 1 : 0, 0);
        want("neighbors-untouched", [(id)o revenantHasKeyUpdate] + [(id)o revenantHasChallenge], 2);

        sec_protocol_options_set_key_update_block(NULL, NULL, NULL);
        sec_protocol_options_set_challenge_block(NULL, NULL, NULL);
        sec_protocol_options_set_verify_block(NULL, NULL, NULL);
        printf("null-options\t1\n");

        weakOptions = o;
        want("alive-in-scope", weakOptions ? 1 : 0, 1);
        o = nil; p = nil;
    }
    want("deallocated-after-scope", weakOptions ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
