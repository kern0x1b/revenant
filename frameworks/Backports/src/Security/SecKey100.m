#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "RevenantSecureEnclave.h"

extern OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serializedPublic);
extern SecKeyRef SecKeyCreateFromPublicData(CFAllocatorRef allocator, CFIndex algorithmID, CFDataRef serialized);
extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);
extern CFIndex SecKeyGetAlgorithmID(SecKeyRef key);
extern SecKeyRef SecKeyCreateRSAPublicKey(CFAllocatorRef allocator, const uint8_t *keyData, CFIndex keyDataLength, uint32_t encoding);
extern SecKeyRef SecKeyCreateRSAPrivateKey(CFAllocatorRef allocator, const uint8_t *keyData, CFIndex keyDataLength, uint32_t encoding);
extern int RevenantCKValidPublicKeyES256(const uint8_t *publicKey, size_t publicLength);

static void revenant_sec_fail(CFErrorRef *error, OSStatus status, NSString *description)
{
    if (!error)
        return;
    *error = CFErrorCreate(kCFAllocatorDefault, (__bridge CFStringRef)NSOSStatusErrorDomain, status,
                           (__bridge CFDictionaryRef)@{@"NSDescription": description});
}

static BOOL revenant_sec_padding(SecKeyAlgorithm algorithm, SecPadding *padding)
{
    if (!algorithm)
        return NO;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSAEncryptionRaw)) {
        *padding = kSecPaddingNone;
        return YES;
    }
    if (CFEqual(algorithm, kSecKeyAlgorithmRSAEncryptionPKCS1)) {
        *padding = kSecPaddingPKCS1;
        return YES;
    }
    if (CFEqual(algorithm, kSecKeyAlgorithmRSAEncryptionOAEPSHA1)) {
        *padding = kSecPaddingOAEP;
        return YES;
    }
    return NO;
}

static NSString *revenant_sec_unsupported(SecKeyRef key, SecKeyAlgorithm algorithm, NSString *operation)
{
    return [NSString stringWithFormat:@"%@: algorithm not supported by the key %@",
                                      algorithm ? [NSString stringWithFormat:@"algid:%@:%@", operation, algorithm] : operation, key];
}

static const uint8_t *revenant_der_value(const uint8_t *cursor, const uint8_t *end, uint8_t tag, size_t *length)
{
    if (cursor >= end || *cursor++ != tag || cursor >= end)
        return NULL;
    size_t value = *cursor++;
    if (value & 0x80) {
        size_t count = value & 0x7F;
        if (count == 0 || count > 4 || (size_t)(end - cursor) < count)
            return NULL;
        value = 0;
        while (count-- > 0)
            value = (value << 8) | *cursor++;
    }
    if ((size_t)(end - cursor) < value)
        return NULL;
    *length = value;
    return cursor;
}

static size_t revenant_der_integers(const uint8_t *bytes, CFIndex count, BOOL *starts_at_zero, CFIndex *whole)
{
    if (!bytes || count <= 0)
        return 0;
    size_t length = 0;
    const uint8_t *cursor = revenant_der_value(bytes, bytes + count, 0x30, &length);
    if (!cursor)
        return 0;
    const uint8_t *end = cursor + length;
    *whole = end - bytes;
    size_t integers = 0;
    *starts_at_zero = NO;
    while (cursor < end) {
        size_t size = 0;
        const uint8_t *value = revenant_der_value(cursor, end, 0x02, &size);
        if (!value)
            return 0;
        if (integers == 0)
            *starts_at_zero = size == 1 && value[0] == 0;
        cursor = value + size;
        integers++;
    }
    return integers;
}

static BOOL revenant_is_private_representation(CFDataRef data)
{
    BOOL zero = NO;
    CFIndex whole = 0;
    return revenant_der_integers(CFDataGetBytePtr(data), CFDataGetLength(data), &zero, &whole) == 9 && zero
        && whole == CFDataGetLength(data);
}

static BOOL revenant_says_public(CFDictionaryRef attributes)
{
    if (!attributes)
        return NO;
    CFTypeRef keyClass = CFDictionaryGetValue(attributes, kSecAttrKeyClass);
    return keyClass != NULL && CFEqual(keyClass, kSecAttrKeyClassPublic);
}

