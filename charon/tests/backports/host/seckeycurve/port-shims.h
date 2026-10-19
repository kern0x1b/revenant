#ifndef PORT_SHIMS_H
#define PORT_SHIMS_H

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <string.h>

extern void CharonShimMarkPortKey(SecKeyRef privateKey, const uint8_t *scalar, size_t length);
extern void CharonShimMarkPortPublicKey(SecKeyRef publicKey);
extern void CharonShimMarkReleaseKey(SecKeyRef key, CFStringRef type);
extern OSStatus charonHost_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result);
extern CFDictionaryRef charonHost_SecKeyCopyAttributeDictionary(SecKeyRef key);

extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);

#define CHARON_SHIM_SECKEY_MARKER "CharonSecKeyScalar"

static const uint8_t CharonShimSubjectPublicKeyInfo[] = {
    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08,
    0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00};

static SecKeyAlgorithm CharonShimAlgorithmForPadding(SecPadding padding)
{
    switch (padding) {
        case kSecPaddingPKCS1SHA1:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA1;
        case kSecPaddingPKCS1SHA224:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA224;
        case kSecPaddingPKCS1SHA256:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256;
        case kSecPaddingPKCS1SHA384:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA384;
        case kSecPaddingPKCS1SHA512:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512;
        default:
            return kSecKeyAlgorithmECDSASignatureDigestX962SHA256;
    }
}
static OSStatus CharonShimRawSign(SecKeyRef key, const uint8_t *bytes, size_t length,
                                  uint8_t *signature, size_t *signatureLength, SecPadding padding)
{
    typedef CFDataRef (*CharonShimCreateSignature)(SecKeyRef, SecKeyAlgorithm, CFDataRef, CFErrorRef *);
    static CharonShimCreateSignature host = NULL;
    if (!host) {
        host = (CharonShimCreateSignature)dlsym(RTLD_DEFAULT, "SecKeyCreateSignature");
    }
    if (!host) {
        return errSecUnimplemented;
    }
    CFErrorRef error = NULL;
    SecKeyAlgorithm algorithm = CharonShimAlgorithmForPadding(padding);
    CFDataRef digest = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
    CFDataRef made = host(key, algorithm, digest, &error);
    CFRelease(digest);
    if (error) {
        CFRelease(error);
    }
    if (!made) {
        return errSecInternalError;
    }
    size_t room = *signatureLength;
    size_t written = (size_t)CFDataGetLength(made);
    if (written > room) {
        CFRelease(made);
        return errSecParam;
    }
    memcpy(signature, CFDataGetBytePtr(made), written);
    CFRelease(made);
    *signatureLength = written;
    return errSecSuccess;
}

static OSStatus CharonShimRawVerify(SecKeyRef key, const uint8_t *bytes, size_t length,
                                    const uint8_t *signature, size_t signatureLength, SecPadding padding)
{
    typedef Boolean (*CharonShimVerifySignature)(SecKeyRef, SecKeyAlgorithm, CFDataRef, CFDataRef, CFErrorRef *);
    static CharonShimVerifySignature host = NULL;
    if (!host) {
        host = (CharonShimVerifySignature)dlsym(RTLD_DEFAULT, "SecKeyVerifySignature");
    }
    if (!host) {
        return errSecUnimplemented;
    }
    SecKeyAlgorithm algorithm = CharonShimAlgorithmForPadding(padding);
    CFDataRef digest = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
    uint8_t der[72];
    const uint8_t *given = signature;
    size_t givenLength = signatureLength;
    if (signatureLength == 64) {
        size_t offset = 0;
        der[offset++] = 0x30;
        der[offset++] = 0;
        size_t content = offset;
        for (int half = 0; half < 2; half++) {
            const uint8_t *value = signature + half * 32;
            int first = 0;
            while (first < 31 && value[first] == 0) {
                first++;
            }
            int size = 32 - first;
            if (value[first] & 0x80) {
                der[offset++] = 0x02;
                der[offset++] = (uint8_t)(size + 1);
                der[offset++] = 0x00;
            } else {
                der[offset++] = 0x02;
                der[offset++] = (uint8_t)size;
            }
            memcpy(der + offset, value + first, (size_t)size);
            offset += (size_t)size;
        }
        der[1] = (uint8_t)(offset - content);
        given = der;
        givenLength = offset;
    }
    CFDataRef made = CFDataCreate(kCFAllocatorDefault, given, (CFIndex)givenLength);
    CFErrorRef error = NULL;
    BOOL valid = host(key, algorithm, digest, made, &error);
    CFRelease(digest);
    CFRelease(made);
    if (error) {
        CFRelease(error);
    }
    return valid ? errSecSuccess : errSecVerifyFailed;
}

static CFDataRef CharonShimPublicBytes(SecKeyRef key)
{
    SecKeyRef publicKey = SecKeyCopyPublicKey(key);
    if (!publicKey) {
        return NULL;
    }
    CFErrorRef error = NULL;
    CFDataRef point = SecKeyCopyExternalRepresentation(publicKey, &error);
    CFRelease(publicKey);
    if (error) {
        CFRelease(error);
    }
    if (!point) {
        return NULL;
    }
    size_t length = (size_t)CFDataGetLength(point);
    if (length != 65) {
        CFRelease(point);
        return NULL;
    }
    uint8_t buffer[sizeof CharonShimSubjectPublicKeyInfo + 65];
    memcpy(buffer, CharonShimSubjectPublicKeyInfo, sizeof CharonShimSubjectPublicKeyInfo);
    memcpy(buffer + sizeof CharonShimSubjectPublicKeyInfo, CFDataGetBytePtr(point), 65);
    CFRelease(point);
    return CFDataCreate(kCFAllocatorDefault, buffer, (CFIndex)sizeof buffer);
}

static OSStatus SecKeyRawSign(SecKeyRef key, SecPadding padding, const uint8_t *bytes, size_t length,
                              uint8_t *signature, size_t *signatureLength)
{
    return CharonShimRawSign(key, bytes, length, signature, signatureLength, padding);
}

static OSStatus SecKeyRawVerify(SecKeyRef key, SecPadding padding, const uint8_t *bytes, size_t length,
                                const uint8_t *signature, size_t signatureLength)
{
    return CharonShimRawVerify(key, bytes, length, signature, signatureLength, padding);
}

static CFIndex SecKeyGetAlgorithmID(SecKeyRef key)
{
    (void)key;
    return 0;
}

static OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serialized)
{
    CFDataRef bytes = CharonShimPublicBytes(key);
    if (!bytes) {
        return errSecInternalError;
    }
    *serialized = bytes;
    return errSecSuccess;
}

static SecKeyRef SecKeyCreateFromPublicData(CFAllocatorRef allocator, CFIndex algorithmID, CFDataRef serialized)
{
    (void)algorithmID;
    (void)serialized;
    return NULL;
}


#endif
