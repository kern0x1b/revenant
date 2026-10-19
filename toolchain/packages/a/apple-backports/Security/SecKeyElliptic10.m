#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <string.h>
#import <stdlib.h>
#import <CommonCrypto/CommonDigest.h>

extern CFIndex SecKeyGetAlgorithmID(SecKeyRef key);
extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);
extern OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serialized);
extern SecKeyRef SecKeyCreateFromPublicData(CFAllocatorRef allocator, CFIndex algorithmID, CFDataRef serialized);

extern int CharonCKPublicKeyES256(const uint8_t *privateKey, uint8_t *out);
extern int CharonCKDigestSignES256(const uint8_t *privateKey, const uint8_t *digest, uint8_t *der, size_t capacity);
extern int CharonCKDigestVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *digest,
                                    const uint8_t *der, size_t derLength);
extern int CharonCKSharedSecretES256(const uint8_t *privateKey, const uint8_t *peerPublic, size_t publicLength,
                                    uint8_t *secret);
static void charon_elliptic_sha256(const uint8_t *message, size_t length, uint8_t digest[32])
{
    CC_SHA256(message, (CC_LONG)length, digest);
}

void CharonSecKeyFail(CFErrorRef *error, OSStatus status, NSString *description)
{
    if (!error) {
        return;
    }
    *error = CFErrorCreate(kCFAllocatorDefault, (__bridge CFStringRef)NSOSStatusErrorDomain, status,
                           (__bridge CFDictionaryRef)@{@"NSDescription": description});
}

#define kCharonSecKeyMarker "CharonSecKeyScalar"

bool CharonSecurityKeyIsPortEC(SecKeyRef key)
{
    CFDictionaryRef attributes = SecKeyCopyAttributeDictionary(key);
    if (!attributes) {
        return NO;
    }
    CFTypeRef marker = CFDictionaryGetValue(attributes, CFSTR(kCharonSecKeyMarker));
    BOOL ours = marker != NULL;
    CFRelease(attributes);
    return ours;
}

static BOOL charon_elliptic_port_scalar(SecKeyRef key, uint8_t scalar[32])
{
    CFDictionaryRef attributes = SecKeyCopyAttributeDictionary(key);
    if (!attributes) {
        return NO;
    }
    CFTypeRef stored = CFDictionaryGetValue(attributes, kSecValueData);
    BOOL whole = stored != NULL && CFGetTypeID(stored) == CFDataGetTypeID() && CFDataGetLength((CFDataRef)stored) == 32;
    if (whole) {
        memcpy(scalar, CFDataGetBytePtr((CFDataRef)stored), 32);
    }
    CFRelease(attributes);
    return whole;
}

static const uint8_t *charon_elliptic_value(const uint8_t *cursor, const uint8_t *end, uint8_t tag, size_t *length)
{
    if (cursor >= end || *cursor++ != tag || cursor >= end) {
        return NULL;
    }
    size_t value = *cursor++;
    if (value & 0x80) {
        size_t count = value & 0x7F;
        if (count == 0 || count > 4 || (size_t)(end - cursor) < count) {
            return NULL;
        }
        value = 0;
        while (count-- > 0) {
            value = (value << 8) | *cursor++;
        }
    }
    if ((size_t)(end - cursor) < value) {
        return NULL;
    }
    *length = value;
    return cursor;
}

static BOOL charon_elliptic_point(SecKeyRef key, uint8_t point[65])
{
    CFDataRef serialized = NULL;
    if (SecKeyCopyPublicBytes(key, &serialized) != errSecSuccess || !serialized) {
        if (serialized) {
            CFRelease(serialized);
        }
        return NO;
    }
    const uint8_t *bytes = CFDataGetBytePtr(serialized);
    const uint8_t *end = bytes + CFDataGetLength(serialized);
    size_t length = 0;
    const uint8_t *content = charon_elliptic_value(bytes, end, 0x30, &length);
    const uint8_t *innerEnd = content ? content + length : NULL;
    size_t algorithm = 0;
    const uint8_t *algorithmValue = content ? charon_elliptic_value(content, innerEnd, 0x30, &algorithm) : NULL;
    size_t bits = 0;
    const uint8_t *bitString = algorithmValue ? charon_elliptic_value(algorithmValue + algorithm, innerEnd, 0x03, &bits) : NULL;
    BOOL whole = bitString && bits == 66 && bitString[0] == 0x00 && bitString[1] == 0x04;
    if (whole) {
        memcpy(point, bitString + 1, 65);
    }
    CFRelease(serialized);
    return whole;
}

static const uint8_t uECCP256Order[32] = {0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
                                          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                                          0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
                                          0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51};

