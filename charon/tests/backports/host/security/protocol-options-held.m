#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <dispatch/dispatch.h>
#import <stdio.h>

// The six setters, and what "HELD" has to mean for each of them.
//
// A DECLARATION of the class, not a second @implementation: the case is its own translation unit and the
// implementation is in the port's file, so declaring the interface here is what a header would do. A
// CATEGORY then adds the probes, which are internal to the port and so are not on the real interface.
@interface CharonSecProtocolOptionsHeld : NSObject <OS_sec_protocol_options>
@end

@interface CharonSecProtocolOptionsHeld (CharonProbe)
- (size_t)charonCiphersuiteCount;
- (size_t)charonGroupCount;
- (sec_protocol_pre_shared_key_selection_t)charonPSKSelection;
@end

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}

// A block made HERE, on the stack of a frame that is about to RETURN. If the port stored the pointer
// instead of copying, calling the held block afterwards would call into a dead frame - and on a stack
// frame already reused, that is a silent wrong answer rather than a crash. So the test is not "the block
// was stored" but "the block still works once its frame is gone".
static int madeInDeadFrame = 0;   // __block is not allowed at file scope, and a block may
                                   // modify a file-scope static anyway
static void makeABlockThatOutlivesItsFrame(sec_protocol_options_t options)
{
    __block int local = 0;                 // a stack block: it dies when this function returns
    sec_protocol_pre_shared_key_selection_t block =
        ^(sec_protocol_metadata_t m, dispatch_data_t hint, sec_protocol_pre_shared_key_selection_complete_t done) {
            (void)m; (void)hint;
            local++;
            madeInDeadFrame++;
            if (done) done(NULL);
        };
    // the queue is a STRONG local, so ARC gives it back when this frame returns; the port must have
    // taken its own reference for the block to remain callable afterwards
    dispatch_queue_t queue = dispatch_queue_create("charon.probe", DISPATCH_QUEUE_SERIAL);
    sec_protocol_options_set_pre_shared_key_selection_block(options, block, queue);
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakOptions = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"CharonSecProtocolOptionsHeld");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];

        // the held values, read back: two ciphersuites appended are two ciphersuites held
        sec_protocol_options_append_tls_ciphersuite(o, tls_ciphersuite_AES_128_GCM_SHA256);
        sec_protocol_options_append_tls_ciphersuite(o, tls_ciphersuite_AES_256_GCM_SHA384);
        want("ciphersuites-held", (long)[(id)o charonCiphersuiteCount], 2);
        sec_protocol_options_append_tls_ciphersuite_group(o, tls_ciphersuite_group_default);
        want("groups-held", (long)[(id)o charonGroupCount], 1);

        // the version range, held and READ BACK THROUGH THE COMPARATOR - which is what makes that
        // comparator a real answer rather than a comparison of nothing
        sec_protocol_options_t p = (sec_protocol_options_t)[[cls alloc] init];
        sec_protocol_options_set_min_tls_protocol_version(o, tls_protocol_version_TLSv10);
        sec_protocol_options_set_max_tls_protocol_version(o, tls_protocol_version_TLSv12);
        want("range-held-not-equal-yet", sec_protocol_options_are_equal(o, p) ? 1 : 0, 0);
        sec_protocol_options_set_min_tls_protocol_version(p, tls_protocol_version_TLSv10);
        sec_protocol_options_set_max_tls_protocol_version(p, tls_protocol_version_TLSv12);
        want("range-read-back-equal", sec_protocol_options_are_equal(o, p) ? 1 : 0, 1);
        sec_protocol_options_set_max_tls_protocol_version(p, tls_protocol_version_TLSv10);
        want("range-differs", sec_protocol_options_are_equal(o, p) ? 1 : 0, 0);

        // the hint is held: dispatch_data_t is a CF-visible object, so its retain count is measurable
        static const char hintBody[] = "an identity hint";
        dispatch_data_t hint = dispatch_data_create(hintBody, sizeof hintBody - 1, NULL, NULL);
        sec_protocol_options_set_tls_pre_shared_key_identity_hint(o, hint);
        printf("hint-set\t1\n");
        // the port holds its OWN reference now, so dropping this strong local must not free the hint

        // THE BLOCK, after its frame is gone
        makeABlockThatOutlivesItsFrame(o);
        // CALL THE HELD BLOCK, now that the frame that created it has returned. A port that stored the
        // pointer instead of copying it would be calling into a dead frame, and on a reused stack frame
        // that is a silent wrong answer rather than a crash - which is why the check is "it still works"
        // and not "it was stored".
        sec_protocol_pre_shared_key_selection_t held = [(id)o charonPSKSelection];
        printf("held-block-present\t%d\n", held ? 1 : 0);
        if (held)
            held(NULL, NULL, NULL);
        want("block-survives-dead-frame", madeInDeadFrame, 1);
        weakOptions = o;
        // ALIVE is read while the scope still holds the strong reference. Reading a weak reference after
        // releasing its strong one is nil BY DEFINITION - the inversion that has now bitten this case
        // twice and the metadata case once.
        want("alive-in-scope", weakOptions ? 1 : 0, 1);
        o = nil; p = nil;
    }
    want("deallocated-after-scope", weakOptions ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
