#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <stdio.h>
#import <string.h>

bool RevenantCertificateReadTLV(const uint8_t *bytes, size_t length, size_t at, uint8_t *tag,
                              size_t *content, size_t *next, size_t limit);
bool RevenantCertificateNameTLV(const uint8_t *bytes, size_t length, bool wantSubject,
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
        if (RevenantCertificateNameTLV(bytes, length, subject ? true : false, &start, &end)) {
            accepted++;
            if (end < start || end > length)
                { printf("OUT-OF-RANGE start=%zu end=%zu of %zu\n", start, end, length); abort(); }
        } else {
            refused++;
        }
    }
    for (size_t at = 0; at < length; at++) {
        uint8_t tag = 0;
        size_t content = 0, next = 0;
        if (RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length)) {
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
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        for (size_t n = 0; n <= FixtureLength; n++) {
            walk(Fixture, n);
            throughTheAccessors(Fixture, n);
        }
        unsigned char mutated[40 > FixtureLength ? FixtureLength : 40];
        for (size_t i = 0; i < sizeof mutated; i++) {
            for (int v = 0; v < 256; v++) {
                memcpy(mutated, Fixture, sizeof mutated);
                mutated[i] = (unsigned char)v;
                walk(mutated, sizeof mutated);
                throughTheAccessors(mutated, sizeof mutated);
            }
        }
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
