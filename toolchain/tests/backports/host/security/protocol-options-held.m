#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <dispatch/dispatch.h>
#import <stdio.h>

@interface RevenantSecProtocolOptionsHeld : NSObject <OS_sec_protocol_options>
@end

@interface RevenantSecProtocolOptionsHeld (RevenantProbe)
- (size_t)revenantCiphersuiteCount;
- (size_t)revenantGroupCount;
- (sec_protocol_pre_shared_key_selection_t)revenantPSKSelection;
@end

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}

static int madeInDeadFrame = 0;
static void makeABlockThatOutlivesItsFrame(sec_protocol_options_t options)
{
    __block int local = 0;
    sec_protocol_pre_shared_key_selection_t block =
        ^(sec_protocol_metadata_t m, dispatch_data_t hint, sec_protocol_pre_shared_key_selection_complete_t done) {
            (void)m; (void)hint;
            local++;
            madeInDeadFrame++;
            if (done) done(NULL);
        };
    dispatch_queue_t queue = dispatch_queue_create("revenant.probe", DISPATCH_QUEUE_SERIAL);
    sec_protocol_options_set_pre_shared_key_selection_block(options, block, queue);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakOptions = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"RevenantSecProtocolOptionsHeld");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];

        sec_protocol_options_append_tls_ciphersuite(o, tls_ciphersuite_AES_128_GCM_SHA256);
        sec_protocol_options_append_tls_ciphersuite(o, tls_ciphersuite_AES_256_GCM_SHA384);
        want("ciphersuites-held", (long)[(id)o revenantCiphersuiteCount], 2);
        sec_protocol_options_append_tls_ciphersuite_group(o, tls_ciphersuite_group_default);
        want("groups-held", (long)[(id)o revenantGroupCount], 1);

        sec_protocol_options_t p = (sec_protocol_options_t)[[cls alloc] init];
        sec_protocol_options_set_min_tls_protocol_version(o, tls_protocol_version_TLSv10);
        sec_protocol_options_set_max_tls_protocol_version(o, tls_protocol_version_TLSv12);
        want("range-held-not-equal-yet", sec_protocol_options_are_equal(o, p) ? 1 : 0, 0);
        sec_protocol_options_set_min_tls_protocol_version(p, tls_protocol_version_TLSv10);
        sec_protocol_options_set_max_tls_protocol_version(p, tls_protocol_version_TLSv12);
        want("range-read-back-equal", sec_protocol_options_are_equal(o, p) ? 1 : 0, 1);
        sec_protocol_options_set_max_tls_protocol_version(p, tls_protocol_version_TLSv10);
        want("range-differs", sec_protocol_options_are_equal(o, p) ? 1 : 0, 0);

        static const char hintBody[] = "an identity hint";
        dispatch_data_t hint = dispatch_data_create(hintBody, sizeof hintBody - 1, NULL, NULL);
        sec_protocol_options_set_tls_pre_shared_key_identity_hint(o, hint);
        printf("hint-set\t1\n");

        makeABlockThatOutlivesItsFrame(o);
        sec_protocol_pre_shared_key_selection_t held = [(id)o revenantPSKSelection];
        printf("held-block-present\t%d\n", held ? 1 : 0);
        if (held)
            held(NULL, NULL, NULL);
        want("block-survives-dead-frame", madeInDeadFrame, 1);
        weakOptions = o;
        want("alive-in-scope", weakOptions ? 1 : 0, 1);
        o = nil; p = nil;
    }
    want("deallocated-after-scope", weakOptions ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
