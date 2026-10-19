// seckey-ecraw.m - what the release's own Security does with an elliptic key, measured on the release
// itself (xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/seckey-ecraw). Everything in
// facts/Security/SecKeyElliptic.md about the release side is what this prints, and the port's four
// SecKey calls are written from it.
//
// A command-line program, no UIApplicationMain: build it as a daemon target (@addon/charon/daemon;
// Security, Foundation; -fobjc-arc) and run it as above. It needs no OpenGL, no network and no
// package of this repository's, so it runs on the emulated 6.1.3 and on a device alike.
//
// It asks, and prints one line per answer so two runs can be diffed:
//   1. can the release make a P-256 pair at all (SecKeyGeneratePair), and what does it publish of it;
//   2. what does SecKeyRawSign answer for a 32 byte digest - the two 32 byte halves, or their DER;
//   3. with which padding does it take that call, and does it hash the digest itself;
//   4. does SecKeyRawVerify accept what SecKeyRawSign produced;
//   5. is there an elliptic key agreement on the release at all (dlsym over the names Security of that
//      era had), and what does the finite-field one say for an EC key.
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

    // 1. A P-256 pair, from the release's own generator.
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

    // 2. The release's own signing, over a digest, with each padding it might take.
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
            // A different digest must not verify, so a YES above is about this message and not a shape.
            uint8_t other[32];
            memcpy(other, digest, sizeof other);
            other[0] ^= 0xff;
            printf("release SecKeyRawVerify of another digest: %d\n",
                   (int)SecKeyRawVerify(publicKey, paddings[which], other, sizeof other, signature, length));
        }
    }
    // 3. Whether the release hashes the digest itself: 32 bytes is a digest, 40 is a SHA-1 of one.
    if (bestLength) {
        uint8_t forty[40];
        memset(forty, 0x5a, sizeof forty);
        uint8_t signature[256];
        size_t length = sizeof signature;
        printf("release SecKeyRawSign of 40 bytes: %d\n",
               (int)SecKeyRawSign(privateKey, kSecPaddingNone, forty, sizeof forty, signature, &length));
    }

    // 4. Is there an elliptic key agreement on this release at all? The names Security of that era
    // had, asked one by one: the two the SecKey API of iOS 10 uses, and the finite-field family that
    // is the release's own key agreement.
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
