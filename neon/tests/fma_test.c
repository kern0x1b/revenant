#include <arm_neon.h>
#include "revenant_neon_fma.h"
#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define SAMPLES (1u << 20)
#define SPECIAL_VALUES 11
#define SPECIAL_COUNT 1332

static uint64_t state = 0x2545F4914F6CDD1DULL;
static int fails;
static float random_a[SAMPLES], random_b[SAMPLES], random_c[SAMPLES];
static float special_a[SPECIAL_COUNT], special_b[SPECIAL_COUNT], special_c[SPECIAL_COUNT];

static uint32_t next32(void)
{
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return (uint32_t)(state >> 16);
}

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static int same_float(float got, float want)
{
    if (isnan(got) || isnan(want))
        return isnan(got) && isnan(want);
    uint32_t a, b;
    memcpy(&a, &got, sizeof a);
    memcpy(&b, &want, sizeof b);
    return a == b;
}

static size_t differing_lanes(const float *a, const float *b, const float *c, size_t count)
{
    size_t differ = 0;
    for (size_t i = 0; i + 4 <= count; i += 4) {
        float shim[4], native[4];
        vst1q_f32(shim, revenant_vfmaq_f32(vld1q_f32(a + i), vld1q_f32(b + i), vld1q_f32(c + i)));
        vst1q_f32(native, vfmaq_f32(vld1q_f32(a + i), vld1q_f32(b + i), vld1q_f32(c + i)));
        for (int lane = 0; lane < 4; lane++) {
            if (!same_float(shim[lane], native[lane]))
                differ++;
        }
    }
    return differ;
}

static void fill_specials(void)
{
    const float values[SPECIAL_VALUES] = {0.0f, -0.0f, 1.0f, -1.0f, 1e-40f, -1e-40f, INFINITY, -INFINITY, NAN, FLT_MAX, FLT_MIN};
    size_t index = 0;
    for (int i = 0; i < SPECIAL_VALUES; i++)
        for (int j = 0; j < SPECIAL_VALUES; j++)
            for (int k = 0; k < SPECIAL_VALUES; k++) {
                special_a[index] = values[i];
                special_b[index] = values[j];
                special_c[index] = values[k];
                index++;
            }
    special_a[index] = special_b[index] = special_c[index] = 0.0f;
}

int main(void)
{
    for (size_t i = 0; i < SAMPLES; i++) {
        uint32_t bits[3] = {next32() << 16 ^ next32(), next32() << 16 ^ next32(), next32() << 16 ^ next32()};
        memcpy(&random_a[i], &bits[0], sizeof bits[0]);
        memcpy(&random_b[i], &bits[1], sizeof bits[1]);
        memcpy(&random_c[i], &bits[2], sizeof bits[2]);
    }
    size_t differ = differing_lanes(random_a, random_b, random_c, SAMPLES);
    printf("vfmaq_f32: %zu lanes differ from the native fused intrinsic over %u random groups\n", differ, SAMPLES);
    expect(differ == 0, "every random lane is the native fused multiply-add, bit for bit");

    fill_specials();
    expect(differing_lanes(special_a, special_b, special_c, SPECIAL_COUNT) == 0,
           "every combination of zeros, ones, denormals, infinities, NaN and the largest and smallest normal is native, bit for bit");

    float single_rounding_a = -(1.0f + ldexpf(1.0f, -11));
    float single_rounding_b = 1.0f + ldexpf(1.0f, -12);
    float out[4];
    vst1q_f32(out, revenant_vfmaq_f32(vdupq_n_f32(single_rounding_a), vdupq_n_f32(single_rounding_b), vdupq_n_f32(single_rounding_b)));
    expect(out[0] == ldexpf(1.0f, -24), "the product rounds once: -(1 + 2^-11) + (1 + 2^-12)^2 is 2^-24, not 0");

    if (fails == 0)
        printf("vfmaq_f32: all checks passed\n");
    return fails != 0;
}
