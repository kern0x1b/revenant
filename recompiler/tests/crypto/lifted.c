#include <arm_neon.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "xl_state.h"
#include "carry.h"
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

static uint64_t edge_value(void) {
    static const uint64_t special[] = {0, 1, 2, UINT64_MAX, UINT64_MAX - 1, INT64_MAX, (uint64_t)INT64_MIN, UINT32_MAX, INT32_MAX, UINT64_C(0x80000000)};
    uint64_t value = next_random();
    unsigned choice = (unsigned)(next_random() % 16);
    return choice < sizeof(special) / sizeof(special[0]) ? special[choice] : value;
}

static void put_scalars(state_t *state, uint64_t x0, uint64_t x1, uint64_t x2) {
    memcpy(state->bytes + XL_OFFSET_X0, &x0, 8);
    memcpy(state->bytes + XL_OFFSET_X1, &x1, 8);
    memcpy(state->bytes + XL_OFFSET_X2, &x2, 8);
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

#define CASE_PREPARED(name, expression, in_x0_x1, prepare)                            \
    static void case_##name(void) {                                                  \
        cases++;                                                                     \
        for (unsigned i = 0; i < ITERATIONS; i++) {                                  \
            state_t state, before;                                                   \
            randomize(&state, i);                                                    \
            prepare;                                                                 \
            before = state;                                                          \
            uint8x16_t v0 = vector_at(&state, XL_OFFSET_V0);                         \
            uint8x16_t v1 = vector_at(&state, XL_OFFSET_V1);                         \
            uint8x16_t v2 = vector_at(&state, XL_OFFSET_V2);                         \
            uint64_t x0 = scalar_at(&state, XL_OFFSET_X0);                           \
            uint64_t x1 = scalar_at(&state, XL_OFFSET_X1);                           \
            uint64_t x2 = scalar_at(&state, XL_OFFSET_X2);                           \
            (void)v1;                                                                \
            (void)v2;                                                                \
            (void)x0;                                                                \
            (void)x1;                                                                \
            (void)x2;                                                                \
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

#define CASE(name, expression, in_x0_x1) CASE_PREPARED(name, expression, in_x0_x1, (void)0)

#define LANE16(value) vreinterpretq_u8_u16(vsetq_lane_u16((value), vdupq_n_u16(0), 0))
#define LANE32(value) vreinterpretq_u8_u32(vsetq_lane_u32((value), vdupq_n_u32(0), 0))
#define LANE64(value) vreinterpretq_u8_u64(vsetq_lane_u64((value), vdupq_n_u64(0), 0))
#define HALF_LANE(value) LANE16(half_bits(value))
#define SINGLE_LANE(value) vreinterpretq_u8_f32(vsetq_lane_f32((value), vdupq_n_f32(0), 0))
#define DOUBLE_LANE(value) vreinterpretq_u8_f64(vsetq_lane_f64((value), vdupq_n_f64(0), 0))

static uint16_t half_bits(_Float16 value) {
    uint16_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static _Float16 first_half(uint8x16_t vector) {
    uint16_t bits = vgetq_lane_u16(vreinterpretq_u16_u8(vector), 0);
    _Float16 value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static float first_single(uint8x16_t vector) { return vgetq_lane_f32(vreinterpretq_f32_u8(vector), 0); }
static double first_double(uint8x16_t vector) { return vgetq_lane_f64(vreinterpretq_f64_u8(vector), 0); }

CASE(crypto_aese, vaeseq_u8(v0, v1), 0)
CASE(crypto_aesd, vaesdq_u8(v0, v1), 0)
CASE(crypto_aesmc, vaesmcq_u8(v0), 0)
CASE(crypto_aesimc, vaesimcq_u8(v0), 0)
CASE(crypto_round, vaesmcq_u8(vaeseq_u8(v0, v1)), 0)
CASE(crypto_trn1_16b, vtrn1q_u8(v0, v1), 0)
CASE(crypto_trn2_16b, vtrn2q_u8(v0, v1), 0)
CASE(crypto_trn1_8h, vreinterpretq_u8_u16(vtrn1q_u16(vreinterpretq_u16_u8(v0), vreinterpretq_u16_u8(v1))), 0)
CASE(crypto_trn2_8h, vreinterpretq_u8_u16(vtrn2q_u16(vreinterpretq_u16_u8(v0), vreinterpretq_u16_u8(v1))), 0)
CASE(crypto_trn1_4s, FROM_U32(vtrn1q_u32(U32(v0), U32(v1))), 0)
CASE(crypto_trn2_4s, FROM_U32(vtrn2q_u32(U32(v0), U32(v1))), 0)
CASE(crypto_trn1_2d, vreinterpretq_u8_u64(vtrn1q_u64(vreinterpretq_u64_u8(v0), vreinterpretq_u64_u8(v1))), 0)
CASE(crypto_trn2_2d, vreinterpretq_u8_u64(vtrn2q_u64(vreinterpretq_u64_u8(v0), vreinterpretq_u64_u8(v1))), 0)
CASE(crypto_trn1_8b, vcombine_u8(vtrn1_u8(vget_low_u8(v0), vget_low_u8(v1)), vdup_n_u8(0)), 0)
CASE(crypto_trn2_8b, vcombine_u8(vtrn2_u8(vget_low_u8(v0), vget_low_u8(v1)), vdup_n_u8(0)), 0)
CASE(crypto_sli_16b, vsliq_n_u8(v0, v1, 3), 0)
CASE(crypto_sli_8h, vreinterpretq_u8_u16(vsliq_n_u16(vreinterpretq_u16_u8(v0), vreinterpretq_u16_u8(v1), 5)), 0)
CASE(crypto_sli_4s, vreinterpretq_u8_u32(vsliq_n_u32(vreinterpretq_u32_u8(v0), vreinterpretq_u32_u8(v1), 12)), 0)
CASE(crypto_sli_2d, vreinterpretq_u8_u64(vsliq_n_u64(vreinterpretq_u64_u8(v0), vreinterpretq_u64_u8(v1), 40)), 0)
CASE(crypto_sli_8b, vcombine_u8(vsli_n_u8(vget_low_u8(v0), vget_low_u8(v1), 7), vdup_n_u8(0)), 0)
CASE(crypto_sli_4h, vcombine_u8(vreinterpret_u8_u16(vsli_n_u16(vreinterpret_u16_u8(vget_low_u8(v0)), vreinterpret_u16_u8(vget_low_u8(v1)), 1)), vdup_n_u8(0)), 0)
CASE(crypto_sli_2s, vcombine_u8(vreinterpret_u8_u32(vsli_n_u32(vreinterpret_u32_u8(vget_low_u8(v0)), vreinterpret_u32_u8(vget_low_u8(v1)), 31)), vdup_n_u8(0)), 0)
CASE(crypto_sli_d, vreinterpretq_u8_u64(vcombine_u64(vsli_n_u64(vget_low_u64(vreinterpretq_u64_u8(v0)), vget_low_u64(vreinterpretq_u64_u8(v1)), 17), vdup_n_u64(0))), 0)
CASE(crypto_sri_16b, vsriq_n_u8(v0, v1, 3), 0)
CASE(crypto_sri_8h, vreinterpretq_u8_u16(vsriq_n_u16(vreinterpretq_u16_u8(v0), vreinterpretq_u16_u8(v1), 5)), 0)
CASE(crypto_sri_4s, vreinterpretq_u8_u32(vsriq_n_u32(vreinterpretq_u32_u8(v0), vreinterpretq_u32_u8(v1), 12)), 0)
CASE(crypto_sri_2d, vreinterpretq_u8_u64(vsriq_n_u64(vreinterpretq_u64_u8(v0), vreinterpretq_u64_u8(v1), 40)), 0)
CASE(crypto_sri_8b, vcombine_u8(vsri_n_u8(vget_low_u8(v0), vget_low_u8(v1), 7), vdup_n_u8(0)), 0)
CASE(crypto_sri_4h, vcombine_u8(vreinterpret_u8_u16(vsri_n_u16(vreinterpret_u16_u8(vget_low_u8(v0)), vreinterpret_u16_u8(vget_low_u8(v1)), 1)), vdup_n_u8(0)), 0)
CASE(crypto_sri_2s, vcombine_u8(vreinterpret_u8_u32(vsri_n_u32(vreinterpret_u32_u8(vget_low_u8(v0)), vreinterpret_u32_u8(vget_low_u8(v1)), 31)), vdup_n_u8(0)), 0)
CASE(crypto_sri_d, vreinterpretq_u8_u64(vcombine_u64(vsri_n_u64(vget_low_u64(vreinterpretq_u64_u8(v0)), vget_low_u64(vreinterpretq_u64_u8(v1)), 17), vdup_n_u64(0))), 0)
CASE(crypto_sli_4s_by_0, vreinterpretq_u8_u32(vsliq_n_u32(vreinterpretq_u32_u8(v0), vreinterpretq_u32_u8(v1), 0)), 0)
CASE(crypto_sri_4s_by_32, vreinterpretq_u8_u32(vsriq_n_u32(vreinterpretq_u32_u8(v0), vreinterpretq_u32_u8(v1), 32)), 0)
CASE(crypto_uaddlv_16b, LANE16((uint16_t)vaddlvq_u8(v0)), 0)
CASE(crypto_uaddlv_8b, LANE16((uint16_t)vaddlv_u8(vget_low_u8(v0))), 0)
CASE(crypto_uaddlv_8h, LANE32((uint32_t)vaddlvq_u16(vreinterpretq_u16_u8(v0))), 0)
CASE(crypto_uaddlv_4h, LANE32((uint32_t)vaddlv_u16(vreinterpret_u16_u8(vget_low_u8(v0)))), 0)
CASE(crypto_uaddlv_4s, LANE64((uint64_t)vaddlvq_u32(vreinterpretq_u32_u8(v0))), 0)
CASE(crypto_saddlv_16b, LANE16((uint16_t)vaddlvq_s8(vreinterpretq_s8_u8(v0))), 0)
CASE(crypto_saddlv_8b, LANE16((uint16_t)vaddlv_s8(vreinterpret_s8_u8(vget_low_u8(v0)))), 0)
CASE(crypto_saddlv_8h, LANE32((uint32_t)vaddlvq_s16(vreinterpretq_s16_u8(v0))), 0)
CASE(crypto_saddlv_4h, LANE32((uint32_t)vaddlv_s16(vreinterpret_s16_u8(vget_low_u8(v0)))), 0)
CASE(crypto_saddlv_4s, LANE64((uint64_t)vaddlvq_s32(vreinterpretq_s32_u8(v0))), 0)
CASE(crypto_fcvt_h_s, HALF_LANE((_Float16)first_single(v0)), 0)
CASE(crypto_fcvt_h_d, HALF_LANE((_Float16)first_double(v0)), 0)
CASE(crypto_fcvt_s_h, SINGLE_LANE((float)first_half(v0)), 0)
CASE(crypto_fcvt_d_h, DOUBLE_LANE((double)first_half(v0)), 0)
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

CASE_PREPARED(crypto_adc_x, vreinterpretq_u8_u64(carry_adc_x(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_adc_w, vreinterpretq_u8_u64(carry_adc_w(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_adcs_x, vreinterpretq_u8_u64(carry_adcs_x(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_adcs_w, vreinterpretq_u8_u64(carry_adcs_w(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_sbc_x, vreinterpretq_u8_u64(carry_sbc_x(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_sbc_w, vreinterpretq_u8_u64(carry_sbc_w(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_sbcs_x, vreinterpretq_u8_u64(carry_sbcs_x(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_sbcs_w, vreinterpretq_u8_u64(carry_sbcs_w(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_ngc_x, vreinterpretq_u8_u64(carry_ngc_x(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_ngcs_x, vreinterpretq_u8_u64(carry_ngcs_x(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_ngcs_w, vreinterpretq_u8_u64(carry_ngcs_w(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() & 7))
CASE_PREPARED(crypto_final_reduction, vreinterpretq_u8_u64(carry_final_reduction(x0, x1, x2)), 0, put_scalars(&state, edge_value(), edge_value(), next_random() % 5))

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
    case_crypto_trn1_16b();
    case_crypto_trn2_16b();
    case_crypto_trn1_8h();
    case_crypto_trn2_8h();
    case_crypto_trn1_4s();
    case_crypto_trn2_4s();
    case_crypto_trn1_2d();
    case_crypto_trn2_2d();
    case_crypto_trn1_8b();
    case_crypto_trn2_8b();
    case_crypto_sli_16b();
    case_crypto_sli_8h();
    case_crypto_sli_4s();
    case_crypto_sli_2d();
    case_crypto_sli_8b();
    case_crypto_sli_4h();
    case_crypto_sli_2s();
    case_crypto_sli_d();
    case_crypto_sri_16b();
    case_crypto_sri_8h();
    case_crypto_sri_4s();
    case_crypto_sri_2d();
    case_crypto_sri_8b();
    case_crypto_sri_4h();
    case_crypto_sri_2s();
    case_crypto_sri_d();
    case_crypto_sli_4s_by_0();
    case_crypto_sri_4s_by_32();
    case_crypto_uaddlv_16b();
    case_crypto_uaddlv_8b();
    case_crypto_uaddlv_8h();
    case_crypto_uaddlv_4h();
    case_crypto_uaddlv_4s();
    case_crypto_saddlv_16b();
    case_crypto_saddlv_8b();
    case_crypto_saddlv_8h();
    case_crypto_saddlv_4h();
    case_crypto_saddlv_4s();
    case_crypto_fcvt_h_s();
    case_crypto_fcvt_h_d();
    case_crypto_fcvt_s_h();
    case_crypto_fcvt_d_h();
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
    case_crypto_adc_x();
    case_crypto_adc_w();
    case_crypto_adcs_x();
    case_crypto_adcs_w();
    case_crypto_sbc_x();
    case_crypto_sbc_w();
    case_crypto_sbcs_x();
    case_crypto_sbcs_w();
    case_crypto_ngc_x();
    case_crypto_ngcs_x();
    case_crypto_ngcs_w();
    case_crypto_final_reduction();
    printf("%u functions, %lu comparisons, %lu failures\n", cases, comparisons, failures);
    return failures != 0;
}
