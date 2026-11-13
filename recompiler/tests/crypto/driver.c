#include <arm_neon.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "../../src/runtime/crypto.c"

enum { ITERATIONS = 20000 };

static uint64_t seed = 0x9e3779b97f4a7c15ull;
static unsigned long failures;
static unsigned long comparisons;

static uint64_t next_random(void) {
    seed ^= seed >> 12;
    seed ^= seed << 25;
    seed ^= seed >> 27;
    return seed * 0x2545f4914f6cdd1dull;
}

static void fill(void *buffer, size_t size) {
    uint8_t *bytes = buffer;
    for (size_t i = 0; i < size; i++) {
        bytes[i] = (uint8_t)(next_random() >> 56);
    }
}

static void compare(const char *name, const void *want, const void *got, size_t size) {
    comparisons++;
    if (memcmp(want, got, size) != 0) {
        if (failures++ < 10) {
            printf("MISMATCH %s\n  want", name);
            for (size_t i = 0; i < size; i++) {
                printf(" %02x", ((const uint8_t *)want)[i]);
            }
            printf("\n  got ");
            for (size_t i = 0; i < size; i++) {
                printf(" %02x", ((const uint8_t *)got)[i]);
            }
            printf("\n");
        }
    }
}

#define AES_BINARY(name, intrinsic)                                                  \
    static void test_##name(void) {                                                  \
        for (unsigned i = 0; i < ITERATIONS; i++) {                                  \
            uint8_t d[16], n[16], want[16], got[16];                                 \
            fill(d, 16);                                                             \
            fill(n, 16);                                                             \
            vst1q_u8(want, intrinsic(vld1q_u8(d), vld1q_u8(n)));                     \
            memcpy(got, d, 16);                                                      \
            rellume_aarch64_##name(got, n);                                          \
            compare(#name, want, got, 16);                                           \
        }                                                                            \
    }

#define AES_UNARY(name, intrinsic)                                                   \
    static void test_##name(void) {                                                  \
        for (unsigned i = 0; i < ITERATIONS; i++) {                                  \
            uint8_t d[16], n[16], want[16];                                          \
            fill(d, 16);                                                             \
            fill(n, 16);                                                             \
            vst1q_u8(want, intrinsic(vld1q_u8(n)));                                  \
            rellume_aarch64_##name(d, n);                                            \
            compare(#name, want, d, 16);                                             \
        }                                                                            \
    }

#define SHA_ELEMENT(name, intrinsic)                                                 \
    static void test_##name(void) {                                                  \
        for (unsigned i = 0; i < ITERATIONS; i++) {                                  \
            uint32_t d[4], m[4], want[4], got[4], e;                                 \
            fill(d, 16);                                                             \
            fill(m, 16);                                                             \
            fill(&e, 4);                                                             \
            vst1q_u32(want, intrinsic(vld1q_u32(d), e, vld1q_u32(m)));               \
            memcpy(got, d, 16);                                                      \
            rellume_aarch64_##name(got, e, m);                                       \
            compare(#name, want, got, 16);                                           \
        }                                                                            \
    }

#define SHA_UNARY(name, intrinsic)                                                   \
    static void test_##name(void) {                                                  \
        for (unsigned i = 0; i < ITERATIONS; i++) {                                  \
            uint32_t d[4], n[4], want[4], got[4];                                    \
            fill(d, 16);                                                             \
            fill(n, 16);                                                             \
            vst1q_u32(want, intrinsic(vld1q_u32(d), vld1q_u32(n)));                  \
            memcpy(got, d, 16);                                                      \
            rellume_aarch64_##name(got, n);                                          \
            compare(#name, want, got, 16);                                           \
        }                                                                            \
    }

#define SHA_BINARY(name, intrinsic)                                                  \
    static void test_##name(void) {                                                  \
        for (unsigned i = 0; i < ITERATIONS; i++) {                                  \
            uint32_t d[4], n[4], m[4], want[4], got[4];                              \
            fill(d, 16);                                                             \
            fill(n, 16);                                                             \
            fill(m, 16);                                                             \
            vst1q_u32(want, intrinsic(vld1q_u32(d), vld1q_u32(n), vld1q_u32(m)));    \
            memcpy(got, d, 16);                                                      \
            rellume_aarch64_##name(got, n, m);                                       \
            compare(#name, want, got, 16);                                           \
        }                                                                            \
    }

