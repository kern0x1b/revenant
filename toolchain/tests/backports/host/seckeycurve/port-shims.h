#ifndef PORT_SHIMS_H
#define PORT_SHIMS_H

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <string.h>

extern void RevenantShimMarkPortKey(SecKeyRef privateKey, const uint8_t *scalar, size_t length);
extern void RevenantShimMarkPortPublicKey(SecKeyRef publicKey);
extern void RevenantShimMarkReleaseKey(SecKeyRef key, CFStringRef type);
extern OSStatus revenantHost_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result);
extern CFDictionaryRef revenantHost_SecKeyCopyAttributeDictionary(SecKeyRef key);

extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);

#define REVENANT_SHIM_SECKEY_MARKER "RevenantSecKeyScalar"

static const uint8_t RevenantShimSubjectPublicKeyInfo[] = {
    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08,
    0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00};

static SecKeyAlgorithm RevenantShimAlgorithmForPadding(SecPadding padding)
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
static OSStatus RevenantShimRawSign(SecKeyRef key, const uint8_t *bytes, size_t length,
                                  uint8_t *signature, size_t *signatureLength, SecPadding padding)
{
    typedef CFDataRef (*RevenantShimCreateSignature)(SecKeyRef, SecKeyAlgorithm, CFDataRef, CFErrorRef *);
    static RevenantShimCreateSignature host = NULL;
    if (!host) {
        host = (RevenantShimCreateSignature)dlsym(RTLD_DEFAULT, "SecKeyCreateSignature");
    }
    if (!host) {
        return errSecUnimplemented;
    }
    CFErrorRef error = NULL;
    SecKeyAlgorithm algorithm = RevenantShimAlgorithmForPadding(padding);
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

static OSStatus RevenantShimRawVerify(SecKeyRef key, const uint8_t *bytes, size_t length,
                                    const uint8_t *signature, size_t signatureLength, SecPadding padding)
{
    typedef Boolean (*RevenantShimVerifySignature)(SecKeyRef, SecKeyAlgorithm, CFDataRef, CFDataRef, CFErrorRef *);
    static RevenantShimVerifySignature host = NULL;
    if (!host) {
        host = (RevenantShimVerifySignature)dlsym(RTLD_DEFAULT, "SecKeyVerifySignature");
    }
    if (!host) {
        return errSecUnimplemented;
    }
    SecKeyAlgorithm algorithm = RevenantShimAlgorithmForPadding(padding);
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

static CFDataRef RevenantShimPublicBytes(SecKeyRef key)
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
    uint8_t buffer[sizeof RevenantShimSubjectPublicKeyInfo + 65];
    memcpy(buffer, RevenantShimSubjectPublicKeyInfo, sizeof RevenantShimSubjectPublicKeyInfo);
    memcpy(buffer + sizeof RevenantShimSubjectPublicKeyInfo, CFDataGetBytePtr(point), 65);
    CFRelease(point);
    return CFDataCreate(kCFAllocatorDefault, buffer, (CFIndex)sizeof buffer);
}

static OSStatus SecKeyRawSign(SecKeyRef key, SecPadding padding, const uint8_t *bytes, size_t length,
                              uint8_t *signature, size_t *signatureLength)
{
    return RevenantShimRawSign(key, bytes, length, signature, signatureLength, padding);
}

static OSStatus SecKeyRawVerify(SecKeyRef key, SecPadding padding, const uint8_t *bytes, size_t length,
                                const uint8_t *signature, size_t signatureLength)
{
    return RevenantShimRawVerify(key, bytes, length, signature, signatureLength, padding);
}

static CFIndex SecKeyGetAlgorithmID(SecKeyRef key)
{
    (void)key;
    return 0;
}

static OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serialized)
{
    CFDataRef bytes = RevenantShimPublicBytes(key);
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
