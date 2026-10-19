#import <Foundation/Foundation.h>
#import <Security/Security.h>

extern OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serializedPublic);
extern SecKeyRef SecKeyCreateFromPublicData(CFAllocatorRef allocator, CFIndex algorithmID, CFDataRef serialized);
extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);
extern CFIndex SecKeyGetAlgorithmID(SecKeyRef key);

static void charon_sec_fail(CFErrorRef *error, OSStatus status, NSString *description)
{
    if (!error)
        return;
    *error = CFErrorCreate(kCFAllocatorDefault, (__bridge CFStringRef)NSOSStatusErrorDomain, status,
                           (__bridge CFDictionaryRef)@{@"NSDescription": description});
}

static BOOL charon_sec_padding(SecKeyAlgorithm algorithm, SecPadding *padding)
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

static NSString *charon_sec_unsupported(SecKeyRef key, SecKeyAlgorithm algorithm, NSString *operation)
{
    return [NSString stringWithFormat:@"%@: algorithm not supported by the key %@",
                                      algorithm ? [NSString stringWithFormat:@"algid:%@:%@", operation, algorithm] : operation, key];
}

static const uint8_t *charon_der_value(const uint8_t *cursor, const uint8_t *end, uint8_t tag, size_t *length)
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

static size_t charon_der_integers(CFDataRef data, BOOL *starts_at_zero)
{
    const uint8_t *bytes = CFDataGetBytePtr(data);
    CFIndex count = CFDataGetLength(data);
    if (!bytes || count <= 0)
        return 0;
    size_t length = 0;
    const uint8_t *cursor = charon_der_value(bytes, bytes + count, 0x30, &length);
    if (!cursor || cursor + length != bytes + count)
        return 0;
    const uint8_t *end = cursor + length;
    size_t integers = 0;
    *starts_at_zero = NO;
    while (cursor < end) {
        size_t size = 0;
        const uint8_t *value = charon_der_value(cursor, end, 0x02, &size);
        if (!value)
            return 0;
        if (integers == 0)
            *starts_at_zero = size == 1 && value[0] == 0;
        cursor = value + size;
        integers++;
    }
    return integers;
}

static BOOL charon_is_private_representation(CFDataRef data)
{
    BOOL zero = NO;
    return charon_der_integers(data, &zero) == 9 && zero;
}

static BOOL charon_says_public(CFDictionaryRef attributes)
{
    if (!attributes)
        return NO;
    CFTypeRef keyClass = CFDictionaryGetValue(attributes, kSecAttrKeyClass);
    return keyClass != NULL && CFEqual(keyClass, kSecAttrKeyClassPublic);
}

SecKeyRef SecKeyCreateRandomKey(CFDictionaryRef parameters, CFErrorRef *error)
{
    if (!parameters) {
        charon_sec_fail(error, errSecParam, @"no parameters for key generation");
        return NULL;
    }
    SecKeyRef publicKey = NULL, privateKey = NULL;
    OSStatus status = SecKeyGeneratePair(parameters, &publicKey, &privateKey);
    if (publicKey)
        CFRelease(publicKey);
    if (status != errSecSuccess) {
        if (privateKey)
            CFRelease(privateKey);
        charon_sec_fail(error, status, [NSString stringWithFormat:@"the release's own key generation refused these parameters: %@",
                                                                  (__bridge NSDictionary *)parameters]);
        return NULL;
    }
    if (!privateKey)
        charon_sec_fail(error, errSecInternalError, @"the release's own key generation answered no private key");
    return privateKey;
}

SecKeyRef SecKeyCopyPublicKey(SecKeyRef key)
{
    if (!key)
        return NULL;
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

static CFDataRef charon_sec_transform(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef input, CFErrorRef *error,
                                      BOOL encrypting)
{
    NSString *operation = encrypting ? @"encrypt" : @"decrypt";
    if (!key || !input) {
        charon_sec_fail(error, errSecParam, [NSString stringWithFormat:@"%@ needs a key and data", operation]);
        return NULL;
    }
    SecPadding padding = kSecPaddingNone;
    if (!charon_sec_padding(algorithm, &padding)) {
        charon_sec_fail(error, errSecParam, charon_sec_unsupported(key, algorithm, operation));
        return NULL;
    }
    size_t room = SecKeyGetBlockSize(key);
    if (room == 0) {
        charon_sec_fail(error, errSecParam, charon_sec_unsupported(key, algorithm, operation));
        return NULL;
    }
    NSMutableData *output = [NSMutableData dataWithLength:room];
    size_t written = room;
    OSStatus status = encrypting
        ? SecKeyEncrypt(key, padding, CFDataGetBytePtr(input), (size_t)CFDataGetLength(input), output.mutableBytes, &written)
        : SecKeyDecrypt(key, padding, CFDataGetBytePtr(input), (size_t)CFDataGetLength(input), output.mutableBytes, &written);
    if (status != errSecSuccess) {
        charon_sec_fail(error, status, [NSString stringWithFormat:@"algid:%@:%@: the release's own %@ refused the data",
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
    return charon_sec_transform(key, algorithm, plaintext, error, YES);
}

CFDataRef SecKeyCreateDecryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef ciphertext, CFErrorRef *error)
{
    return charon_sec_transform(key, algorithm, ciphertext, error, NO);
}

CFDataRef SecKeyCopyExternalRepresentation(SecKeyRef key, CFErrorRef *error)
{
    if (!key) {
        charon_sec_fail(error, errSecParam, @"no key to export");
        return NULL;
    }
    CFDictionaryRef attributes = SecKeyCopyAttributeDictionary(key);
    CFDataRef stored = NULL;
    if (attributes) {
        CFTypeRef value = CFDictionaryGetValue(attributes, kSecValueData);
        stored = value && CFGetTypeID(value) == CFDataGetTypeID() ? (CFDataRef)value : NULL;
    }
    if (stored && charon_is_private_representation(stored)) {
        CFDataRef answer = CFDataCreateCopy(kCFAllocatorDefault, stored);
        CFRelease(attributes);
        return answer;
    }
    CFDataRef serialized = NULL;
    OSStatus status = SecKeyCopyPublicBytes(key, &serialized);
    BOOL answerable = serialized && ((stored && CFEqual(stored, serialized)) || charon_says_public(attributes));
    if (attributes)
        CFRelease(attributes);
    if (answerable)
        return serialized;
    if (serialized)
        CFRelease(serialized);
    charon_sec_fail(error, status != errSecSuccess ? status : errSecUnimplemented,
                    @"the release keeps no external representation of this key: it answers the public half only, "
                    @"and returning that for a private key would be a different key");
    return NULL;
}
