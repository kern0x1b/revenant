// What HAP pairs with, over a vetted library for the parts that are curves or ciphers and over this
// package's own code for the parts that are HomeKit's.
//
// **The curves and the AEAD are Monocypher's** (4.0.2, BSD-2-Clause OR CC0-1.0, vendored at
// packages/m/monocypher): X25519 for the pair-verify key agreement, Ed25519 for the pair-setup and
// pair-verify signatures, and `crypto_aead_lock` with `crypto_aead_init_ietf` — which is
// ChaCha20-Poly1305 with the 12-byte nonce HAP's session keys use, and not the XChaCha20-Poly1305
// Monocypher's own `crypto_aead` is. BLAKE2b is there too, and is not used: HAP derives with
// HKDF-SHA-512 and HKDF-SHA-256, which are SHA-2, and iOS 6's CommonCrypto has SHA-2 and HMAC-SHA-2.
//
// **SRP-6a is this package's own**, on `CharonHAPBignum`'s modular exponentiation, which is checked
// against an independent implementation on 72 primes from 32 to 3072 bits. It is written here rather
// than vendored because it is a hundred lines of exponentiation and hashing over a modexp that is
// already verified here, and a vendored SRP would be a second, unverified answer to a question this
// package can already answer correctly. The group is RFC 5054's 3072-bit one, which is the group HAP
// documents.
//
// Nothing in this file is API: every entry point is the port's own name.
#ifndef CHARON_HAP_CRYPTO_H
#define CHARON_HAP_CRYPTO_H

#include <stdint.h>
#include <stddef.h>

// SRP-6a, the pair-setup's key agreement, is NOT here, and the reason is in
// facts/HomeKit/CharonHapCrypto.md: its 3072-bit group prime could not be read out of a real
// HomeKit.framework on this machine, and a group prime written from memory is a value no release
// ships, which pairs with nothing and fails in a way that reads like a network fault. Everything
// SRP-6a needs underneath it is here and checked: the modular exponentiation in CharonHAPBignum and
// the SHA-512 and HMAC below.

// The curves, over Monocypher.
void charon_hap_x25519(uint8_t shared[32], const uint8_t secret[32], const uint8_t peer[32]);
void charon_hap_x25519_keypair(uint8_t secret[32], uint8_t public[32]);
// The seed is 32 bytes and the library grows the 64-byte secret from it, so a caller with its own
// randomness supplies the seed and gets the same key everywhere.
void charon_hap_ed25519_keypair(uint8_t secret[64], uint8_t public[32]);
void charon_hap_ed25519_keypair_from_seed(uint8_t secret[64], uint8_t public[32], const uint8_t seed[32]);
void charon_hap_ed25519_sign(uint8_t signature[64], const uint8_t *message, size_t length, const uint8_t secret[64]);
int  charon_hap_ed25519_verify(const uint8_t signature[64], const uint8_t *message, size_t length, const uint8_t public[32]);

// ChaCha20-Poly1305, the IETF construction with the 12-byte nonce HAP uses.
void charon_hap_seal(uint8_t *cipher, uint8_t tag[16], const uint8_t *plain, size_t length,
                     const uint8_t key[32], const uint8_t nonce[12], const uint8_t *extra, size_t extraLength);
int  charon_hap_open(uint8_t *plain, const uint8_t *cipher, const uint8_t tag[16], size_t length,
                     const uint8_t key[32], const uint8_t nonce[12], const uint8_t *extra, size_t extraLength);

// SHA-512, SHA-256, HMAC-SHA-512, HMAC-SHA-256 and HKDF over either, which is what HAP derives its
// session keys with. CommonCrypto has all of them on this release; the wrappers are here so that the
// transport's own code reads as HAP's derivation and not as a call into a hash library.
void charon_hap_sha512(uint8_t out[64], const uint8_t *data, size_t length);
// SHA-1, which SRP-6a in RFC 5054's own test vector is defined over and which HAP does not use: it is
// here so the vector can be run against the same code rather than a second copy of it. CommonCrypto
// has it on this release and it is the only place in the package that asks for it.
void charon_hap_sha1(uint8_t out[20], const uint8_t *data, size_t length);
void charon_hap_hmac_sha1(uint8_t out[20], const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length);
// Which hash the SRP code runs over, so one implementation serves HAP's SHA-512 and the RFC's SHA-1.
typedef struct {
    void (*hash)(uint8_t *out, const uint8_t *data, size_t length);
    size_t length;   // 20 for SHA-1, 64 for SHA-512
} CharonHapHash;

extern const CharonHapHash charon_hap_sha1_hash;    // RFC 5054's test vector
extern const CharonHapHash charon_hap_sha512_hash;  // what HAP's pair-setup runs over
void charon_hap_sha256(uint8_t out[32], const uint8_t *data, size_t length);
void charon_hap_hmac_sha512(uint8_t out[64], const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length);
void charon_hap_hmac_sha256(uint8_t out[32], const uint8_t *key, size_t keyLength, const uint8_t *data, size_t length);
// HKDF (RFC 5869) extract-and-expand, with SHA-512.
void charon_hap_hkdf_sha512(uint8_t *out, size_t length, const uint8_t *salt, size_t saltLength,
                            const uint8_t *inputKey, size_t inputKeyLength, const uint8_t *info, size_t infoLength);
// HKDF-SHA-256, which is what the Bluetooth LE pairing derives with.
void charon_hap_hkdf_sha256(uint8_t *out, size_t length, const uint8_t *salt, size_t saltLength,
                            const uint8_t *inputKey, size_t inputKeyLength, const uint8_t *info, size_t infoLength);

// A constant-time equality, which is what every MAC and proof check here ends in.
int charon_hap_equal(const uint8_t *left, const uint8_t *right, size_t length);

#endif