static void charon_elliptic_order_half(uint8_t half[32])
{
    memset(half, 0, 32);
    for (int index = 0; index < 31; index++) {
        half[index] = (uint8_t)((uECCP256Order[index] >> 1) | ((uECCP256Order[index + 1] & 1u) << 7));
    }
    half[31] = (uint8_t)(uECCP256Order[31] >> 1);
}

static void charon_elliptic_order_minus(uint8_t out[32], const uint8_t value[32])
{
    unsigned borrow = 0;
    for (int index = 31; index >= 0; index--) {
        unsigned difference = (unsigned)uECCP256Order[index] - (unsigned)value[index] - borrow;
        out[index] = (uint8_t)difference;
        borrow = (difference >> 8) & 1u;
    }
}

static int charon_elliptic_der_integer(uint8_t *out, const uint8_t value[32])
{
    int first = 0;
    while (first < 31 && value[first] == 0) {
        first++;
    }
    int length = 32 - first;
    if (value[first] & 0x80) {
        out[0] = 0x02;
        out[1] = (uint8_t)(length + 1);
        out[2] = 0x00;
        memcpy(out + 3, value + first, (size_t)length);
        return length + 3;
    }
    out[0] = 0x02;
    out[1] = (uint8_t)length;
    memcpy(out + 2, value + first, (size_t)length);
    return length + 2;
}

static CFDataRef charon_elliptic_der(CFDataRef raw, CFErrorRef *error)
{
    if (!raw) {
        CharonSecKeyFail(error, errSecInternalError, @"the release's own signing handed back nothing");
        return NULL;
    }
    const uint8_t *bytes = CFDataGetBytePtr(raw);
    size_t length = (size_t)CFDataGetLength(raw);
    if (length > 2 && bytes[0] == 0x30 && bytes[1] == length - 2) {
        return (CFDataRef)CFRetain(raw);
    }
    if (length != 64) {
        CharonSecKeyFail(error, errSecInternalError,
                             [NSString stringWithFormat:@"the release's own signing answered %lu bytes for a P-256 signature, which is neither the two 32 byte halves nor their DER",
                                                      (unsigned long)length]);
        return NULL;
    }
    uint8_t halves[64];
    memcpy(halves, bytes, 64);
    uint8_t half[32];
    charon_elliptic_order_half(half);
    if (memcmp(halves + 32, half, 32) > 0) {
        charon_elliptic_order_minus(halves + 32, halves + 32);
    }
    uint8_t der[72];
    size_t offset = 0;
    der[offset++] = 0x30;
    der[offset++] = 0;
    size_t content = offset;
    offset += (size_t)charon_elliptic_der_integer(der + offset, halves);
    offset += (size_t)charon_elliptic_der_integer(der + offset, halves + 32);
    der[1] = (uint8_t)(offset - content);
    return CFDataCreate(kCFAllocatorDefault, der, (CFIndex)offset);
}

static BOOL charon_elliptic_exchange(SecKeyAlgorithm algorithm, BOOL *hashed)
{
    if (!algorithm) {
        return NO;
    }
    NSString *name = (__bridge NSString *)algorithm;
    if (![name hasPrefix:@"ECDH"]) {
        return NO;
    }
    *hashed = [name hasSuffix:@"SHA1"] || [name hasSuffix:@"SHA224"] || [name hasSuffix:@"SHA256"]
        || [name hasSuffix:@"SHA384"] || [name hasSuffix:@"SHA512"];
    return YES;
}

bool CharonSecKeyECCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm)
{
    if (!operation || !algorithm) {
        return false;
    }
    if (CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256) ||
        CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256)) {
        return operation == kSecKeyOperationTypeSign || operation == kSecKeyOperationTypeVerify;
    }
    BOOL hashed = NO;
    if (!charon_elliptic_exchange(algorithm, &hashed)) {
        return false;
    }
    return operation == kSecKeyOperationTypeKeyExchange;
}

