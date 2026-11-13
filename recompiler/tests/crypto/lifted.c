#include <arm_neon.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "xl_state.h"
#include "lifted.h"

enum { ITERATIONS = 4000 };

typedef struct {
    _Alignas(16) uint8_t bytes[XL_STATE_SIZE];
} state_t;

static uint64_t seed = 0x2545f4914f6cdd1dull;
static unsigned long failures;
static unsigned long comparisons;
static unsigned cases;

static uint64_t next_random(void) {
    seed ^= seed >> 12;
    seed ^= seed << 25;
    seed ^= seed >> 27;
    return seed * 0x9e3779b97f4a7c15ull;
}

static void randomize(state_t *state, unsigned iteration) {
    for (unsigned i = 0; i < XL_STATE_SIZE; i++) {
        state->bytes[i] = iteration == 0 ? 0 : iteration == 1 ? 0xff : (uint8_t)(next_random() >> 56);
    }
}

static uint8x16_t vector_at(const state_t *state, unsigned offset) {
    return vld1q_u8(state->bytes + offset);
}

static uint64_t scalar_at(const state_t *state, unsigned offset) {
    uint64_t value;
    memcpy(&value, state->bytes + offset, 8);
    return value;
}

static void report(const char *name, const void *want, const void *got, size_t size) {
    comparisons++;
    if (memcmp(want, got, size) != 0 && failures++ < 10) {
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

static void preserved(const char *name, const state_t *before, const state_t *after) {
    report(name, before->bytes + XL_OFFSET_X19, after->bytes + XL_OFFSET_X19, XL_OFFSET_TPIDRRO_EL0 - XL_OFFSET_X19);
    report(name, before->bytes + XL_OFFSET_V8, after->bytes + XL_OFFSET_V8, XL_OFFSET_V16 - XL_OFFSET_V8);
}

#define U32(v) vreinterpretq_u32_u8(v)
#define FROM_U32(v) vreinterpretq_u8_u32(v)

#define CASE(name, expression, in_x0_x1)                                             \
    static void case_##name(void) {                                                  \
        cases++;                                                                     \
        for (unsigned i = 0; i < ITERATIONS; i++) {                                  \
            state_t state, before;                                                   \
            randomize(&state, i);                                                    \
            before = state;                                                          \
            uint8x16_t v0 = vector_at(&state, XL_OFFSET_V0);                         \
            uint8x16_t v1 = vector_at(&state, XL_OFFSET_V1);                         \
            uint8x16_t v2 = vector_at(&state, XL_OFFSET_V2);                         \
            uint64_t x0 = scalar_at(&state, XL_OFFSET_X0);                           \
            uint64_t x1 = scalar_at(&state, XL_OFFSET_X1);                           \
            (void)v1;                                                                \
            (void)v2;                                                                \
            (void)x0;                                                                \
            (void)x1;                                                                \
            uint8_t want[16];                                                        \
            vst1q_u8(want, expression);                                              \
            SUB_##name(state.bytes);                                                 \
            report(#name, want, state.bytes + XL_OFFSET_V0, 16);                     \
            if (in_x0_x1) {                                                          \
                report(#name " x0:x1", want, state.bytes + XL_OFFSET_X0, 16);        \
            }                                                                        \
            preserved(#name, &before, &state);                                       \
        }                                                                            \
    }

CASE(crypto_aese, vaeseq_u8(v0, v1), 0)
CASE(crypto_aesd, vaesdq_u8(v0, v1), 0)
CASE(crypto_aesmc, vaesmcq_u8(v0), 0)
CASE(crypto_aesimc, vaesimcq_u8(v0), 0)
CASE(crypto_round, vaesmcq_u8(vaeseq_u8(v0, v1)), 0)
CASE(crypto_sha1c, FROM_U32(vsha1cq_u32(U32(v0), (uint32_t)x0, U32(v1))), 0)
CASE(crypto_sha1p, FROM_U32(vsha1pq_u32(U32(v0), (uint32_t)x0, U32(v1))), 0)
CASE(crypto_sha1m, FROM_U32(vsha1mq_u32(U32(v0), (uint32_t)x0, U32(v1))), 0)
CASE(crypto_sha1su0, FROM_U32(vsha1su0q_u32(U32(v0), U32(v1), U32(v2))), 0)
CASE(crypto_sha1su1, FROM_U32(vsha1su1q_u32(U32(v0), U32(v1))), 0)
CASE(crypto_sha256h, FROM_U32(vsha256hq_u32(U32(v0), U32(v1), U32(v2))), 0)
CASE(crypto_sha256h2, FROM_U32(vsha256h2q_u32(U32(v0), U32(v1), U32(v2))), 0)
CASE(crypto_sha256su0, FROM_U32(vsha256su0q_u32(U32(v0), U32(v1))), 0)
CASE(crypto_sha256su1, FROM_U32(vsha256su1q_u32(U32(v0), U32(v1), U32(v2))), 0)
CASE(crypto_pmull_8b, vreinterpretq_u8_p16(vmull_p8(vget_low_p8(vreinterpretq_p8_u8(v0)), vget_low_p8(vreinterpretq_p8_u8(v1)))), 0)
CASE(crypto_pmull2_16b, vreinterpretq_u8_p16(vmull_high_p8(vreinterpretq_p8_u8(v0), vreinterpretq_p8_u8(v1))), 0)
CASE(crypto_pmull_1d, vreinterpretq_u8_p128(vmull_p64((poly64_t)x0, (poly64_t)x1)), 1)
CASE(crypto_pmull2_2d, vreinterpretq_u8_p128(vmull_high_p64(vreinterpretq_p64_u8(v0), vreinterpretq_p64_u8(v1))), 1)

static void case_crypto_sha1h(void) {
    cases++;
    for (unsigned i = 0; i < ITERATIONS; i++) {
        state_t state, before;
        randomize(&state, i);
        before = state;
        uint64_t want = vsha1h_u32((uint32_t)scalar_at(&state, XL_OFFSET_X0));
        SUB_crypto_sha1h(state.bytes);
        uint64_t got = scalar_at(&state, XL_OFFSET_X0);
        report("crypto_sha1h", &want, &got, 8);
        preserved("crypto_sha1h", &before, &state);
    }
}

int main(void) {
    case_crypto_aese();
    case_crypto_aesd();
    case_crypto_aesmc();
    case_crypto_aesimc();
    case_crypto_round();
    case_crypto_sha1c();
    case_crypto_sha1p();
    case_crypto_sha1m();
    case_crypto_sha1h();
    case_crypto_sha1su0();
    case_crypto_sha1su1();
    case_crypto_sha256h();
    case_crypto_sha256h2();
    case_crypto_sha256su0();
    case_crypto_sha256su1();
    case_crypto_pmull_8b();
    case_crypto_pmull2_16b();
    case_crypto_pmull_1d();
    case_crypto_pmull2_2d();
    printf("%u functions, %lu comparisons, %lu failures\n", cases, comparisons, failures);
    return failures != 0;
}