AES_BINARY(aese, vaeseq_u8)
AES_BINARY(aesd, vaesdq_u8)
AES_UNARY(aesmc, vaesmcq_u8)
AES_UNARY(aesimc, vaesimcq_u8)

#define AES_EVERY_BYTE(name, intrinsic)                                              \
    static void test_every_byte_##name(void) {                                       \
        for (unsigned offset = 0; offset < 256; offset++) {                          \
            uint8_t d[16], n[16] = {0}, want[16], got[16];                           \
            for (unsigned i = 0; i < 16; i++) {                                      \
                d[i] = (uint8_t)(offset + i);                                        \
            }                                                                        \
            vst1q_u8(want, intrinsic(vld1q_u8(d), vld1q_u8(n)));                     \
            memcpy(got, d, 16);                                                      \
            rellume_aarch64_##name(got, n);                                          \
            compare(#name " every byte", want, got, 16);                             \
        }                                                                            \
    }

AES_EVERY_BYTE(aese, vaeseq_u8)
AES_EVERY_BYTE(aesd, vaesdq_u8)
SHA_ELEMENT(sha1c, vsha1cq_u32)
SHA_ELEMENT(sha1p, vsha1pq_u32)
SHA_ELEMENT(sha1m, vsha1mq_u32)
SHA_BINARY(sha1su0, vsha1su0q_u32)
SHA_UNARY(sha1su1, vsha1su1q_u32)
SHA_BINARY(sha256h, vsha256hq_u32)
SHA_BINARY(sha256h2, vsha256h2q_u32)
SHA_UNARY(sha256su0, vsha256su0q_u32)
SHA_BINARY(sha256su1, vsha256su1q_u32)

static void test_sha1h(void) {
    for (unsigned i = 0; i < ITERATIONS; i++) {
        uint32_t value;
        fill(&value, 4);
        uint32_t want = vsha1h_u32(value);
        uint32_t got = rotate_left(value, 30);
        compare("sha1h", &want, &got, 4);
    }
}

static void test_pmull8(void) {
    for (unsigned i = 0; i < ITERATIONS; i++) {
        uint64_t n, m;
        uint16_t want[8], got[8];
        fill(&n, 8);
        fill(&m, 8);
        poly8x8_t a = vcreate_p8(n), b = vcreate_p8(m);
        vst1q_u16(want, vreinterpretq_u16_p16(vmull_p8(a, b)));
        rellume_aarch64_pmull8(got, n, m);
        compare("pmull8", want, got, 16);
    }
}

static void test_pmull64(void) {
    for (unsigned i = 0; i < ITERATIONS; i++) {
        uint64_t n, m;
        poly128_t want;
        uint64_t got[2];
        fill(&n, 8);
        fill(&m, 8);
        want = vmull_p64((poly64_t)n, (poly64_t)m);
        rellume_aarch64_pmull64(got, n, m);
        compare("pmull64", &want, got, 16);
    }
}

static void hex(const uint8_t *bytes, size_t size, char *out) {
    for (size_t i = 0; i < size; i++) {
        sprintf(out + 2 * i, "%02x", bytes[i]);
    }
}

static void expect_hex(const char *name, const uint8_t *bytes, size_t size, const char *want) {
    char got[129];
    hex(bytes, size, got);
    comparisons++;
    if (strcmp(got, want) != 0) {
        if (failures++ < 10) {
            printf("MISMATCH %s\n  want %s\n  got  %s\n", name, want, got);
        }
    }
}

static void unhex(const char *text, uint8_t *bytes) {
    for (size_t i = 0; text[2 * i]; i++) {
        unsigned value;
        sscanf(text + 2 * i, "%2x", &value);
        bytes[i] = (uint8_t)value;
    }
}

static uint32_t substitute_word(uint32_t word) {
    uint8x16_t columns = vreinterpretq_u8_u32(vdupq_n_u32(word));
    return vgetq_lane_u32(vreinterpretq_u32_u8(vaeseq_u8(columns, vdupq_n_u8(0))), 0);
}

