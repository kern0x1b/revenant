#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolMetadata.h>
#import <dispatch/dispatch.h>
#import <stdio.h>

// The three sec_protocol_metadata functions, on a metadata object the PORT made.
//
// The class is reached with NSClassFromString rather than by redeclaring it: the case links the port's
// own file, so an @interface for CharonSecProtocolMetadata here would be a SECOND declaration of a class
// that is already defined, which is the mistake the wrapper family already made once.
//
// NO KEYCHAIN, no network, and no TLS: nothing here negotiates anything, which is the point - a caller
// must never receive a value that looks negotiated.
static int failures = 0;

static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) {
        printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect);
        failures++;
    }
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakView = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"CharonSecProtocolMetadata");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls)
            return 1;

        // (a) the object is a sec_protocol_metadata_t, and the two getters answer 0
        sec_protocol_metadata_t metadata = (sec_protocol_metadata_t)[[cls alloc] init];
        printf("is-metadata\t%d\n", [metadata conformsToProtocol:@protocol(OS_sec_protocol_metadata)]);
        want("tls-version", (long)sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata), 0);
        want("tls-ciphersuite", (long)sec_protocol_metadata_get_negotiated_tls_ciphersuite(metadata), 0);

        // (b) the psk accessor returns false AND DOES NOT RUN THE HANDLER
        __block int calls = 0;
        bool answered = sec_protocol_metadata_access_pre_shared_keys(metadata,
            ^(dispatch_data_t psk, dispatch_data_t psk_identity) {
                (void)psk; (void)psk_identity;
                calls++;
            });
        want("psk-access", answered ? 1 : 0, 0);
        want("psk-handler-calls", calls, 0);

        // (c) the ARC BALANCE, the way an ObjC object can be shown at all: ALIVE while the scope holds
        //     it, GONE once the pool has drained. CFGetRetainCount is not available under ARC and must
        //     not be called, so a weak reference is the measurement - a wrapper that retained itself, or
        //     that kept the metadata alive, would leave it non-nil at the end.
        weakView = metadata;
        want("alive-in-scope", weakView ? 1 : 0, 1);
        metadata = nil;
    }
    // read OUTSIDE the scope that owned it, which is the only place the answer means anything
    want("deallocated-after-scope", weakView ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
