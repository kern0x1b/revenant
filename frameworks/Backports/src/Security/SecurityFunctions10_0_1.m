#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#include <stdlib.h>

extern bool RevenantSecurityKeyIsPortEC(SecKeyRef key);
#if TARGET_OS_IPHONE
extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);
#endif
extern CFDictionaryRef RevenantSecureEnclaveKeyCopyAttributes(SecKeyRef key);
extern bool RevenantSecKeyECCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm);
extern CFDataRef RevenantSecKeyECSign(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error);
extern Boolean RevenantSecKeyECVerify(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData, CFDataRef signature, CFErrorRef *error);
extern CFDataRef RevenantSecKeyECExchange(SecKeyRef privateKey, SecKeyAlgorithm algorithm, SecKeyRef publicKey, CFDictionaryRef parameters, CFErrorRef *error);
extern void RevenantSecKeyFail(CFErrorRef *error, OSStatus status, NSString *description);

CFDictionaryRef RevenantSecurityAttributesFromItemResult(CFTypeRef result)
{
    if (!result)
        return NULL;
    if (CFGetTypeID(result) != CFDictionaryGetTypeID())
        return NULL;
    return (CFDictionaryRef)result;
}

CFDictionaryRef BACKPORT_IMPL(SecKeyCopyAttributes)(SecKeyRef key)
{
    if (!key)
        return NULL;
    if (RevenantSecurityKeyIsPortEC(key))
        return RevenantSecureEnclaveKeyCopyAttributes(key);
    const void *keys[] = {kSecValueRef, kSecReturnAttributes};
    const void *values[] = {key, kCFBooleanTrue};
    CFDictionaryRef query = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 2,
                                              &kCFTypeDictionaryKeyCallBacks,
                                              &kCFTypeDictionaryValueCallBacks);
    if (!query)
        return NULL;
    CFTypeRef found = NULL;
    OSStatus status = SecItemCopyMatching(query, &found);
    CFRelease(query);
    if (status != errSecSuccess) {
#if TARGET_OS_IPHONE
        return SecKeyCopyAttributeDictionary(key);
#else
        return NULL;
#endif
    }
    return RevenantSecurityAttributesFromItemResult(found);
}

bool RevenantSecurityCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm, bool rsa, bool ec);

Boolean BACKPORT_IMPL(SecKeyIsAlgorithmSupported)(SecKeyRef key, SecKeyOperationType operation, SecKeyAlgorithm algorithm)
{
    if (!key || !algorithm)
        return false;
    if (RevenantSecurityKeyIsPortEC(key))
        return RevenantSecKeyECCarries(operation, algorithm);
    CFDictionaryRef attributes = SecKeyCopyAttributes(key);
    if (!attributes)
        return false;
    CFTypeRef type = CFDictionaryGetValue(attributes, kSecAttrKeyType);
    bool rsa = type && CFEqual(type, kSecAttrKeyTypeRSA);
    bool ec = type && CFEqual(type, kSecAttrKeyTypeECSECPrimeRandom);
    CFRelease(attributes);
    if (!rsa && !ec) {
        return false;
    }
    return RevenantSecurityCarries(operation, algorithm, rsa, ec);
}

struct RevenantRSASignature {
    SecPadding padding;
    size_t digestLength;
    bool ofMessage;
};

static bool RevenantSecurityRSASignature(SecKeyAlgorithm algorithm, struct RevenantRSASignature *found)
{
    const struct {
        SecKeyAlgorithm algorithm;
        struct RevenantRSASignature signature;
    } known[] = {
        {kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA1, {kSecPaddingPKCS1SHA1, CC_SHA1_DIGEST_LENGTH, false}},
        {kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA224, {kSecPaddingPKCS1SHA224, CC_SHA224_DIGEST_LENGTH, false}},
        {kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256, {kSecPaddingPKCS1SHA256, CC_SHA256_DIGEST_LENGTH, false}},
        {kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA384, {kSecPaddingPKCS1SHA384, CC_SHA384_DIGEST_LENGTH, false}},
        {kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512, {kSecPaddingPKCS1SHA512, CC_SHA512_DIGEST_LENGTH, false}},
        {kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1, {kSecPaddingPKCS1SHA1, CC_SHA1_DIGEST_LENGTH, true}},
        {kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA224, {kSecPaddingPKCS1SHA224, CC_SHA224_DIGEST_LENGTH, true}},
        {kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, {kSecPaddingPKCS1SHA256, CC_SHA256_DIGEST_LENGTH, true}},
        {kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384, {kSecPaddingPKCS1SHA384, CC_SHA384_DIGEST_LENGTH, true}},
        {kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512, {kSecPaddingPKCS1SHA512, CC_SHA512_DIGEST_LENGTH, true}},
    };
    for (size_t index = 0; index < sizeof known / sizeof known[0]; index++) {
        if (CFEqual(algorithm, known[index].algorithm)) {
            *found = known[index].signature;
            return true;
        }
    }
    return false;
}

