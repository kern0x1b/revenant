#include <CommonCrypto/CommonDigest.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#include "uECC.h"

#include "CharonCKWebAuth.h"

static const uint8_t uECCP256Order[32] = {
    0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
    0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51};

static void uECCOrderMinus(uint8_t out[32], const uint8_t value[32])
{
    unsigned borrow = 0;
    for (int index = 31; index >= 0; index--) {
        unsigned difference = (unsigned)uECCP256Order[index] - (unsigned)value[index] - borrow;
        out[index] = (uint8_t)difference;
        borrow = (difference >> 8) & 1u;
    }
}

static void uECCOrderHalf(uint8_t half[32])
{
    half[0] = (uint8_t)(uECCP256Order[0] >> 1);
    for (int index = 1; index < 32; index++) {
        half[index] = (uint8_t)((uECCP256Order[index] >> 1) | ((uECCP256Order[index - 1] & 1u) << 7));
    }
}

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

void CharonCKSHA256(const uint8_t *message, size_t length, uint8_t *digest)
{
    if (!message && length != 0) {
        return;
    }
    CC_SHA256(message, (CC_LONG)length, digest);
}

int CharonCKDigestSignES256(const uint8_t *privateKey, const uint8_t *digest, uint8_t *der, size_t capacity)
{
    uint8_t raw[64];
    uint8_t half[32];
    if (!privateKey || !digest) {
        return 0;
    }
    CharonCKInstallRNG();
    if (!uECC_sign(privateKey, digest, CC_SHA256_DIGEST_LENGTH, raw, uECC_secp256r1())) {
        return 0;
    }

    uECCOrderHalf(half);
    if (memcmp(raw + 32, half, 32) > 0) {
        uECCOrderMinus(raw + 32, raw + 32);
    }

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

const uint8_t *CharonCKGroupOrder(void) { return uECCP256Order; }

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
        if (der[offset + 2] == 0x00 && (size == 1 || (der[offset + 3] & 0x80) == 0)) {
            return 0;
        }
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
    if (!uECC_compute_public_key(privateKey, out + 1, uECC_secp256r1())) {
        return 0;
    }
    out[0] = 0x04;
    return 65;
}

int CharonCKDigestVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *digest,
                              const uint8_t *der, size_t derLength)
{
    uint8_t r[32], s[32];
    uint8_t raw[64];
    if (publicLength != 65 || publicKey[0] != 0x04 || !digest || !der) {
        return 0;
    }
    if (!CharonCKDERSignatureValues(der, derLength, r, s)) {
        return 0;
    }
    memcpy(raw, r, 32);
    memcpy(raw + 32, s, 32);
    return uECC_verify(publicKey + 1, digest, CC_SHA256_DIGEST_LENGTH, raw, uECC_secp256r1());
}

int CharonCKVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *message, size_t length,
                        const uint8_t *der, size_t derLength)
{
    if (publicLength != 65 || publicKey[0] != 0x04) {
        return 0;
    }
    uint8_t r[32], s[32];
    if (!CharonCKDERSignatureValues(der, derLength, r, s)) {
        return 0;
    }
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CharonCKSHA256(message, length, digest);
    return CharonCKDigestVerifyES256(publicKey, publicLength, digest, der, derLength);
}

int CharonCKSharedSecretES256(const uint8_t *privateKey, const uint8_t *peerPublic, size_t publicLength,
                              uint8_t *secret)
{
    if (!privateKey || !peerPublic || publicLength != 65 || peerPublic[0] != 0x04 || !secret) {
        return 0;
    }
    CharonCKInstallRNG();
    return uECC_shared_secret(peerPublic + 1, privateKey, secret, uECC_secp256r1());
}
