#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

// The PADDING mapping, driven with no key, no keychain, no SecItemAdd, no kSecAttrIsPermanent and no
// identity: it is a pure function of the algorithm, and that is the part worth checking here. Signing
// itself needs a key, and the guest measurement of the keychain half is still owed.
SecPadding CharonSecurityPaddingFor(SecKeyAlgorithm algorithm);

static void padding(const char *label, SecKeyAlgorithm algorithm, long want)
{
    SecPadding got = CharonSecurityPaddingFor(algorithm);
    printf("%s\t%ld\n", label, (long)got);
    if ((long)got != want)
        printf("WRONG\t%s: answered %ld and the port claims %ld\n", label, (long)got, want);
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        // the paddings are the header's own enumerators, read by value so the expectation is the
        // SDK's number and not a spelling copied from a document
        padding("pkcs1-sha1", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1, kSecPaddingPKCS1SHA1);
        padding("pkcs1-sha224", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA224, kSecPaddingPKCS1SHA224);
        padding("pkcs1-sha256", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, kSecPaddingPKCS1SHA256);
        padding("pkcs1-sha384", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384, kSecPaddingPKCS1SHA384);
        padding("pkcs1-sha512", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512, kSecPaddingPKCS1SHA512);
        // an algorithm the release cannot carry, and the one the table says it cannot
        padding("ecdsa-sha256", kSecKeyAlgorithmECDSASignatureMessageX962SHA256, kSecPaddingNone);
    }
    return 0;
}
