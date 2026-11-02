#include <Accelerate/Accelerate.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

vImage_Error vImageScale_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImage_Flags flags);
vImage_Error vImageScale_Planar16U(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImage_Flags flags);

typedef vImage_Error (*scale_function)(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);

struct scale_case {
    const char *name;
    unsigned channels;
    unsigned sw, sh, dw, dh;
    double bound;
    double ramp_bound;
};

static const struct scale_case cases[] = {
    {"argb 8x6 to 4x3", 4, 8, 6, 4, 3, 9905, 33},
    {"argb 9x7 to 4x3", 4, 9, 7, 4, 3, 4645, 116},
    {"argb 3x2 to 7x5", 4, 3, 2, 7, 5, 10648, 151},
    {"argb 4x4 to 8x8", 4, 4, 4, 8, 8, 12031, 139},
    {"planar 8x6 to 4x3", 1, 8, 6, 4, 3, 10173, 33},
    {"planar 9x7 to 4x3", 1, 9, 7, 4, 3, 5407, 116},
    {"planar 3x2 to 7x5", 1, 3, 2, 7, 5, 10243, 151},
    {"planar 4x4 to 8x8", 1, 4, 4, 8, 8, 7119, 139},
};

static scale_function apple_scale(unsigned channels)
{
    void *handle = dlopen("/System/Library/Frameworks/Accelerate.framework/Frameworks/vImage.framework/vImage", RTLD_NOW);
    if (!handle) {
        fprintf(stderr, "dlopen vImage: %s\n", dlerror());
        exit(1);
    }
    void *symbol = dlsym(handle, channels == 4 ? "vImageScale_ARGB16U" : "vImageScale_Planar16U");
    if (!symbol) {
        fprintf(stderr, "dlsym: %s\n", dlerror());
        exit(1);
    }
    return (scale_function)symbol;
}

static uint16_t *fill(size_t count, uint32_t *seed)
{
    uint16_t *values = malloc(count * sizeof *values);
    for (size_t i = 0; i < count; i++) {
        *seed = *seed * 1103515245u + 12345u;
        values[i] = (uint16_t)((*seed >> 8) & 0xffff);
    }
    return values;
}

static vImage_Buffer buffer(void *data, unsigned width, unsigned height, unsigned channels)
{
    vImage_Buffer out = { data, height, width, (size_t)width * channels * 2 };
    return out;
}

static uint16_t *ramp_fill(const struct scale_case *c)
{
    uint16_t *values = malloc((size_t)c->sw * c->sh * c->channels * sizeof *values);
    for (unsigned y = 0; y < c->sh; y++)
        for (unsigned x = 0; x < c->sw; x++)
            for (unsigned k = 0; k < c->channels; k++)
                values[(y * c->sw + x) * c->channels + k] = (uint16_t)(1000 * x + 500 * y + 3000 * k);
    return values;
}

static double run_case(const struct scale_case *c, uint32_t seed, int ramp, double *mean)
{
    size_t sourceCount = (size_t)c->sw * c->sh * c->channels;
    size_t destCount = (size_t)c->dw * c->dh * c->channels;
    uint16_t *input = ramp ? ramp_fill(c) : fill(sourceCount, &seed);
    uint16_t *ours = calloc(destCount, sizeof *ours);
    uint16_t *apple = calloc(destCount, sizeof *apple);
    vImage_Buffer src = buffer(input, c->sw, c->sh, c->channels);
    vImage_Buffer ourDest = buffer(ours, c->dw, c->dh, c->channels);
    vImage_Buffer appleDest = buffer(apple, c->dw, c->dh, c->channels);
    scale_function scale = c->channels == 4 ? vImageScale_ARGB16U : vImageScale_Planar16U;
    vImage_Error status = scale(&src, &ourDest, NULL, kvImageNoFlags);
    if (status != kvImageNoError) {
        printf("%s: ours returned %ld\n", c->name, (long)status);
        exit(1);
    }
    status = apple_scale(c->channels)(&src, &appleDest, NULL, kvImageNoFlags);
    if (status != kvImageNoError) {
        printf("%s: apple returned %ld\n", c->name, (long)status);
        exit(1);
    }
    double worst = 0.0, total = 0.0;
    for (size_t i = 0; i < destCount; i++) {
        double difference = fabs((double)ours[i] - (double)apple[i]);
        if (difference > worst)
            worst = difference;
        total += difference;
    }
    *mean = total / (double)destCount;
    free(input);
    free(ours);
    free(apple);
    return worst;
}

static int failures;

