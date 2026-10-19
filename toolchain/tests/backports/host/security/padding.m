#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

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
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        padding("pkcs1-sha1", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1, kSecPaddingPKCS1SHA1);
        padding("pkcs1-sha224", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA224, kSecPaddingPKCS1SHA224);
        padding("pkcs1-sha256", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, kSecPaddingPKCS1SHA256);
        padding("pkcs1-sha384", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384, kSecPaddingPKCS1SHA384);
        padding("pkcs1-sha512", kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512, kSecPaddingPKCS1SHA512);
        padding("ecdsa-sha256", kSecKeyAlgorithmECDSASignatureMessageX962SHA256, kSecPaddingNone);
    }
    return 0;
}
