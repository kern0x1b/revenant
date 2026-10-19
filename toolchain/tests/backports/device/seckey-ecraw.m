#include <Security/Security.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

static void hex(const char *label, const uint8_t *bytes, size_t length)
{
    printf("%s ", label);
    for (size_t index = 0; index < length; index++) {
        printf("%02x", bytes[index]);
    }
    printf("\n");
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);

    NSDictionary *attributes = @{@"class": (__bridge id)kSecClassKey,
                                 @"type": (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
                                 @"size": @256};
    SecKeyRef privateKey = NULL, publicKey = NULL;
    OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef)attributes, &publicKey, &privateKey);
    printf("release SecKeyGeneratePair EC: %d private %s public %s\n", (int)status,
           privateKey ? "yes" : "no", publicKey ? "yes" : "no");
    if (status != errSecSuccess || !privateKey || !publicKey) {
        printf("release: no elliptic key can be made, so the four SecKey calls of iOS 10 have nothing to sign with here\n");
        return 0;
    }

    CFDataRef serialized = NULL;
    status = SecKeyCopyPublicBytes(publicKey, &serialized);
    printf("release SecKeyCopyPublicBytes: %d, %ld bytes\n", (int)status, serialized ? (long)CFDataGetLength(serialized) : 0L);
    if (serialized) {
        hex("release public point:", CFDataGetBytePtr(serialized), (size_t)CFDataGetLength(serialized));
        CFRelease(serialized);
    }

    uint8_t digest[32];
    for (int index = 0; index < 32; index++) {
        digest[index] = (uint8_t)(index * 7 + 1);
    }
    SecPadding paddings[2] = {kSecPaddingNone, kSecPaddingPKCS1};
    const char *names[2] = {"none", "pkcs1"};
    uint8_t best[256];
    size_t bestLength = 0;
    for (int which = 0; which < 2; which++) {
        uint8_t signature[256];
        size_t length = sizeof signature;
        memset(signature, 0, sizeof signature);
        OSStatus signed_ = SecKeyRawSign(privateKey, paddings[which], digest, sizeof digest, signature, &length);
        printf("release SecKeyRawSign padding %s: %d, %ld bytes", names[which], (int)signed_, (long)length);
        if (signed_ == errSecSuccess && length > 0) {
            printf(", first bytes %02x %02x %02x %02x", signature[0], signature[1], signature[2], signature[3]);
            printf(" %s", length == 64 ? "(two 32 byte halves)" : (signature[0] == 0x30 ? "(a DER SEQUENCE)" : "(neither shape)"));
            if (length > bestLength) {
                memcpy(best, signature, length);
                bestLength = length;
            }
        }
        printf("\n");
        if (signed_ == errSecSuccess) {
            hex("release signature:", signature, length);
            OSStatus verified = SecKeyRawVerify(publicKey, paddings[which], digest, sizeof digest, signature, length);
            printf("release SecKeyRawVerify padding %s of it: %d\n", names[which], (int)verified);
            uint8_t other[32];
            memcpy(other, digest, sizeof other);
            other[0] ^= 0xff;
            printf("release SecKeyRawVerify of another digest: %d\n",
                   (int)SecKeyRawVerify(publicKey, paddings[which], other, sizeof other, signature, length));
        }
    }
    if (bestLength) {
        uint8_t forty[40];
        memset(forty, 0x5a, sizeof forty);
        uint8_t signature[256];
        size_t length = sizeof signature;
        printf("release SecKeyRawSign of 40 bytes: %d\n",
               (int)SecKeyRawSign(privateKey, kSecPaddingNone, forty, sizeof forty, signature, &length));
    }

    static const char *exchangeNames[] = {
        "SecKeyCopyExchangeKey", "SecKeyExchangeKey", "SecKeyECDHExchange", "SecKeyComputeSharedSecret",
        "SecKeyCreateFromData", "SecKeyECDH", "SecKeyExchange", NULL};
    for (int index = 0; exchangeNames[index]; index++) {
        printf("release %s: %s\n", exchangeNames[index], dlsym(RTLD_DEFAULT, exchangeNames[index]) ? "present" : "absent");
    }
    printf("release SecDHComputeKey: %s, SecDHGenerateKeypair: %s, SecKeyRawSign: %s, SecKeyRawVerify: %s\n",
           dlsym(RTLD_DEFAULT, "SecDHComputeKey") ? "present" : "absent",
           dlsym(RTLD_DEFAULT, "SecDHGenerateKeypair") ? "present" : "absent",
           dlsym(RTLD_DEFAULT, "SecKeyRawSign") ? "present" : "absent",
           dlsym(RTLD_DEFAULT, "SecKeyRawVerify") ? "present" : "absent");
    printf("done\n");
    return 0;
}
