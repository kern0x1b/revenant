#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

// Which (operation, algorithm) pairs the table claims, for VERIFY, with the padding each one checks
// with. No key, no keychain, no SecItemAdd, no kSecAttrIsPermanent, no identity: the table is a pure
// function of the operation, the algorithm and the key's class, and that is what is driven here.
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
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        pair("verify-rsa-sha256", kSecKeyOperationTypeVerify,
             kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, true, false, true);
        pair("verify-rsa-sha384", kSecKeyOperationTypeVerify,
             kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384, true, false, true);
        // CARRIED, and it was not until this series' merge: the release has an EC key type
        // (kSecAttrKeyTypeEC, SecItem.h:802-803, API_AVAILABLE(macos(10.9), ios(4.0))) and its own
        // SecKeyRawVerify takes such a key and a digest, with kSecPaddingNone - which is 0, and what
        // the padding column below reads. The old `false` here was the pre-merge table's, and while it
        // stood this case printed its own WRONG line against a table that had changed underneath it, so
        // the comparator above read a red control and the mutation proved nothing.
        pair("verify-ec-sha256", kSecKeyOperationTypeVerify,
             kSecKeyAlgorithmECDSASignatureMessageX962SHA256, false, true, true);
        pair("verify-rsa-ecdsa", kSecKeyOperationTypeVerify,
             kSecKeyAlgorithmECDSASignatureMessageX962SHA256, true, false, false);
    }
    return 0;
}
