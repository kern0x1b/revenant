#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <dispatch/dispatch.h>
#import <stdio.h>

// The two dispatch_data setters. Three things are checked and each has its own failure mode:
//
//   1. BOTH HALVES OF THE PAIR SURVIVE their creating scope. A pair is only useful whole, so a port that
//      held one half would look right and be useless.
//   2. THE PORT'S REFERENCE SURVIVES THE CALLER'S. dispatch_data_t is an ObjC object, so a strong ivar
//      retains it; a port that stored it unretained would be reading freed memory once the caller's
//      strong local goes away - which is what the case arranges, by letting the scope end.
//   3. A PAIR WITH A MISSING HALF IS NOT STORED, so a later read cannot produce half a key.
@interface CharonSecProtocolData : NSObject <OS_sec_protocol_options>
- (dispatch_data_t)charonDHParams;
- (size_t)charonPSKCount;
- (BOOL)charonPSKAt:(size_t)index psk:(dispatch_data_t *)psk identity:(dispatch_data_t *)identity;
@end

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}
// THE BYTES ARE READ, NOT THE POINTER, so the value is checked and not merely its address. There is no
// dispatch_data_get_bytes: the SDK offers dispatch_data_create_map and dispatch_data_apply, and apply is
// the reader - which is itself worth knowing, since a probe that reached for get_bytes would not build.
static void text(dispatch_data_t data, const char *label)
{
    if (!data) { printf("%s\tNULL\n", label); return; }
    __block NSMutableString *out = [NSMutableString string];
    dispatch_data_apply(data, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
        (void)region; (void)offset;
        [out appendString:[[NSString alloc] initWithBytes:buffer length:size encoding:NSUTF8StringEncoding]];
        return true;   // keep going: a dispatch_data can be several regions
    });
    printf("%s\t%s\n", label, [out UTF8String] ?: "");
}

// The values are made HERE, in a scope that is about to end, so the caller's own strong reference is
// gone by the time the case reads them back.
static void setFromAScopeThatEnds(sec_protocol_options_t options)
{
    const char dhBytes[] = "a finite-field group the caller chose";
    const char pskBytes[] = "the pre-shared key bytes";
    const char idBytes[] = "the identity that names it";
    dispatch_data_t dh = dispatch_data_create(dhBytes, sizeof dhBytes - 1, NULL, NULL);
    dispatch_data_t psk = dispatch_data_create(pskBytes, sizeof pskBytes - 1, NULL, NULL);
    dispatch_data_t identity = dispatch_data_create(idBytes, sizeof idBytes - 1, NULL, NULL);
    sec_protocol_options_set_tls_diffie_hellman_parameters(options, dh);
    sec_protocol_options_add_pre_shared_key(options, psk, identity);
    // dh, psk and identity go out of scope HERE. A port that stored them unretained is now holding
    // three objects it does not own.
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakOptions = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"CharonSecProtocolData");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_options_t o = (sec_protocol_options_t)[[cls alloc] init];

        setFromAScopeThatEnds(o);

        // (2) the port's own reference kept the value alive
        text([(id)o charonDHParams], "dh-after-scope");
        // (1) and BOTH halves of the pair, read back whole
        dispatch_data_t psk = NULL, identity = NULL;
        want("pair-present", [(id)o charonPSKAt:0 psk:&psk identity:&identity] ? 1 : 0, 1);
        text(psk, "psk-after-scope");
        text(identity, "identity-after-scope");
        want("psk-count", (long)[(id)o charonPSKCount], 1);
        // (3) a half pair is not stored, so the count does not move
        const char a[] = "key only";
        dispatch_data_t onlyKey = dispatch_data_create(a, sizeof a - 1, NULL, NULL);
        sec_protocol_options_add_pre_shared_key(o, onlyKey, NULL);
        want("after-half-pair", (long)[(id)o charonPSKCount], 1);
        want("past-end", [(id)o charonPSKAt:9 psk:&psk identity:&identity] ? 1 : 0, 0);

        sec_protocol_options_set_tls_diffie_hellman_parameters(NULL, NULL);
        sec_protocol_options_add_pre_shared_key(NULL, NULL, NULL);
        printf("null-options\t1\n");

        weakOptions = o;
        want("alive-in-scope", weakOptions ? 1 : 0, 1);
        o = nil;
    }
    want("deallocated-after-scope", weakOptions ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
