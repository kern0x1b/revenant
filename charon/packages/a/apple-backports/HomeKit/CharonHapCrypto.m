#include "CharonHapCrypto.h"
#include <monocypher/monocypher.h>
#include <monocypher/monocypher-ed25519.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#include <string.h>
#include <stdlib.h>

#pragma mark - the curves and the AEAD

void charon_hap_x25519(uint8_t shared[32], const uint8_t secret[32], const uint8_t peer[32])
{
    crypto_x25519(shared, secret, peer);
}

void charon_hap_x25519_keypair(uint8_t secret[32], uint8_t public[32])
{
    crypto_x25519_public_key(public, secret);
}

void charon_hap_ed25519_keypair(uint8_t secret[64], uint8_t public[32])
{
    // Monocypher's Ed25519 key pair is grown from a 32-byte seed and derives the second half of the
    // secret itself, so the seed is the only randomness needed and the source of it is named here:
    // arc4random_buf, which the release has carried since iOS 4. A caller that wants a key from its
    // own randomness passes the seed in through charon_hap_ed25519_keypair_from_seed.
    uint8_t seed[32];
    arc4random_buf(seed, sizeof(seed));
    charon_hap_ed25519_keypair_from_seed(secret, public, seed);
}

void charon_hap_ed25519_keypair_from_seed(uint8_t secret[64], uint8_t public[32], const uint8_t seed[32])
{
    // Monocypher destroys the seed it is given -- crypto_ed25519_key_pair wipes it once it has hashed
    // it -- so the caller's buffer is copied rather than handed over. A caller who passed a string
    // literal here would otherwise have the library write zeroes into read-only memory.
    uint8_t owned[32];
    memcpy(owned, seed, sizeof(owned));
    crypto_ed25519_key_pair(secret, public, owned);
}

void charon_hap_ed25519_sign(uint8_t signature[64], const uint8_t *message, size_t length, const uint8_t secret[64])
{
    crypto_ed25519_sign(signature, secret, message, length);
}

int charon_hap_ed25519_verify(const uint8_t signature[64], const uint8_t *message, size_t length, const uint8_t public[32])
{
    return crypto_ed25519_check(signature, public, message, length) ? 0 : 1;
}

void charon_hap_seal(uint8_t *cipher, uint8_t tag[16], const uint8_t *plain, size_t length,
                     const uint8_t key[32], const uint8_t nonce[12], const uint8_t *extra, size_t extraLength)
{
    // The IETF initialisation is what makes this the 12-byte-nonce construction HAP's session keys
    // use; Monocypher's own crypto_aead_init_x is the 24-byte XChaCha20 one and would produce a
    // ciphertext no accessory could read. 4.0 seals through a context, which carries the counter
    // between the calls, so a one-shot seal is a context that is written once and never read back.
    crypto_aead_ctx context;
    crypto_aead_init_ietf(&context, key, nonce);
    crypto_aead_write(&context, cipher, tag, extra, extraLength, plain, length);
}

int charon_hap_open(uint8_t *plain, const uint8_t *cipher, const uint8_t tag[16], size_t length,
                    const uint8_t key[32], const uint8_t nonce[12], const uint8_t *extra, size_t extraLength)
{
    crypto_aead_ctx context;
    crypto_aead_init_ietf(&context, key, nonce);
    // Monocypher's read answers 0 on success, so a session that has run out of context reads as a
    // failure rather than as an empty message, which is what the seam needs.
    return crypto_aead_read(&context, plain, tag, extra, extraLength, cipher, length);
}

#pragma mark - the hashes and the derivation

void charon_hap_sha512(uint8_t out[64], const uint8_t *data, size_t length)
{
    CC_SHA512(data, (CC_LONG)length, out);
}

void charon_hap_sha1(uint8_t out[20], const uint8_t *data, size_t length)
{
    CC_SHA1(data, (CC_LONG)length, out);
}

void charon_hap_hmac_sha1(uint8_t out[20], const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length)
{
    CCHmac(kCCHmacAlgSHA1, key, keyLength, data, length, out);
}