static CFDataRef RevenantSecurityRSAInput(const struct RevenantRSASignature *signature, CFDataRef data)
{
    if (!signature->ofMessage) {
        if ((size_t)CFDataGetLength(data) != signature->digestLength)
            return NULL;
        return CFRetain(data);
    }
    uint8_t digest[CC_SHA512_DIGEST_LENGTH];
    const uint8_t *bytes = CFDataGetBytePtr(data);
    CC_LONG length = (CC_LONG)CFDataGetLength(data);
    switch (signature->padding) {
    case kSecPaddingPKCS1SHA1:
        CC_SHA1(bytes, length, digest);
        break;
    case kSecPaddingPKCS1SHA224:
        CC_SHA224(bytes, length, digest);
        break;
    case kSecPaddingPKCS1SHA256:
        CC_SHA256(bytes, length, digest);
        break;
    case kSecPaddingPKCS1SHA384:
        CC_SHA384(bytes, length, digest);
        break;
    default:
        CC_SHA512(bytes, length, digest);
        break;
    }
    return CFDataCreate(kCFAllocatorDefault, digest, (CFIndex)signature->digestLength);
}

bool RevenantSecurityCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm, bool rsa, bool ec)
{
    if (operation == kSecKeyOperationTypeSign || operation == kSecKeyOperationTypeVerify) {
        if (rsa) {
            struct RevenantRSASignature signature;
            return RevenantSecurityRSASignature(algorithm, &signature);
        }
        return CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256)
            || CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256);
    }
    if (operation == kSecKeyOperationTypeEncrypt || operation == kSecKeyOperationTypeDecrypt) {
        return rsa && (CFEqual(algorithm, kSecKeyAlgorithmRSAEncryptionPKCS1)
                        || CFEqual(algorithm, kSecKeyAlgorithmRSAEncryptionOAEPSHA1AESGCM));
    }
    if (operation == kSecKeyOperationTypeKeyExchange) {
        return false;
    }
    return false;
}

static size_t RevenantSecuritySignatureRoom(SecKeyRef key, bool ec, CFIndex length)
{
    if (ec) {
        return 72;
    }
    SecKeyRef publicKey = SecKeyCopyPublicKey(key);
    if (publicKey) {
        CFErrorRef error = NULL;
        CFDataRef modulus = SecKeyCopyExternalRepresentation(publicKey, &error);
        CFRelease(publicKey);
        if (error) {
            CFRelease(error);
        }
        if (modulus) {
            size_t size = (size_t)CFDataGetLength(modulus);
            CFRelease(modulus);
            if (size > 1) {
                return size;
            }
        }
    }
    return (size_t)(length > 0 ? length : 0);
}

static CFDataRef RevenantSecurityRawInput(SecKeyAlgorithm algorithm, bool rsa, CFDataRef data, SecPadding *padding)
{
    *padding = kSecPaddingNone;
    if (!rsa)
        return CFRetain(data);
    struct RevenantRSASignature signature;
    if (!RevenantSecurityRSASignature(algorithm, &signature))
        return NULL;
    *padding = signature.padding;
    return RevenantSecurityRSAInput(&signature, data);
}

