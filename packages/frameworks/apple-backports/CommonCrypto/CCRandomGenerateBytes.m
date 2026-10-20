#import <CommonCrypto/CommonRandom.h>
#import <Security/SecRandom.h>

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