static void hash_sha1(uint8_t *out, const uint8_t *data, size_t length) { charon_hap_sha1(out, data, length); }
static void hash_sha512(uint8_t *out, const uint8_t *data, size_t length) { charon_hap_sha512(out, data, length); }

const CharonHapHash charon_hap_sha1_hash = { hash_sha1, 20 };
const CharonHapHash charon_hap_sha512_hash = { hash_sha512, 64 };

void charon_hap_sha256(uint8_t out[32], const uint8_t *data, size_t length)
{
    CC_SHA256(data, (CC_LONG)length, out);
}

void charon_hap_hmac_sha512(uint8_t out[64], const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length)
{
    CCHmac(kCCHmacAlgSHA512, key, keyLength, data, length, out);
}

void charon_hap_hmac_sha256(uint8_t out[32], const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length)
{
    CCHmac(kCCHmacAlgSHA256, key, keyLength, data, length, out);
}

// HMAC over whichever SHA-2 the caller names, in one place so the derivation and the proofs read the
// same whichever they use.
static void hmac_of(int sha512, const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length, uint8_t *out)
{
    if (sha512)
        CCHmac(kCCHmacAlgSHA512, key, keyLength, data, length, out);
    else
        CCHmac(kCCHmacAlgSHA256, key, keyLength, data, length, out);
}

// HKDF (RFC 5869), extract then expand. The output is at most the hash's own length in one go, which
// is all HAP asks for, and the buffer is bounded by what the caller declared.
static void hkdf(uint8_t *out, size_t length, const uint8_t *salt, size_t saltLength,
                 const uint8_t *inputKey, size_t inputKeyLength, const uint8_t *info, size_t infoLength,
                 int sha512)
{
    const size_t hashLength = sha512 ? 64 : 32;
    uint8_t zeros[64];
    uint8_t prk[64];
    uint8_t previous[64];
    uint8_t input[512];
    memset(zeros, 0, sizeof(zeros));

    // extract: PRK = HMAC(salt, inputKey). An absent salt is a string of hashLength zeros (RFC 5869 2.2).
    hmac_of(sha512, saltLength ? salt : zeros, saltLength ? saltLength : hashLength, inputKey, inputKeyLength, prk);

    // expand: T(1) = HMAC(PRK, info || 0x01); T(i) = HMAC(PRK, T(i-1) || info || i).
    size_t done = 0, have = 0;
    uint8_t counter = 1;
    while (done < length) {
        size_t total = 0;
        if (have) {
            memcpy(input, previous, hashLength);
            total = hashLength;
        }
        if (infoLength) {
            memcpy(input + total, info, infoLength);
            total += infoLength;
        }
        input[total++] = counter;
        hmac_of(sha512, prk, hashLength, input, total, previous);
        size_t take = (length - done < hashLength) ? (length - done) : hashLength;
        memcpy(out + done, previous, take);
        done += take;
        have = hashLength;
        ++counter;
    }
}

void charon_hap_hkdf_sha512(uint8_t *out, size_t length, const uint8_t *salt, size_t saltLength,
                            const uint8_t *inputKey, size_t inputKeyLength, const uint8_t *info, size_t infoLength)
{
    hkdf(out, length, salt, saltLength, inputKey, inputKeyLength, info, infoLength, 1);
}

void charon_hap_hkdf_sha256(uint8_t *out, size_t length, const uint8_t *salt, size_t saltLength,
                            const uint8_t *inputKey, size_t inputKeyLength, const uint8_t *info, size_t infoLength)
{
    hkdf(out, length, salt, saltLength, inputKey, inputKeyLength, info, infoLength, 0);
}

int charon_hap_equal(const uint8_t *left, const uint8_t *right, size_t length)
{
    uint8_t difference = 0;
    for (size_t index = 0; index < length; ++index)
        difference |= (uint8_t)(left[index] ^ right[index]);
    return difference == 0;
}