CFDataRef BACKPORT_IMPL(SecKeyCreateSignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign,
                                CFErrorRef *error)
{
    if (!key || !algorithm || !dataToSign)
        return NULL;
    if (error)
        *error = NULL;
    if (RevenantSecurityKeyIsPortEC(key))
        return RevenantSecKeyECSign(key, algorithm, dataToSign, error);
    CFDictionaryRef attributes = SecKeyCopyAttributes(key);
    if (!attributes)
        return NULL;
    CFTypeRef type = CFDictionaryGetValue(attributes, kSecAttrKeyType);
    bool rsa = type && CFEqual(type, kSecAttrKeyTypeRSA);
    bool ec = type && CFEqual(type, kSecAttrKeyTypeECSECPrimeRandom);
    CFRelease(attributes);
    if (!rsa && !ec) {
        return NULL;
    }
    if (!RevenantSecurityCarries(kSecKeyOperationTypeSign, algorithm, rsa, ec))
        return NULL;
    SecPadding padding = kSecPaddingNone;
    CFDataRef input = RevenantSecurityRawInput(algorithm, rsa, dataToSign, &padding);
    if (!input)
        return NULL;
    CFIndex length = CFDataGetLength(input);
    size_t room = RevenantSecuritySignatureRoom(key, ec, length);
    unsigned char *buffer = room ? calloc(room, 1) : NULL;
    if (!buffer) {
        CFRelease(input);
        return NULL;
    }
    size_t signatureLength = room;
    OSStatus status = SecKeyRawSign(key, padding, (const uint8_t *)CFDataGetBytePtr(input),
                                     (size_t)length, buffer, &signatureLength);
    if (status == errSecParam && ec && padding == kSecPaddingNone) {
        signatureLength = room;
        status = SecKeyRawSign(key, kSecPaddingPKCS1, (const uint8_t *)CFDataGetBytePtr(input),
                               (size_t)length, buffer, &signatureLength);
    }
    CFRelease(input);
    if (status != errSecSuccess) {
        free(buffer);
        return NULL;
    }
    CFDataRef signature = CFDataCreate(kCFAllocatorDefault, buffer, (CFIndex)signatureLength);
    free(buffer);
    return signature;
}

Boolean BACKPORT_IMPL(SecKeyVerifySignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData,
                              CFDataRef signature, CFErrorRef *error)
{
    if (!key || !algorithm || !signedData || !signature)
        return false;
    if (error)
        *error = NULL;
    if (RevenantSecurityKeyIsPortEC(key))
        return RevenantSecKeyECVerify(key, algorithm, signedData, signature, error);
    CFDictionaryRef attributes = SecKeyCopyAttributes(key);
    if (!attributes)
        return false;
    CFTypeRef type = CFDictionaryGetValue(attributes, kSecAttrKeyType);
    bool rsa = type && CFEqual(type, kSecAttrKeyTypeRSA);
    bool ec = type && CFEqual(type, kSecAttrKeyTypeECSECPrimeRandom);
    CFRelease(attributes);
    if (!rsa && !ec) {
        return false;
    }
    if (!RevenantSecurityCarries(kSecKeyOperationTypeVerify, algorithm, rsa, ec))
        return false;
    SecPadding padding = kSecPaddingNone;
    CFIndex signatureLength = CFDataGetLength(signature);
    if (CFDataGetLength(signedData) < 1 || signatureLength < 1)
        return false;
    CFDataRef input = RevenantSecurityRawInput(algorithm, rsa, signedData, &padding);
    if (!input)
        return false;
    OSStatus status = SecKeyRawVerify(key, padding,
                                      (const uint8_t *)CFDataGetBytePtr(input),
                                      (size_t)CFDataGetLength(input),
                                      (const uint8_t *)CFDataGetBytePtr(signature),
                                      (size_t)signatureLength);
    CFRelease(input);
    return status == errSecSuccess;
}

CFDataRef BACKPORT_IMPL(SecKeyCopyKeyExchangeResult)(SecKeyRef privateKey, SecKeyAlgorithm algorithm, SecKeyRef publicKey,
                                      CFDictionaryRef parameters, CFErrorRef *error)
{
    if (privateKey && RevenantSecurityKeyIsPortEC(privateKey))
        return RevenantSecKeyECExchange(privateKey, algorithm, publicKey, parameters, error);

    RevenantSecKeyFail(error, errSecParam,
                     @"the release has no elliptic key agreement: its Security exports SecKeyRawSign and SecKeyRawVerify and only the finite-field SecDH family, so a key of its keychain cannot exchange");
    return NULL;
}
