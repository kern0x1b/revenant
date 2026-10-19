#ifndef CHARON_HAP_CRYPTO_H
#define CHARON_HAP_CRYPTO_H

#include <stdint.h>
#include <stddef.h>

void charon_hap_x25519(uint8_t shared[32], const uint8_t secret[32], const uint8_t peer[32]);
void charon_hap_x25519_keypair(uint8_t secret[32], uint8_t public[32]);
void charon_hap_ed25519_keypair(uint8_t secret[64], uint8_t public[32]);
void charon_hap_ed25519_keypair_from_seed(uint8_t secret[64], uint8_t public[32], const uint8_t seed[32]);
void charon_hap_ed25519_sign(uint8_t signature[64], const uint8_t *message, size_t length, const uint8_t secret[64]);
int  charon_hap_ed25519_verify(const uint8_t signature[64], const uint8_t *message, size_t length, const uint8_t public[32]);

void charon_hap_seal(uint8_t *cipher, uint8_t tag[16], const uint8_t *plain, size_t length,
                     const uint8_t key[32], const uint8_t nonce[12], const uint8_t *extra, size_t extraLength);
int  charon_hap_open(uint8_t *plain, const uint8_t *cipher, const uint8_t tag[16], size_t length,
                     const uint8_t key[32], const uint8_t nonce[12], const uint8_t *extra, size_t extraLength);

void charon_hap_sha512(uint8_t out[64], const uint8_t *data, size_t length);
void charon_hap_sha1(uint8_t out[20], const uint8_t *data, size_t length);
void charon_hap_hmac_sha1(uint8_t out[20], const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length);
typedef struct {
    void (*hash)(uint8_t *out, const uint8_t *data, size_t length);
    size_t length;
} CharonHapHash;

extern const CharonHapHash charon_hap_sha1_hash;
extern const CharonHapHash charon_hap_sha512_hash;
void charon_hap_sha256(uint8_t out[32], const uint8_t *data, size_t length);
void charon_hap_hmac_sha512(uint8_t out[64], const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length);
void charon_hap_hmac_sha256(uint8_t out[32], const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length);
void charon_hap_hkdf_sha512(uint8_t *out, size_t length, const uint8_t *salt, size_t saltLength,
                            const uint8_t *inputKey, size_t inputKeyLength, const uint8_t *info, size_t infoLength);
void charon_hap_hkdf_sha256(uint8_t *out, size_t length, const uint8_t *salt, size_t saltLength,
                            const uint8_t *inputKey, size_t inputKeyLength, const uint8_t *info, size_t infoLength);

int charon_hap_equal(const uint8_t *left, const uint8_t *right, size_t length);

#endif