static void expect(int condition, const char *message)
{
    if (!condition) {
        printf("FAIL: %s\n", message);
        failures++;
    }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    uint32_t seed = 7;

    for (size_t index = 0; index < sizeof cases / sizeof cases[0]; index++) {
        const struct scale_case *c = &cases[index];
        double mean = 0.0;
        double worst = run_case(c, seed + (uint32_t)index, 0, &mean);
        printf("noise %s: max=%.1f mean=%.2f\n", c->name, worst, mean);
        expect(worst <= c->bound, c->name);
        worst = run_case(c, seed, 1, &mean);
        printf("ramp %s: max=%.1f mean=%.2f\n", c->name, worst, mean);
        expect(worst <= c->ramp_bound, c->name);
    }

    for (size_t index = 0; index < sizeof cases / sizeof cases[0]; index++) {
        const struct scale_case *c = &cases[index];
        size_t count = (size_t)c->dw * c->dh * c->channels;
        uint16_t *constant = malloc((size_t)c->sw * c->sh * c->channels * sizeof *constant);
        for (size_t i = 0; i < (size_t)c->sw * c->sh * c->channels; i++)
            constant[i] = 40000;
        uint16_t *out = calloc(count, sizeof *out);
        vImage_Buffer src = buffer(constant, c->sw, c->sh, c->channels);
        vImage_Buffer dest = buffer(out, c->dw, c->dh, c->channels);
        scale_function scale = c->channels == 4 ? vImageScale_ARGB16U : vImageScale_Planar16U;
        scale(&src, &dest, NULL, kvImageNoFlags);
        int uniform = 1;
        for (size_t i = 0; i < count; i++)
            uniform = uniform && out[i] == 40000;
        expect(uniform, "a constant image stays constant");
        free(constant);
        free(out);
    }

    {
        uint16_t identity[5 * 5 * 4];
        for (size_t i = 0; i < 5 * 5 * 4; i++)
            identity[i] = (uint16_t)(i * 2500);
        uint16_t out[5 * 5 * 4];
        vImage_Buffer src = buffer(identity, 5, 5, 4);
        vImage_Buffer dest = buffer(out, 5, 5, 4);
        vImageScale_ARGB16U(&src, &dest, NULL, kvImageNoFlags);
        expect(memcmp(identity, out, sizeof identity) == 0, "a same-size scale returns the source");
    }

    {
        uint16_t block[4 * 4];
        for (unsigned y = 0; y < 4; y++)
            for (unsigned x = 0; x < 4; x++)
                block[y * 4 + x] = (uint16_t)((y * 4 + x) * 4096);
        uint16_t out[2 * 2];
        vImage_Buffer src = buffer(block, 4, 4, 1);
        vImage_Buffer dest = buffer(out, 2, 2, 1);
        vImageScale_Planar16U(&src, &dest, NULL, kvImageNoFlags);
        int exact = 1;
        for (unsigned y = 0; y < 2; y++)
            for (unsigned x = 0; x < 2; x++) {
                unsigned sum = 0;
                for (unsigned dy = 0; dy < 2; dy++)
                    for (unsigned dx = 0; dx < 2; dx++)
                        sum += block[(2 * y + dy) * 4 + 2 * x + dx];
                exact = exact && out[y * 2 + x] == (uint16_t)((sum + 2) / 4);
            }
        expect(exact, "a 2x integer downscale averages each block");
    }

    {
        uint16_t source[2 * 2] = { 1, 2, 3, 4 };
        uint16_t out[4 * 4];
        memset(out, 0xab, sizeof out);
        vImage_Buffer src = buffer(source, 2, 2, 1);
        vImage_Buffer dest = buffer(out, 4, 4, 1);
        vImage_Error status = vImageScale_Planar16U(&src, &dest, NULL, kvImageGetTempBufferSize);
        uint8_t untouched = 1;
        for (size_t i = 0; i < sizeof out; i++)
            untouched = untouched && ((uint8_t *)out)[i] == 0xab;
        expect(status == kvImageNoError && untouched, "kvImageGetTempBufferSize only reports the size");
        expect(vImageScale_Planar16U(&src, &dest, NULL, (vImage_Flags)1 << 30) == kvImageUnknownFlagsBit,
               "an unknown flag is refused");
        const vImage_Buffer *volatile absent = NULL;
        expect(vImageScale_Planar16U(absent, &dest, NULL, kvImageNoFlags) == kvImageNullPointerArgument,
               "a null source is refused");
    }

    printf("failures: %d\n", failures);
    return failures == 0 ? 0 : 1;
}
