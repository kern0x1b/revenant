#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecTrust.h>
#import <Security/SecPolicy.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

static const unsigned char Fixture[] = {
#include "fixtures/certificate.der.inc"
};
static const size_t FixtureLength = sizeof Fixture;

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the balance says %ld\n", what, got, expect); failures++; }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakCertificate = nil, weakTrust = nil;
    @autoreleasepool {
        SecCertificateRef cert = SecCertificateCreateWithData(NULL,
                                CFDataCreate(kCFAllocatorDefault, Fixture, (CFIndex)FixtureLength));
        if (!cert) { printf("no fixture certificate\n"); return 1; }
        want("fixture-retain", (long)CFGetRetainCount(cert), 1);

        {
            sec_certificate_t wrapper = sec_certificate_create(cert);
            if (!wrapper) { printf("WRONG\tcreate: NULL for a real certificate\n"); return 1; }
            want("after-create", (long)CFGetRetainCount(cert), 2);
            SecCertificateRef got = sec_certificate_copy_ref(wrapper);
            if (got != cert) {
                printf("WRONG\tcopy-ref: the port answered a DIFFERENT ref than it was given\n");
                failures++;
            } else {
                printf("copy-ref-same\t1\n");
            }
            want("after-copy", (long)CFGetRetainCount(cert), 3);
            if (got) CFRelease(got);
            want("after-copy-release", (long)CFGetRetainCount(cert), 2);
            weakCertificate = (id)wrapper;
        }
        want("certificate-released", weakCertificate ? 1 : 0, 0);
        want("after-wrapper-scope", (long)CFGetRetainCount(cert), 1);

        printf("copy-ref-null\t%s\n", sec_certificate_copy_ref(NULL) ? "present" : "NULL");

        SecPolicyRef policy = SecPolicyCreateBasicX509();
        SecTrustRef trust = NULL;
        OSStatus made = SecTrustCreateWithCertificates(cert, policy, &trust);
        printf("made-trust\t%ld\n", (long)made);
        if (made == errSecSuccess && trust) {
            long before = (long)CFGetRetainCount(trust);
            printf("trust-retain-before\t%ld\n", before);
            sec_trust_t wrapper = sec_trust_create(trust);
            if (!wrapper) { printf("WRONG\ttrust-create: NULL for a real trust\n"); return 1; }
            want("trust-after-create", (long)CFGetRetainCount(trust), before + 1);
            SecTrustRef got = sec_trust_copy_ref(wrapper);
            if (got != trust) {
                printf("WRONG\ttrust-copy-ref: the port answered a DIFFERENT ref than it was given\n");
                failures++;
            } else {
                printf("trust-copy-ref-same\t1\n");
            }
            want("trust-after-copy", (long)CFGetRetainCount(trust), before + 2);
            if (got) CFRelease(got);
            weakTrust = (id)wrapper;
        }
        CFRelease(trust);
        CFRelease(policy);
        want("trust-released", weakTrust ? 1 : 0, 0);
        printf("copy-ref-trust-null\t%s\n", sec_trust_copy_ref(NULL) ? "present" : "NULL");

        CFRelease(cert);
    }
    printf("failures\t%d\n", failures);
    return failures ? 1 : 0;
}
