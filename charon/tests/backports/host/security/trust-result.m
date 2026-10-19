#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <stdio.h>

// The port's SecTrustGetTrustResult against the HOST'S OWN, reached by dlopen of the system framework and
// dlsym off THAT handle - this case defines the same name, so calling the name would compare the port with
// itself. No keychain: SecTrustCreateWithCertificates takes a certificate and a policy and nothing else.
// THE PORT'S OWN COPY IS ALSO LOOKED UP BY NAME, and that is not tidiness. Calling the function by name
// let the LINKER decide, and it chose the framework's: the mutant that invents a verdict instead of
// asking the release ran, and the case reported the framework's own answer as if it were the port's. A
// case that cannot say which implementation it called is a case that passes without testing anything.
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
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        void *system = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY | RTLD_LOCAL);
        typedef OSStatus (*GetTrustResult)(SecTrustRef, SecTrustResultType *);
        GetTrustResult host = (GetTrustResult)dlsym(system, "SecTrustGetTrustResult");
        // the port's own, off the MAIN handle: with -framework Security in the link, the dylib's
        // definition of this name can be the one a call resolves to
        portGet = (GetTrustResult)dlsym(RTLD_DEFAULT, "SecTrustGetTrustResult");
        typedef OSStatus (*Evaluate)(SecTrustRef, SecTrustResultType *);
        Evaluate hostEvaluate = (Evaluate)dlsym(system, "SecTrustEvaluate");
        printf("host-symbols\t%s\n", (host && hostEvaluate) ? "both" : "MISSING");
        printf("port-symbol\t%s\n", portGet ? "found" : "MISSING");
        if (!host || !hostEvaluate || !portGet)
            return 1;

        // a trust over the committed fixture, so the evaluation is a real one and not a stub
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

        // the out-parameter is required: a NULL one is errSecParam, not a write through NULL
        printf("null-out\t%ld\t%ld\n", (long)portGet(trust, NULL), (long)host(trust, NULL));
        printf("null-trust\t%ld\t%ld\n", (long)portGet(NULL, &portResult),
               (long)host(NULL, &hostResult));
        CFRelease(trust);
        CFRelease(policy);
        CFRelease(fixture);
    }
    return 0;
}
