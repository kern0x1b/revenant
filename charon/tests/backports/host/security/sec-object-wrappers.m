#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecTrust.h>
#import <Security/SecPolicy.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

// The four slice rows on REAL refs, with no keychain anywhere: a SecCertificateRef is built from DER
// with SecCertificateCreateWithData and a SecTrustRef with SecTrustCreateWithCertificates, and neither
// call touches a keychain, an identity or a preference.
//
// FOUR things are measured, each with its own failure mode:
//   (a) copy_ref returns the REF IT WAS GIVEN, by pointer equality - a port that wrapped a copy, or
//       built a second certificate, would answer a different pointer and the test is the only thing
//       that would say so
//   (b) the RETAIN BALANCE, with the expected numbers written down: create +1, copy_ref +1, releasing
//       the copy -1, the object leaving ARC scope -1, back to the case's own single reference
//   (c) the object RELEASES EXACTLY ONCE, shown by a weak reference reading nil after the scope drains;
//       a wrapper that retained twice or never released would leave it non-nil, and one that over-released
//       would crash in copy_ref
//   (d) a NULL argument is refused by the class check rather than crashing
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
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    __weak id weakCertificate = nil, weakTrust = nil;
    @autoreleasepool {
        SecCertificateRef cert = SecCertificateCreateWithData(NULL,
                                CFDataCreate(kCFAllocatorDefault, Fixture, (CFIndex)FixtureLength));
        if (!cert) { printf("no fixture certificate\n"); return 1; }
        want("fixture-retain", (long)CFGetRetainCount(cert), 1);

        // (a) and (b): create holds the caller's ref, copy_ref answers the SAME one
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
            // (c) the object itself, held weakly so the dealloc is what is being watched
            weakCertificate = (id)wrapper;   // a plain ObjC cast: a protocol-qualified
            // pointer is not id for a __bridge cast, the same lesson as dispatch_data
        }
        // (c) after the scope the wrapper is gone, so its +1 went back
        want("certificate-released", weakCertificate ? 1 : 0, 0);
        want("after-wrapper-scope", (long)CFGetRetainCount(cert), 1);

        // (d) a NULL is refused by the class check, not a crash
        printf("copy-ref-null\t%s\n", sec_certificate_copy_ref(NULL) ? "present" : "NULL");

        // the trust, over the same certificate and a basic X.509 policy
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
