#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

static void report(const char *label, OSStatus status, Boolean value, Boolean want)
{
    printf("%s\t%ld\t%d\n", label, (long)status, value ? 1 : 0);
    if (value != want)
        printf("WRONG\t%s: read back [%d] and the caller set [%d]\n", label, value ? 1 : 0, want ? 1 : 0);
}

int main(int argc, const char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        NSData *der = [NSData dataWithContentsOfFile:@"tests/backports/host/security/fixtures/certificate.der"];
        if (!der) { printf("no fixture\n"); return 1; }
        SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)der);
        if (!cert) { printf("no certificate\n"); return 1; }
        SecPolicyRef policy = SecPolicyCreateBasicX509();
        SecTrustRef trust = NULL;
        OSStatus made = SecTrustCreateWithCertificates(cert, policy, &trust);
        printf("made-trust\t%ld\n", (long)made);
        if (made != errSecSuccess || !trust) { printf("no trust\n"); return 1; }

        Boolean value = false;
        OSStatus got = SecTrustGetNetworkFetchAllowed(trust, &value);
        report("default", got, value, false);
        OSStatus set = SecTrustSetNetworkFetchAllowed(trust, true);
        printf("set-true\t%ld\n", (long)set);
        value = false;
        got = SecTrustGetNetworkFetchAllowed(trust, &value);
        report("after-true", got, value, true);
        set = SecTrustSetNetworkFetchAllowed(trust, false);
        value = true;
        got = SecTrustGetNetworkFetchAllowed(trust, &value);
        report("after-false", got, value, false);
        printf("null-trust\t%ld\n", (long)SecTrustSetNetworkFetchAllowed(NULL, true));
        CFRelease(trust);
        CFRelease(policy);
        CFRelease(cert);
    }
    return 0;
}
