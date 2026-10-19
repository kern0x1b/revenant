// The ES256 signature a CloudKit Web Services authentication key makes, over micro-ecc.
//
// The elliptic arithmetic is micro-ecc's, unmodified and packaged as charon@micro-ecc (BSD-2); this
// file is the JOSE around it and nothing more: SHA-256 of the message, the DER encoding
// SEQUENCE { INTEGER r, INTEGER s } that a JOSE ES256 verifier reads, and the low-s half.
//
// Two things here are not micro-ecc's and both were found by holding this to OpenSSL:
//
//  * The DER is minimal. Each INTEGER is as many bytes as its value needs, with one more when the
//    top bit of the value is set, and never a padding byte it does not need. Writing a fixed
//    33-byte INTEGER with a leading zero is a shape LibreSSL's parser refuses ("too long"), so a
//    signature that is arithmetically perfect is rejected on the way in.
//  * The low-s half. micro-ecc does not take it and Apple's own Security does. (r, s) and
//    (r, n - s) are both valid for the same message, so replacing s by n - s when s is over half
//    the group order leaves a signature that still verifies and is the one SecKeyCreateSignature
//    produces, which is what a CloudKit Web Services token is checked against.
//
// Nothing else is touched.

#include <CommonCrypto/CommonDigest.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#include "uECC.h"

#include "CharonCKWebAuth.h"

// The order of P-256's generator, and half of it.
//
// The curve struct that would give this to us is private to micro-ecc's own translation unit, and
// micro-ecc here is upstream and byte-for-byte unmodified, so the value is transcribed from FIPS
// 186-4 D.1.2.3. Its last two bytes are 25 51.
//
// This constant was wrong for a long time and every symptom of it was blamed on something else. It
// read fc 63 ff 51 where the order is fc 63 25 51, so the value here is over the true order by 0xda00
// and its half is over the true half by 0x6d00. Two rounds of the low-s work chased the consequences
// instead: an early version also shifted the half the wrong way round for a big-endian number, and
// the subtraction was written correctly over a number that was not the order, so the flip emitted
// (r, n - s) with n over the true order by 0xda00 - a pair that is arithmetically a signature and is
// rejected by every verifier, because the reflected point of a signature is only a signature when
// the reflection is taken in the true order. (r, s) and (r, n - s) are both valid for the same
// message, and that is what makes the low-s assertion the only one that can see which was made.
//
// Measured, on one key and one message, with OpenSSL's own signature and no code of this file in the
// loop - which is what finally named the constant rather than the subtraction:
//
//     s -> n - s with this file's order : Error Verifying Data
//     s -> n - s with P-256's true order : Verified OK
//
// The first version of this file had the other error too, byte 30 reading 0x25 where FIPS reads 0xff,
// and the comment above it claimed a 0x25 that is in neither the wrong value nor the right one.
static const uint8_t uECCP256Order[32] = {
    0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
    0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51};

// n - s, the borrow taken out of the low bytes and carried up. The order is the constant above, so
// the subtraction and the comparison that decides it are two halves of one number and cannot drift.
static void uECCOrderMinus(uint8_t out[32], const uint8_t value[32])
{
    unsigned borrow = 0;
    for (int index = 31; index >= 0; index--) {
        unsigned difference = (unsigned)uECCP256Order[index] - (unsigned)value[index] - borrow;
        out[index] = (uint8_t)difference;
        borrow = (difference >> 8) & 1u;
    }
}

// n >> 1, a right shift of the whole 256-bit big-endian value: the bit that leaves byte k lands on the
// top of byte k+1, so it is read from the byte above and written into the one below. The first
// version read it from index + 1 into index, which is the little-endian rule applied to a big-endian
// number, and produced a threshold of 0.9999999702 of n rather than half of it.
static void uECCOrderHalf(uint8_t half[32])
{
    half[0] = (uint8_t)(uECCP256Order[0] >> 1);
    for (int index = 1; index < 32; index++) {
        half[index] = (uint8_t)((uECCP256Order[index] >> 1) | ((uECCP256Order[index - 1] & 1u) << 7));
    }
}

// The kernel's own random device, which is the only source a nonce may come from. A descriptor is
// opened once and kept: micro-ecc asks for bytes many times over, and an open per call costs more
// than the signature does.
static int uECC_kernel_random(uint8_t *dest, unsigned size)
{
    static int descriptor = -1;
    if (descriptor < 0) {
        descriptor = open("/dev/urandom", O_RDONLY);
        if (descriptor < 0) {
            return 0;
        }
    }
    unsigned done = 0;
    while (done < size) {
        ssize_t got = read(descriptor, dest + done, size - done);
        if (got <= 0) {
            return 0;
        }
        done += (unsigned)got;
    }
    return 1;
}

static void CharonCKInstallRNG(void)
{
    static int installed = 0;
    if (!installed) {
        uECC_set_rng(uECC_kernel_random);
        installed = 1;
    }
}

