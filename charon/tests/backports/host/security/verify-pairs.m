#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

bool CharonSecurityCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm, bool rsa, bool ec);
SecPadding CharonSecurityPaddingFor(SecKeyAlgorithm algorithm);

static void pair(const char *label, SecKeyOperationType operation, SecKeyAlgorithm algorithm,
                 bool rsa, bool ec, bool want)
{
    bool got = CharonSecurityCarries(operation, algorithm, rsa, ec);
    SecPadding padding = CharonSecurityPaddingFor(algorithm);
    printf("%s\t%d\t%ld\n", label, got ? 1 : 0, (long)padding);
    if (got != want)
        printf("WRONG\t%s: the table said [%s] and the port claims [%s]\n", label,
               got ? "carries" : "cannot", want ? "carries" : "cannot");
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        pair("verify-rsa-sha256", kSecKeyOperationTypeVerify,
             kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, true, false, true);
        pair("verify-rsa-sha384", kSecKeyOperationTypeVerify,
             kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384, true, false, true);
        pair("verify-ec-sha256", kSecKeyOperationTypeVerify,
             kSecKeyAlgorithmECDSASignatureMessageX962SHA256, false, true, true);
        pair("verify-rsa-ecdsa", kSecKeyOperationTypeVerify,
             kSecKeyAlgorithmECDSASignatureMessageX962SHA256, true, false, false);
    }
    return 0;
}
