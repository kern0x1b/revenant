#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <string.h>
#import <stdlib.h>
#import <CommonCrypto/CommonDigest.h>

// The EC half of three of the four Security calls of iOS 10, for the keys this package makes itself.
//
// THIS FILE DEFINES NO PUBLIC SecKey* SYMBOL. The four public names live in
// Security/SecurityFunctions10_0_1.m, which had them first, and it dispatches: a key of the release's
// own keychain is signed and verified by the release's own SecKeyRawSign and SecKeyRawVerify there,
// and a key of this package's kind - one that carries its own scalar and that the release's keychain
// does not hold - comes here for the curve. That is one public symbol per function with both
// behaviours behind it, instead of two files each defining the same four and the linker refusing the
// library (measured: "ld: 4 duplicate symbols for architecture armv7", the four being
// _SecKeyCreateSignature, _SecKeyVerifySignature, _SecKeyCopyKeyExchangeResult and
// _SecKeyIsAlgorithmSupported in these two objects).
//
// The arrangement also settles the band boundary. A file whose exports a band's release already has is
// left out of that band, and the call is then undefined in that band only; this file exports nothing a
// release can already have, so no band can drop it, while the public file was in every band already.
//
// Every name below that is not static begins with Charon, which is what backports.lua's
// internal_symbol() keys on: the curve and the marker stay out of this library's API, and what an
// application links is the four Security names and nothing else.
//
// The curve is charon@micro-ecc, BSD-2, through the JOSE and the ECDH that package carries; the
// measurement is in facts/Security/SecKeyElliptic.md, and the host differential that takes it is
// tests/backports/host/seckeycurve.

extern CFIndex SecKeyGetAlgorithmID(SecKeyRef key);
extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);
extern OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serialized);
extern SecKeyRef SecKeyCreateFromPublicData(CFAllocatorRef allocator, CFIndex algorithmID, CFDataRef serialized);
// SecKeyRawSign and SecKeyRawVerify are declared by the SDK's own SecKey.h (iOS 2.0, deprecated in
// 15.0 in favour of the four calls of this file), and the release exports both, so they are called
// through that declaration and not through one written here.

// The curve, from charon@micro-ecc, for the keys this package makes itself: the uncompressed public
// point of a private scalar, a DER signature of a digest, and the ECDH shared secret. Every name here
// begins with Charon, so backports.lua's internal_symbol() keeps them out of this library's exports.
extern int CharonCKPublicKeyES256(const uint8_t *privateKey, uint8_t *out);
extern int CharonCKDigestSignES256(const uint8_t *privateKey, const uint8_t *digest, uint8_t *der, size_t capacity);
extern int CharonCKDigestVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *digest,
                                    const uint8_t *der, size_t derLength);
extern int CharonCKSharedSecretES256(const uint8_t *privateKey, const uint8_t *peerPublic, size_t publicLength,
                                    uint8_t *secret);
// The SHA-256 of the message under a Message algorithm, and of nothing else: the digest an ECDSA
// signature is over is this, and CommonCrypto has it on the release (CC_SHA256 is in the armv7 shared
// cache of iOS 6.1.3), so the port does not need a curve to hash.
static void charon_elliptic_sha256(const uint8_t *message, size_t length, uint8_t digest[32])
{
    CC_SHA256(message, (CC_LONG)length, digest);
}

// The one way this library builds a CFError, exported because the other file of this library needs it
// too and a second CFErrorCreate beside it is a second answer to the same question. The domain is
// NSOSStatusErrorDomain and the code is the OSStatus, which is the shape the release's own
// SecKeyRawSign answers in and the shape the seckeycurve differential reads.
void CharonSecKeyFail(CFErrorRef *error, OSStatus status, NSString *description)
{
    if (!error) {
        return;
    }
    *error = CFErrorCreate(kCFAllocatorDefault, (__bridge CFStringRef)NSOSStatusErrorDomain, status,
                           (__bridge CFDictionaryRef)@{@"NSDescription": description});
}

// The two kinds of key, which are told apart by where they are and not by what they are: a key of
// the release's own keychain is one the release made and can sign with, and a key this package made
// is one that holds its own scalar and needs the curve. Until the port has keys of its own kind -
// SecKeyCreateWithData and the EC arm of SecKeyCreateRandomKey - every key is the release's, and
// the marker below is what a key of the port's would carry in its attributes.
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

// The 32 byte private scalar of a key of this package: the 32 bytes SecKeyCreateWithData keeps as the
// key's own kSecValueData beside the point it derived from them.
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

// The uncompressed public point of a key: the BIT STRING inside the SubjectPublicKeyInfo the release
// serializes, which is a 0x04 tag and the two 32 byte coordinates.
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
    // The first byte of a BIT STRING counts the unused bits of the last one, which is 0 for a point.
    BOOL whole = bitString && bits == 66 && bitString[0] == 0x00 && bitString[1] == 0x04;
    if (whole) {
        memcpy(point, bitString + 1, 65);
    }
    CFRelease(serialized);
    return whole;
}

