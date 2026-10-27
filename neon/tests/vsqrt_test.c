#include <arm_neon.h>
#include "revenant_neon_sqrt.h"
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define SAMPLES (1u << 20)
#define MAX_ULP 2

static uint64_t state = 0x9E3779B97F4A7C15ULL;
static int fails;

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

static int32_t ulps(float got, float want)
{
    int32_t a, b;
    if (isnan(got) || isnan(want))
        return isnan(got) && isnan(want) ? 0 : INT32_MAX;
    memcpy(&a, &got, sizeof a);
    memcpy(&b, &want, sizeof b);
    return a > b ? a - b : b - a;
}

static int32_t worst_ulp(const float *in, size_t count, size_t *exact)
{
    int32_t worst = 0;
    for (size_t i = 0; i + 4 <= count; i += 4) {
        float lanes[4];
        vst1q_f32(lanes, revenant_vsqrtq_f32(vld1q_f32(in + i)));
        for (int lane = 0; lane < 4; lane++) {
            int32_t d = ulps(lanes[lane], sqrtf(in[i + lane]));
            if (d == 0 && exact)
                (*exact)++;
            if (d > worst)
                worst = d;
        }
    }
    return worst;
}

static void special_case(float input, float expected, const char *what)
{
    float lane[4] = {input, input, input, input};
    float out[4];
    vst1q_f32(out, revenant_vsqrtq_f32(vld1q_f32(lane)));
    int ok = isnan(expected) ? isnan(out[0]) : (signbit(out[0]) == signbit(expected) && out[0] == expected);
    expect(ok, what);
}

int main(void)
{
    static float random_normals[SAMPLES];
    for (size_t i = 0; i < SAMPLES; i++) {
        uint32_t bits = (next32() & 0x007fffffu) | ((1u + next32() % 254u) << 23);
        memcpy(&random_normals[i], &bits, sizeof bits);
    }
    size_t exact = 0;
    int32_t worst = worst_ulp(random_normals, SAMPLES, &exact);
    printf("vsqrtq_f32: %d ulp at most over %u random normals, %.2f%% correctly rounded\n", worst, SAMPLES,
           100.0 * (double)exact / (double)SAMPLES);
    expect(worst <= MAX_ULP, "the root of a random normal is within two ulp of sqrtf");

    special_case(0.0f, 0.0f, "sqrt(+0) is +0");
    special_case(-0.0f, -0.0f, "sqrt(-0) is -0");
    special_case(INFINITY, INFINITY, "sqrt(+inf) is +inf");
    special_case(-1.0f, NAN, "sqrt of a negative number is NaN");
    special_case(-INFINITY, NAN, "sqrt(-inf) is NaN");
    special_case(NAN, NAN, "sqrt(NaN) is NaN");
    special_case(-1e-40f, NAN, "sqrt of a negative denormal is NaN");

    float flushed[4];
    vst1q_f32(flushed, revenant_vsqrtq_f32(vdupq_n_f32(1e-40f)));
    expect(flushed[0] == 0.0f || ulps(flushed[0], sqrtf(1e-40f)) <= MAX_ULP,
           "a positive denormal gives zero, as NEON flushes it, or its root within two ulp");

    float exact_inputs[8] = {1.0f, 4.0f, 9.0f, 0.25f, 16.0f, 100.0f, 3.4028235e38f, 1e-30f};
    size_t exact_count = 0;
    int32_t exact_worst = worst_ulp(exact_inputs, 8, &exact_count);
    expect(exact_worst <= MAX_ULP, "the roots of 1, 4, 9, 0.25, 16, 100, FLT_MAX and 1e-30 are within two ulp");

    if (fails == 0)
        printf("vsqrtq_f32: all checks passed\n");
    return fails != 0;
}