SecKeyRef BACKPORT_IMPL(SecKeyCreateRandomKey)(CFDictionaryRef parameters, CFErrorRef *error)
{
    if (!parameters) {
        revenant_sec_fail(error, errSecParam, @"no parameters for key generation");
        return NULL;
    }
    CFTypeRef token = CFDictionaryGetValue(parameters, kSecAttrTokenID);
    if (token && CFEqual(token, kSecAttrTokenIDSecureEnclave) && !RevenantSecItemSystemEnforcesAccessControl())
        return RevenantSecureEnclaveKeyCreateRandom(parameters, error);
    SecKeyRef publicKey = NULL, privateKey = NULL;
    OSStatus status = SecKeyGeneratePair(parameters, &publicKey, &privateKey);
    if (publicKey)
        CFRelease(publicKey);
    if (status != errSecSuccess) {
        if (privateKey)
            CFRelease(privateKey);
        revenant_sec_fail(error, status, [NSString stringWithFormat:@"the release's own key generation refused these parameters: %@",
                                                                  (__bridge NSDictionary *)parameters]);
        return NULL;
    }
    if (!privateKey)
        revenant_sec_fail(error, errSecInternalError, @"the release's own key generation answered no private key");
    return privateKey;
}

SecKeyRef BACKPORT_IMPL(SecKeyCopyPublicKey)(SecKeyRef key)
{
    if (!key)
        return NULL;
    if (RevenantSecureEnclaveKeyIs(key))
        return RevenantSecureEnclaveKeyCopyPublic(key);
    CFDataRef serialized = NULL;
    if (SecKeyCopyPublicBytes(key, &serialized) != errSecSuccess || !serialized) {
        if (serialized)
            CFRelease(serialized);
        return NULL;
    }
    SecKeyRef found = SecKeyCreateFromPublicData(kCFAllocatorDefault, SecKeyGetAlgorithmID(key), serialized);
    CFRelease(serialized);
    return found;
}

static CFDataRef revenant_sec_transform(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef input, CFErrorRef *error,
                                      BOOL encrypting)
{
    NSString *operation = encrypting ? @"encrypt" : @"decrypt";
    if (!key || !input) {
        revenant_sec_fail(error, errSecParam, [NSString stringWithFormat:@"%@ needs a key and data", operation]);
        return NULL;
    }
    if (RevenantSecureEnclaveKeyIs(key)) {
        revenant_sec_fail(error, errSecUnimplemented,
                          [NSString stringWithFormat:@"%@: the Secure Enclave emulation's P-256 keys sign and exchange only", operation]);
        return NULL;
    }
    SecPadding padding = kSecPaddingNone;
    if (!revenant_sec_padding(algorithm, &padding)) {
        revenant_sec_fail(error, errSecParam, revenant_sec_unsupported(key, algorithm, operation));
        return NULL;
    }
    size_t room = SecKeyGetBlockSize(key);
    if (room == 0) {
        revenant_sec_fail(error, errSecParam, revenant_sec_unsupported(key, algorithm, operation));
        return NULL;
    }
    NSMutableData *output = [NSMutableData dataWithLength:room];
    size_t written = room;
    OSStatus status = encrypting
        ? SecKeyEncrypt(key, padding, CFDataGetBytePtr(input), (size_t)CFDataGetLength(input), output.mutableBytes, &written)
        : SecKeyDecrypt(key, padding, CFDataGetBytePtr(input), (size_t)CFDataGetLength(input), output.mutableBytes, &written);
    if (status != errSecSuccess) {
        revenant_sec_fail(error, status, [NSString stringWithFormat:@"algid:%@:%@: the release's own %@ refused the data",
                                                                  operation, algorithm, operation]);
        return NULL;
    }
    if (written > room)
        written = room;
    output.length = written;
    return (CFDataRef)CFBridgingRetain(output);
}

CFDataRef BACKPORT_IMPL(SecKeyCreateEncryptedData)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef plaintext, CFErrorRef *error)
{
    return revenant_sec_transform(key, algorithm, plaintext, error, YES);
}

CFDataRef BACKPORT_IMPL(SecKeyCreateDecryptedData)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef ciphertext, CFErrorRef *error)
{
    return revenant_sec_transform(key, algorithm, ciphertext, error, NO);
}

