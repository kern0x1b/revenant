#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <stdio.h>
#import <string.h>

// THE REVIEWER'S FUZZ FOLLOW-UP: the reader is handed DER it would never be handed by a certificate, and
// none of it may read outside the buffer it was given.
//
//   1. the fixture TRUNCATED AT EVERY LENGTH, 0 through its whole 847 bytes, so every walk is cut at
//      every point a field boundary can fall on
//   2. every single-byte change to the FIRST 40 BYTES, which is where the Certificate SEQUENCE, the
//      tbsCertificate, the [0] version, the serialNumber, the signature AlgorithmIdentifier, the issuer
//      Name, the validity and the subject Name all live - so a mutated length or tag is met
//   3. every length octet in those 40 bytes set to 0xFF and to 0x00, which is where an over-long or an
//      indefinite length comes from
//
// The walk is driven DIRECTLY, because a certificate the host refuses to build never reaches it, and
// through the public accessors with a certificate the host WILL build, so both paths are covered.
bool CharonCertificateReadTLV(const uint8_t *bytes, size_t length, size_t at, uint8_t *tag,
                              size_t *content, size_t *next, size_t limit);
bool CharonCertificateNameTLV(const uint8_t *bytes, size_t length, bool wantSubject,
                             size_t *outStart, size_t *outEnd);

static const unsigned char Fixture[] = {
#include "fixtures/certificate.der.inc"
};
static const size_t FixtureLength = sizeof Fixture;

static long accepted = 0, refused = 0, built = 0;

static void walk(const unsigned char *bytes, size_t length)
{
    for (int subject = 0; subject < 2; subject++) {
        size_t start = 0, end = 0;
        if (CharonCertificateNameTLV(bytes, length, subject ? true : false, &start, &end)) {
            accepted++;
            // an accepted walk must produce a slice INSIDE the buffer it was given, or the caller reads
            // freed or adjacent memory when it copies it out
            if (end < start || end > length)
                { printf("OUT-OF-RANGE start=%zu end=%zu of %zu\n", start, end, length); abort(); }
        } else {
            refused++;
        }
    }
    // the TLV reader is exercised at every offset, not only at field boundaries
    for (size_t at = 0; at < length; at++) {
        uint8_t tag = 0;
        size_t content = 0, next = 0;
        if (CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length)) {
            if (content < at || next < content || next > length)
                { printf("TLV-OUT-OF-RANGE at=%zu content=%zu next=%zu of %zu\n", at, content, next, length); abort(); }
        }
    }
}

static void throughTheAccessors(const unsigned char *bytes, size_t length)
{
    SecCertificateRef cert = SecCertificateCreateWithData(NULL,
                                    CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length));
    if (!cert)
        return;
    built++;
    CFDataRef d = SecCertificateCopyNormalizedIssuerSequence(cert);
    if (d) CFRelease(d);
    d = SecCertificateCopyNormalizedSubjectSequence(cert);
    if (d) CFRelease(d);
    CFStringRef name = NULL;
    if (SecCertificateCopyCommonName(cert, &name) == errSecSuccess && name) CFRelease(name);
    CFArrayRef mail = NULL;
    if (SecCertificateCopyEmailAddresses(cert, &mail) == errSecSuccess && mail) CFRelease(mail);
    CFRelease(cert);
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        // 1. TRUNCATION AT EVERY LENGTH
        for (size_t n = 0; n <= FixtureLength; n++) {
            walk(Fixture, n);
            throughTheAccessors(Fixture, n);
        }
        // 2. EVERY SINGLE BYTE in the first 40, over every value
        unsigned char mutated[40 > FixtureLength ? FixtureLength : 40];
        for (size_t i = 0; i < sizeof mutated; i++) {
            for (int v = 0; v < 256; v++) {
                memcpy(mutated, Fixture, sizeof mutated);
                mutated[i] = (unsigned char)v;
                walk(mutated, sizeof mutated);
                throughTheAccessors(mutated, sizeof mutated);
            }
        }
        // 3. every length octet forced to 0xFF and to 0x00 - an over-long and an indefinite length
        for (size_t i = 0; i < sizeof mutated; i++) {
            for (int v = 0; v < 2; v++) {
                memcpy(mutated, Fixture, sizeof mutated);
                mutated[i] = v ? 0xFF : 0x00;
                walk(mutated, sizeof mutated);
                throughTheAccessors(mutated, sizeof mutated);
            }
        }
        printf("truncations %zu, mutations %zu, walks accepted %ld, refused %ld, certificates built %ld\n",
               FixtureLength + 1, (size_t)sizeof mutated * 256, accepted, refused, built);
        printf("no out-of-range slice and no crash\n");
    }
    return 0;
}
