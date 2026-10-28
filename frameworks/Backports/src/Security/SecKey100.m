#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "RevenantSecureEnclave.h"

extern OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serializedPublic);
extern SecKeyRef SecKeyCreateFromPublicData(CFAllocatorRef allocator, CFIndex algorithmID, CFDataRef serialized);
extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);
extern CFIndex SecKeyGetAlgorithmID(SecKeyRef key);

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

static size_t revenant_der_integers(CFDataRef data, BOOL *starts_at_zero)
{
    const uint8_t *bytes = CFDataGetBytePtr(data);
    CFIndex count = CFDataGetLength(data);
    if (!bytes || count <= 0)
        return 0;
    size_t length = 0;
    const uint8_t *cursor = revenant_der_value(bytes, bytes + count, 0x30, &length);
    if (!cursor || cursor + length != bytes + count)
        return 0;
    const uint8_t *end = cursor + length;
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
    return revenant_der_integers(data, &zero) == 9 && zero;
}

static BOOL revenant_says_public(CFDictionaryRef attributes)
{
    if (!attributes)
        return NO;
    CFTypeRef keyClass = CFDictionaryGetValue(attributes, kSecAttrKeyClass);
    return keyClass != NULL && CFEqual(keyClass, kSecAttrKeyClassPublic);
}

SecKeyRef SecKeyCreateRandomKey(CFDictionaryRef parameters, CFErrorRef *error)
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

SecKeyRef SecKeyCopyPublicKey(SecKeyRef key)
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

CFDataRef SecKeyCreateEncryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef plaintext, CFErrorRef *error)
{
    return revenant_sec_transform(key, algorithm, plaintext, error, YES);
}

CFDataRef SecKeyCreateDecryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef ciphertext, CFErrorRef *error)
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

CFDataRef SecKeyCopyExternalRepresentation(SecKeyRef key, CFErrorRef *error)
{
    if (!key) {
        revenant_sec_fail(error, errSecParam, @"no key to export");
        return NULL;
    }
    if (RevenantSecureEnclaveKeyIs(key)) {
        if (RevenantSecureEnclaveKeyIsPrivate(key)) {
            revenant_sec_fail(error, errSecUnimplemented, @"export not implemented for key");
            return NULL;
        }
        uint8_t point[65];
        if (RevenantSecureEnclaveKeyPoint(key, point) != errSecSuccess) {
            revenant_sec_fail(error, errSecInternalError, @"the emulated key keeps no public point");
            return NULL;
        }
        return CFDataCreate(kCFAllocatorDefault, point, sizeof point);
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