static CFDataRef revenant_sec_stored_data(SecKeyRef key)
{
    CFMutableDictionaryRef byKey = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(byKey, kSecValueRef, key);
    CFDictionarySetValue(byKey, kSecReturnPersistentRef, kCFBooleanTrue);
    CFTypeRef persistent = NULL;
    OSStatus status = SecItemCopyMatching(byKey, &persistent);
    CFRelease(byKey);
    if (status != errSecSuccess || !persistent)
        return NULL;
    CFMutableDictionaryRef byReference = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(byReference, kSecValuePersistentRef, persistent);
    CFDictionarySetValue(byReference, kSecReturnData, kCFBooleanTrue);
    CFTypeRef data = NULL;
    status = SecItemCopyMatching(byReference, &data);
    CFRelease(byReference);
    CFRelease(persistent);
    if (status != errSecSuccess || !data)
        return NULL;
    if (CFGetTypeID(data) != CFDataGetTypeID()) {
        CFRelease(data);
        return NULL;
    }
    return (CFDataRef)data;
}

CFDataRef BACKPORT_IMPL(SecKeyCopyExternalRepresentation)(SecKeyRef key, CFErrorRef *error)
{
    if (!key) {
        revenant_sec_fail(error, errSecParam, @"no key to export");
        return NULL;
    }
    if (RevenantSecureEnclaveKeyIs(key)) {
        uint8_t exported[97];
        if (RevenantSecureEnclaveKeyPoint(key, exported) != errSecSuccess) {
            revenant_sec_fail(error, errSecInternalError, @"the emulated key keeps no public point");
            return NULL;
        }
        if (!RevenantSecureEnclaveKeyIsPrivate(key))
            return CFDataCreate(kCFAllocatorDefault, exported, 65);
        if (!RevenantSecureEnclaveKeyIsImported(key)) {
            revenant_sec_fail(error, errSecUnimplemented, @"export not implemented for key");
            return NULL;
        }
        OSStatus status = RevenantSecureEnclaveKeyScalar(key, exported + 65);
        if (status != errSecSuccess) {
            revenant_sec_fail(error, status, @"the imported key keeps no private scalar to export");
            return NULL;
        }
        CFDataRef whole = CFDataCreate(kCFAllocatorDefault, exported, sizeof exported);
        memset(exported + 65, 0, 32);
        return whole;
    }
    CFDataRef stored = revenant_sec_stored_data(key);
    if (stored && revenant_is_private_representation(stored))
        return stored;
    CFDictionaryRef attributes = SecKeyCopyAttributeDictionary(key);
    CFDataRef serialized = NULL;
    OSStatus status = SecKeyCopyPublicBytes(key, &serialized);
    BOOL answerable = serialized && ((stored && CFEqual(stored, serialized)) || revenant_says_public(attributes));
    if (attributes)
        CFRelease(attributes);
    if (stored)
        CFRelease(stored);
    if (answerable)
        return serialized;
    if (serialized)
        CFRelease(serialized);
    revenant_sec_fail(error, status != errSecSuccess ? status : errSecUnimplemented,
                    @"the release keeps no external representation of this key: it answers the public half only, "
                    @"and returning that for a private key would be a different key");
    return NULL;
}

static const uint8_t revenant_rsa_encryption_oid[] = {0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01};
static const uint32_t revenant_rsa_encoding_pkcs1 = 1;

static BOOL revenant_rsa_public_slice(const uint8_t *bytes, CFIndex count, const uint8_t **slice, CFIndex *length)
{
    BOOL zero = NO;
    CFIndex whole = 0;
    if (revenant_der_integers(bytes, count, &zero, &whole) == 2) {
        *slice = bytes;
        *length = whole;
        return YES;
    }
    size_t outer = 0;
    const uint8_t *cursor = revenant_der_value(bytes, bytes + count, 0x30, &outer);
    if (!cursor)
        return NO;
    const uint8_t *end = cursor + outer;
    size_t algorithm = 0;
    const uint8_t *algorithmValue = revenant_der_value(cursor, end, 0x30, &algorithm);
    if (!algorithmValue)
        return NO;
    size_t oid = 0;
    const uint8_t *oidValue = revenant_der_value(algorithmValue, algorithmValue + algorithm, 0x06, &oid);
    if (!oidValue || oid != sizeof revenant_rsa_encryption_oid || memcmp(oidValue, revenant_rsa_encryption_oid, oid) != 0)
        return NO;
    size_t bits = 0;
    const uint8_t *bitValue = revenant_der_value(algorithmValue + algorithm, end, 0x03, &bits);
    if (!bitValue || bits < 1 || bitValue[0] != 0)
        return NO;
    if (revenant_der_integers(bitValue + 1, (CFIndex)bits - 1, &zero, &whole) != 2)
        return NO;
    *slice = bitValue + 1;
    *length = whole;
    return YES;
}

