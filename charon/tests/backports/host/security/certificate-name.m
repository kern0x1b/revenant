#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>
#import <dlfcn.h>

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
    printf("%s\t%lu\t%lu\t%s\n", label, (unsigned long)CFDataGetLength(port),
           (unsigned long)CFDataGetLength(host), same ? "same" : "DIFFERENT");
    if (!same) printf("WRONG\t%s: the port's bytes are not the host's\n", label);
}

int main(void)
{
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
        CFDataRef i = SecCertificateCopyNormalizedIssuerSequence(cert);
        CFDataRef s = SecCertificateCopyNormalizedSubjectSequence(cert);
        printf("selfsigned-same\t%s\n", (i && s && CFEqual(i, s)) ? "yes" : "NO");
        if (!(i && s && CFEqual(i, s))) printf("WRONG\tselfsigned-same: issuer and subject must match on a self-signed certificate\n");

        NSData *truncated = [der subdataWithRange:NSMakeRange(0, 60)];
        NSData *wrongTag = [der subdataWithRange:NSMakeRange(0, 40)];
        uint8_t *notCert = malloc(8);
        memset(notCert, 0x30, 8);
        SecCertificateRef bad = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)truncated);
        printf("truncated\t%s\n", bad ? (SecCertificateCopyNormalizedIssuerSequence(bad) ? "present" : "NULL") : "no-cert");
        free(notCert);
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
        printf("null-cert\t%s\n", SecCertificateCopyNormalizedIssuerSequence(NULL) ? "present" : "NULL");
        printf("null-subject\t%s\n", SecCertificateCopyNormalizedSubjectSequence(NULL) ? "present" : "NULL");
    }
    return 0;
}