// One DER INTEGER of a 32-byte value, as few bytes as it needs, at most 33. Answers its length.
static int uECCDERInteger(uint8_t *out, const uint8_t value[32])
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

// The SHA-256 the header declares, defined once: the message-level pair below is the digest-level one
// with a call of this in front, and a caller that has a digest to sign uses the digest-level one
// directly. It was declared and defined nowhere, so a consumer that linked the archive and called it
// failed at the link - measured, by this band's own Security library.
void CharonCKSHA256(const uint8_t *message, size_t length, uint8_t *digest)
{
    if (!message && length != 0) {
        return;
    }
    CC_SHA256(message, (CC_LONG)length, digest);
}

// The signature of a digest the caller has already taken. Security's
// ...ECDSASignatureDigestX962SHA256 says *Digest*: the 32 bytes the caller hashed are the
// message, and hashing them again would sign a different one. The message-level pair below
// is this with CharonCKSHA256 in front, and the two are the whole of a signature: the
// low-s normalisation and the minimal DER are shared rather than written twice.
int CharonCKDigestSignES256(const uint8_t *privateKey, const uint8_t *digest, uint8_t *der, size_t capacity)
{
    uint8_t raw[64];
    uint8_t half[32];
    if (!privateKey || !digest) {
        return 0;
    }
    CharonCKInstallRNG();
    // The digest's length is 32, named: `digest` is a pointer here, so sizeof would say eight, and
    // micro-ecc would sign the first eight bytes of the hash. Every signature would then be a signature
    // of something else, and BOTH the host's SecKeyVerifySignature and this file's own verify would
    // refuse all of them - 200 of 200, which is what the re-review measured.
    if (!uECC_sign(privateKey, digest, CC_SHA256_DIGEST_LENGTH, raw, uECC_secp256r1())) {
        return 0;
    }

    // The low-s normalisation, which the 40-check OpenSSL round trip cannot see: both (r, s) and
    // (r, n - s) verify, so every one of those checks passes with either, and only this comparison
    // and the order can tell which was made.
    //
    // `half` is filled in here, and it is worth saying why that line is load-bearing: it was lost
    // once, to a comment edit, and the comparison then ran against uninitialised stack. The
    // threshold that came out of that was a fixed prefix, so the flip fired on a quarter of the
    // signatures rather than half, and every one it fired on was corrupted - which is what "2555 of
    // 5000 self-verify failures" was, and what a correct threshold never does.
    //
    // Two defects were hiding behind that one, and both are fixed: the lost call, and the order
    // above, which was not the order. With the order right the comparison is against the true half
    // and the subtraction is a reflection in the true group, so a flipped signature is a signature:
    //
    //     low-s: low=5000 high=0 self-verify failures=0 of 5000
    //     micro-ecc: 40 checks agreed in both directions, 0 failures
    //
    // What the previous round concluded - that the flip is arithmetically right and the write is
    // wrong, so it cannot ship - was a correct reading of a wrong constant. It is the order that
    // made the write wrong; with the order corrected there is nothing wrong with what the flip
    // writes, and the round trip that shares no code with any of this now passes with the flip on.
    uECCOrderHalf(half);
    if (memcmp(raw + 32, half, 32) > 0) {
        uECCOrderMinus(raw + 32, raw + 32);
    }

    // The DER, written by the same minimal encoder the reader above is the inverse of: an INTEGER is
    // as many bytes as its value needs, and one more when the top bit of the value is set.
    // The largest DER two 32-byte values can be: the SEQUENCE header, and an INTEGER per value with
    // its length byte and, at most, the one sign pad. That is 2 + (2 + 33) + (2 + 33) = 72. The check
    // asked for 8 + 2 * 35 = 78, which no P-256 signature reaches, so the port refused every signature
    // it made - the writer was not asked, and Security/SecKeyElliptic10.m got a zero-length DER back.
    if (capacity < 2 + 2 * (2 + 33)) {
        return 0;
    }
    size_t offset = 0;
    der[offset++] = 0x30;
    der[offset++] = 0;
    size_t contentStart = offset;
    offset += (size_t)uECCDERInteger(der + offset, raw);
    offset += (size_t)uECCDERInteger(der + offset, raw + 32);
    der[1] = (uint8_t)(offset - contentStart);
    return (int)offset;
}

int CharonCKSignES256(const uint8_t *privateKey, const uint8_t *message, size_t length, uint8_t *der, size_t capacity)
{
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CharonCKSHA256(message, length, digest);
    return CharonCKDigestSignES256(privateKey, digest, der, capacity);
}

// The order and its half, for the test that asserts every signature made here is low-s. Without
// this the test would have to transcribe n a second time, and a second transcription of the value
// this file got wrong is exactly how the mistake survived.
const uint8_t *CharonCKGroupOrder(void) { return uECCP256Order; }

