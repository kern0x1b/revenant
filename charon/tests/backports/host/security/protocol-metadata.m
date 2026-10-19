#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolMetadata.h>
#import <dispatch/dispatch.h>
#import <stdio.h>

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
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakView = nil;
    @autoreleasepool {
        Class cls = NSClassFromString(@"CharonSecProtocolMetadata");
        printf("port-class\t%s\n", cls ? "found" : "MISSING");
        if (!cls)
            return 1;

        sec_protocol_metadata_t metadata = (sec_protocol_metadata_t)[[cls alloc] init];
        printf("is-metadata\t%d\n", [metadata conformsToProtocol:@protocol(OS_sec_protocol_metadata)]);
        want("tls-version", (long)sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata), 0);
        want("tls-ciphersuite", (long)sec_protocol_metadata_get_negotiated_tls_ciphersuite(metadata), 0);

        __block int calls = 0;
        bool answered = sec_protocol_metadata_access_pre_shared_keys(metadata,
            ^(dispatch_data_t psk, dispatch_data_t psk_identity) {
                (void)psk; (void)psk_identity;
                calls++;
            });
        want("psk-access", answered ? 1 : 0, 0);
        want("psk-handler-calls", calls, 0);

        weakView = metadata;
        want("alive-in-scope", weakView ? 1 : 0, 1);
        metadata = nil;
    }
    want("deallocated-after-scope", weakView ? 1 : 0, 0);
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