static void expand_key(const uint8_t *key, unsigned key_words, uint8_t schedule[][16]) {
    uint32_t words[60];
    static const uint8_t round_constants[10] = {0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36};
    unsigned rounds = key_words + 6;
    memcpy(words, key, 4 * key_words);
    for (unsigned i = key_words; i < 4 * (rounds + 1); i++) {
        uint32_t word = words[i - 1];
        if (i % key_words == 0) {
            word = substitute_word(rotate_right(word, 8));
            word ^= round_constants[i / key_words - 1];
        } else if (key_words > 6 && i % key_words == 4) {
            word = substitute_word(word);
        }
        words[i] = words[i - key_words] ^ word;
    }
    memcpy(schedule, words, 16 * (rounds + 1));
}

static void xor_block(uint8_t *a, const uint8_t *b) {
    for (unsigned i = 0; i < 16; i++) {
        a[i] ^= b[i];
    }
}

static void encrypt(const uint8_t schedule[][16], unsigned rounds, const uint8_t *in, uint8_t *out) {
    uint8_t state[16], mixed[16];
    memcpy(state, in, 16);
    for (unsigned r = 0; r < rounds - 1; r++) {
        rellume_aarch64_aese(state, schedule[r]);
        rellume_aarch64_aesmc(mixed, state);
        memcpy(state, mixed, 16);
    }
    rellume_aarch64_aese(state, schedule[rounds - 1]);
    xor_block(state, schedule[rounds]);
    memcpy(out, state, 16);
}

static void decrypt(const uint8_t schedule[][16], unsigned rounds, const uint8_t *in, uint8_t *out) {
    uint8_t state[16], mixed[16], inverse[15][16];
    memcpy(inverse[0], schedule[0], 16);
    for (unsigned r = 1; r < rounds; r++) {
        rellume_aarch64_aesimc(inverse[r], schedule[r]);
    }
    memcpy(inverse[rounds], schedule[rounds], 16);
    memcpy(state, in, 16);
    for (unsigned r = rounds; r > 1; r--) {
        rellume_aarch64_aesd(state, inverse[r]);
        rellume_aarch64_aesimc(mixed, state);
        memcpy(state, mixed, 16);
    }
    rellume_aarch64_aesd(state, inverse[1]);
    xor_block(state, inverse[0]);
    memcpy(out, state, 16);
}

static void test_fips197(void) {
    uint8_t key[32], plain[16], cipher[16], back[16], schedule[15][16];
    unhex("00112233445566778899aabbccddeeff", plain);
    unhex("000102030405060708090a0b0c0d0e0f", key);
    expand_key(key, 4, schedule);
    encrypt((const uint8_t(*)[16])schedule, 10, plain, cipher);
    expect_hex("FIPS-197 C.1 AES-128 encrypt", cipher, 16, "69c4e0d86a7b0430d8cdb78070b4c55a");
    decrypt((const uint8_t(*)[16])schedule, 10, cipher, back);
    expect_hex("FIPS-197 C.1 AES-128 decrypt", back, 16, "00112233445566778899aabbccddeeff");
    unhex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", key);
    expand_key(key, 8, schedule);
    encrypt((const uint8_t(*)[16])schedule, 14, plain, cipher);
    expect_hex("FIPS-197 C.3 AES-256 encrypt", cipher, 16, "8ea2b7ca516745bfeafc49904b496089");
    decrypt((const uint8_t(*)[16])schedule, 14, cipher, back);
    expect_hex("FIPS-197 C.3 AES-256 decrypt", back, 16, "00112233445566778899aabbccddeeff");
}

