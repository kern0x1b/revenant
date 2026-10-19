#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

bool RevenantSecurityCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm, bool rsa, bool ec);

static void answer(const char *label, SecKeyOperationType op, SecKeyAlgorithm alg, bool rsa, bool ec)
{
    printf("%s\t%s\n", label, RevenantSecurityCarries(op, alg, rsa, ec) ? "YES" : "NO");
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        answer("rsa-sign-sha256", kSecKeyOperationTypeSign,
               kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, true, false);
        answer("rsa-verify-sha256", kSecKeyOperationTypeVerify,
               kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, true, false);
        answer("rsa-sign-sha1", kSecKeyOperationTypeSign,
               kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1, true, false);
        answer("rsa-encrypt-oaep", kSecKeyOperationTypeEncrypt,
               kSecKeyAlgorithmRSAEncryptionOAEPSHA1AESGCM, true, false);
        answer("rsa-decrypt-pkcs1", kSecKeyOperationTypeDecrypt,
               kSecKeyAlgorithmRSAEncryptionPKCS1, true, false);
        answer("ec-sign-sha256", kSecKeyOperationTypeSign,
               kSecKeyAlgorithmECDSASignatureMessageX962SHA256, false, true);
        answer("rsa-keyexchange", kSecKeyOperationTypeKeyExchange,
               kSecKeyAlgorithmRSAEncryptionOAEPSHA1AESGCM, true, false);
        answer("rsa-sign-unknown", kSecKeyOperationTypeSign,
               kSecKeyAlgorithmECDSASignatureMessageX962SHA256, true, false);
    }
    return 0;
}
