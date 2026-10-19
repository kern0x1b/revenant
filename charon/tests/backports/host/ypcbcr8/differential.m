#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RENAME(x) charonHost_##x
extern const vImage_YpCbCrToARGBMatrix *RENAME(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4);
extern const vImage_YpCbCrToARGBMatrix *RENAME(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2);
extern const vImage_ARGBToYpCbCrMatrix *RENAME(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4);
extern const vImage_ARGBToYpCbCrMatrix *RENAME(kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2);

#define DECL_YPCA8(name) \
    extern vImage_Error RENAME(name)(const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t[4], const uint8_t, vImage_Flags)
#define DECL_YPCANONE(name) \
    extern vImage_Error RENAME(name)(const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t[4], vImage_Flags)
#define DECL_YPCA16(name) \
    extern vImage_Error RENAME(name)(const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t[4], const uint16_t, vImage_Flags)
#define DECL_YPCAQ12(name) \
    extern vImage_Error RENAME(name)(const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t[4], const Pixel_16Q12, vImage_Flags)
DECL_YPCA8(vImageConvert_422YpCbYpCr8ToARGB8888);
DECL_YPCA8(vImageConvert_422CbYpCrYp8ToARGB8888);
DECL_YPCANONE(vImageConvert_444AYpCbCr8ToARGB8888);
DECL_YPCANONE(vImageConvert_444CbYpCrA8ToARGB8888);
DECL_YPCA8(vImageConvert_444CrYpCb8ToARGB8888);
DECL_YPCANONE(vImageConvert_444AYpCbCr16ToARGB8888);
DECL_YPCANONE(vImageConvert_444AYpCbCr16ToARGB16U);
DECL_YPCA8(vImageConvert_422CbYpCrYp16ToARGB8888);
DECL_YPCA16(vImageConvert_422CbYpCrYp16ToARGB16U);
DECL_YPCA8(vImageConvert_444CrYpCb10ToARGB8888);
DECL_YPCAQ12(vImageConvert_444CrYpCb10ToARGB16Q12);
DECL_YPCA8(vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888);
DECL_YPCAQ12(vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12);
extern vImage_Error RENAME(vImageConvert_422CbYpCrYp8_AA8ToARGB8888)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t[4], vImage_Flags);

#define DECL_ARGBC(name) \
    extern vImage_Error RENAME(name)(const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t[4], vImage_Flags)
DECL_ARGBC(vImageConvert_ARGB8888To422YpCbYpCr8);
DECL_ARGBC(vImageConvert_ARGB8888To422CbYpCrYp8);
DECL_ARGBC(vImageConvert_ARGB8888To444AYpCbCr8);
DECL_ARGBC(vImageConvert_ARGB8888To444CbYpCrA8);
DECL_ARGBC(vImageConvert_ARGB8888To444CrYpCb8);
DECL_ARGBC(vImageConvert_ARGB8888To444AYpCbCr16);
DECL_ARGBC(vImageConvert_ARGB8888To422CbYpCrYp16);
DECL_ARGBC(vImageConvert_ARGB8888To444CrYpCb10);
DECL_ARGBC(vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10);
extern vImage_Error RENAME(vImageConvert_ARGB8888To420Yp8_CbCr8)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t[4], vImage_Flags);
extern vImage_Error RENAME(vImageConvert_ARGB8888To420Yp8_Cb8_Cr8)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t[4], vImage_Flags);
extern vImage_Error RENAME(vImageConvert_YpCbCrToARGB_GenerateConversion)(const vImage_YpCbCrToARGBMatrix *, const vImage_YpCbCrPixelRange *, vImage_YpCbCrToARGB *, vImageYpCbCrType, vImageARGBType, vImage_Flags);
extern vImage_Error RENAME(vImageConvert_ARGBToYpCbCr_GenerateConversion)(const vImage_ARGBToYpCbCrMatrix *, const vImage_YpCbCrPixelRange *, vImage_ARGBToYpCbCr *, vImageARGBType, vImageYpCbCrType, vImage_Flags);
extern vImage_Error RENAME(vImageConvert_420Yp8_CbCr8ToARGB8888)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t[4], const uint8_t, vImage_Flags);
extern vImage_Error RENAME(vImageConvert_420Yp8_Cb8_Cr8ToARGB8888)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t[4], const uint8_t, vImage_Flags);
#define DECL_ARGBC16(name) \
    extern vImage_Error RENAME(name)(const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t[4], vImage_Flags)
DECL_ARGBC16(vImageConvert_ARGB16UTo444AYpCbCr16);
DECL_ARGBC16(vImageConvert_ARGB16UTo422CbYpCrYp16);
DECL_ARGBC16(vImageConvert_ARGB16Q12To444CrYpCb10);
DECL_ARGBC16(vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10);
extern vImage_Error RENAME(vImageConvert_ARGB8888To422CbYpCrYp8_AA8)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t[4], vImage_Flags);

static int checks, failures;
static unsigned long long bytesCompared, bytesApart;
static int widest;
static char widestWhere[1024] = "no case has differed at all";

#define CharonYpCbCrBound 2
#define CharonWideBound 256

struct ref_scale {
    float yScale, cScale, biasY, biasC, yMin, yMax, cMin, cMax;
};

static struct ref_scale reference_of(const vImage_ARGBToYpCbCrMatrix *m, const vImage_YpCbCrPixelRange *r, float full)
{
    struct ref_scale s;
    s.yScale = (float)(r->YpRangeMax - r->Yp_bias) / full;
    s.cScale = 2.0f * (float)(r->CbCrRangeMax - r->CbCr_bias) / full;
    s.biasY = (float)r->Yp_bias;
    s.biasC = (float)r->CbCr_bias;
    s.yMin = (float)r->YpMin;
    s.yMax = (float)r->YpMax;
    s.cMin = (float)r->CbCrMin;
    s.cMax = (float)r->CbCrMax;
    (void)m;
    return s;
}

static int clampi(float v, float lo, float hi)
{
    int r = (int)roundf(v);
    if ((float)r < lo)
        r = (int)lo;
    if ((float)r > hi)
        r = (int)hi;
    return r;
}

static uint32_t reference_v410(const struct ref_scale *s, const vImage_ARGBToYpCbCrMatrix *m, int r, int g, int b)
{
    float yp = s->biasY + (r * m->R_Yp + g * m->G_Yp + b * m->B_Yp) * s->yScale;
    float cb = s->biasC + (r * m->R_Cb + g * m->G_Cb + b * m->B_Cb_R_Cr) * s->cScale;
    float cr = s->biasC + (r * m->B_Cb_R_Cr + g * m->G_Cr + b * m->B_Cr) * s->cScale;
    return ((uint32_t)clampi(cr, s->cMin, s->cMax) << 20) | ((uint32_t)clampi(yp, s->yMin, s->yMax) << 10)
        | (uint32_t)clampi(cb, s->cMin, s->cMax);
}

static void reference_split_v210(const uint8_t *unit, float *Yp, float *Cb, float *Cr)
{
    const uint32_t *w = (const uint32_t *)(const void *)unit;
    Cb[0] = (float)(w[0] & 0x3FFu);
    Yp[0] = (float)((w[0] >> 10) & 0x3FFu);
    Cr[0] = (float)((w[0] >> 20) & 0x3FFu);
    Yp[1] = (float)(w[1] & 0x3FFu);
    Cb[1] = (float)((w[1] >> 10) & 0x3FFu);
    Yp[2] = (float)((w[1] >> 20) & 0x3FFu);
    Cr[1] = (float)(w[2] & 0x3FFu);
    Yp[3] = (float)((w[2] >> 10) & 0x3FFu);
    Cb[2] = (float)((w[2] >> 20) & 0x3FFu);
    Yp[4] = (float)(w[3] & 0x3FFu);
    Cr[2] = (float)((w[3] >> 10) & 0x3FFu);
    Yp[5] = (float)((w[3] >> 20) & 0x3FFu);
}

