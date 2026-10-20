#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

extern bool RevenantSecurityKeyIsPortEC(SecKeyRef key);
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

CFDictionaryRef SecKeyCopyAttributes(SecKeyRef key)
{
    if (!key)
        return NULL;
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
    if (status != errSecSuccess)
        return NULL;
    return RevenantSecurityAttributesFromItemResult(found);
}

bool RevenantSecurityCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm, bool rsa, bool ec);

Boolean SecKeyIsAlgorithmSupported(SecKeyRef key, SecKeyOperationType operation, SecKeyAlgorithm algorithm)
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

bool RevenantSecurityCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm, bool rsa, bool ec)
{
    if (operation == kSecKeyOperationTypeSign || operation == kSecKeyOperationTypeVerify) {
        if (rsa) {
            return CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1)
                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256)
                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384)
                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512);
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

SecPadding RevenantSecurityPaddingFor(SecKeyAlgorithm algorithm)
{
    if (CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256) ||
        CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256))
        return kSecPaddingNone;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1))
        return kSecPaddingPKCS1SHA1;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA224))
        return kSecPaddingPKCS1SHA224;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256))
        return kSecPaddingPKCS1SHA256;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384))
        return kSecPaddingPKCS1SHA384;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512))
        return kSecPaddingPKCS1SHA512;
    return kSecPaddingNone;
}

CFDataRef SecKeyCreateSignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign,
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
    SecPadding padding = RevenantSecurityPaddingFor(algorithm);
    CFIndex length = CFDataGetLength(dataToSign);
    if (length < 0)
        return NULL;
    size_t room = RevenantSecuritySignatureRoom(key, ec, length);
    if (room == 0)
        return NULL;
    unsigned char *buffer = calloc(room, 1);
    if (!buffer)
        return NULL;
    size_t signatureLength = room;
    OSStatus status = SecKeyRawSign(key, padding, (const uint8_t *)CFDataGetBytePtr(dataToSign),
                                     (size_t)length, buffer, &signatureLength);
    if (status == errSecParam && ec && padding == kSecPaddingNone) {
        signatureLength = room;
        status = SecKeyRawSign(key, kSecPaddingPKCS1, (const uint8_t *)CFDataGetBytePtr(dataToSign),
                               (size_t)length, buffer, &signatureLength);
    }
    if (status != errSecSuccess) {
        free(buffer);
        return NULL;
    }
    CFDataRef signature = CFDataCreate(kCFAllocatorDefault, buffer, (CFIndex)signatureLength);
    free(buffer);
    return signature;
}

Boolean SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData,
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
    SecPadding padding = RevenantSecurityPaddingFor(algorithm);
    CFIndex signedLength = CFDataGetLength(signedData);
    CFIndex signatureLength = CFDataGetLength(signature);
    if (signedLength < 1 || signatureLength < 1)
        return false;
    OSStatus status = SecKeyRawVerify(key, padding,
                                      (const uint8_t *)CFDataGetBytePtr(signedData),
                                      (size_t)signedLength,
                                      (const uint8_t *)CFDataGetBytePtr(signature),
                                      (size_t)signatureLength);
    (void)status;
    return status == errSecSuccess;
}

CFDataRef SecKeyCopyKeyExchangeResult(SecKeyRef privateKey, SecKeyAlgorithm algorithm, SecKeyRef publicKey,
                                      CFDictionaryRef parameters, CFErrorRef *error)
{
    if (privateKey && RevenantSecurityKeyIsPortEC(privateKey))
        return RevenantSecKeyECExchange(privateKey, algorithm, publicKey, parameters, error);

    RevenantSecKeyFail(error, errSecParam,
                     @"the release has no elliptic key agreement: its Security exports SecKeyRawSign and SecKeyRawVerify and only the finite-field SecDH family, so a key of its keychain cannot exchange");
    return NULL;
}
