#include "RevenantMPSBilinear.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

static int checks;
static int failures;
static int negative;

static void check(int ok, const char *name)
{
    checks++;
    if (negative)
        ok = !ok;
    if (!ok) {
        failures++;
        printf("FAILED: %s\n", name);
    }
}

static void expectValues(const char *name, const float *actual, const float *expected, size_t count)
{
    int ok = 1;
    for (size_t i = 0; i < count; i++)
        if (fabsf(actual[i] - expected[i]) > 1e-6f)
            ok = 0;
    check(ok, name);
}

static int resampleRow(const float *source, size_t sourceWidth, size_t destinationWidth, int edgeMode,
                       double scale, double translate, float *output)
{
    RevenantMPSBilinearTransform transform = {scale, 1.0, translate, 0.0};
    return RevenantMPSBilinearResample(source, sourceWidth, 1, 1, edgeMode, transform, output, 0, 0, destinationWidth, 1);
}

int main(int argc, char **argv)
{
    negative = argc > 1 && strcmp(argv[1], "--negative") == 0;

    const float ramp7[7] = {0, 1, 2, 3, 4, 5, 6};
    const float ramp9[9] = {0, 1, 2, 3, 4, 5, 6, 7, 8};
    const float ramp16[16] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
    const float ramp4[4] = {0, 1, 2, 3};
    const float ramp8[8] = {0, 1, 2, 3, 4, 5, 6, 7};

    float out[16];
    const float downscale7to3[3] = {0.66796875f, 3.0f, 5.33203125f};
    check(resampleRow(ramp7, 7, 3, RevenantMPSBilinearEdgeClamp, 3.0 / 7.0, 0.0, out) == 1, "clamp resample is supported");
    expectValues("default 7 to 3 samples the centre-mapped positions at 1/256 steps", out, downscale7to3, 3);

    const float downscale9to4[4] = {0.625f, 2.875f, 5.125f, 7.375f};
    check(resampleRow(ramp9, 9, 4, RevenantMPSBilinearEdgeClamp, 4.0 / 9.0, 0.0, out) == 1, "clamp resample is supported");
    expectValues("default 9 to 4 samples the centre-mapped positions", out, downscale9to4, 4);

    const float downscale16to7[7] = {0.64453125f, 2.9296875f, 5.21484375f, 7.5f, 9.78515625f, 12.0703125f, 14.35546875f};
    check(resampleRow(ramp16, 16, 7, RevenantMPSBilinearEdgeClamp, 7.0 / 16.0, 0.0, out) == 1, "clamp resample is supported");
    expectValues("default 16 to 7 rounds each fraction to 1/256", out, downscale16to7, 7);

    const float upscaleClamp[8] = {0, 0.25f, 0.75f, 1.25f, 1.75f, 2.25f, 2.75f, 3.0f};
    check(resampleRow(ramp4, 4, 8, RevenantMPSBilinearEdgeClamp, 2.0, 0.0, out) == 1, "clamp resample is supported");
    expectValues("clamp edge repeats the first and last sample", out, upscaleClamp, 8);

    const float upscaleZero[8] = {0, 0.25f, 0.75f, 1.25f, 1.75f, 2.25f, 2.75f, 2.25f};
    check(resampleRow(ramp4, 4, 8, RevenantMPSBilinearEdgeZero, 2.0, 0.0, out) == 1, "zero resample is supported");
    expectValues("zero edge contributes nothing outside the source", out, upscaleZero, 8);

    const float translated[4] = {0, 1.5f, 3.5f, 5.5f};
    check(resampleRow(ramp8, 8, 4, RevenantMPSBilinearEdgeZero, 0.5, 0.5, out) == 1, "zero resample is supported");
    expectValues("translate shifts the mapping: dest = src * scale + translate", out, translated, 4);
    check(resampleRow(ramp8, 8, 4, RevenantMPSBilinearEdgeClamp, 0.5, 0.5, out) == 1, "clamp resample is supported");
    expectValues("translate with clamp keeps the clamped first sample", out, translated, 4);

    float field[7 * 5];
    for (size_t y = 0; y < 5; y++)
        for (size_t x = 0; x < 7; x++)
            field[y * 7 + x] = (float)(x + 10 * y);
    const float horizontal[3] = {0.66796875f, 3.0f, 5.33203125f};
    const float vertical[2] = {0.75f, 3.25f};
    float expected2D[6];
    for (size_t j = 0; j < 2; j++)
        for (size_t i = 0; i < 3; i++)
            expected2D[j * 3 + i] = horizontal[i] + 10.0f * vertical[j];
    RevenantMPSBilinearTransform default2D = {3.0 / 7.0, 2.0 / 5.0, 0.0, 0.0};
    check(RevenantMPSBilinearResample(field, 7, 5, 1, RevenantMPSBilinearEdgeClamp, default2D, out, 0, 0, 3, 2) == 1,
          "two-dimensional clamp resample is supported");
    expectValues("a linear field resamples to the quantised positions in both axes", out, expected2D, 6);

    const float region[2] = {expected2D[4], expected2D[5]};
    float regionOut[2];
    check(RevenantMPSBilinearResample(field, 7, 5, 1, RevenantMPSBilinearEdgeClamp, default2D, regionOut, 1, 1, 2, 1) == 1,
          "a region of the destination is supported");
    expectValues("a region keeps the destination coordinates of the whole image", regionOut, region, 2);

    float untouched[4] = {-7, -7, -7, -7};
    check(resampleRow(ramp4, 4, 4, 2, 1.0, 0.0, untouched) == 0, "mirror edge is refused");
    const float sentinel[4] = {-7, -7, -7, -7};
    expectValues("a refused resample writes nothing", untouched, sentinel, 4);

    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}