static float source_channel(const void *row, int index, int wide)
{
    if (wide)
        return (float)(*(const uint16_t *)(const void *)((const uint8_t *)row + (size_t)index * 2));
    return (float)((const uint8_t *)row)[index];
}

static void reference_v210(const struct ref_scale *s, const vImage_ARGBToYpCbCrMatrix *m, const void *top,
                           int count, const uint8_t pm[4], int wide, uint32_t *out)
{
    const uint8_t *bytes = (const uint8_t *)top;
    float yp[6], cb[3], cr[3];
    for (int i = 0; i < 6 && i < count; i++) {
        const uint8_t *pixel = bytes + (size_t)i * (wide ? 8u : 4u);
        yp[i] = s->biasY + (source_channel(pixel, pm[1], wide) * m->R_Yp + source_channel(pixel, pm[2], wide) * m->G_Yp
                            + source_channel(pixel, pm[3], wide) * m->B_Yp) * s->yScale;
    }
    for (int i = 0; i < 3; i++) {
        float b = 0, r = 0;
        unsigned counted = 0;
        for (int k = 0; k < 2; k++) {
            int at = i * 2 + k;
            if (at >= count)
                continue;
            const uint8_t *pixel = bytes + (size_t)at * (wide ? 8u : 4u);
            float red = source_channel(pixel, pm[1], wide);
            float green = source_channel(pixel, pm[2], wide);
            float blue = source_channel(pixel, pm[3], wide);
            b += red * m->R_Cb + green * m->G_Cb + blue * m->B_Cb_R_Cr;
            r += red * m->B_Cb_R_Cr + green * m->G_Cr + blue * m->B_Cr;
            counted++;
        }
        if (!counted)
            counted = 1;
        cb[i] = s->biasC + b * s->cScale / (float)counted;
        cr[i] = s->biasC + r * s->cScale / (float)counted;
    }
    for (int i = 0; i < 6; i++)
        yp[i] = (float)clampi(yp[i], s->yMin, s->yMax);
    for (int i = 0; i < 3; i++) {
        cb[i] = (float)clampi(cb[i], s->cMin, s->cMax);
        cr[i] = (float)clampi(cr[i], s->cMin, s->cMax);
    }
    out[0] = ((uint32_t)cr[0] & 0x3FF) << 20 | ((uint32_t)yp[0] & 0x3FF) << 10 | ((uint32_t)cb[0] & 0x3FF);
    out[1] = ((uint32_t)yp[1] & 0x3FF) << 20 | ((uint32_t)yp[2] & 0x3FF) << 10 | ((uint32_t)cb[1] & 0x3FF);
    out[2] = ((uint32_t)cb[2] & 0x3FF) << 20 | ((uint32_t)yp[3] & 0x3FF) << 10 | ((uint32_t)cr[1] & 0x3FF);
    out[3] = ((uint32_t)cr[2] & 0x3FF) << 20 | ((uint32_t)yp[5] & 0x3FF) << 10 | ((uint32_t)yp[4] & 0x3FF);
}

static struct ref_scale reference_decode_of(const vImage_YpCbCrToARGBMatrix *m, const vImage_YpCbCrPixelRange *r,
                                            float destFull)
{
    struct ref_scale s;
    s.yScale = destFull / (float)(r->YpRangeMax - r->Yp_bias);
    s.cScale = destFull / (2.0f * (float)(r->CbCrRangeMax - r->CbCr_bias));
    s.biasY = (float)r->Yp_bias;
    s.biasC = (float)r->CbCr_bias;
    s.yMin = (float)r->YpMin;
    s.yMax = (float)r->YpMax;
    s.cMin = (float)r->CbCrMin;
    s.cMax = (float)r->CbCrMax;
    (void)m;
    return s;
}

static void reference_decode(const struct ref_scale *s, const vImage_YpCbCrToARGBMatrix *m, float Yp, float Cb,
                             float Cr, uint32_t A, float full, uint32_t out[4])
{
    float y = (Yp - s->biasY) * s->yScale * m->Yp;
    float b = (Cb - s->biasC) * s->cScale;
    float r = (Cr - s->biasC) * s->cScale;
    out[0] = A;
    out[1] = (uint32_t)clampi(y + r * m->Cr_R, 0.0f, full);
    out[2] = (uint32_t)clampi(y + b * m->Cb_G + r * m->Cr_G, 0.0f, full);
    out[3] = (uint32_t)clampi(y + b * m->Cb_B, 0.0f, full);
}

static unsigned long long q12Apart, q12Bytes;
static int q12Widest;

static BOOL header_only(vImageYpCbCrType type)
{
    return type == kvImage444CrYpCb10 || type == kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10;
}

