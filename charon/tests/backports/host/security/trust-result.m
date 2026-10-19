#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <stdio.h>

typedef OSStatus (*GetTrustResult)(SecTrustRef, SecTrustResultType *);
static GetTrustResult portGet;

static void report(const char *label, OSStatus status, SecTrustResultType result, OSStatus wantStatus)
{
    printf("%s\t%ld\t%ld\n", label, (long)status, (long)result);
    if (status != wantStatus)
        printf("WRONG\t%s: status [%ld] and the port claims [%ld]\n", label, (long)status, (long)wantStatus);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        void *system = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY | RTLD_LOCAL);
        typedef OSStatus (*GetTrustResult)(SecTrustRef, SecTrustResultType *);
        GetTrustResult host = (GetTrustResult)dlsym(system, "SecTrustGetTrustResult");
        portGet = (GetTrustResult)dlsym(RTLD_DEFAULT, "SecTrustGetTrustResult");
        typedef OSStatus (*Evaluate)(SecTrustRef, SecTrustResultType *);
        Evaluate hostEvaluate = (Evaluate)dlsym(system, "SecTrustEvaluate");
        printf("host-symbols\t%s\n", (host && hostEvaluate) ? "both" : "MISSING");
        printf("port-symbol\t%s\n", portGet ? "found" : "MISSING");
        if (!host || !hostEvaluate || !portGet)
            return 1;

        SecTrustRef trust = NULL;
        NSData *der = [NSData dataWithContentsOfFile:@"tests/backports/host/security/fixtures/certificate.der"];
        SecCertificateRef fixture = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)der);
        SecPolicyRef policy = SecPolicyCreateBasicX509();
        OSStatus created = SecTrustCreateWithCertificates(fixture, policy, &trust);
        printf("made-trust\t%ld\n", (long)created);
        if (created != errSecSuccess || !trust)
            return 1;

        SecTrustResultType portResult = (SecTrustResultType)-1, hostResult = (SecTrustResultType)-1;
        OSStatus portStatus = portGet(trust, &portResult);
        OSStatus hostStatus = host(trust, &hostResult);
        printf("verdict\t%ld\t%ld\t%ld\t%ld\n", (long)portStatus, (long)hostStatus,
               (long)portResult, (long)hostResult);
        if (portStatus != hostStatus || portResult != hostResult)
            printf("WRONG\tverdict: port [%ld/%ld] and the host says [%ld/%ld]\n",
                   (long)portStatus, (long)portResult, (long)hostStatus, (long)hostResult);

        printf("null-out\t%ld\t%ld\n", (long)portGet(trust, NULL), (long)host(trust, NULL));
        printf("null-trust\t%ld\t%ld\n", (long)portGet(NULL, &portResult),
               (long)host(NULL, &hostResult));
        CFRelease(trust);
        CFRelease(policy);
        CFRelease(fixture);
    }
    return 0;
}
