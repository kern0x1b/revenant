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

static void vector_aese(uint8_t *d, const uint8_t *n) { rellume_aarch64_aese(d, n); }
static void vector_aesd(uint8_t *d, const uint8_t *n) { rellume_aarch64_aesd(d, n); }
static void vector_aesmc(uint8_t *d, const uint8_t *n) { rellume_aarch64_aesmc(d, n); }
static void vector_aesimc(uint8_t *d, const uint8_t *n) { rellume_aarch64_aesimc(d, n); }
static void vector_sha1c(uint32_t *d, uint32_t e, const uint32_t *w) { rellume_aarch64_sha1c(d, e, w); }
static void vector_sha1p(uint32_t *d, uint32_t e, const uint32_t *w) { rellume_aarch64_sha1p(d, e, w); }
static void vector_sha1m(uint32_t *d, uint32_t e, const uint32_t *w) { rellume_aarch64_sha1m(d, e, w); }
static void vector_sha1su0(uint32_t *d, const uint32_t *n, const uint32_t *m) { rellume_aarch64_sha1su0(d, n, m); }
static void vector_sha1su1(uint32_t *d, const uint32_t *n) { rellume_aarch64_sha1su1(d, n); }
static void vector_sha256h(uint32_t *d, const uint32_t *n, const uint32_t *m) { rellume_aarch64_sha256h(d, n, m); }
static void vector_sha256h2(uint32_t *d, const uint32_t *n, const uint32_t *m) { rellume_aarch64_sha256h2(d, n, m); }
static void vector_sha256su0(uint32_t *d, const uint32_t *n) { rellume_aarch64_sha256su0(d, n); }
static void vector_sha256su1(uint32_t *d, const uint32_t *n, const uint32_t *m) { rellume_aarch64_sha256su1(d, n, m); }

#include "vectors.h"

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