static void report(BOOL passed, NSString *name, NSString *detail)
{
    checks++;
    if (passed) {
        printf("ok   %s\n", name.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: %s\n", name.UTF8String, detail.UTF8String);
}

static vImage_Buffer make(vImagePixelCount width, vImagePixelCount height, size_t bytesPerPixel)
{
    vImage_Buffer buffer = {NULL, height, width, (width * bytesPerPixel + 63) & ~(size_t)63};
    buffer.data = calloc(buffer.rowBytes, height);
    return buffer;
}

static uint64_t seed = 0x9E3779B97F4A7C15ull;
static uint8_t next_byte(void)
{
    seed = seed * 6364136223846793005ull + 1442695040888963407ull;
    static const uint8_t corners[] = {0, 1, 15, 16, 17, 63, 64, 127, 128, 235, 240, 255};
    return corners[(seed >> 33) % (sizeof corners)];
}

static void fill(vImage_Buffer buffer)
{
    for (vImagePixelCount row = 0; row < buffer.height; row++) {
        uint8_t *line = (uint8_t *)buffer.data + row * buffer.rowBytes;
        for (size_t at = 0; at < buffer.rowBytes; at++)
            line[at] = next_byte();
    }
}

static void fill_pair(vImage_Buffer theirs, vImage_Buffer ours)
{
    for (vImagePixelCount row = 0; row < theirs.height; row++) {
        uint8_t *left = (uint8_t *)theirs.data + row * theirs.rowBytes;
        uint8_t *right = (uint8_t *)ours.data + row * ours.rowBytes;
        for (size_t at = 0; at < theirs.rowBytes; at++)
            left[at] = right[at] = next_byte();
    }
}

static NSString *compare(vImage_Buffer theirs, vImage_Buffer ours, unsigned words, int tolerance)
{
    int worst = 0;
    unsigned long long where = 0;
    for (vImagePixelCount row = 0; row < theirs.height; row++) {
        const uint8_t *left = (const uint8_t *)theirs.data + row * theirs.rowBytes;
        const uint8_t *right = (const uint8_t *)ours.data + row * ours.rowBytes;
        for (size_t at = 0; at < theirs.rowBytes; at += words) {
            int difference = words == 1 ? (int)left[at] - (int)right[at]
                                        : (int)(*(const uint16_t *)(const void *)(left + at))
                                              - (int)(*(const uint16_t *)(const void *)(right + at));
            if (difference < 0)
                difference = -difference;
            bytesCompared++;
            if (difference == 0)
                continue;
            bytesApart++;
            if (difference > widest) {
                widest = difference;
                snprintf(widestWhere, sizeof widestWhere, "a 16-bit sample: the port and the system rounded "
                         "the eight-bit dot product's one unit differently. The ceiling for one unit of "
                         "that sum in a 16-bit sample is 2 * (CbCrRangeMax - CbCr_bias) / 255, which is 514.0 "
                         "at the full sixteen-bit range and 224.88 at the 28672 chroma range; the bound is "
                         "the measured maximum plus one, not the ceiling.");
            }
            if (difference > worst) {
                worst = difference;
                where = (unsigned long long)row * 1000000 + (unsigned long long)(at / words);
            }
        }
    }
    if (worst < (double)tolerance)
        return nil;
    return [NSString stringWithFormat:@"row %llu sample %llu differs by %d, past the last bit's %d",
                                      where / 1000000, where % 1000000, worst, tolerance];
}

struct range_case {
    const char *name;
    vImage_YpCbCrPixelRange range;
};

static const struct range_case ranges8[] = {
    {"video range, unclamped", {16, 128, 235, 240, 255, 0, 255, 1}},
    {"video range, clamped", {16, 128, 235, 240, 235, 16, 240, 16}},
    {"full range, clamped", {0, 128, 255, 255, 255, 1, 255, 0}},
    {"full range, wide open", {0, 128, 255, 255, 255, 0, 255, 0}}
};
static const struct range_case ranges10[] = {
    {"10-bit video, unclamped", {64, 512, 940, 960, 1023, 0, 1023, 1}},
    {"10-bit video, clamped", {64, 512, 940, 960, 940, 64, 960, 64}},
    {"10-bit full, clamped", {0, 512, 1023, 1023, 1023, 1, 1023, 0}},
    {"10-bit full, wide open", {0, 512, 1023, 1023, 1023, 0, 1023, 0}}
};
static const struct range_case ranges16[] = {
    {"16-bit video, unclamped", {4096, 32768, 60160, 61440, 65535, 0, 65535, 1}},
    {"16-bit video, clamped", {4096, 32768, 60160, 61440, 60160, 4096, 61440, 4096}},
    {"16-bit full, clamped", {0, 32768, 65535, 65535, 65535, 1, 65535, 0}},
    {"16-bit full, wide open", {0, 32768, 65535, 65535, 65535, 0, 65535, 0}}
};

static const uint8_t *permutations[] = {
    (const uint8_t[]){0, 1, 2, 3},
    (const uint8_t[]){3, 2, 1, 0},
    (const uint8_t[]){1, 0, 3, 2},
    (const uint8_t[]){2, 3, 0, 1}
};
#define PERMUTES ((int)(sizeof permutations / sizeof *permutations))

struct yuv_case {
    const char *name;
    vImageYpCbCrType type;
    vImageARGBType argb;
    size_t sourceBytes;
    unsigned unit;
    unsigned destWords;
    BOOL wide;
};

static const struct yuv_case yuv_cases[] = {
    {"422YpCbYpCr8ToARGB8888", kvImage422YpCbYpCr8, kvImageARGB8888, 2, 1, 4, NO},
    {"422CbYpCrYp8ToARGB8888", kvImage422CbYpCrYp8, kvImageARGB8888, 2, 1, 4, NO},
    {"444AYpCbCr8ToARGB8888", kvImage444AYpCbCr8, kvImageARGB8888, 4, 1, 4, NO},
    {"444CbYpCrA8ToARGB8888", kvImage444CbYpCrA8, kvImageARGB8888, 4, 1, 4, NO},
    {"444CrYpCb8ToARGB8888", kvImage444CrYpCb8, kvImageARGB8888, 3, 1, 4, NO},
    {"444AYpCbCr16ToARGB8888", kvImage444AYpCbCr16, kvImageARGB8888, 8, 1, 4, NO},
    {"444AYpCbCr16ToARGB16U", kvImage444AYpCbCr16, kvImageARGB16U, 8, 1, 8, YES},
    {"422CbYpCrYp16ToARGB8888", kvImage422CbYpCrYp16, kvImageARGB8888, 4, 1, 4, NO},
    {"422CbYpCrYp16ToARGB16U", kvImage422CbYpCrYp16, kvImageARGB16U, 4, 1, 8, YES},
    {"444CrYpCb10ToARGB8888", kvImage444CrYpCb10, kvImageARGB8888, 4, 1, 4, NO},
    {"444CrYpCb10ToARGB16Q12", kvImage444CrYpCb10, kvImageARGB16Q12, 4, 1, 8, YES},
    {"422v210ToARGB8888", kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10, kvImageARGB8888, 8, 6, 4, NO},
    {"422v210ToARGB16Q12", kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10, kvImageARGB16Q12, 8, 6, 8, YES},
    {"420CbCr8ToARGB8888", kvImage420Yp8_CbCr8, kvImageARGB8888, 1, 1, 4, NO},
    {"420Cb8Cr8ToARGB8888", kvImage420Yp8_Cb8_Cr8, kvImageARGB8888, 1, 1, 4, NO}
};
#define YUV_CASES ((int)(sizeof yuv_cases / sizeof *yuv_cases))

static const vImagePixelCount sizes[] = {2, 6, 12, 34};
#define SIZES ((int)(sizeof sizes / sizeof *sizes))

static vImage_Error call_theirs(const struct yuv_case *example, vImage_Buffer *src, vImage_Buffer *dest,
                                const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], vImage_Flags flags)
{
    switch (example->type) {
    case kvImage422YpCbYpCr8:
        return vImageConvert_422YpCbYpCr8ToARGB8888(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage422CbYpCrYp8:
        return vImageConvert_422CbYpCrYp8ToARGB8888(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage444AYpCbCr8:
        return vImageConvert_444AYpCbCr8ToARGB8888(&src[0], dest, info, permuteMap, flags);
    case kvImage444CbYpCrA8:
        return vImageConvert_444CbYpCrA8ToARGB8888(&src[0], dest, info, permuteMap, flags);
    case kvImage444CrYpCb8:
        return vImageConvert_444CrYpCb8ToARGB8888(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage444AYpCbCr16:
        return example->argb == kvImageARGB16U
                   ? vImageConvert_444AYpCbCr16ToARGB16U(&src[0], dest, info, permuteMap, flags)
                   : vImageConvert_444AYpCbCr16ToARGB8888(&src[0], dest, info, permuteMap, flags);
    case kvImage422CbYpCrYp16:
        return example->argb == kvImageARGB16U
                   ? vImageConvert_422CbYpCrYp16ToARGB16U(&src[0], dest, info, permuteMap, 40000, flags)
                   : vImageConvert_422CbYpCrYp16ToARGB8888(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage444CrYpCb10:
        return example->argb == kvImageARGB16Q12
                   ? vImageConvert_444CrYpCb10ToARGB16Q12(&src[0], dest, info, permuteMap, 3000, flags)
                   : vImageConvert_444CrYpCb10ToARGB8888(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10:
        return example->argb == kvImageARGB16Q12
                   ? vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(&src[0], dest, info, permuteMap, 3000, flags)
                   : vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage420Yp8_CbCr8:
        return vImageConvert_420Yp8_CbCr8ToARGB8888(&src[0], &src[1], dest, info, permuteMap, 200, flags);
    case kvImage420Yp8_Cb8_Cr8:
        return vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&src[0], &src[1], &src[2], dest, info, permuteMap, 200, flags);
    default:
        return kvImageInvalidParameter;
    }
}

static vImage_Error call_ours(const struct yuv_case *example, vImage_Buffer *src, vImage_Buffer *dest,
                              const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], vImage_Flags flags)
{
    switch (example->type) {
    case kvImage422YpCbYpCr8:
        return RENAME(vImageConvert_422YpCbYpCr8ToARGB8888)(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage422CbYpCrYp8:
        return RENAME(vImageConvert_422CbYpCrYp8ToARGB8888)(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage444AYpCbCr8:
        return RENAME(vImageConvert_444AYpCbCr8ToARGB8888)(&src[0], dest, info, permuteMap, flags);
    case kvImage444CbYpCrA8:
        return RENAME(vImageConvert_444CbYpCrA8ToARGB8888)(&src[0], dest, info, permuteMap, flags);
    case kvImage444CrYpCb8:
        return RENAME(vImageConvert_444CrYpCb8ToARGB8888)(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage444AYpCbCr16:
        return example->argb == kvImageARGB16U
                   ? RENAME(vImageConvert_444AYpCbCr16ToARGB16U)(&src[0], dest, info, permuteMap, flags)
                   : RENAME(vImageConvert_444AYpCbCr16ToARGB8888)(&src[0], dest, info, permuteMap, flags);
    case kvImage422CbYpCrYp16:
        return example->argb == kvImageARGB16U
                   ? RENAME(vImageConvert_422CbYpCrYp16ToARGB16U)(&src[0], dest, info, permuteMap, 40000, flags)
                   : RENAME(vImageConvert_422CbYpCrYp16ToARGB8888)(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage444CrYpCb10:
        return example->argb == kvImageARGB16Q12
                   ? RENAME(vImageConvert_444CrYpCb10ToARGB16Q12)(&src[0], dest, info, permuteMap, 3000, flags)
                   : RENAME(vImageConvert_444CrYpCb10ToARGB8888)(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10:
        return example->argb == kvImageARGB16Q12
                   ? RENAME(vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12)(&src[0], dest, info, permuteMap, 3000, flags)
                   : RENAME(vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888)(&src[0], dest, info, permuteMap, 200, flags);
    case kvImage420Yp8_CbCr8:
        return RENAME(vImageConvert_420Yp8_CbCr8ToARGB8888)(&src[0], &src[1], dest, info, permuteMap, 200, flags);
    case kvImage420Yp8_Cb8_Cr8:
        return RENAME(vImageConvert_420Yp8_Cb8_Cr8ToARGB8888)(&src[0], &src[1], &src[2], dest, info, permuteMap, 200, flags);
    default:
        return kvImageInvalidParameter;
    }
}

static vImage_Error call_argb_theirs(const struct yuv_case *example, const vImage_Buffer *src, vImage_Buffer *dest,
                                    const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4])
{
    switch (example->type) {
    case kvImage422YpCbYpCr8:
        return vImageConvert_ARGB8888To422YpCbYpCr8(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage422CbYpCrYp8:
        return vImageConvert_ARGB8888To422CbYpCrYp8(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444AYpCbCr8:
        return vImageConvert_ARGB8888To444AYpCbCr8(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444CbYpCrA8:
        return vImageConvert_ARGB8888To444CbYpCrA8(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444CrYpCb8:
        return vImageConvert_ARGB8888To444CrYpCb8(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444AYpCbCr16:
        return example->argb == kvImageARGB16U
                   ? vImageConvert_ARGB16UTo444AYpCbCr16(src, &dest[0], info, permuteMap, kvImageNoFlags)
                   : vImageConvert_ARGB8888To444AYpCbCr16(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage422CbYpCrYp16:
        return example->argb == kvImageARGB16U
                   ? vImageConvert_ARGB16UTo422CbYpCrYp16(src, &dest[0], info, permuteMap, kvImageNoFlags)
                   : vImageConvert_ARGB8888To422CbYpCrYp16(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444CrYpCb10:
        return example->argb == kvImageARGB16Q12
                   ? vImageConvert_ARGB16Q12To444CrYpCb10(src, &dest[0], info, permuteMap, kvImageNoFlags)
                   : vImageConvert_ARGB8888To444CrYpCb10(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10:
        return example->argb == kvImageARGB16Q12
                   ? vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(src, &dest[0], info, permuteMap, kvImageNoFlags)
                   : vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage420Yp8_CbCr8:
        return vImageConvert_ARGB8888To420Yp8_CbCr8(src, &dest[0], &dest[1], info, permuteMap, kvImageNoFlags);
    case kvImage420Yp8_Cb8_Cr8:
        return vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(src, &dest[0], &dest[1], &dest[2], info, permuteMap, kvImageNoFlags);
    default:
        return kvImageInvalidParameter;
    }
}

static vImage_Error call_argb_ours(const struct yuv_case *example, const vImage_Buffer *src, vImage_Buffer *dest,
                                   const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4])
{
    switch (example->type) {
    case kvImage422YpCbYpCr8:
        return RENAME(vImageConvert_ARGB8888To422YpCbYpCr8)(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage422CbYpCrYp8:
        return RENAME(vImageConvert_ARGB8888To422CbYpCrYp8)(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444AYpCbCr8:
        return RENAME(vImageConvert_ARGB8888To444AYpCbCr8)(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444CbYpCrA8:
        return RENAME(vImageConvert_ARGB8888To444CbYpCrA8)(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444CrYpCb8:
        return RENAME(vImageConvert_ARGB8888To444CrYpCb8)(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444AYpCbCr16:
        return example->argb == kvImageARGB16U
                   ? RENAME(vImageConvert_ARGB16UTo444AYpCbCr16)(src, &dest[0], info, permuteMap, kvImageNoFlags)
                   : RENAME(vImageConvert_ARGB8888To444AYpCbCr16)(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage422CbYpCrYp16:
        return example->argb == kvImageARGB16U
                   ? RENAME(vImageConvert_ARGB16UTo422CbYpCrYp16)(src, &dest[0], info, permuteMap, kvImageNoFlags)
                   : RENAME(vImageConvert_ARGB8888To422CbYpCrYp16)(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage444CrYpCb10:
        return example->argb == kvImageARGB16Q12
                   ? RENAME(vImageConvert_ARGB16Q12To444CrYpCb10)(src, &dest[0], info, permuteMap, kvImageNoFlags)
                   : RENAME(vImageConvert_ARGB8888To444CrYpCb10)(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10:
        return example->argb == kvImageARGB16Q12
                   ? RENAME(vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10)(src, &dest[0], info, permuteMap, kvImageNoFlags)
                   : RENAME(vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10)(src, &dest[0], info, permuteMap, kvImageNoFlags);
    case kvImage420Yp8_CbCr8:
        return RENAME(vImageConvert_ARGB8888To420Yp8_CbCr8)(src, &dest[0], &dest[1], info, permuteMap, kvImageNoFlags);
    case kvImage420Yp8_Cb8_Cr8:
        return RENAME(vImageConvert_ARGB8888To420Yp8_Cb8_Cr8)(src, &dest[0], &dest[1], &dest[2], info, permuteMap, kvImageNoFlags);
    default:
        return kvImageInvalidParameter;
    }
}

static int planes_of(vImageYpCbCrType type)
{
    return type == kvImage420Yp8_Cb8_Cr8 ? 3 : (type == kvImage420Yp8_CbCr8 ? 2 : 1);
}

static int plane_set(vImageYpCbCrType type, vImagePixelCount width, vImagePixelCount height,
                     size_t bytesPerSample, vImage_Buffer out[3])
{
    int count = planes_of(type);
    for (int plane = 0; plane < count; plane++) {
        vImagePixelCount w = plane == 0 ? width : (width + 1) / 2;
        vImagePixelCount h = plane == 0 ? height : (height + 1) / 2;
        size_t bytes = plane == 0 ? bytesPerSample : (type == kvImage420Yp8_CbCr8 ? 2 : 1);
        out[plane] = make(w, h, bytes);
    }
    return count;
}

static vImage_Error call_aa8_theirs(const vImage_Buffer *src, const vImage_Buffer *srcA, const vImage_Buffer *dest,
                                   const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4])
{
    return vImageConvert_422CbYpCrYp8_AA8ToARGB8888(src, srcA, dest, info, permuteMap, kvImageNoFlags);
}

static vImage_Error call_aa8_ours(const vImage_Buffer *src, const vImage_Buffer *srcA, const vImage_Buffer *dest,
                                 const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4])
{
    return RENAME(vImageConvert_422CbYpCrYp8_AA8ToARGB8888)(src, srcA, dest, info, permuteMap, kvImageNoFlags);
}

static float full_of(vImageARGBType type)
{
    switch (type) {
    case kvImageARGB16U:
        return 65535.0f;
    case kvImageARGB16Q12:
        return 4096.0f;
    default:
        return 255.0f;
    }
}

static const struct range_case *ranges_for(vImageYpCbCrType type)
{
    switch (type) {
    case kvImage444CrYpCb10:
    case kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10:
        return ranges10;
    case kvImage422CbYpCrYp16:
    case kvImage444AYpCbCr16:
        return ranges16;
    default:
        return ranges8;
    }
}

static void forward_geometry(const struct yuv_case *example, vImagePixelCount width, vImagePixelCount height,
                             vImagePixelCount *sourceWidth, vImagePixelCount *sourceHeight)
{
    if (example->unit == 6) {
        *sourceWidth = (width / 6) * 6;
        *sourceHeight = height;
    } else {
        *sourceWidth = width;
        *sourceHeight = height;
    }
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        for (int c = 0; c < YUV_CASES; c++) {
            const struct yuv_case *example = &yuv_cases[c];
            const struct range_case *set = ranges_for(example->type);
            for (int matrix = 0; matrix < 2; matrix++) {
                const vImage_YpCbCrToARGBMatrix *toARGB =
                    matrix ? kvImage_YpCbCrToARGBMatrix_ITU_R_709_2 : kvImage_YpCbCrToARGBMatrix_ITU_R_601_4;
                const vImage_ARGBToYpCbCrMatrix *toYpCbCr =
                    matrix ? kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2 : kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4;
                const vImage_YpCbCrToARGBMatrix *ourToARGB =
                    matrix ? RENAME(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2) : RENAME(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4);
                const vImage_ARGBToYpCbCrMatrix *ourToYpCbCr =
                    matrix ? RENAME(kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2) : RENAME(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4);
                const char *matrixName = matrix ? "709" : "601";
                for (int r = 0; r < 4; r++) {
                    NSString *head = [NSString stringWithFormat:@"%s %s %s", example->name, matrixName, set[r].name];
                    vImage_YpCbCrToARGB theirInfo, ourInfo;
                    vImage_ARGBToYpCbCr theirForward, ourForward;
                    vImage_Error a = vImageConvert_YpCbCrToARGB_GenerateConversion(toARGB, &set[r].range, &theirInfo,
                                                                                 example->type, example->argb, kvImageNoFlags);
                    vImage_Error b = RENAME(vImageConvert_YpCbCrToARGB_GenerateConversion)(ourToARGB, &set[r].range,
                                                                                         &ourInfo, example->type,
                                                                                         example->argb, kvImageNoFlags);
                    report(a == b && a == kvImageNoError,
                           [head stringByAppendingString:@": the forward conversion is generated"],
                           ([NSString stringWithFormat:@"%ld against %ld", (long)a, (long)b]));
                    a = vImageConvert_ARGBToYpCbCr_GenerateConversion(toYpCbCr, &set[r].range, &theirForward,
                                                                       example->argb, example->type, kvImageNoFlags);
                    b = RENAME(vImageConvert_ARGBToYpCbCr_GenerateConversion)(ourToYpCbCr, &set[r].range, &ourForward,
                                                                             example->argb, example->type, kvImageNoFlags);
                    report(a == b && a == kvImageNoError,
                           [head stringByAppendingString:@": the reverse conversion is generated"],
                           ([NSString stringWithFormat:@"%ld against %ld", (long)a, (long)b]));
                    for (int s = 0; s < SIZES; s++) {
                        vImagePixelCount width = sizes[s], height = sizes[s];
                        vImagePixelCount sourceWidth, sourceHeight;
                        forward_geometry(example, width, height, &sourceWidth, &sourceHeight);
                        if (sourceWidth == 0 || sourceHeight == 0)
                            continue;
                        for (int p = 0; p < PERMUTES; p++) {
                            const uint8_t *permuteMap = permutations[p];
                            NSString *what = [NSString stringWithFormat:@"%@ %llux%llu permute %u%u%u%u", head,
                                                              (unsigned long long)sourceWidth,
                                                              (unsigned long long)sourceHeight, permuteMap[0],
                                                              permuteMap[1], permuteMap[2], permuteMap[3]];

                            vImage_Buffer theirPlanes[3] = {{0}}, ourPlanes[3] = {{0}};
                            int count = plane_set(example->type, sourceWidth, sourceHeight, example->sourceBytes, theirPlanes);
                            plane_set(example->type, sourceWidth, sourceHeight, example->sourceBytes, ourPlanes);
                            for (int plane = 0; plane < count; plane++)
                                fill_pair(theirPlanes[plane], ourPlanes[plane]);
                            vImage_Buffer theirDest = make(sourceWidth, sourceHeight, example->destWords);
                            vImage_Buffer ourDest = make(sourceWidth, sourceHeight, example->destWords);
                            vImage_Error theirs = call_theirs(example, theirPlanes, &theirDest, &theirInfo, permuteMap, kvImageNoFlags);
                            vImage_Error ours = call_ours(example, ourPlanes, &ourDest, &ourInfo, permuteMap, kvImageNoFlags);
                            report(theirs == ours && theirs == kvImageNoError,
                                   [what stringByAppendingString:@": Y'CbCr to ARGB answers"],
                                   ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
                            NSString *difference;
                            if (!header_only(example->type)) {
                                NSString *difference = compare(theirDest, ourDest, example->wide ? 2 : 1, CharonYpCbCrBound);
                                report(difference == nil,
                                       [what stringByAppendingString:@": Y'CbCr to ARGB is within the last bit"],
                                       difference ?: @"");
                            } else {
                                struct ref_scale fwd = reference_decode_of(toARGB, &set[r].range, full_of(example->argb));
                                int bad = 0;
                                for (vImagePixelCount row = 0; row < sourceHeight; row++) {
                                    const uint8_t *in = (const uint8_t *)theirPlanes[0].data
                                        + row * theirPlanes[0].rowBytes;
                                    const uint8_t *mine = (const uint8_t *)ourDest.data + row * ourDest.rowBytes;
                                    const uint8_t *theirs = (const uint8_t *)theirDest.data + row * theirDest.rowBytes;
                                    for (vImagePixelCount column = 0; column < sourceWidth; column++) {
                                        float Yp, Cb, Cr;
                                        uint32_t A = example->wide ? 3000u : 200u;
                                        if (example->type == kvImage444CrYpCb10) {
                                            uint32_t w;
                                            memcpy(&w, in + column * 4, 4);
                                            Cb = (float)(w & 0x3FFu);
                                            Yp = (float)((w >> 10) & 0x3FFu);
                                            Cr = (float)((w >> 20) & 0x3FFu);
                                        } else {
                                            float yp[6], cb[3], cr[3];
                                            const uint8_t *unit = in + (column / 6) * 48;
                                            reference_split_v210(unit, yp, cb, cr);
                                            Yp = yp[column % 6];
                                            Cb = cb[(column % 6) / 2];
                                            Cr = cr[(column % 6) / 2];
                                        }
                                        uint32_t graded[4], want[4];
                                        reference_decode(&fwd, toARGB, Yp, Cb, Cr, A, full_of(example->argb), graded);
                                        for (int ch = 0; ch < 4; ch++)
                                            want[ch] = graded[permuteMap[ch]];
                                        for (int ch = 0; ch < 4; ch++) {
                                            uint32_t got = example->wide
                                                               ? (uint32_t)(*(const uint16_t *)(const void *)(mine + column * 8 + ch * 2))
                                                               : (uint32_t)mine[column * 4 + ch];
                                            if (got != want[ch])
                                                bad++;
                                            q12Bytes++;
                                            int apart = (int)got - (int)(example->wide
                                                                                  ? (uint32_t)(*(const uint16_t *)(const void *)(theirs + column * 8 + ch * 2))
                                                                                  : (uint32_t)theirs[column * 4 + ch]);
                                            if (apart < 0)
                                                apart = -apart;
                                            if (apart) {
                                                q12Apart++;
                                                if (apart > q12Widest)
                                                    q12Widest = apart;
                                            }
                                        }
                                    }
                                }
                                report(bad == 0, [what stringByAppendingString:@": the answer is the header's formula"],
                                       ([NSString stringWithFormat:@"%d channels differ from the formula Conversion.h writes out", bad]));
                            }

                            vImage_Buffer rgb = make(sourceWidth, sourceHeight, example->wide ? 8 : 4);
                            fill(rgb);
                            vImage_Buffer theirBack[3] = {{0}}, ourBack[3] = {{0}};
                            int backCount = plane_set(example->type, sourceWidth, sourceHeight, example->sourceBytes, theirBack);
                            plane_set(example->type, sourceWidth, sourceHeight, example->sourceBytes, ourBack);
                            theirs = call_argb_theirs(example, &rgb, theirBack, &theirForward, permuteMap);
                            ours = call_argb_ours(example, &rgb, ourBack, &ourForward, permuteMap);
                            report(theirs == ours && theirs == kvImageNoError,
                                   [what stringByAppendingString:@": ARGB to Y'CbCr answers"],
                                   ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
                            for (int plane = 0; plane < backCount; plane++) {
                                if (header_only(example->type))
                                    break;
                                int shapeScale = (example->type == kvImage422CbYpCrYp16
                                                  || example->type == kvImage444AYpCbCr16) ? CharonWideBound
                                                                                           : CharonYpCbCrBound;
                                difference = compare(theirBack[plane], ourBack[plane], example->wide ? 2 : 1,
                                                   example->wide ? (int)(full_of(example->argb) / 255.0f) : shapeScale);;
                                NSString *which = [what stringByAppendingString:(plane ? @": the chroma plane"
                                                                                    : @": the Y'CbCr plane")];
                                report(difference == nil, [which stringByAppendingString:@" is within the last bit"],
                                       difference ?: @"");
                            }
                            if (header_only(example->type)) {
                                struct ref_scale rev = reference_of(toYpCbCr, &set[r].range, full_of(example->argb));
                                int bad = 0;
                                for (vImagePixelCount row = 0; row < sourceHeight; row++) {
                                    const uint8_t *in = (const uint8_t *)rgb.data + row * rgb.rowBytes;
                                    const uint8_t *mine = (const uint8_t *)ourBack[0].data + row * ourBack[0].rowBytes;
                                    const uint8_t *theirs = (const uint8_t *)theirBack[0].data + row * theirBack[0].rowBytes;
                                    for (vImagePixelCount column = 0; column < sourceWidth; column++) {
                                        if (example->type == kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10 && column % 6)
                                            continue;
                                        size_t step = example->wide ? 8u : 4u;
                                        const uint8_t *px = in + column * step;
                                        int ch1 = example->wide
                                                          ? (int)(*(const uint16_t *)(const void *)(px + (size_t)permuteMap[1] * 2))
                                                          : (int)px[permuteMap[1]];
                                        int ch2 = example->wide
                                                          ? (int)(*(const uint16_t *)(const void *)(px + (size_t)permuteMap[2] * 2))
                                                          : (int)px[permuteMap[2]];
                                        int ch3 = example->wide
                                                          ? (int)(*(const uint16_t *)(const void *)(px + (size_t)permuteMap[3] * 2))
                                                          : (int)px[permuteMap[3]];
                                        uint32_t want, got;
                                        if (example->type == kvImage444CrYpCb10) {
                                            want = reference_v410(&rev, toYpCbCr, ch1, ch2, ch3);
                                            got = (uint32_t)(*(const uint32_t *)(const void *)(mine + column * 4));
                                        } else {
                                            uint32_t packed[4];
                                            int left = (int)sourceWidth - (int)column;
                                            if (left > 6)
                                                left = 6;
                                            reference_v210(&rev, toYpCbCr, in + (column / 6) * 6 * step, left, permuteMap,
                                                           example->wide ? 1 : 0, packed);
                                            want = packed[0];
                                            got = (uint32_t)(*(const uint32_t *)(const void *)(mine + (column / 6) * 16));
                                        }
                                        if (got != want)
                                            bad++;
                                        q12Bytes++;
                                        int apart = (int)got
                                            - (int)(*(const uint32_t *)(const void *)(theirs + (example->type == kvImage444CrYpCb10
                                                                                                ? (size_t)column * 4
                                                                                                : (size_t)(column / 6) * 16)));
                                        if (apart < 0)
                                            apart = -apart;
                                        if (apart) {
                                            q12Apart++;
                                            if (apart > q12Widest)
                                                q12Widest = apart;
                                        }
                                    }
                                }
                                report(bad == 0, [what stringByAppendingString:@": the answer is the header's formula"],
                                       ([NSString stringWithFormat:@"%d pixels differ from the formula Conversion.h writes out", bad]));
                            }
                        }
                    }
                }
            }
        }

        for (int matrix = 0; matrix < 2; matrix++) {
            const vImage_YpCbCrToARGBMatrix *toARGB =
                matrix ? kvImage_YpCbCrToARGBMatrix_ITU_R_709_2 : kvImage_YpCbCrToARGBMatrix_ITU_R_601_4;
            const vImage_ARGBToYpCbCrMatrix *toYpCbCr =
                matrix ? kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2 : kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4;
            const vImage_YpCbCrToARGBMatrix *ourToARGB =
                matrix ? RENAME(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2) : RENAME(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4);
            const vImage_ARGBToYpCbCrMatrix *ourToYpCbCr =
                matrix ? RENAME(kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2) : RENAME(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4);
            const char *matrixName = matrix ? "709" : "601";
            for (int r = 0; r < 4; r++) {
                NSString *head = [NSString stringWithFormat:@"422CbYpCrYp8_AA8 %s %s", matrixName, ranges8[r].name];
                vImage_YpCbCrToARGB theirInfo, ourInfo;
                vImage_ARGBToYpCbCr theirForward, ourForward;
                vImageConvert_YpCbCrToARGB_GenerateConversion(toARGB, &ranges8[r].range, &theirInfo,
                                                             kvImage422CbYpCrYp8_AA8, kvImageARGB8888, kvImageNoFlags);
                RENAME(vImageConvert_YpCbCrToARGB_GenerateConversion)(ourToARGB, &ranges8[r].range, &ourInfo,
                                                                      kvImage422CbYpCrYp8_AA8, kvImageARGB8888, kvImageNoFlags);
                vImageConvert_ARGBToYpCbCr_GenerateConversion(toYpCbCr, &ranges8[r].range, &theirForward,
                                                              kvImageARGB8888, kvImage422CbYpCrYp8_AA8, kvImageNoFlags);
                RENAME(vImageConvert_ARGBToYpCbCr_GenerateConversion)(ourToYpCbCr, &ranges8[r].range, &ourForward,
                                                                      kvImageARGB8888, kvImage422CbYpCrYp8_AA8, kvImageNoFlags);
                for (int s = 0; s < SIZES; s++) {
                    for (int p = 0; p < PERMUTES; p++) {
                        vImagePixelCount width = sizes[s], height = sizes[s];
                        const uint8_t *permuteMap = permutations[p];
                        NSString *what = [NSString stringWithFormat:@"%@ %llux%llu permute %u%u%u%u", head,
                                                          (unsigned long long)width, (unsigned long long)height,
                                                          permuteMap[0], permuteMap[1], permuteMap[2], permuteMap[3]];
                        vImage_Buffer source = make(width, height, 2);
                        fill(source);
                        vImage_Buffer alpha = make(width, height, 1);
                        fill(alpha);
                        vImage_Buffer theirDest = make(width, height, 4), ourDest = make(width, height, 4);
                        vImage_Error theirs = call_aa8_theirs(&source, &alpha, &theirDest, &theirInfo, permuteMap);
                        vImage_Error ours = call_aa8_ours(&source, &alpha, &ourDest, &ourInfo, permuteMap);
                        report(theirs == ours && theirs == kvImageNoError,
                               [what stringByAppendingString:@": Y'CbCr to ARGB answers"],
                               ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
                        NSString *difference = compare(theirDest, ourDest, 1, CharonYpCbCrBound);
                        report(difference == nil,
                               [what stringByAppendingString:@": Y'CbCr to ARGB is within the last bit"], difference ?: @"");

                        vImage_Buffer rgb = make(width, height, 4);
                        fill(rgb);
                        vImage_Buffer theirBack = make(width, height, 2), ourBack = make(width, height, 2);
                        vImage_Buffer theirAlphaOut = make(width, height, 1);
                        vImage_Buffer ourAlphaOut = make(width, height, 1);
                        theirs = vImageConvert_ARGB8888To422CbYpCrYp8_AA8(&rgb, &theirBack, &theirAlphaOut, &theirForward,
                                                                         permuteMap, kvImageNoFlags);
                        ours = RENAME(vImageConvert_ARGB8888To422CbYpCrYp8_AA8)(&rgb, &ourBack, &ourAlphaOut, &ourForward,
                                                                                permuteMap, kvImageNoFlags);
                        report(theirs == ours && theirs == kvImageNoError,
                               [what stringByAppendingString:@": ARGB to Y'CbCr answers"],
                               ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
                        difference = compare(theirBack, ourBack, 1, CharonYpCbCrBound);
                        report(difference == nil,
                               [what stringByAppendingString:@": ARGB to Y'CbCr is within the last bit"], difference ?: @"");
                        difference = compare(theirAlphaOut, ourAlphaOut, 1, CharonYpCbCrBound);
                        (void)difference;
                        report(difference == nil,
                               [what stringByAppendingString:@": the alpha plane is within the last bit"], difference ?: @"");
                    }
                }
            }
        }

        struct wide_case {
            const char *name;
            vImageYpCbCrType type;
            int which;
        };
        static const struct wide_case wide_cases[] = {
            {"ARGB16UTo444AYpCbCr16", kvImage444AYpCbCr16, 0},
            {"ARGB16UTo422CbYpCrYp16", kvImage422CbYpCrYp16, 0},
            {"ARGB16Q12To444CrYpCb10", kvImage444CrYpCb10, 1},
            {"ARGB16Q12To422v210", kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10, 1}
        };
        static const size_t wide_source[] = {8, 4, 4, 8};
        for (int c = 0; c < 4; c++) {
            const struct range_case *set = wide_cases[c].which == 0 ? ranges16 : ranges10;
            for (int matrix = 0; matrix < 2; matrix++) {
                const vImage_ARGBToYpCbCrMatrix *toYpCbCr =
                    matrix ? kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2 : kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4;
                const vImage_ARGBToYpCbCrMatrix *ourToYpCbCr =
                    matrix ? RENAME(kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2) : RENAME(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4);
                vImageARGBType argb = wide_cases[c].which == 0 ? kvImageARGB16U : kvImageARGB16Q12;
                const char *matrixName = matrix ? "709" : "601";
                for (int r = 0; r < 4; r++) {
                    vImage_ARGBToYpCbCr theirForward, ourForward;
                    struct ref_scale ref = reference_of(toYpCbCr, &set[r].range, wide_cases[c].which == 0 ? 65535.0f : 4096.0f);
                    vImage_Error a = vImageConvert_ARGBToYpCbCr_GenerateConversion(toYpCbCr, &set[r].range, &theirForward,
                                                                                    argb, wide_cases[c].type, kvImageNoFlags);
                    vImage_Error b = RENAME(vImageConvert_ARGBToYpCbCr_GenerateConversion)(ourToYpCbCr, &set[r].range,
                                                                                          &ourForward, argb, wide_cases[c].type, kvImageNoFlags);
                    NSString *head = [NSString stringWithFormat:@"%s %s %s", wide_cases[c].name, matrixName, set[r].name];
                    report(a == b && a == kvImageNoError, [head stringByAppendingString:@": the conversion is generated"],
                           ([NSString stringWithFormat:@"%ld against %ld", (long)a, (long)b]));
                    for (int s = 0; s < SIZES; s++) {
                        vImagePixelCount width = sizes[s], height = sizes[s];
                        if (c == 3 && width % 6)
                            continue;
                        vImage_Buffer source = make(width, height, 8);
                        fill(source);
                        vImage_Buffer theirDest = make(width, height, wide_source[c]);
                        vImage_Buffer ourDest = make(width, height, wide_source[c]);
                        vImage_Error theirs, ours;
                        if (c == 0) {
                            theirs = vImageConvert_ARGB16UTo444AYpCbCr16(&source, &theirDest, &theirForward, permutations[1], kvImageNoFlags);
                            ours = RENAME(vImageConvert_ARGB16UTo444AYpCbCr16)(&source, &ourDest, &ourForward, permutations[1], kvImageNoFlags);
                        } else if (c == 1) {
                            theirs = vImageConvert_ARGB16UTo422CbYpCrYp16(&source, &theirDest, &theirForward, permutations[1], kvImageNoFlags);
                            ours = RENAME(vImageConvert_ARGB16UTo422CbYpCrYp16)(&source, &ourDest, &ourForward, permutations[1], kvImageNoFlags);
                        } else if (c == 2) {
                            theirs = vImageConvert_ARGB16Q12To444CrYpCb10(&source, &theirDest, &theirForward, permutations[1], kvImageNoFlags);
                            ours = RENAME(vImageConvert_ARGB16Q12To444CrYpCb10)(&source, &ourDest, &ourForward, permutations[1], kvImageNoFlags);
                        } else {
                            theirs = vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(&source, &theirDest, &theirForward, permutations[1], kvImageNoFlags);
                            ours = RENAME(vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10)(&source, &ourDest, &ourForward, permutations[1], kvImageNoFlags);
                        }
                        NSString *what = [NSString stringWithFormat:@"%@ %llux%llu", head, (unsigned long long)width,
                                                          (unsigned long long)height];
                        report(theirs == ours && theirs == kvImageNoError,
                               [what stringByAppendingString:@": ARGB to Y'CbCr answers"],
                               ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
                        if (c < 2) {
                            NSString *difference = compare(theirDest, ourDest, 2, CharonWideBound);
                            report(difference == nil,
                                   [what stringByAppendingString:@": ARGB to Y'CbCr is within the last bit"], difference ?: @"");
                            continue;
                        }
                        size_t stride = source.rowBytes / 2;
                        int bad = 0;
                        for (vImagePixelCount row = 0; row < height; row++) {
                            const uint16_t *in = (const uint16_t *)source.data + (size_t)row * stride;
                            for (vImagePixelCount column = 0; column < width; column++) {
                                uint32_t want;
                                if (c == 2) {
                                    const uint8_t *pm = permutations[1];
                                    want = reference_v410(&ref, toYpCbCr, in[column * 4 + pm[1]], in[column * 4 + pm[2]],
                                                          in[column * 4 + pm[3]]);
                                    uint32_t mine = ((const uint32_t *)ourDest.data)[(size_t)row * (ourDest.rowBytes / 4) + column];
                                    uint32_t theirsWord = ((const uint32_t *)theirDest.data)[(size_t)row * (theirDest.rowBytes / 4) + column];
                                    if (mine != want)
                                        bad++;
                                    q12Bytes++;
                                    int apart = (int)mine - (int)theirsWord;
                                    if (apart < 0)
                                        apart = -apart;
                                    if (apart) {
                                        q12Apart++;
                                        if (apart > q12Widest)
                                            q12Widest = apart;
                                    }
                                } else {
                                    if (column % 6)
                                        continue;
                                    int remaining = (int)width - (int)column;
                                    if (remaining > 6)
                                        remaining = 6;
                                    uint32_t packed[4];
                                    const uint16_t *top = in + (size_t)column * 4;
                                    reference_v210(&ref, toYpCbCr, top, remaining, permutations[1],
                                                   c == 2 || c == 3 ? 1 : 0, packed);
                                    const uint32_t *mine = (const uint32_t *)ourDest.data
                                        + (size_t)row * (ourDest.rowBytes / 4) + (size_t)(column / 6) * 4;
                                    for (int word = 0; word < 4; word++) {
                                        q12Bytes++;
                                        if (mine[word] != packed[word]) {
                                            bad++;
                                        }
                                    }
                                    continue;
                                }
                            }
                        }
                        report(bad == 0, [what stringByAppendingString:@": the Q12 answer is the header's own formula"],
                               ([NSString stringWithFormat:@"%d pixels differ from the formula Conversion.h writes out", bad]));

                    }
                }
            }
        }

        {
            vImage_YpCbCrToARGB theirInfo, ourInfo;
            vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &ranges8[0].range,
                                                         &theirInfo, kvImage422YpCbYpCr8, kvImageARGB8888, kvImageNoFlags);
            RENAME(vImageConvert_YpCbCrToARGB_GenerateConversion)(RENAME(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4),
                                                                  &ranges8[0].range, &ourInfo, kvImage422YpCbYpCr8,
                                                                  kvImageARGB8888, kvImageNoFlags);
            vImage_Buffer source = make(4, 4, 2), big = make(8, 8, 4);
            vImage_Error theirs = vImageConvert_422YpCbYpCr8ToARGB8888(&source, &big, &theirInfo, permutations[0], 7, kvImageNoFlags);
            vImage_Error ours = RENAME(vImageConvert_422YpCbYpCr8ToARGB8888)(&source, &big, &ourInfo, permutations[0], 7, kvImageNoFlags);
            report(theirs == ours, @"a destination larger than the source answers the system's code",
                   ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
            theirs = vImageConvert_422YpCbYpCr8ToARGB8888(&source, &source, &theirInfo, permutations[0], 7, kvImageNoFlags | kvImageDoNotClamp);
            ours = RENAME(vImageConvert_422YpCbYpCr8ToARGB8888)(&source, &source, &ourInfo, permutations[0], 7, kvImageNoFlags | kvImageDoNotClamp);
            report(theirs == ours, @"a flag the header does not name answers the system's code",
                   ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));

            const uint8_t repeated[4] = {0, 1, 1, 3};
            const uint8_t past[4] = {0, 1, 2, 9};
            theirs = vImageConvert_422YpCbYpCr8ToARGB8888(&source, &source, &theirInfo, repeated, 7, kvImageNoFlags);
            ours = RENAME(vImageConvert_422YpCbYpCr8ToARGB8888)(&source, &source, &ourInfo, repeated, 7, kvImageNoFlags);
            printf("note a map that repeats a channel: the system answers %ld, the port answers %ld\n", (long)theirs, (long)ours);
            theirs = vImageConvert_422YpCbYpCr8ToARGB8888(&source, &source, &theirInfo, past, 7, kvImageNoFlags);
            ours = RENAME(vImageConvert_422YpCbYpCr8ToARGB8888)(&source, &source, &ourInfo, past, 7, kvImageNoFlags);
            printf("note a map that names channel 9: the system answers %ld, the port answers %ld\n", (long)theirs, (long)ours);
            vImage_Buffer none = make(4, 4, 4);
            theirs = vImageConvert_422YpCbYpCr8ToARGB8888(&source, &none, &theirInfo, 0, 7, kvImageNoFlags);
            ours = RENAME(vImageConvert_422YpCbYpCr8ToARGB8888)(&source, &none, &ourInfo, 0, 7, kvImageNoFlags);
            report(theirs == ours, @"a null permutation map answers the system's code",
                   ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
        }

        printf("\n%d checks, %d failures, %llu bytes compared, %llu apart (%.4f per cent), widest %d\n", checks,
               failures, bytesCompared, bytesApart, bytesCompared ? 100.0 * (double)bytesApart / (double)bytesCompared : 0.0,
               widest);
        printf("the widest difference is %d, in %s\n", widest, widestWhere);
        printf("the Q12-source pair: %llu words compared against the system, %llu apart (%.2f per cent), widest %d - "
               "the port's answer is Conversion.h's formula, and the measurement is in facts/Accelerate/vImageYpCbCr.md\n",
               q12Bytes, q12Apart, q12Bytes ? 100.0 * (double)q12Apart / (double)q12Bytes : 0.0, q12Widest);
    }
    return failures ? 1 : 0;
}
