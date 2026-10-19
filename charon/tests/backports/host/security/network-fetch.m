#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

// A REAL SecTrustRef, made on the host from the committed fixture: SecTrustCreateWithCertificates takes
// a certificate and no keychain, so this touches no SecItem, no identity and no user keychain. What is
// checked is the round trip - what the caller sets is what the caller reads back - and NOT whether the
// release acts on it, which it does not: 6.1.3 has no network fetch at all.
static void report(const char *label, OSStatus status, Boolean value, Boolean want)
{
    printf("%s\t%ld\t%d\n", label, (long)status, value ? 1 : 0);
    if (value != want)
        printf("WRONG\t%s: read back [%d] and the caller set [%d]\n", label, value ? 1 : 0, want ? 1 : 0);
}

int main(int argc, const char **argv)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
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
        // the default: a trust nobody has set anything on has not been allowed to fetch
        OSStatus got = SecTrustGetNetworkFetchAllowed(trust, &value);
        report("default", got, value, false);
        // set true, and the getter must read back what the caller set
        OSStatus set = SecTrustSetNetworkFetchAllowed(trust, true);
        printf("set-true\t%ld\n", (long)set);
        value = false;
        got = SecTrustGetNetworkFetchAllowed(trust, &value);
        report("after-true", got, value, true);
        // and back off, so this is a flag and not a latch
        set = SecTrustSetNetworkFetchAllowed(trust, false);
        value = true;
        got = SecTrustGetNetworkFetchAllowed(trust, &value);
        report("after-false", got, value, false);
        // a NULL trust is a parameter error, not a crash
        printf("null-trust\t%ld\n", (long)SecTrustSetNetworkFetchAllowed(NULL, true));
        CFRelease(trust);
        CFRelease(policy);
        CFRelease(cert);
    }
    return 0;
}