// The r and s of a DER SEQUENCE { INTEGER r, INTEGER s }, as the two 32-byte values, and whether
// the encoding was one of ours. One reader for the verifier and for the test's accessor, because
// two of them drifted: the verifier stripped the sign pad and the accessor did not, so every padded s
// began 0x00, compared below any half of the order, and the low-s count read high=0 while the port
// emitted high-s in half of its signatures.
int CharonCKDERSignatureValues(const uint8_t *der, size_t derLength, uint8_t r[32], uint8_t s[32])
{
    if (derLength < 8 || derLength > 72 || der[0] != 0x30 || der[1] != (uint8_t)(derLength - 2)) {
        return 0;
    }
    size_t offset = 2;
    for (int which = 0; which < 2; which++) {
        if (offset + 2 > derLength || der[offset] != 0x02) {
            return 0;
        }
        size_t size = der[offset + 1];
        if (size == 0 || size > 33 || offset + 2 + size > derLength) {
            return 0;
        }
        // A padding byte the value did not need is not DER, and one that is needed but absent would
        // read as a negative s.
        if (der[offset + 2] == 0x00 && (size == 1 || (der[offset + 3] & 0x80) == 0)) {
            return 0;
        }
        // A 33-byte content is 32 bytes of value under the sign pad, so the value starts one byte
        // further in. This is the step the accessor missed.
        const uint8_t *value = der + offset + 2;
        size_t bytes = size;
        if (size == 33) {
            value += 1;
            bytes = 32;
        }
        uint8_t *out = which == 0 ? r : s;
        memset(out, 0, 32);
        memcpy(out + (32 - bytes), value, bytes);
        offset += 2 + size;
    }
    return offset == derLength;
}

const uint8_t *CharonCKDERSignatureS(const uint8_t *der, size_t derLength)
{
    // The value, not the content: this returns 32 bytes with the sign pad off, and the one reader
    // above is what decides.
    static uint8_t s[32];
    uint8_t r[32];
    return CharonCKDERSignatureValues(der, derLength, r, s) ? s : NULL;
}

const uint8_t *CharonCKGroupOrderHalf(void)
{
    static uint8_t half[32];
    uECCOrderHalf(half);
    return half;
}

int CharonCKPublicKeyES256(const uint8_t *privateKey, uint8_t *out)
{
    // uECC_make_key would generate a new pair and overwrite the key it is given; the function that
    // takes a private key and hands back its public point is uECC_compute_public_key.
    //
    // It writes the two coordinates as big-endian bytes - `uECC_VLI_NATIVE_LITTLE_ENDIAN` is 0
    // unless a build asks for 1, and micro-ecc's own note says the two are incompatible - and no
    // 0x04 tag, so the uncompressed point the rest of the port speaks is the tag followed by those
    // 64 bytes exactly as they come.
    if (!uECC_compute_public_key(privateKey, out + 1, uECC_secp256r1())) {
        return 0;
    }
    out[0] = 0x04;
    return 65;
}

// The verification of a digest the caller has already taken, over the same reader as the
// message-level one below, which is this with CharonCKSHA256 in front.
int CharonCKDigestVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *digest,
                              const uint8_t *der, size_t derLength)
{
    uint8_t r[32], s[32];
    uint8_t raw[64];
    if (publicLength != 65 || publicKey[0] != 0x04 || !digest || !der) {
        return 0;
    }
    // the two values, read by the one reader the test's accessor also uses
    if (!CharonCKDERSignatureValues(der, derLength, r, s)) {
        return 0;
    }
    memcpy(raw, r, 32);
    memcpy(raw + 32, s, 32);
    // micro-ecc takes the two coordinates without the 0x04 tag, and the digest at its own length: it
    // was a pointer's sizeof, eight, for one version of this file, and the length is 32 here.
    return uECC_verify(publicKey + 1, digest, CC_SHA256_DIGEST_LENGTH, raw, uECC_secp256r1());
}

int CharonCKVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *message, size_t length,
                        const uint8_t *der, size_t derLength)
{
    if (publicLength != 65 || publicKey[0] != 0x04) {
        return 0;
    }
    // The two values, read by the one reader the test's accessor also uses.
    uint8_t r[32], s[32];
    if (!CharonCKDERSignatureValues(der, derLength, r, s)) {
        return 0;
    }
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CharonCKSHA256(message, length, digest);
    return CharonCKDigestVerifyES256(publicKey, publicLength, digest, der, derLength);
}

// The ECDH shared secret: uECC_shared_secret between a 32 byte private key and a peer's 65 byte
// uncompressed public point, which is the X coordinate of the shared point and is what Security's own
// SecKeyCopyKeyExchangeResult answers for the Standard names. The kernel's random device is the nonce
// source micro-ecc wants here too, so the blinding it does is this package's and not a fixed value.
int CharonCKSharedSecretES256(const uint8_t *privateKey, const uint8_t *peerPublic, size_t publicLength,
                              uint8_t *secret)
{
    if (!privateKey || !peerPublic || publicLength != 65 || peerPublic[0] != 0x04 || !secret) {
        return 0;
    }
    CharonCKInstallRNG();
    return uECC_shared_secret(peerPublic + 1, privateKey, secret, uECC_secp256r1());
}
