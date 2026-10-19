#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <dispatch/dispatch.h>
#import <stdio.h>

// The three block setters, and the three are SEPARATE settings: a key-update block, a challenge block
// and a verify block are different things, and a port that stored them in one slot would make setting
// the verify block report a challenge block as set. So each is set alone and the other two read back.
@interface CharonSecProtocolBlocks : NSObject <OS_sec_protocol_options>
- (BOOL)charonHasKeyUpdate;
- (BOOL)charonHasChallenge;
- (BOOL)charonHasVerify;
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
        Class cls = NSClassFromString(@"CharonSecProtocolBlocks");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];
        sec_protocol_options_t p = (sec_protocol_options_t)[[cls alloc] init];

        // each block alone: set, and the other two must still be unset
        sec_protocol_options_set_key_update_block(o,
            ^(sec_protocol_metadata_t m, sec_protocol_key_update_complete_t c) { (void)m; (void)c; }, NULL);
        want("key-update-alone", [(id)o charonHasKeyUpdate] ? 1 : 0, 1);
        want("challenge-still-unset", [(id)o charonHasChallenge] ? 1 : 0, 0);
        want("verify-still-unset", [(id)o charonHasVerify] ? 1 : 0, 0);

        sec_protocol_options_set_challenge_block(o,
            ^(sec_protocol_metadata_t m, sec_protocol_challenge_complete_t c) { (void)m; (void)c; }, NULL);
        sec_protocol_options_set_verify_block(o,
            ^(sec_protocol_metadata_t m, sec_trust_t t, sec_protocol_verify_complete_t c) { (void)m; (void)t; (void)c; }, NULL);
        want("all-three-set", [(id)o charonHasKeyUpdate] + [(id)o charonHasChallenge] + [(id)o charonHasVerify], 3);

        // a QUEUE goes with each block, and holding one does not imply holding the other
        dispatch_queue_t q = dispatch_queue_create("charon.blocks", DISPATCH_QUEUE_SERIAL);
        sec_protocol_options_set_verify_block(p,
            ^(sec_protocol_metadata_t m, sec_trust_t t, sec_protocol_verify_complete_t c) { (void)m; (void)t; (void)c; }, q);
        want("p-has-verify", [(id)p charonHasVerify] ? 1 : 0, 1);
        want("p-has-no-key-update", [(id)p charonHasKeyUpdate] ? 1 : 0, 0);
        want("p-has-no-challenge", [(id)p charonHasChallenge] ? 1 : 0, 0);

        // a NULL block CLEARS rather than leaving the previous one, and is not counted as set
        sec_protocol_options_set_verify_block(o, NULL, NULL);
        want("after-null-verify", [(id)o charonHasVerify] ? 1 : 0, 0);
        want("neighbors-untouched", [(id)o charonHasKeyUpdate] + [(id)o charonHasChallenge], 2);

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
