#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

// The TABLE half of SecKeyIsAlgorithmSupported, driven over the operations, the key classes and the
// algorithms - with NO key, NO keychain, NO SecItemAdd, NO kSecAttrIsPermanent and NO identity, because
// the table is a pure function of (operation, algorithm, class) and that is the part worth checking here.
// The key lookup that completes the public function needs a key, and the guest measurement of the
// keychain half is still owed.
bool CharonSecurityCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm, bool rsa, bool ec);

static void answer(const char *label, SecKeyOperationType op, SecKeyAlgorithm alg, bool rsa, bool ec)
{
    printf("%s\t%s\n", label, CharonSecurityCarries(op, alg, rsa, ec) ? "YES" : "NO");
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        // the release has one padding, kSecPaddingPKCS1SHA1, and it is RSA's - so RSA sign/verify over a
        // digest is what it can carry, and the pairs below are what the differential checks.
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
