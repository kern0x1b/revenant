#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>
#import <dlfcn.h>

// The port's reader against the HOST'S OWN accessors, on the committed fixture. The host has
// SecCertificateCopyNormalizedIssuerSequence and SecCertificateCopyNormalizedSubjectSequence, so this is
// a differential and not a self-comparison: the port parses the release's DER and the SDK's answer says
// whether the slice is the right one. No keychain, no SecItem, no identity - the certificate is made
// with SecCertificateCreateWithData from a static blob.
// The HOST'S OWN accessors, reached by dlopen of the SYSTEM framework and dlsym off that handle. Not
// by calling the name: this file defines SecCertificateCopyNormalizedIssuerSequence itself, so a call to
// that name resolves to the PORT's copy and the "differential" would compare the port with itself - which
// is exactly what the first version of this case did, and it passed.
// The walk itself, so MALFORMED INPUT IS EXERCISED rather than assumed: a certificate the host refuses
// to build never reaches the port, so the only way to reach a malformed walk is to hand the reader bytes.
bool CharonCertificateNameTLV(const uint8_t *bytes, size_t length, bool wantSubject,
                             size_t *outStart, size_t *outEnd);

typedef CFDataRef (*CopyName)(SecCertificateRef);
static CopyName hostIssuer, hostSubject;

static void compare(const char *label, CFDataRef port, CFDataRef host)
{
    if (!port || !host) {
        printf("%s\t%s\t%s\n", label, port ? "present" : "NULL", host ? "present" : "NULL");
        if (port != host) printf("WRONG\t%s: port [%s] host [%s]\n", label, port ? "present" : "NULL", host ? "present" : "NULL");
        return;
    }
    bool same = CFEqual(port, host);
    if (!same) {
        const unsigned char *p = (const unsigned char *)CFDataGetBytePtr(port);
        const unsigned char *h = (const unsigned char *)CFDataGetBytePtr(host);
        for (CFIndex i = 0; i < CFDataGetLength(host) && i < CFDataGetLength(port); i++)
            if (p[i] != h[i]) { printf("first-diff\t%ld\tport %02x host %02x\n", (long)i, p[i], h[i]); break; }
        printf("port-head\t"); for (int i = 0; i < 10 && i < CFDataGetLength(port); i++) printf("%02x", p[i]);
        printf("\nhost-head\t"); for (int i = 0; i < 10 && i < CFDataGetLength(host); i++) printf("%02x", h[i]);
        printf("\n");
    }
    // BOTH LENGTHS ARE PRINTED, because "the port's 66 bytes are not the host's" does not say whether
    // the host has 66 different bytes or a different number of them, and that is the first question
    printf("%s\t%lu\t%lu\t%s\n", label, (unsigned long)CFDataGetLength(port),
           (unsigned long)CFDataGetLength(host), same ? "same" : "DIFFERENT");
    if (!same) printf("WRONG\t%s: the port's bytes are not the host's\n", label);
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        NSData *der = [NSData dataWithContentsOfFile:@"tests/backports/host/security/fixtures/certificate.der"];
        SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)der);
        if (!cert) { printf("no certificate\n"); return 1; }
        void *system = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY | RTLD_LOCAL);
        if (!system) { printf("no system framework: %s\n", dlerror()); return 1; }
        hostIssuer = (CopyName)dlsym(system, "SecCertificateCopyNormalizedIssuerSequence");
        hostSubject = (CopyName)dlsym(system, "SecCertificateCopyNormalizedSubjectSequence");
        printf("host-symbols\t%s\n", (hostIssuer && hostSubject) ? "both" : "MISSING");
        if (!hostIssuer || !hostSubject) return 1;
        compare("issuer", SecCertificateCopyNormalizedIssuerSequence(cert), hostIssuer(cert));
        compare("subject", SecCertificateCopyNormalizedSubjectSequence(cert), hostSubject(cert));
        // THIS FIXTURE IS SELF-SIGNED, so its issuer and its subject ARE THE SAME NAME and a correct
        // reader must return identical bytes for the two. That is a stronger claim on this certificate
        // than "they differ", and it is stated the other way round deliberately: a reader that walked to
        // the wrong field twice would pass a "they differ" check and fails this one.
        CFDataRef i = SecCertificateCopyNormalizedIssuerSequence(cert);
        CFDataRef s = SecCertificateCopyNormalizedSubjectSequence(cert);
        printf("selfsigned-same\t%s\n", (i && s && CFEqual(i, s)) ? "yes" : "NO");
        if (!(i && s && CFEqual(i, s))) printf("WRONG\tselfsigned-same: issuer and subject must match on a self-signed certificate\n");

        // MALFORMED INPUT IS NULL AND SAYS NOTHING ELSE: three shapes, each cut from the real DER so
        // the first bytes are a valid SEQUENCE and the damage is inside it
        NSData *truncated = [der subdataWithRange:NSMakeRange(0, 60)];         // a length that runs out
        NSData *wrongTag = [der subdataWithRange:NSMakeRange(0, 40)];           // header, then junk
        uint8_t *notCert = malloc(8);
        memset(notCert, 0x30, 8);
        SecCertificateRef bad = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)truncated);
        // MALFORMED: a length that runs past what was handed over. The PORT's answer is the one that
        // matters here, and it must be NULL - the host is not asked, because a malformed certificate is
        // not something the host has a verdict about.
        printf("truncated\t%s\n", bad ? (SecCertificateCopyNormalizedIssuerSequence(bad) ? "present" : "NULL") : "no-cert");
        free(notCert);
        // MALFORMED INPUT, four shapes, each handed straight to the walk:
        //   a length that runs past the buffer, a first tag that is not a SEQUENCE, an INDEFINITE length
        //   (0x80, which DER does not allow at all), and a long-form length naming more bytes than exist
        uint8_t runsOut[] = {0x30, 0x7f, 0x01};
        uint8_t notSequence[] = {0x02, 0x01, 0x00};
        uint8_t indefinite[] = {0x30, 0x80, 0x00, 0x00};
        uint8_t longForm[] = {0x30, 0x84, 0x7f, 0xff, 0xff, 0xff, 0x00};
        uint8_t shortBuf[] = {0x30, 0x03, 0x30, 0x01, 0x00};
        struct { const char *what; uint8_t *bytes; size_t n; } shapes[] = {
            {"runs-out", runsOut, sizeof runsOut}, {"wrong-tag", notSequence, sizeof notSequence},
            {"indefinite", indefinite, sizeof indefinite}, {"long-form", longForm, sizeof longForm},
            {"short-tbs", shortBuf, sizeof shortBuf},
        };
        for (size_t i = 0; i < sizeof shapes / sizeof shapes[0]; i++) {
            size_t start = 0, end = 0;
            bool ok = CharonCertificateNameTLV(shapes[i].bytes, shapes[i].n, false, &start, &end);
            printf("malformed-%s\t%s\n", shapes[i].what, ok ? "ACCEPTED" : "refused");
            if (ok) printf("WRONG\tmalformed-%s: the walk accepted bytes that are not a certificate\n", shapes[i].what);
        }
        // and a NULL certificate is NULL, not a crash
        printf("null-cert\t%s\n", SecCertificateCopyNormalizedIssuerSequence(NULL) ? "present" : "NULL");
        printf("null-subject\t%s\n", SecCertificateCopyNormalizedSubjectSequence(NULL) ? "present" : "NULL");
    }
    return 0;
}