// The signature the release made, in the SEQUENCE of two INTEGERs that SecKeyCreateSignature answers.
//
// The release's SecKeyRawSign hands back the two halves of a P-256 signature where it puts them - the
// 64 bytes of r and s, or the DER of them - and which one it is the release's business, not an
// assumption: both shapes are read, and a result that is neither is refused rather than guessed at.
// r and s are put in the low-s half, which is the form Apple's own Security produces and which a
// CloudKit web services token is checked against; (r, s) and (r, n - s) are both valid signatures.
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
    // An INTEGER is as many bytes as its value needs and one more when the top bit is set; a padding
    // byte the value did not need is a shape a DER reader refuses.
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

// The DER of the two halves the release made, or the DER the release made itself, handed on as it is.
static CFDataRef charon_elliptic_der(CFDataRef raw, CFErrorRef *error)
{
    if (!raw) {
        CharonSecKeyFail(error, errSecInternalError, @"the release's own signing handed back nothing");
        return NULL;
    }
    const uint8_t *bytes = CFDataGetBytePtr(raw);
    size_t length = (size_t)CFDataGetLength(raw);
    if (length > 2 && bytes[0] == 0x30 && bytes[1] == length - 2) {
        // Already the SEQUENCE of two INTEGERs: the release's own encoding, kept.
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

// The name every elliptic exchange algorithm of Security's own vocabulary begins with: no SDK this
// port builds against declares kSecKeyAlgorithmECDH, only the family kSecKeyAlgorithmECDHKeyExchange*
// whose names are the strings below, and the header of SecKeyCopyKeyExchangeResult tells the caller
// to pass "kSecKeyAlgorithmECDH" - which is that family's own prefix.
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

// What the curve carries for a key of this package's kind, as a pure function of the operation and
// the algorithm, so a host with no key and no keychain can drive it. The sign and verify half agrees
// with the release table in SecurityFunctions10_0_1.m - the two ECDSA digest algorithms and nothing
// else - and the exchange half is what the release cannot do at all, so a key this package made is the
// only kind that answers it. That agreement is a check, not a hope: the seckeycurve differential asks
// both functions the same question and fails if the two answers differ.
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
        return false;   // P-256 has no other vocabulary in Security, and the RSA ones are not this key's
    }
    // The exchange is the one operation the release cannot do for an elliptic key, and that is measured
    // rather than assumed: the armv7 shared cache of iOS 6.1.3 exports SecKeyRawSign and SecKeyRawVerify
    // and no elliptic exchange at all - its only key agreement is the finite-field SecDH* family
    // (SecDHComputeKey, SecDHGeneratePair), which is not a curve.
    return operation == kSecKeyOperationTypeKeyExchange;
}

// The curve's signing, for a key that carries the marker. A key of the release's keychain is not here:
// it is signed by the release's own SecKeyRawSign in SecurityFunctions10_0_1.m, beside the RSA one,
// because that is the release's own primitive for a key of its keychain whatever the key's class, and
// one place is where that is said.
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
    // A Digest algorithm signs the 32 bytes the caller took and a Message algorithm the message; both
    // are signed over the SHA-256 of it, and that is the one hash either of them is about.
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
        // The public function dispatches on the marker before it calls this, so a key that is not the
        // port's cannot arrive; the refusal is here so that a caller of this name from inside the
        // library is answered rather than quietly signed with the wrong key's curve.
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

// The curve's verification, for a key that carries the marker. The DER a caller may pass is read back
// into its two halves first, so that a signature either shape is verified; the release-key path is in
// SecurityFunctions10_0_1.m for the reason CharonSecKeyECSign gives.
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
        // As in CharonSecKeyECSign: the public function has already dispatched on the marker.
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
    // The signature goes to micro-ecc's verifier as the caller gave it, and that verifier reads the DER
    // SEQUENCE of two INTEGERs - which is what Apple's own SecKeyCreateSignature produces and therefore
    // what a caller of a JOSE-verified token holds. The two raw halves are the release's shape, and
    // reading them is the release path's work in SecurityFunctions10_0_1.m, not this file's.
    return CharonCKDigestVerifyES256(point, sizeof point, hashed, CFDataGetBytePtr(signature),
                                     (size_t)CFDataGetLength(signature)) != 0;
}

// The exchange, for a key that carries the marker. A key of the release's own keychain never reaches
// here: SecurityFunctions10_0_1.m answers that one, because the refusal is a fact about the release
// and not about this package's curve.
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
    // A "Standard" name hands back the X coordinate of the shared point as it is, and a name that ends
    // in a digest hands back that digest of it, which is what Security's own two families say they do.
    if (!hashed) {
        return CFDataCreate(kCFAllocatorDefault, secret, (CFIndex)sizeof secret);
    }
    uint8_t digest[32];
    charon_elliptic_sha256(secret, sizeof secret, digest);
    return CFDataCreate(kCFAllocatorDefault, digest, (CFIndex)sizeof digest);
}
