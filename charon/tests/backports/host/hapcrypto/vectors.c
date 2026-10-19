/* The HAP crypto against the published vectors of each primitive it wraps:
     RFC 7748 section 5.2 for X25519, RFC 8032 section 7.1 TEST 2 for Ed25519,
     RFC 8439 section 2.8.2 for ChaCha20-Poly1305, RFC 5869 test case 1 for HKDF-SHA256 and
     test case 1 of the SHA-256 vectors for SHA-256 itself. */
#include <stdio.h>
#include <string.h>
#include "CharonHapCrypto.h"

static int hex(char c) { if (c >= '0' && c <= '9') return c - '0'; if (c >= 'a' && c <= 'f') return c - 'a' + 10; if (c >= 'A' && c <= 'F') return c - 'A' + 10; return -1; }
static size_t unhex(uint8_t *out, const char *in, size_t n) { for (size_t i = 0; i < n; ++i) out[i] = (uint8_t)((hex(in[2*i]) << 4) | hex(in[2*i+1])); return n; }
static void show(const char *tag, const uint8_t *v, size_t n) { printf("%s ", tag); for (size_t i = 0; i < n; ++i) printf("%02x", v[i]); printf("\n"); }
static int failed = 0;
static void check(const char *what, const uint8_t *got, const char *want, size_t n) {
    uint8_t expect[512];
    unhex(expect, want, n);
    if (memcmp(got, expect, n) == 0) printf("ok   %s\n", what);
    else { printf("FAIL %s\n  got  ", what); show("", got, n); printf("  want %s\n", want); failed++; }
}
int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    /* RFC 7748 5.2, the first X25519 test vector. */
    {
        uint8_t a[32], b[32], shared[32];
        unhex(a, "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a", 32);
        unhex(b, "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f", 32);
        charon_hap_x25519(shared, a, b);
        check("X25519 (RFC 7748 5.2 vector 1)", shared,
              "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742", 32);
    }
    /* RFC 8032 7.1 TEST 2. */
    {
        uint8_t sk[64], publicKey[32], signature[64];
        const char *seed = "4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb";
        uint8_t seedBytes[32];
        unhex(seedBytes, seed, 32);
        charon_hap_ed25519_keypair_from_seed(sk, publicKey, seedBytes);
        charon_hap_ed25519_sign(signature, (const uint8_t *)"r", 1, sk);
        check("Ed25519 (RFC 8032 7.1 TEST 2)", signature,
              "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da"
              "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00", 64);
        charon_hap_ed25519_verify(signature, (const uint8_t *)"r", 1, publicKey);
    }
    /* RFC 8439 2.8.2, the AEAD test vector. */
    {
        uint8_t key[32], nonce[12], aad[12], plain[114], cipher[114], tag[16], back[114];
        unhex(key, "808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f", 32);
        unhex(nonce, "070000004041424344454647", 12);
        unhex(aad, "50515253c0c1c2c3c4c5c6c7", 12);
        unhex(plain,
              "4c616469657320616e642047656e746c656d656e206f662074686520636c617373206f66202739393a204966204920636f756c64206f6666657220796f75206f6e6c79206f6e652074697020666f7220746865206675747572652c2073756e73637265656e20776f756c642062652069742e", 114);
        charon_hap_seal(cipher, tag, plain, 114, key, nonce, aad, 12);
        check("ChaCha20-Poly1305 ciphertext (RFC 8439 2.8.2)", cipher,
              "d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d6"
              "3dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b36"
              "92ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc"
              "3ff4def08e4b7a9de576d26586cec64b6116", 114);
        check("ChaCha20-Poly1305 tag (RFC 8439 2.8.2)", tag, "1ae10b594f09e26a7e902ecbd0600691", 16);
        int opened = charon_hap_open(back, cipher, tag, 114, key, nonce, aad, 12);
        printf("%s ChaCha20-Poly1305 opens its own ciphertext\n", opened == 0 ? "ok  " : "FAIL");
        if (opened != 0) failed++;
    }
    /* RFC 5869 test case 1: HKDF-SHA256. */
    {
        uint8_t ikm[22], salt[13], info[10], out[42];
        unhex(ikm, "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b", 22);
        unhex(salt, "000102030405060708090a0b0c", 13);
        unhex(info, "f0f1f2f3f4f5f6f7f8f9", 10);
        charon_hap_hkdf_sha256(out, 42, salt, 13, ikm, 22, info, 10);
        check("HKDF-SHA256 (RFC 5869 test case 1)", out,
              "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf"
              "34007208d5b887185865", 42);
    }
    /* RFC 5869 test case 3: HKDF-SHA256 with no salt. */
    {
        uint8_t ikm[22], out[42];
        unhex(ikm, "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b", 22);
        charon_hap_hkdf_sha256(out, 42, NULL, 0, ikm, 22, NULL, 0);
        check("HKDF-SHA256, no salt (RFC 5869 test case 3)", out,
              "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d"
              "9d201395faa4b61a96c8", 42);
    }
    /* FIPS 180-4, SHA-256 of "abc". */
    {
        uint8_t out[32];
        charon_hap_sha256(out, (const uint8_t *)"abc", 3);
        check("SHA-256(\"abc\")", out,
              "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", 32);
    }
    /* FIPS 180-4, SHA-512 of "abc". */
    {
        uint8_t out[64];
        charon_hap_sha512(out, (const uint8_t *)"abc", 3);
        check("SHA-512(\"abc\")", out,
              "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
              "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f", 64);
    }
    printf(failed ? "\n%d FAILED\n" : "\nall vectors agree\n", failed);
    return failed ? 1 : 0;
}
