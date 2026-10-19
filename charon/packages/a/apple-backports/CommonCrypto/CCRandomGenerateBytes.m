#import <CommonCrypto/CommonRandom.h>
#import <Security/SecRandom.h>

// CCRandomGenerateBytes, introduced in iOS 8.0. iOS 6.1.3 exports CCRandomCopyBytes (libSystem) and
// SecRandomCopyBytes (Security); it does not export this name. The bytes come from SecRandomCopyBytes, the
// release's own generator, which the device answers with its kernel random source. Facts and the host
// measurements behind every answer: facts/CommonCrypto/CCRandomGenerateBytes.md.
CCRNGStatus CCRandomGenerateBytes(void *bytes, size_t count)
{
    if (count == 0)
        return kCCSuccess;
    if (bytes == NULL)
        return kCCParamError;
    if (SecRandomCopyBytes(kSecRandomDefault, count, bytes) != errSecSuccess)
        return kCCRNGFailure;
    return kCCSuccess;
}
