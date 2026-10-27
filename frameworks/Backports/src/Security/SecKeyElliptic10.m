#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <string.h>
#import <stdlib.h>
#import <CommonCrypto/CommonDigest.h>
#import "RevenantSecureEnclave.h"

extern CFIndex SecKeyGetAlgorithmID(SecKeyRef key);
extern OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serialized);
extern SecKeyRef SecKeyCreateFromPublicData(CFAllocatorRef allocator, CFIndex algorithmID, CFDataRef serialized);
extern void RevenantSecKeyFail(CFErrorRef *error, OSStatus status, NSString *description);

extern int RevenantCKPublicKeyES256(const uint8_t *privateKey, uint8_t *out);
extern int RevenantCKDigestSignES256(const uint8_t *privateKey, const uint8_t *digest, uint8_t *der, size_t capacity);
extern int RevenantCKDigestVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *digest,
                                    const uint8_t *der, size_t derLength);
extern int RevenantCKSharedSecretES256(const uint8_t *privateKey, const uint8_t *peerPublic, size_t publicLength,
                                    uint8_t *secret);
static void revenant_elliptic_sha256(const uint8_t *message, size_t length, uint8_t digest[32])
{
    CC_SHA256(message, (CC_LONG)length, digest);
}

bool RevenantSecurityKeyIsPortEC(SecKeyRef key)
{
    return RevenantSecureEnclaveKeyIs(key);
}

static OSStatus revenant_elliptic_port_scalar(SecKeyRef key, uint8_t scalar[32])
{
    return RevenantSecureEnclaveKeyScalar(key, scalar);
}

static const uint8_t *revenant_elliptic_value(const uint8_t *cursor, const uint8_t *end, uint8_t tag, size_t *length)
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

static BOOL revenant_elliptic_point(SecKeyRef key, uint8_t point[65])
{
    if (RevenantSecureEnclaveKeyIs(key)) {
        return RevenantSecureEnclaveKeyPoint(key, point) == errSecSuccess;
    }
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
    const uint8_t *content = revenant_elliptic_value(bytes, end, 0x30, &length);
    const uint8_t *innerEnd = content ? content + length : NULL;
    size_t algorithm = 0;
    const uint8_t *algorithmValue = content ? revenant_elliptic_value(content, innerEnd, 0x30, &algorithm) : NULL;
    size_t bits = 0;
    const uint8_t *bitString = algorithmValue ? revenant_elliptic_value(algorithmValue + algorithm, innerEnd, 0x03, &bits) : NULL;
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

static void revenant_elliptic_order_half(uint8_t half[32])
{
    memset(half, 0, 32);
    for (int index = 0; index < 31; index++) {
        half[index] = (uint8_t)((uECCP256Order[index] >> 1) | ((uECCP256Order[index + 1] & 1u) << 7));
    }
    half[31] = (uint8_t)(uECCP256Order[31] >> 1);
}

static void revenant_elliptic_order_minus(uint8_t out[32], const uint8_t value[32])
{
    unsigned borrow = 0;
    for (int index = 31; index >= 0; index--) {
        unsigned difference = (unsigned)uECCP256Order[index] - (unsigned)value[index] - borrow;
        out[index] = (uint8_t)difference;
        borrow = (difference >> 8) & 1u;
    }
}

static int revenant_elliptic_der_integer(uint8_t *out, const uint8_t value[32])
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

static CFDataRef revenant_elliptic_der(CFDataRef raw, CFErrorRef *error)
{
    if (!raw) {
        RevenantSecKeyFail(error, errSecInternalError, @"the release's own signing handed back nothing");
        return NULL;
    }
    const uint8_t *bytes = CFDataGetBytePtr(raw);
    size_t length = (size_t)CFDataGetLength(raw);
    if (length > 2 && bytes[0] == 0x30 && bytes[1] == length - 2) {
        return (CFDataRef)CFRetain(raw);
    }
    if (length != 64) {
        RevenantSecKeyFail(error, errSecInternalError,
                             [NSString stringWithFormat:@"the release's own signing answered %lu bytes for a P-256 signature, which is neither the two 32 byte halves nor their DER",
                                                      (unsigned long)length]);
        return NULL;
    }
    uint8_t halves[64];
    memcpy(halves, bytes, 64);
    uint8_t half[32];
    revenant_elliptic_order_half(half);
    if (memcmp(halves + 32, half, 32) > 0) {
        revenant_elliptic_order_minus(halves + 32, halves + 32);
    }
    uint8_t der[72];
    size_t offset = 0;
    der[offset++] = 0x30;
    der[offset++] = 0;
    size_t content = offset;
    offset += (size_t)revenant_elliptic_der_integer(der + offset, halves);
    offset += (size_t)revenant_elliptic_der_integer(der + offset, halves + 32);
    der[1] = (uint8_t)(offset - content);
    return CFDataCreate(kCFAllocatorDefault, der, (CFIndex)offset);
}

static BOOL revenant_elliptic_exchange(SecKeyAlgorithm algorithm)
{
    if (!algorithm) {
        return NO;
    }
    return CFEqual(algorithm, kSecKeyAlgorithmECDHKeyExchangeStandard) || CFEqual(algorithm, kSecKeyAlgorithmECDHKeyExchangeCofactor);
}

bool RevenantSecKeyECCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm)
{
    if (!operation || !algorithm) {
        return false;
    }
    if (CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256) ||
        CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256)) {
        return operation == kSecKeyOperationTypeSign || operation == kSecKeyOperationTypeVerify;
    }
    if (!revenant_elliptic_exchange(algorithm)) {
        return false;
    }
    return operation == kSecKeyOperationTypeKeyExchange;
}