static BOOL revenant_ec_point(const uint8_t *bytes, uint8_t point[65])
{
    memcpy(point, bytes, 65);
    if (point[0] == 0x06 || point[0] == 0x07) {
        if ((point[0] & 1) != (point[64] & 1))
            return NO;
        point[0] = 0x04;
    }
    return point[0] == 0x04 && RevenantCKValidPublicKeyES256(point, 65) != 0;
}

SecKeyRef BACKPORT_IMPL(SecKeyCreateWithData)(CFDataRef keyData, CFDictionaryRef attributes, CFErrorRef *error)
{
    if (!keyData || !attributes) {
        revenant_sec_fail(error, errSecParam, @"a key needs its data and its attributes");
        return NULL;
    }
    CFTypeRef type = CFDictionaryGetValue(attributes, kSecAttrKeyType);
    CFTypeRef keyClass = CFDictionaryGetValue(attributes, kSecAttrKeyClass);
    if (!type || !keyClass) {
        revenant_sec_fail(error, errSecParam, @"the attributes name no key type or no key class");
        return NULL;
    }
    if (CFEqual(keyClass, kSecAttrKeyClassSymmetric)) {
        revenant_sec_fail(error, errSecUnimplemented, @"symmetric keys are not made from data");
        return NULL;
    }
    BOOL isPublic = CFEqual(keyClass, kSecAttrKeyClassPublic);
    if (!isPublic && !CFEqual(keyClass, kSecAttrKeyClassPrivate)) {
        revenant_sec_fail(error, errSecParam, @"the key class is neither public nor private");
        return NULL;
    }
    const uint8_t *bytes = CFDataGetBytePtr(keyData);
    CFIndex count = CFDataGetLength(keyData);
    if (CFEqual(type, kSecAttrKeyTypeRSA)) {
        if (isPublic) {
            const uint8_t *slice = NULL;
            CFIndex length = 0;
            if (!revenant_rsa_public_slice(bytes, count, &slice, &length)) {
                revenant_sec_fail(error, errSecParam, @"the data is not a PKCS#1 RSA public key");
                return NULL;
            }
            SecKeyRef key = SecKeyCreateRSAPublicKey(kCFAllocatorDefault, slice, length, revenant_rsa_encoding_pkcs1);
            if (!key)
                revenant_sec_fail(error, errSecParam, @"the release's Security refused the RSA public key data");
            return key;
        }
        BOOL zero = NO;
        CFIndex whole = 0;
        if (revenant_der_integers(bytes, count, &zero, &whole) != 9 || !zero) {
            revenant_sec_fail(error, errSecParam, @"the data is not a PKCS#1 RSA private key");
            return NULL;
        }
        SecKeyRef key = SecKeyCreateRSAPrivateKey(kCFAllocatorDefault, bytes, whole, revenant_rsa_encoding_pkcs1);
        if (!key)
            revenant_sec_fail(error, errSecParam, @"the release's Security refused the RSA private key data");
        return key;
    }
    if (CFEqual(type, kSecAttrKeyTypeECSECPrimeRandom)) {
        uint8_t point[65];
        if (count != (isPublic ? 65 : 97) || !revenant_ec_point(bytes, point)) {
            revenant_sec_fail(error, errSecParam, @"the data is not an ANSI X9.63 P-256 key of this class");
            return NULL;
        }
        SecKeyRef key = RevenantSecureEnclaveKeyCreateImported(point, isPublic ? NULL : bytes + 65);
        if (!key)
            revenant_sec_fail(error, errSecInternalError, @"the release could not make the key object");
        return key;
    }
    revenant_sec_fail(error, errSecParam, @"only RSA and P-256 keys are made from data");
    return NULL;
}
