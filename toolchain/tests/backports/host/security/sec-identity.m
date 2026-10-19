#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecIdentity.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import <stdio.h>
#import <string.h>

@interface RevenantSecIdentity : NSObject <OS_sec_identity>
- (void)revenantSetCertificates:(CFArrayRef)certificates;
- (CFArrayRef)revenantCertificates;
@end

@interface RevenantSecProtocolLocalIdentity : NSObject <OS_sec_protocol_options>
- (sec_identity_t)revenantLocalIdentity;
@end

@interface RevenantSecIdentity (RevenantProbe)
- (void)revenantSetCertificates:(CFArrayRef)certificates;
- (CFArrayRef)revenantCertificates;
@end

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}

int main(void)
{
    @autoreleasepool {
        CFDataRef standIn = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)"stand-in", 8);

        sec_identity_t identity = sec_identity_create((SecIdentityRef)standIn);
        if (!identity) { printf("WRONG\tcreate: NULL for a ref it was given\n"); return 1; }
        want("create-present", 1, 1);
        CFIndex beforeCopy = CFGetRetainCount(standIn);
        SecIdentityRef got = sec_identity_copy_ref(identity);
        want("copy-ref-retains", CFGetRetainCount(standIn) > beforeCopy ? 1 : 0, 1);
        if (got != (SecIdentityRef)standIn)
            printf("WRONG\tcopy_ref: the port answered a DIFFERENT ref than it was given\n"), failures++;
        else
            printf("copy-ref-same\t1\n");
        if (got) CFRelease(got);

        NSData *der = [NSData dataWithContentsOfFile:@"tests/backports/host/security/fixtures/certificate.der"];
        SecCertificateRef leaf = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)der);
        if (!leaf) { printf("WRONG\tfixture: no certificate from the committed DER\n"); return 1; }
        const void *keys[] = { (const void *)leaf };
        CFMutableArrayRef source = CFArrayCreateMutable(kCFAllocatorDefault, 1, &kCFTypeArrayCallBacks);
        CFArrayAppendValue(source, keys[0]);
        sec_identity_t withCerts = sec_identity_create_with_certificates((SecIdentityRef)standIn, source);
        want("certificates-copied", (long)CFArrayGetCount(sec_identity_copy_certificates_ref(withCerts)), 1);
        CFArrayRemoveAllValues(source);
        want("copy-survives-source-change",
             (long)CFArrayGetCount(sec_identity_copy_certificates_ref(withCerts)), 1);

        __block int runs = 0;
        bool accessed = sec_identity_access_certificates(withCerts, ^(sec_certificate_t c) {
            (void)c; runs++;
        });
        want("access-true", accessed ? 1 : 0, 1);
        want("handler-runs-per-certificate", runs, 1);
        runs = 0;
        accessed = sec_identity_access_certificates(identity, ^(sec_certificate_t c) { (void)c; runs++; });
        want("access-empty-true", accessed ? 1 : 0, 1);
        want("handler-runs-on-empty", runs, 0);

        SecIdentityRef fromNil = sec_identity_copy_ref(NULL);
        want("copy_ref-of-nil", fromNil ? 1 : 0, 0);
        if (fromNil) CFRelease(fromNil);

        Class holder = NSClassFromString(@"RevenantSecProtocolLocalIdentity");
        printf("holder-class\t%s\n", holder ? "found" : "MISSING");
        if (holder) {
            sec_protocol_options_t options = (sec_protocol_options_t)[[holder alloc] init];
            sec_protocol_options_set_local_identity(options, identity);
            sec_identity_t readBack = [(RevenantSecProtocolLocalIdentity *)options revenantLocalIdentity];
            if (readBack == identity) printf("local-identity-holds\t1\n");
            else { printf("WRONG\tlocal-identity: the port did not hold the identity it was given\n"); failures++; }
            want("local-identity-present", readBack ? 1 : 0, 1);
        }
        printf("failures\t%d\n", failures);
    }
    return failures ? 1 : 0;
}