CFDataRef CharonSecKeyECSign(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef data, CFErrorRef *error)
{
    if (!key || !data) {
        CharonSecKeyFail(error, errSecParam, @"a signature needs a key and the data to sign");
        return NULL;
    }
    BOOL digest = CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256)
        || CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256);
    if (!digest) {
        CharonSecKeyFail(error, errSecParam,
                             [NSString stringWithFormat:@"algid:sign:%@: this port signs P-256 with SHA-256 and nothing else", algorithm]);
        return NULL;
    }
    BOOL ofMessage = CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256);
    uint8_t hashed[32];
    if (ofMessage) {
        charon_elliptic_sha256(CFDataGetBytePtr(data), (size_t)CFDataGetLength(data), hashed);
    } else {
        if (CFDataGetLength(data) != 32) {
            CharonSecKeyFail(error, errSecParam,
                                 [NSString stringWithFormat:@"a P-256 signature is of a 32 byte digest and %ld were given", (long)CFDataGetLength(data)]);
            return NULL;
        }
        memcpy(hashed, CFDataGetBytePtr(data), 32);
    }
    if (!CharonSecurityKeyIsPortEC(key)) {
        CharonSecKeyFail(error, errSecParam, @"this is the curve's own signing, and the key is not one of the port's");
        return NULL;
    }
    uint8_t scalar[32];
    if (!charon_elliptic_port_scalar(key, scalar)) {
        CharonSecKeyFail(error, errSecParam, @"this key of the port's keeps no private scalar to sign with");
        return NULL;
    }
    uint8_t der[72];
    int written = CharonCKDigestSignES256(scalar, hashed, der, sizeof der);
    if (written <= 0) {
        CharonSecKeyFail(error, errSecInternalError, @"micro-ecc made no signature of the digest");
        return NULL;
    }
    return CFDataCreate(kCFAllocatorDefault, der, (CFIndex)written);
}

Boolean CharonSecKeyECVerify(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef data, CFDataRef signature, CFErrorRef *error)
{
    if (!key || !data || !signature) {
        CharonSecKeyFail(error, errSecParam, @"a verification needs a key, the data and the signature");
        return false;
    }
    BOOL digest = CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256)
        || CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256);
    if (!digest) {
        CharonSecKeyFail(error, errSecParam,
                             [NSString stringWithFormat:@"algid:verify:%@: this port verifies P-256 with SHA-256 and nothing else", algorithm]);
        return false;
    }
    if (!CharonSecurityKeyIsPortEC(key)) {
        CharonSecKeyFail(error, errSecParam, @"this is the curve's own verification, and the key is not one of the port's");
        return false;
    }
    CFIndex length = CFDataGetLength(data);
    uint8_t hashed[32];
    if (CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256)) {
        charon_elliptic_sha256(CFDataGetBytePtr(data), (size_t)length, hashed);
    } else {
        if (length != 32) {
            CharonSecKeyFail(error, errSecParam,
                                 [NSString stringWithFormat:@"a P-256 signature is of a 32 byte digest and %ld were given", (long)length]);
            return false;
        }
        memcpy(hashed, CFDataGetBytePtr(data), 32);
    }
    uint8_t point[65];
    if (!charon_elliptic_point(key, point)) {
        CharonSecKeyFail(error, errSecParam, @"this key publishes no uncompressed public point to verify with");
        return false;
    }
    return CharonCKDigestVerifyES256(point, sizeof point, hashed, CFDataGetBytePtr(signature),
                                     (size_t)CFDataGetLength(signature)) != 0;
}

CFDataRef CharonSecKeyECExchange(SecKeyRef privateKey, SecKeyAlgorithm algorithm, SecKeyRef publicKey,
                                  CFDictionaryRef options, CFErrorRef *error)
{
    (void)options;
    if (!privateKey || !publicKey) {
        CharonSecKeyFail(error, errSecParam, @"an exchange needs both keys");
        return NULL;
    }
    BOOL hashed = NO;
    if (!charon_elliptic_exchange(algorithm, &hashed)) {
        CharonSecKeyFail(error, errSecParam, [NSString stringWithFormat:@"algid:exchange:%@: this port exchanges over P-256 and nothing else", algorithm]);
        return NULL;
    }
    if (!CharonSecurityKeyIsPortEC(privateKey)) {
        CharonSecKeyFail(error, errSecParam,
                             @"the release has no elliptic key agreement: its Security exports SecKeyRawSign and SecKeyRawVerify and only the finite-field SecDH family, so a key of its keychain cannot exchange");
        return NULL;
    }
    uint8_t scalar[32];
    if (!charon_elliptic_port_scalar(privateKey, scalar)) {
        CharonSecKeyFail(error, errSecParam, @"this key of the port's keeps no private scalar to exchange with");
        return NULL;
    }
    uint8_t peer[65];
    if (!charon_elliptic_point(publicKey, peer)) {
        CharonSecKeyFail(error, errSecParam, @"the peer's key publishes no uncompressed public point to exchange with");
        return NULL;
    }
    uint8_t secret[32];
    if (!CharonCKSharedSecretES256(scalar, peer, sizeof peer, secret)) {
        CharonSecKeyFail(error, errSecInternalError, @"micro-ecc made no shared secret of the two keys");
        return NULL;
    }
    if (!hashed) {
        return CFDataCreate(kCFAllocatorDefault, secret, (CFIndex)sizeof secret);
    }
    uint8_t digest[32];
    charon_elliptic_sha256(secret, sizeof secret, digest);
    return CFDataCreate(kCFAllocatorDefault, digest, (CFIndex)sizeof digest);
}