static const uint32_t sha256_k[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static uint32_t load_big_endian(const uint8_t *bytes) {
    return (uint32_t)bytes[0] << 24 | (uint32_t)bytes[1] << 16 | (uint32_t)bytes[2] << 8 | bytes[3];
}

static void sha256_block(uint32_t state[8], const uint8_t block[64]) {
    uint32_t w[16][4];
    uint32_t abcd[4], efgh[4], saved_abcd[4], saved_efgh[4];
    for (unsigned i = 0; i < 16; i++) {
        w[i / 4][i % 4] = load_big_endian(block + 4 * i);
    }
    memcpy(abcd, state, 16);
    memcpy(efgh, state + 4, 16);
    memcpy(saved_abcd, abcd, 16);
    memcpy(saved_efgh, efgh, 16);
    for (unsigned group = 0; group < 16; group++) {
        uint32_t wk[4], previous[4];
        for (unsigned i = 0; i < 4; i++) {
            wk[i] = w[group % 4][i] + sha256_k[4 * group + i];
        }
        memcpy(previous, abcd, 16);
        rellume_aarch64_sha256h(abcd, efgh, wk);
        rellume_aarch64_sha256h2(efgh, previous, wk);
        if (group < 12) {
            uint32_t *current = w[group % 4];
            uint32_t *one = w[(group + 1) % 4];
            uint32_t *two = w[(group + 2) % 4];
            uint32_t *three = w[(group + 3) % 4];
            rellume_aarch64_sha256su0(current, one);
            rellume_aarch64_sha256su1(current, two, three);
        }
    }
    for (unsigned i = 0; i < 4; i++) {
        state[i] = saved_abcd[i] + abcd[i];
        state[4 + i] = saved_efgh[i] + efgh[i];
    }
}

static void test_sha256_abc(void) {
    uint32_t state[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
    uint8_t block[64] = {'a', 'b', 'c', 0x80};
    uint8_t digest[32];
    block[63] = 24;
    sha256_block(state, block);
    for (unsigned i = 0; i < 8; i++) {
        digest[4 * i] = (uint8_t)(state[i] >> 24);
        digest[4 * i + 1] = (uint8_t)(state[i] >> 16);
        digest[4 * i + 2] = (uint8_t)(state[i] >> 8);
        digest[4 * i + 3] = (uint8_t)state[i];
    }
    expect_hex("FIPS 180-4 SHA-256 of abc", digest, 32, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
}

static void sha1_block(uint32_t state[5], const uint8_t block[64]) {
    uint32_t w[4][4];
    uint32_t abcd[4], e;
    static const uint32_t k[4] = {0x5a827999, 0x6ed9eba1, 0x8f1bbcdc, 0xca62c1d6};
    for (unsigned i = 0; i < 16; i++) {
        w[i / 4][i % 4] = load_big_endian(block + 4 * i);
    }
    memcpy(abcd, state, 16);
    e = state[4];
    for (unsigned group = 0; group < 20; group++) {
        uint32_t wk[4], next_e;
        for (unsigned i = 0; i < 4; i++) {
            wk[i] = w[group % 4][i] + k[group / 5];
        }
        next_e = rotate_left(abcd[0], 30);
        if (group < 5) {
            rellume_aarch64_sha1c(abcd, e, wk);
        } else if (group < 10) {
            rellume_aarch64_sha1p(abcd, e, wk);
        } else if (group < 15) {
            rellume_aarch64_sha1m(abcd, e, wk);
        } else {
            rellume_aarch64_sha1p(abcd, e, wk);
        }
        e = next_e;
        if (group < 16) {
            uint32_t *current = w[group % 4];
            rellume_aarch64_sha1su0(current, w[(group + 1) % 4], w[(group + 2) % 4]);
            rellume_aarch64_sha1su1(current, w[(group + 3) % 4]);
        }
    }
    for (unsigned i = 0; i < 4; i++) {
        state[i] += abcd[i];
    }
    state[4] += e;
}

static void test_sha1_abc(void) {
    uint32_t state[5] = {0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0};
    uint8_t block[64] = {'a', 'b', 'c', 0x80};
    uint8_t digest[20];
    block[63] = 24;
    sha1_block(state, block);
    for (unsigned i = 0; i < 5; i++) {
        digest[4 * i] = (uint8_t)(state[i] >> 24);
        digest[4 * i + 1] = (uint8_t)(state[i] >> 16);
        digest[4 * i + 2] = (uint8_t)(state[i] >> 8);
        digest[4 * i + 3] = (uint8_t)state[i];
    }
    expect_hex("FIPS 180-4 SHA-1 of abc", digest, 20, "a9993e364706816aba3e25717850c26c9cd0d89d");
}

int main(void) {
    test_aese();
    test_aesd();
    test_every_byte_aese();
    test_every_byte_aesd();
    test_aesmc();
    test_aesimc();
    test_sha1c();
    test_sha1p();
    test_sha1m();
    test_sha1h();
    test_sha1su0();
    test_sha1su1();
    test_sha256h();
    test_sha256h2();
    test_sha256su0();
    test_sha256su1();
    test_pmull8();
    test_pmull64();
    test_fips197();
    test_sha256_abc();
    test_sha1_abc();
    printf("%lu comparisons, %lu failures\n", comparisons, failures);
    return failures != 0;
}
