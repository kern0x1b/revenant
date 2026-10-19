#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolMetadata.h>
#import <dispatch/dispatch.h>
#import <stdio.h>

// The fourteen accessors, on metadata objects the PORT made. The point of this case is not that they
// answer an absence - it is that the four block-taking ones answer it WITHOUT RUNNING THE HANDLER,
// because a handler that ran would hand the caller values that were never negotiated.
static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH: a mutant that segfaults mid-case would otherwise lose every
    // row printed before it, and the comparator would then say the rows "did not measure" and name the
    // wrong thing. This is what lets a crash name the assertion it reached.
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakA = nil, weakB = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"CharonSecProtocolMetadata");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls) return 1;
        sec_protocol_metadata_t m = (sec_protocol_metadata_t)[[cls alloc] init];
        sec_protocol_metadata_t n = (sec_protocol_metadata_t)[[cls alloc] init];

        // the pointer returns, where _Nullable makes NULL the header's own answer
        want("negotiated-protocol", sec_protocol_metadata_get_negotiated_protocol(m) ? 1 : 0, 0);
        want("server-name", sec_protocol_metadata_get_server_name(m) ? 1 : 0, 0);
        want("peer-public-key", sec_protocol_metadata_copy_peer_public_key(m) ? 1 : 0, 0);
        want("create-secret", sec_protocol_metadata_create_secret(m, 3, "lab", 4) ? 1 : 0, 0);
        want("create-secret-ctx",
             sec_protocol_metadata_create_secret_with_context(m, 3, "lab", 0, NULL, 4) ? 1 : 0, 0);

        // the two enums that HAVE a member meaning none, so 0 is documented rather than invented
        want("protocol-version", sec_protocol_metadata_get_negotiated_protocol_version(m),
             (long)kSSLProtocolUnknown);
        want("ciphersuite", sec_protocol_metadata_get_negotiated_ciphersuite(m),
             (long)SSL_NULL_WITH_NULL_NULL);
        want("early-data", sec_protocol_metadata_get_early_data_accepted(m) ? 1 : 0, 0);

        // THE FOUR BLOCK-TAKING ONES: false, and the handler must NOT run
        __block int calls = 0;
        want("chain-access", sec_protocol_metadata_access_peer_certificate_chain(m,
             ^(sec_certificate_t c) { (void)c; calls++; }) ? 1 : 0, 0);
        want("ocsp-access", sec_protocol_metadata_access_ocsp_response(m,
             ^(dispatch_data_t d) { (void)d; calls++; }) ? 1 : 0, 0);
        want("sigalg-access", sec_protocol_metadata_access_supported_signature_algorithms(m,
             ^(uint16_t a) { (void)a; calls++; }) ? 1 : 0, 0);
        want("dn-access", sec_protocol_metadata_access_distinguished_names(m,
             ^(dispatch_data_t d) { (void)d; calls++; }) ? 1 : 0, 0);
        want("handler-calls", calls, 0);

        // the two comparators: a real answer about objects the caller made
        want("peers-same-object", sec_protocol_metadata_peers_are_equal(m, m) ? 1 : 0, 1);
        want("peers-two-objects", sec_protocol_metadata_peers_are_equal(m, n) ? 1 : 0, 1);
        want("peers-one-null", sec_protocol_metadata_peers_are_equal(m, NULL) ? 1 : 0, 0);
        want("peers-both-null", sec_protocol_metadata_peers_are_equal(NULL, NULL) ? 1 : 0, 1);
        want("challenge-same", sec_protocol_metadata_challenge_parameters_are_equal(m, n) ? 1 : 0, 1);
        want("challenge-one-null", sec_protocol_metadata_challenge_parameters_are_equal(n, NULL) ? 1 : 0, 0);

        weakA = m; weakB = n;
        want("alive-in-scope", (weakA && weakB) ? 1 : 0, 1);
        m = nil; n = nil;
    }
    want("deallocated-after-scope", (weakA || weakB) ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