CFDataRef RevenantSecKeyECSign(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef data, CFErrorRef *error)
{
    if (!key || !data) {
        RevenantSecKeyFail(error, errSecParam, @"a signature needs a key and the data to sign");
        return NULL;
    }
    BOOL digest = CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256)
        || CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256);
    if (!digest) {
        RevenantSecKeyFail(error, errSecParam,
                             [NSString stringWithFormat:@"algid:sign:%@: this port signs P-256 with SHA-256 and nothing else", algorithm]);
        return NULL;
    }
    BOOL ofMessage = CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256);
    uint8_t hashed[32];
    if (ofMessage) {
        revenant_elliptic_sha256(CFDataGetBytePtr(data), (size_t)CFDataGetLength(data), hashed);
    } else {
        if (CFDataGetLength(data) != 32) {
            RevenantSecKeyFail(error, errSecParam,
                                 [NSString stringWithFormat:@"a P-256 signature is of a 32 byte digest and %ld were given", (long)CFDataGetLength(data)]);
            return NULL;
        }
        memcpy(hashed, CFDataGetBytePtr(data), 32);
    }
    if (!RevenantSecurityKeyIsPortEC(key)) {
        RevenantSecKeyFail(error, errSecParam, @"this is the curve's own signing, and the key is not one of the port's");
        return NULL;
    }
    uint8_t scalar[32];
    OSStatus status = revenant_elliptic_port_scalar(key, scalar);
    if (status != errSecSuccess) {
        RevenantSecKeyFail(error, status, @"this key of the port's keeps no private scalar to sign with");
        return NULL;
    }
    uint8_t der[72];
    int written = RevenantCKDigestSignES256(scalar, hashed, der, sizeof der);
    if (written <= 0) {
        RevenantSecKeyFail(error, errSecInternalError, @"micro-ecc made no signature of the digest");
        return NULL;
    }
    return CFDataCreate(kCFAllocatorDefault, der, (CFIndex)written);
}

Boolean RevenantSecKeyECVerify(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef data, CFDataRef signature, CFErrorRef *error)
{
    if (!key || !data || !signature) {
        RevenantSecKeyFail(error, errSecParam, @"a verification needs a key, the data and the signature");
        return false;
    }
    BOOL digest = CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256)
        || CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256);
    if (!digest) {
        RevenantSecKeyFail(error, errSecParam,
                             [NSString stringWithFormat:@"algid:verify:%@: this port verifies P-256 with SHA-256 and nothing else", algorithm]);
        return false;
    }
    if (!RevenantSecurityKeyIsPortEC(key)) {
        RevenantSecKeyFail(error, errSecParam, @"this is the curve's own verification, and the key is not one of the port's");
        return false;
    }
    CFIndex length = CFDataGetLength(data);
    uint8_t hashed[32];
    if (CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256)) {
        revenant_elliptic_sha256(CFDataGetBytePtr(data), (size_t)length, hashed);
    } else {
        if (length != 32) {
            RevenantSecKeyFail(error, errSecParam,
                                 [NSString stringWithFormat:@"a P-256 signature is of a 32 byte digest and %ld were given", (long)length]);
            return false;
        }
        memcpy(hashed, CFDataGetBytePtr(data), 32);
    }
    uint8_t point[65];
    if (!revenant_elliptic_point(key, point)) {
        RevenantSecKeyFail(error, errSecParam, @"this key publishes no uncompressed public point to verify with");
        return false;
    }
    return RevenantCKDigestVerifyES256(point, sizeof point, hashed, CFDataGetBytePtr(signature),
                                     (size_t)CFDataGetLength(signature)) != 0;
}

CFDataRef RevenantSecKeyECExchange(SecKeyRef privateKey, SecKeyAlgorithm algorithm, SecKeyRef publicKey,
                                  CFDictionaryRef options, CFErrorRef *error)
{
    (void)options;
    if (!privateKey || !publicKey) {
        RevenantSecKeyFail(error, errSecParam, @"an exchange needs both keys");
        return NULL;
    }
    if (!revenant_elliptic_exchange(algorithm)) {
        RevenantSecKeyFail(error, errSecParam,
                             [NSString stringWithFormat:@"algid:exchange:%@: this port exchanges P-256 without a key derivation function only", algorithm]);
        return NULL;
    }
    if (!RevenantSecurityKeyIsPortEC(privateKey)) {
        RevenantSecKeyFail(error, errSecParam,
                             @"the release has no elliptic key agreement: its Security exports SecKeyRawSign and SecKeyRawVerify and only the finite-field SecDH family, so a key of its keychain cannot exchange");
        return NULL;
    }
    uint8_t scalar[32];
    OSStatus status = revenant_elliptic_port_scalar(privateKey, scalar);
    if (status != errSecSuccess) {
        RevenantSecKeyFail(error, status, @"this key of the port's keeps no private scalar to exchange with");
        return NULL;
    }
    uint8_t peer[65];
    if (!revenant_elliptic_point(publicKey, peer)) {
        RevenantSecKeyFail(error, errSecParam, @"the peer's key publishes no uncompressed public point to exchange with");
        return NULL;
    }
    uint8_t secret[32];
    if (!RevenantCKSharedSecretES256(scalar, peer, sizeof peer, secret)) {
        RevenantSecKeyFail(error, errSecInternalError, @"micro-ecc made no shared secret of the two keys");
        return NULL;
    }
    return CFDataCreate(kCFAllocatorDefault, secret, (CFIndex)sizeof secret);
}
