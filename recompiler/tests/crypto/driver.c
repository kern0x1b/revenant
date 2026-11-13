#include <arm_neon.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "../../src/runtime/crypto.c"
#include "../../src/runtime/half.c"

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

static uint16_t carryless_product8(uint8_t n, uint8_t m) {
    uint16_t product = 0;
    for (unsigned bit = 0; bit < 8; bit++) {
        product ^= (uint16_t)((uint16_t)n << bit) & (uint16_t)-((m >> bit) & 1);
    }
    return product;
}

static void test_pmull8(void) {
    for (unsigned i = 0; i < ITERATIONS; i++) {
        uint64_t n, m;
        uint16_t want[8], got[8];
        fill(&n, 8);
        fill(&m, 8);
        for (unsigned lane = 0; lane < 8; lane++) {
            want[lane] = carryless_product8((uint8_t)(n >> (8 * lane)), (uint8_t)(m >> (8 * lane)));
        }
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

static uint16_t half_bits(_Float16 value) {
    uint16_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static _Float16 half_of(uint16_t bits) {
    _Float16 value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static uint32_t single_bits(float value) {
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static float single_of(uint32_t bits) {
    float value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static uint64_t double_bits(double value) {
    uint64_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static double double_of(uint64_t bits) {
    double value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static void compare_scalar(const char *name, uint64_t input, uint64_t want, uint64_t got) {
    comparisons++;
    if (want != got && failures++ < 10) {
        printf("MISMATCH %s of %016llx\n  want %016llx\n  got  %016llx\n", name, (unsigned long long)input, (unsigned long long)want, (unsigned long long)got);
    }
}

static void test_widen_every_half(void) {
    for (uint32_t bits = 0; bits < 0x10000; bits++) {
        compare_scalar("fcvt s, h", bits, single_bits((float)half_of((uint16_t)bits)), single_bits(rellume_aarch64_fcvt_s_h(bits)));
        compare_scalar("fcvt d, h", bits, double_bits((double)half_of((uint16_t)bits)), double_bits(rellume_aarch64_fcvt_d_h(bits)));
    }
}

static void check_single_to_half(float value) {
    compare_scalar("fcvt h, s", single_bits(value), half_bits((_Float16)value), rellume_aarch64_fcvt_h_s(value));
}

static void check_double_to_half(double value) {
    compare_scalar("fcvt h, d", double_bits(value), half_bits((_Float16)value), rellume_aarch64_fcvt_h_d(value));
}

static void test_narrow_around_every_half(void) {
    for (uint32_t bits = 0; bits < 0x7c00; bits++) {
        float low = (float)half_of((uint16_t)bits);
        float high = (float)half_of((uint16_t)(bits + 1));
        float middle = (float)((double)low / 2 + (double)high / 2);
        double wide_low = (double)low, wide_middle = (double)middle;
        float singles[] = {low, nextafterf(low, INFINITY), nextafterf(low, -INFINITY), middle, nextafterf(middle, INFINITY), nextafterf(middle, -INFINITY)};
        double doubles[] = {wide_low, nextafter(wide_low, INFINITY), nextafter(wide_low, -INFINITY), wide_middle, nextafter(wide_middle, INFINITY),
                            nextafter(wide_middle, -INFINITY)};
        for (unsigned i = 0; i < 6; i++) {
            check_single_to_half(singles[i]);
            check_single_to_half(-singles[i]);
            check_double_to_half(doubles[i]);
            check_double_to_half(-doubles[i]);
        }
    }
}

static void test_narrow_random(void) {
    static const uint32_t quiet_and_signaling[] = {0x7f800000u, 0xff800000u, 0x7f800001u, 0x7fa00000u, 0x7fc00000u, 0xff8abcdeu, 0x7fffffffu, 0x00000001u, 0x007fffffu, 0x80000001u};
    for (unsigned i = 0; i < sizeof(quiet_and_signaling) / sizeof(*quiet_and_signaling); i++) {
        check_single_to_half(single_of(quiet_and_signaling[i]));
        check_double_to_half(double_of((uint64_t)quiet_and_signaling[i] << 32 | quiet_and_signaling[i]));
    }
    for (unsigned i = 0; i < 4 * ITERATIONS; i++) {
        uint64_t random = next_random();
        check_single_to_half(single_of((uint32_t)random));
        check_double_to_half(double_of(random));
        int exponent = (int)(next_random() >> 59) - 28;
        uint64_t mantissa = next_random() & ((UINT64_C(1) << 52) - 1);
        check_double_to_half(double_of((random & (UINT64_C(1) << 63)) | (uint64_t)(1023 + exponent) << 52 | mantissa));
        check_single_to_half(single_of((uint32_t)((random >> 32) & 0x80000000u) | (uint32_t)(127 + exponent) << 23 | (uint32_t)(mantissa >> 29)));
    }
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
    test_widen_every_half();
    test_narrow_around_every_half();
    test_narrow_random();
    printf("%lu comparisons, %lu failures\n", comparisons, failures);
    return failures != 0;
}
