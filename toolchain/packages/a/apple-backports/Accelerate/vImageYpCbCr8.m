#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include "RevenantYpCbCr.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

static const vImage_YpCbCrToARGBMatrix revenant_ypcbcr_601_4 = {1.0f, 1.40199995f, -0.714136302f, -0.344136298f, 1.77199996f};
static const vImage_YpCbCrToARGBMatrix revenant_ypcbcr_709_2 = {1.0f, 1.57480001f, -0.46812427f, -0.187324271f, 1.8556f};
static const vImage_ARGBToYpCbCrMatrix revenant_argb_601_4 = {0.298999995f, 0.587000012f, 0.114f, -0.168735892f, -0.331264108f, 0.5f, -0.418687582f, -0.0813124105f};
static const vImage_ARGBToYpCbCrMatrix revenant_argb_709_2 = {0.212599993f, 0.715200007f, 0.0722000003f, -0.114572108f, -0.385427892f, 0.5f, -0.454152912f, -0.0458470918f};

const vImage_YpCbCrToARGBMatrix *kvImage_YpCbCrToARGBMatrix_ITU_R_601_4 = &revenant_ypcbcr_601_4;
const vImage_YpCbCrToARGBMatrix *kvImage_YpCbCrToARGBMatrix_ITU_R_709_2 = &revenant_ypcbcr_709_2;
const vImage_ARGBToYpCbCrMatrix *kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4 = &revenant_argb_601_4;
const vImage_ARGBToYpCbCrMatrix *kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2 = &revenant_argb_709_2;

static const vImage_Flags revenant_vimage_conversion_flags = kvImageDoNotTile | kvImagePrintDiagnosticsToConsole;
static const vImage_Flags revenant_vimage_generate_flags = kvImagePrintDiagnosticsToConsole;

static BOOL revenant_yuv_supports(vImageYpCbCrType yuv, vImageARGBType argb)
{
    switch (yuv) {
    case kvImage422CbYpCrYp8:
    case kvImage422CbYpCrYp8_AA8:
    case kvImage422YpCbYpCr8:
    case kvImage420Yp8_Cb8_Cr8:
    case kvImage420Yp8_CbCr8:
    case kvImage444AYpCbCr8:
    case kvImage444CbYpCrA8:
    case kvImage444CrYpCb8:
    case kvImage444CrYpCb10:
    case kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10:
        return argb == kvImageARGB8888 || argb == kvImageARGB16Q12;
    case kvImage422CbYpCrYp16:
    case kvImage444AYpCbCr16:
        return argb == kvImageARGB8888 || argb == kvImageARGB16U;
    default:
        return NO;
    }
}

vImage_Error vImageConvert_YpCbCrToARGB_GenerateConversion(const vImage_YpCbCrToARGBMatrix *matrix,
                                                           const vImage_YpCbCrPixelRange *pixelRange,
                                                           vImage_YpCbCrToARGB *outInfo,
                                                           vImageYpCbCrType inYpCbCrType,
                                                           vImageARGBType outARGBType,
                                                           vImage_Flags flags)
{
    if (flags & ~revenant_vimage_generate_flags)
        return kvImageUnknownFlagsBit;
    if (!matrix || !pixelRange || !outInfo)
        return kvImageNullPointerArgument;
    float full = revenant_argb_scale(outARGBType);
    if (full == 0.0f || !revenant_yuv_supports(inYpCbCrType, outARGBType))
        return kvImageUnsupportedConversion;
    int32_t yRange = pixelRange->YpRangeMax - pixelRange->Yp_bias;
    int32_t cRange = pixelRange->CbCrRangeMax - pixelRange->CbCr_bias;
    if (yRange == 0 || cRange == 0)
        return kvImageInvalidParameter;
    RevenantToARGB found = {
        .magic = RevenantYpCbCrToARGBMagic,
        .Yp = matrix->Yp,
        .Cr_R = matrix->Cr_R,
        .Cr_G = matrix->Cr_G,
        .Cb_G = matrix->Cb_G,
        .Cb_B = matrix->Cb_B,
        .yScale = full / (float)yRange,
        .cScale = full / (2.0f * (float)cRange),
        .Yp_bias = (float)pixelRange->Yp_bias,
        .CbCr_bias = (float)pixelRange->CbCr_bias,
        .YpMin = (float)pixelRange->YpMin,
        .YpMax = (float)pixelRange->YpMax,
        .CbCrMin = (float)pixelRange->CbCrMin,
        .CbCrMax = (float)pixelRange->CbCrMax
    };
    memset(outInfo, 0, sizeof *outInfo);
    memcpy(outInfo, &found, sizeof found);
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGBToYpCbCr_GenerateConversion(const vImage_ARGBToYpCbCrMatrix *matrix,
                                                           const vImage_YpCbCrPixelRange *pixelRange,
                                                           vImage_ARGBToYpCbCr *outInfo,
                                                           vImageARGBType inARGBType,
                                                           vImageYpCbCrType outYpCbCrType,
                                                           vImage_Flags flags)
{
    if (flags & ~revenant_vimage_generate_flags)
        return kvImageUnknownFlagsBit;
    if (!matrix || !pixelRange || !outInfo)
        return kvImageNullPointerArgument;
    float full = revenant_argb_scale(inARGBType);
    if (full == 0.0f || !revenant_yuv_supports(outYpCbCrType, inARGBType))
        return kvImageUnsupportedConversion;
    int32_t yRange = pixelRange->YpRangeMax - pixelRange->Yp_bias;
    int32_t cRange = pixelRange->CbCrRangeMax - pixelRange->CbCr_bias;
    if (yRange == 0 || cRange == 0)
        return kvImageInvalidParameter;
    RevenantToYpCbCr found = {
        .magic = RevenantARGBToYpCbCrMagic,
        .R_Yp = matrix->R_Yp,
        .G_Yp = matrix->G_Yp,
        .B_Yp = matrix->B_Yp,
        .R_Cb = matrix->R_Cb,
        .G_Cb = matrix->G_Cb,
        .B_Cb_R_Cr = matrix->B_Cb_R_Cr,
        .G_Cr = matrix->G_Cr,
        .B_Cr = matrix->B_Cr,
        .yScale = (float)yRange / full,
        .cScale = 2.0f * (float)cRange / full,
        .Yp_bias = (float)pixelRange->Yp_bias,
        .CbCr_bias = (float)pixelRange->CbCr_bias,
        .YpMin = (float)pixelRange->YpMin,
        .YpMax = (float)pixelRange->YpMax,
        .CbCrMin = (float)pixelRange->CbCrMin,
        .CbCrMax = (float)pixelRange->CbCrMax
    };
    memset(outInfo, 0, sizeof *outInfo);
    memcpy(outInfo, &found, sizeof found);
    return kvImageNoError;
}

enum {
    RevenantYUV422YpCbYpCr8,
    RevenantYUV422CbYpCrYp8,
    RevenantYUV444AYpCbCr8,
    RevenantYUV444CbYpCrA8,
    RevenantYUV444CrYpCb8,
    RevenantYUV444AYpCbCr16,
    RevenantYUV422CbYpCrYp16,
    RevenantYUV444CrYpCb10,
    RevenantYUV422v210
};

typedef struct RevenantYUVLayout {
    unsigned across;
    unsigned down;
    unsigned group;
    unsigned alphaWords;
} RevenantYUVLayout;

static const RevenantYUVLayout revenant_yuv_layouts[] = {
    [RevenantYUV422YpCbYpCr8]  = {2, 1, 2, 1},
    [RevenantYUV422CbYpCrYp8]  = {2, 1, 2, 1},
    [RevenantYUV444AYpCbCr8]   = {1, 1, 1, 1},
    [RevenantYUV444CbYpCrA8]   = {1, 1, 1, 1},
    [RevenantYUV444CrYpCb8]    = {1, 1, 1, 1},
    [RevenantYUV444AYpCbCr16]  = {1, 1, 1, 2},
    [RevenantYUV422CbYpCrYp16] = {2, 1, 2, 1},
    [RevenantYUV444CrYpCb10]   = {1, 1, 1, 1},
    [RevenantYUV422v210]       = {2, 1, 6, 1}
};

static inline void revenant_v410_split(uint32_t pixel, float *Yp, float *Cb, float *Cr)
{
    *Cb = (float)(pixel & 0x3FFu);
    *Yp = (float)((pixel >> 10) & 0x3FFu);
    *Cr = (float)((pixel >> 20) & 0x3FFu);
}

static inline uint32_t revenant_v410_join(uint32_t Yp, uint32_t Cb, uint32_t Cr)
{
    return ((Cr & 0x3FFu) << 20) | ((Yp & 0x3FFu) << 10) | (Cb & 0x3FFu);
}

static inline void revenant_v210_split(const uint32_t *words, float *Yp, float *Cb, float *Cr)
{
    Cb[0] = (float)(words[0] & 0x3FFu);
    Yp[0] = (float)((words[0] >> 10) & 0x3FFu);
    Cr[0] = (float)((words[0] >> 20) & 0x3FFu);
    Yp[1] = (float)(words[1] & 0x3FFu);
    Cb[1] = (float)((words[1] >> 10) & 0x3FFu);
    Yp[2] = (float)((words[1] >> 20) & 0x3FFu);
    Cr[1] = (float)(words[2] & 0x3FFu);
    Yp[3] = (float)((words[2] >> 10) & 0x3FFu);
    Cb[2] = (float)((words[2] >> 20) & 0x3FFu);
    Yp[4] = (float)(words[3] & 0x3FFu);
    Cr[2] = (float)((words[3] >> 10) & 0x3FFu);
    Yp[5] = (float)((words[3] >> 20) & 0x3FFu);
}

static inline void revenant_v210_join(uint32_t *words, const uint32_t *Yp, const uint32_t *Cb, const uint32_t *Cr)
{
    words[0] = revenant_v410_join(Yp[0], Cb[0], Cr[0]);
    words[1] = revenant_v410_join(Yp[2], Cb[1], Yp[1]);
    words[2] = revenant_v410_join(Yp[3], Cr[1], Cb[2]);
    words[3] = revenant_v410_join(Yp[5], Yp[4], Cr[2]);
}

static void revenant_yuv_read(int layout, const uint8_t *row, vImagePixelCount column, uint32_t alpha,
                            BOOL hasAlphaArgument, float *Yp, float *Cb, float *Cr, uint32_t *A)
{
    switch (layout) {
    case RevenantYUV422YpCbYpCr8: {
        vImagePixelCount pair = (column / 2) * 4;
        *Yp = (float)row[pair + (column & 1 ? 2 : 0)];
        *Cb = (float)row[pair + 1];
        *Cr = (float)row[pair + 3];
        *A = hasAlphaArgument ? alpha : 255;
        break;
    }
    case RevenantYUV422CbYpCrYp8: {
        vImagePixelCount pair = (column / 2) * 4;
        *Cb = (float)row[pair];
        *Yp = (float)row[pair + (column & 1 ? 3 : 1)];
        *Cr = (float)row[pair + 2];
        *A = hasAlphaArgument ? alpha : 255;
        break;
    }
    case RevenantYUV444AYpCbCr8:
        *A = row[column * 4];
        *Yp = (float)row[column * 4 + 1];
        *Cb = (float)row[column * 4 + 2];
        *Cr = (float)row[column * 4 + 3];
        break;
    case RevenantYUV444CbYpCrA8:
        *Cb = (float)row[column * 4];
        *Yp = (float)row[column * 4 + 1];
        *Cr = (float)row[column * 4 + 2];
        *A = row[column * 4 + 3];
        break;
    case RevenantYUV444CrYpCb8:
        *Cr = (float)row[column * 3];
        *Yp = (float)row[column * 3 + 1];
        *Cb = (float)row[column * 3 + 2];
        *A = hasAlphaArgument ? alpha : 255;
        break;
    case RevenantYUV444AYpCbCr16: {
        const uint16_t *wide = (const uint16_t *)(const void *)row + column * 4;
        *A = wide[0];
        *Yp = (float)wide[1];
        *Cb = (float)wide[2];
        *Cr = (float)wide[3];
        break;
    }
    case RevenantYUV422CbYpCrYp16: {
        const uint16_t *wide = (const uint16_t *)(const void *)row + (column / 2) * 4;
        *Cb = (float)wide[0];
        *Yp = (float)wide[column & 1 ? 3 : 1];
        *Cr = (float)wide[2];
        *A = hasAlphaArgument ? alpha : 65535;
        break;
    }
    case RevenantYUV444CrYpCb10: {
        revenant_v410_split(*(const uint32_t *)(const void *)(row + column * 4), Yp, Cb, Cr);
        *A = hasAlphaArgument ? alpha : 0;
        break;
    }
    case RevenantYUV422v210: {
        float yp[6], cb[3], cr[3];
        unsigned at = (unsigned)column % 6u;
        revenant_v210_split((const uint32_t *)(const void *)(row + (column / 6) * 48), yp, cb, cr);
        *Yp = yp[at];
        *Cb = cb[at / 2u];
        *Cr = cr[at / 2u];
        *A = hasAlphaArgument ? alpha : 0;
        break;
    }
    default:
        *Yp = *Cb = *Cr = 0.0f;
        *A = hasAlphaArgument ? alpha : 255;
        break;
    }
}

static void revenant_argb_store8(const RevenantToARGB *conversion, float Yp, float Cb, float Cr, uint32_t A,
                               const uint8_t *permuteMap, uint8_t *out)
{
    float red, green, blue;
    revenant_argb_of(conversion, Yp, Cb, Cr, &red, &green, &blue);
    uint8_t argb[4] = {(uint8_t)A, (uint8_t)revenant_grade(red, 255.0f), (uint8_t)revenant_grade(green, 255.0f),
                       (uint8_t)revenant_grade(blue, 255.0f)};
    out[0] = argb[permuteMap[0]];
    out[1] = argb[permuteMap[1]];
    out[2] = argb[permuteMap[2]];
    out[3] = argb[permuteMap[3]];
}

static void revenant_argb_store16(const RevenantToARGB *conversion, float Yp, float Cb, float Cr, uint32_t A,
                                const uint8_t *permuteMap, uint16_t *out, float full)
{
    float red, green, blue;
    revenant_argb_of(conversion, Yp, Cb, Cr, &red, &green, &blue);
    uint32_t argb[4] = {A, revenant_grade(red, full), revenant_grade(green, full), revenant_grade(blue, full)};
    out[0] = (uint16_t)argb[permuteMap[0]];
    out[1] = (uint16_t)argb[permuteMap[1]];
    out[2] = (uint16_t)argb[permuteMap[2]];
    out[3] = (uint16_t)argb[permuteMap[3]];
}

static vImage_Error revenant_yuv_to_argb(int layout, float destFull, const vImage_Buffer *src,
                                       const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                       const uint8_t *permuteMap, uint32_t alpha, BOOL hasAlphaArgument,
                                       const vImage_Buffer *srcA)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (!src || !dest || !info)
        return kvImageNullPointerArgument;
    const RevenantToARGB *conversion = revenant_to_argb(info);
    if (!conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!revenant_permutation(permuteMap))
        return kvImageInvalidParameter;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    const RevenantYUVLayout *shape = &revenant_yuv_layouts[layout];
    if (shape->group > 1 && dest->width % shape->group)
        return kvImageRoiLargerThanInputBuffer;
    vImagePixelCount width = dest->width, height = dest->height;
    for (vImagePixelCount row = 0; row < height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        const uint8_t *alphaRow = srcA ? (const uint8_t *)srcA->data + row * srcA->rowBytes : NULL;
        uint8_t *out8 = (uint8_t *)dest->data + row * dest->rowBytes;
        uint16_t *out16 = (uint16_t *)(void *)out8;
        for (vImagePixelCount column = 0; column < width; column++) {
            float Yp, Cb, Cr;
            uint32_t A = 0;
            revenant_yuv_read(layout, in, column, alpha, hasAlphaArgument, &Yp, &Cb, &Cr, &A);
            if (alphaRow)
                A = alphaRow[column];
            if (shape->alphaWords == 2 && destFull == 255.0f)
                A = (A * 255u + 32767u) / 65535u;
            if (destFull == 255.0f) {
                revenant_argb_store8(conversion, Yp, Cb, Cr, A, permuteMap, out8 + column * 4);
            } else {
                revenant_argb_store16(conversion, Yp, Cb, Cr, A, permuteMap, out16 + column * 4, destFull);
            }
        }
    }
    return kvImageNoError;
}

#define RevenantYUVToARGB(name, layout, full, hasAlpha)                                                         \
    vImage_Error name(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,     \
                      const uint8_t permuteMap[4], const uint8_t alpha, vImage_Flags flags)                     \
    {                                                                                                          \
        if (flags & ~revenant_vimage_conversion_flags)                                                           \
            return kvImageUnknownFlagsBit;                                                                     \
        return revenant_yuv_to_argb(layout, full, src, dest, info, permuteMap, (uint32_t)alpha, hasAlpha, NULL);   \
    }

#define RevenantYUVToARGBNoAlpha(name, layout, full)                                                            \
    vImage_Error name(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,     \
                      const uint8_t permuteMap[4], vImage_Flags flags)                                         \
    {                                                                                                          \
        if (flags & ~revenant_vimage_conversion_flags)                                                           \
            return kvImageUnknownFlagsBit;                                                                     \
        return revenant_yuv_to_argb(layout, full, src, dest, info, permuteMap, 0, NO, NULL);                      \
    }

RevenantYUVToARGB(vImageConvert_422YpCbYpCr8ToARGB8888, RevenantYUV422YpCbYpCr8, 255.0f, YES)
RevenantYUVToARGB(vImageConvert_422CbYpCrYp8ToARGB8888, RevenantYUV422CbYpCrYp8, 255.0f, YES)
RevenantYUVToARGB(vImageConvert_444CrYpCb8ToARGB8888, RevenantYUV444CrYpCb8, 255.0f, YES)
RevenantYUVToARGB(vImageConvert_422CbYpCrYp16ToARGB8888, RevenantYUV422CbYpCrYp16, 255.0f, YES)
RevenantYUVToARGB(vImageConvert_444CrYpCb10ToARGB8888, RevenantYUV444CrYpCb10, 255.0f, YES)
RevenantYUVToARGBNoAlpha(vImageConvert_444AYpCbCr8ToARGB8888, RevenantYUV444AYpCbCr8, 255.0f)
RevenantYUVToARGBNoAlpha(vImageConvert_444CbYpCrA8ToARGB8888, RevenantYUV444CbYpCrA8, 255.0f)
RevenantYUVToARGBNoAlpha(vImageConvert_444AYpCbCr16ToARGB8888, RevenantYUV444AYpCbCr16, 255.0f)

#undef RevenantYUVToARGB
#undef RevenantYUVToARGBNoAlpha

vImage_Error vImageConvert_444AYpCbCr16ToARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4],
                                                  vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_yuv_to_argb(RevenantYUV444AYpCbCr16, 65535.0f, src, dest, info, permuteMap, 0, NO, NULL);
}

vImage_Error vImageConvert_422CbYpCrYp16ToARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4],
                                                  const uint16_t alpha, vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_yuv_to_argb(RevenantYUV422CbYpCrYp16, 65535.0f, src, dest, info, permuteMap, alpha, YES, NULL);
}

vImage_Error vImageConvert_444CrYpCb10ToARGB16Q12(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                   const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4],
                                                   const Pixel_16Q12 alpha, vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_yuv_to_argb(RevenantYUV444CrYpCb10, 4096.0f, src, dest, info, permuteMap, alpha, YES, NULL);
}

vImage_Error vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888(const vImage_Buffer *src,
                                                                     const vImage_Buffer *dest,
                                                                     const vImage_YpCbCrToARGB *info,
                                                                     const uint8_t permuteMap[4],
                                                                     const uint8_t alpha, vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_yuv_to_argb(RevenantYUV422v210, 255.0f, src, dest, info, permuteMap, alpha, YES, NULL);
}

vImage_Error vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(const vImage_Buffer *src,
                                                                      const vImage_Buffer *dest,
                                                                      const vImage_YpCbCrToARGB *info,
                                                                      const uint8_t permuteMap[4],
                                                                      const Pixel_16Q12 alpha, vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_yuv_to_argb(RevenantYUV422v210, 4096.0f, src, dest, info, permuteMap, alpha, YES, NULL);
}

vImage_Error vImageConvert_422CbYpCrYp8_AA8ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *srcA,
                                                      const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                                      const uint8_t permuteMap[4], vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    if (!srcA)
        return kvImageNullPointerArgument;
    if (srcA->width < src->width || srcA->height < src->height)
        return kvImageRoiLargerThanInputBuffer;
    return revenant_yuv_to_argb(RevenantYUV422CbYpCrYp8, 255.0f, src, dest, info, permuteMap, 0, NO, srcA);
}

static vImage_Error revenant_420_to_argb(const vImage_Buffer *srcYp, const vImage_Buffer *srcCb,
                                       const vImage_Buffer *srcCr, const vImage_Buffer *srcCbCr,
                                       const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                       const uint8_t *permuteMap, uint8_t alpha, vImage_Flags flags)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    const RevenantToARGB *conversion = revenant_to_argb(info);
    if (!srcYp || !dest || !conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!revenant_permutation(permuteMap))
        return kvImageInvalidParameter;
    vImagePixelCount width = dest->width, height = dest->height;
    if (srcYp->width < width || srcYp->height < height)
        return kvImageRoiLargerThanInputBuffer;
    vImagePixelCount chromaWidth = (width + 1) / 2, chromaHeight = (height + 1) / 2;
    if (srcCbCr) {
        if (srcCbCr->width < chromaWidth || srcCbCr->height < chromaHeight)
            return kvImageRoiLargerThanInputBuffer;
    } else {
        if (!srcCb || !srcCr)
            return kvImageNullPointerArgument;
        if (srcCb->width < chromaWidth || srcCb->height < chromaHeight
            || srcCr->width < chromaWidth || srcCr->height < chromaHeight)
            return kvImageRoiLargerThanInputBuffer;
    }
    for (vImagePixelCount row = 0; row < height; row++) {
        const uint8_t *luma = (const uint8_t *)srcYp->data + row * srcYp->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        vImagePixelCount chromaRow = row / 2;
        const uint8_t *cbcr = srcCbCr ? (const uint8_t *)srcCbCr->data + chromaRow * srcCbCr->rowBytes : NULL;
        const uint8_t *cbRow = srcCb ? (const uint8_t *)srcCb->data + chromaRow * srcCb->rowBytes : NULL;
        const uint8_t *crRow = srcCr ? (const uint8_t *)srcCr->data + chromaRow * srcCr->rowBytes : NULL;
        for (vImagePixelCount column = 0; column < width; column++) {
            vImagePixelCount chromaColumn = column / 2;
            float cb = cbcr ? (float)cbcr[chromaColumn * 2] : (float)cbRow[chromaColumn];
            float cr = cbcr ? (float)cbcr[chromaColumn * 2 + 1] : (float)crRow[chromaColumn];
            revenant_argb_store8(conversion, (float)luma[column], cb, cr, alpha, permuteMap, out + column * 4);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_420Yp8_CbCr8ToARGB8888(const vImage_Buffer *srcYp, const vImage_Buffer *srcCbCr,
                                                  const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                                  const uint8_t permuteMap[4], const uint8_t alpha,
                                                  vImage_Flags flags)
{
    return revenant_420_to_argb(srcYp, NULL, NULL, srcCbCr, dest, info, permuteMap, alpha, flags);
}

vImage_Error vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(const vImage_Buffer *srcYp, const vImage_Buffer *srcCb,
                                                    const vImage_Buffer *srcCr, const vImage_Buffer *dest,
                                                    const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4],
                                                    const uint8_t alpha, vImage_Flags flags)
{
    return revenant_420_to_argb(srcYp, srcCb, srcCr, NULL, dest, info, permuteMap, alpha, flags);
}

static void revenant_rgb_read(int words, const vImage_Buffer *src, vImagePixelCount row, vImagePixelCount column,
                            const uint8_t *permuteMap, float *rgb)
{
    const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
    if (words == 1) {
        rgb[0] = (float)in[column * 4 + permuteMap[1]];
        rgb[1] = (float)in[column * 4 + permuteMap[2]];
        rgb[2] = (float)in[column * 4 + permuteMap[3]];
    } else {
        const uint16_t *wide = (const uint16_t *)(const void *)in + column * 4;
        rgb[0] = (float)wide[permuteMap[1]];
        rgb[1] = (float)wide[permuteMap[2]];
        rgb[2] = (float)wide[permuteMap[3]];
    }
}

static uint32_t revenant_luma_of(const RevenantToYpCbCr *conversion, const float *rgb)
{
    float Yp, Cb, Cr;
    revenant_ypcbcr_of(conversion, rgb[0], rgb[1], rgb[2], &Yp, &Cb, &Cr);
    return revenant_encode(Yp, conversion->YpMin, conversion->YpMax);
}

static void revenant_chroma_of(const RevenantToYpCbCr *conversion, int words, const vImage_Buffer *src,
                             vImagePixelCount width, vImagePixelCount height, vImagePixelCount row,
                             vImagePixelCount column, unsigned across, unsigned down, const uint8_t *permuteMap,
                             uint32_t *Cb, uint32_t *Cr)
{
    float blue = 0.0f, red = 0.0f;
    unsigned counted = 0;
    for (vImagePixelCount step = 0; step < (vImagePixelCount)down; step++) {
        if (row + step >= height)
            continue;
        for (vImagePixelCount other = 0; other < (vImagePixelCount)across; other++) {
            if (column + other >= width)
                continue;
            float rgb[3], one, two;
            revenant_rgb_read(words, src, row + step, column + other, permuteMap, rgb);
            revenant_ypcbcr_chroma_of(conversion, rgb[0], rgb[1], rgb[2], &one, &two);
            blue += one;
            red += two;
            counted++;
        }
    }
    if (counted == 0)
        counted = 1;
    *Cb = revenant_encode(conversion->CbCr_bias + blue * conversion->cScale / (float)counted, conversion->CbCrMin,
                        conversion->CbCrMax);
    *Cr = revenant_encode(conversion->CbCr_bias + red * conversion->cScale / (float)counted, conversion->CbCrMin,
                        conversion->CbCrMax);
}

static uint32_t revenant_alpha_of(int words, const vImage_Buffer *src, vImagePixelCount row, vImagePixelCount column,
                                const uint8_t *permuteMap)
{
    const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
    if (words == 1)
        return in[column * 4 + permuteMap[0]];
    return ((const uint16_t *)(const void *)in)[column * 4 + permuteMap[0]];
}

static vImage_Error revenant_argb_to_yuv(int layout, int words, const vImage_Buffer *src, const vImage_Buffer *dest,
                                       const vImage_ARGBToYpCbCr *info, const uint8_t *permuteMap,
                                       const vImage_Buffer *destA)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (!src || !dest || !info)
        return kvImageNullPointerArgument;
    const RevenantToYpCbCr *conversion = revenant_to_ypcbcr(info);
    if (!conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!revenant_permutation(permuteMap))
        return kvImageInvalidParameter;
    const RevenantYUVLayout *shape = &revenant_yuv_layouts[layout];
    vImagePixelCount width = dest->width, height = dest->height;
    if (src->width < width || src->height < height)
        return kvImageRoiLargerThanInputBuffer;
    if (destA && (destA->width < width || destA->height < height))
        return kvImageRoiLargerThanInputBuffer;
    for (vImagePixelCount row = 0; row < height; row++) {
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        uint16_t *wide = (uint16_t *)(void *)out;
        for (vImagePixelCount column = 0; column < width; column++) {
            float rgb[3];
            revenant_rgb_read(words, src, row, column, permuteMap, rgb);
            uint32_t luma = revenant_luma_of(conversion, rgb);
            uint32_t Cb = 0, Cr = 0;
            int starts = (column % shape->across) == 0;
            if (starts)
                revenant_chroma_of(conversion, words, src, width, height, row, column, shape->across, shape->down,
                                 permuteMap, &Cb, &Cr);
            switch (layout) {
            case RevenantYUV422YpCbYpCr8: {
                vImagePixelCount pair = (column / 2) * 4;
                out[pair + (column & 1 ? 2 : 0)] = (uint8_t)luma;
                if (starts) {
                    out[pair + 1] = (uint8_t)Cb;
                    out[pair + 3] = (uint8_t)Cr;
                }
                break;
            }
            case RevenantYUV422CbYpCrYp8: {
                vImagePixelCount pair = (column / 2) * 4;
                out[pair + (column & 1 ? 3 : 1)] = (uint8_t)luma;
                if (starts) {
                    out[pair] = (uint8_t)Cb;
                    out[pair + 2] = (uint8_t)Cr;
                }
                break;
            }
            case RevenantYUV444AYpCbCr8:
                out[column * 4] = (uint8_t)revenant_alpha_of(words, src, row, column, permuteMap);
                out[column * 4 + 1] = (uint8_t)luma;
                out[column * 4 + 2] = (uint8_t)Cb;
                out[column * 4 + 3] = (uint8_t)Cr;
                break;
            case RevenantYUV444CbYpCrA8:
                out[column * 4] = (uint8_t)Cb;
                out[column * 4 + 1] = (uint8_t)luma;
                out[column * 4 + 2] = (uint8_t)Cr;
                out[column * 4 + 3] = (uint8_t)revenant_alpha_of(words, src, row, column, permuteMap);
                break;
            case RevenantYUV444CrYpCb8:
                out[column * 3] = (uint8_t)Cr;
                out[column * 3 + 1] = (uint8_t)luma;
                out[column * 3 + 2] = (uint8_t)Cb;
                break;
            case RevenantYUV444AYpCbCr16: {
                uint32_t source = revenant_alpha_of(words, src, row, column, permuteMap);
                wide[column * 4] = (uint16_t)(words == 1 ? source * 257u : source);
                wide[column * 4 + 1] = (uint16_t)luma;
                wide[column * 4 + 2] = (uint16_t)Cb;
                wide[column * 4 + 3] = (uint16_t)Cr;
                break;
            }
            case RevenantYUV422CbYpCrYp16: {
                uint16_t *pair = wide + (column / 2) * 4;
                pair[column & 1 ? 3 : 1] = (uint16_t)luma;
                if (starts) {
                    pair[0] = (uint16_t)Cb;
                    pair[2] = (uint16_t)Cr;
                }
                break;
            }
            default:
                break;
            }
        }
        if (destA) {
            uint8_t *alphaRow = (uint8_t *)destA->data + row * destA->rowBytes;
            for (vImagePixelCount column = 0; column < width; column++)
                alphaRow[column] = (uint8_t)revenant_alpha_of(words, src, row, column, permuteMap);
        }
    }
    return kvImageNoError;
}

#define RevenantARGBToYUV(name, layout, words)                                                                  \
    vImage_Error name(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info,     \
                      const uint8_t permuteMap[4], vImage_Flags flags)                                         \
    {                                                                                                          \
        if (flags & ~revenant_vimage_conversion_flags)                                                           \
            return kvImageUnknownFlagsBit;                                                                     \
        return revenant_argb_to_yuv(layout, words, src, dest, info, permuteMap, NULL);                           \
    }

RevenantARGBToYUV(vImageConvert_ARGB8888To422YpCbYpCr8, RevenantYUV422YpCbYpCr8, 1)
RevenantARGBToYUV(vImageConvert_ARGB8888To422CbYpCrYp8, RevenantYUV422CbYpCrYp8, 1)
RevenantARGBToYUV(vImageConvert_ARGB8888To444AYpCbCr8, RevenantYUV444AYpCbCr8, 1)
RevenantARGBToYUV(vImageConvert_ARGB8888To444CbYpCrA8, RevenantYUV444CbYpCrA8, 1)
RevenantARGBToYUV(vImageConvert_ARGB8888To444CrYpCb8, RevenantYUV444CrYpCb8, 1)
RevenantARGBToYUV(vImageConvert_ARGB8888To444AYpCbCr16, RevenantYUV444AYpCbCr16, 1)
RevenantARGBToYUV(vImageConvert_ARGB8888To422CbYpCrYp16, RevenantYUV422CbYpCrYp16, 1)

#undef RevenantARGBToYUV

vImage_Error vImageConvert_ARGB16UTo444AYpCbCr16(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                  vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_argb_to_yuv(RevenantYUV444AYpCbCr16, 2, src, dest, info, permuteMap, NULL);
}

vImage_Error vImageConvert_ARGB16UTo422CbYpCrYp16(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                  vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_argb_to_yuv(RevenantYUV422CbYpCrYp16, 2, src, dest, info, permuteMap, NULL);
}

vImage_Error vImageConvert_ARGB8888To422CbYpCrYp8_AA8(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                      const vImage_Buffer *destA, const vImage_ARGBToYpCbCr *info,
                                                      const uint8_t permuteMap[4], vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    if (!destA)
        return kvImageNullPointerArgument;
    return revenant_argb_to_yuv(RevenantYUV422CbYpCrYp8, 1, src, dest, info, permuteMap, destA);
}

static vImage_Error revenant_argb_to_v410(int words, const vImage_Buffer *src, const vImage_Buffer *dest,
                                        const vImage_ARGBToYpCbCr *info, const uint8_t *permuteMap)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (!src || !dest || !info)
        return kvImageNullPointerArgument;
    const RevenantToYpCbCr *conversion = revenant_to_ypcbcr(info);
    if (!conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!revenant_permutation(permuteMap))
        return kvImageInvalidParameter;
    vImagePixelCount width = dest->width, height = dest->height;
    if (src->width < width || src->height < height)
        return kvImageRoiLargerThanInputBuffer;
    for (vImagePixelCount row = 0; row < height; row++) {
        uint32_t *out = (uint32_t *)(void *)((uint8_t *)dest->data + row * dest->rowBytes);
        for (vImagePixelCount column = 0; column < width; column++) {
            float rgb[3], Yp, Cb, Cr;
            revenant_rgb_read(words, src, row, column, permuteMap, rgb);
            revenant_ypcbcr_of(conversion, rgb[0], rgb[1], rgb[2], &Yp, &Cb, &Cr);
            out[column] = revenant_v410_join(revenant_encode(Yp, conversion->YpMin, conversion->YpMax),
                                           revenant_encode(Cb, conversion->CbCrMin, conversion->CbCrMax),
                                           revenant_encode(Cr, conversion->CbCrMin, conversion->CbCrMax));
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGB8888To444CrYpCb10(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                 const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                 vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_argb_to_v410(1, src, dest, info, permuteMap);
}

vImage_Error vImageConvert_ARGB16Q12To444CrYpCb10(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                  vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_argb_to_v410(3, src, dest, info, permuteMap);
}

static vImage_Error revenant_argb_to_v210(int words, const vImage_Buffer *src, const vImage_Buffer *dest,
                                        const vImage_ARGBToYpCbCr *info, const uint8_t *permuteMap)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (!src || !dest || !info)
        return kvImageNullPointerArgument;
    const RevenantToYpCbCr *conversion = revenant_to_ypcbcr(info);
    if (!conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!revenant_permutation(permuteMap))
        return kvImageInvalidParameter;
    vImagePixelCount width = dest->width, height = dest->height;
    if (src->width < width || src->height < height)
        return kvImageRoiLargerThanInputBuffer;
    if (width % 6)
        return kvImageRoiLargerThanInputBuffer;
    for (vImagePixelCount row = 0; row < height; row++) {
        uint32_t *out = (uint32_t *)(void *)((uint8_t *)dest->data + row * dest->rowBytes);
        for (vImagePixelCount column = 0; column < width; column += 6) {
            uint32_t Yp[6], Cb[3], Cr[3];
            for (vImagePixelCount index = 0; index < 6; index++) {
                float rgb[3];
                revenant_rgb_read(words, src, row, column + index, permuteMap, rgb);
                Yp[index] = revenant_encode(revenant_ypcbcr_luma_of(conversion, rgb[0], rgb[1], rgb[2]),
                                          conversion->YpMin, conversion->YpMax);
            }
            for (vImagePixelCount index = 0; index < 3; index++) {
                revenant_chroma_of(conversion, words, src, width, height, row, column + index * 2, 2, 1, permuteMap,
                                 &Cb[index], &Cr[index]);
            }
            revenant_v210_join(out + (column / 6) * 4, Yp, Cb, Cr);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(const vImage_Buffer *src,
                                                                     const vImage_Buffer *dest,
                                                                     const vImage_ARGBToYpCbCr *info,
                                                                     const uint8_t permuteMap[4], vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_argb_to_v210(1, src, dest, info, permuteMap);
}

vImage_Error vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(const vImage_Buffer *src,
                                                                      const vImage_Buffer *dest,
                                                                      const vImage_ARGBToYpCbCr *info,
                                                                      const uint8_t permuteMap[4], vImage_Flags flags)
{
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return revenant_argb_to_v210(3, src, dest, info, permuteMap);
}

static vImage_Error revenant_argb_to_420(const vImage_Buffer *src, const vImage_Buffer *destYp,
                                       const vImage_Buffer *destCb, const vImage_Buffer *destCr,
                                       const vImage_Buffer *destCbCr, const vImage_ARGBToYpCbCr *info,
                                       const uint8_t *permuteMap, vImage_Flags flags)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (flags & ~revenant_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    const RevenantToYpCbCr *conversion = revenant_to_ypcbcr(info);
    if (!src || !destYp || !conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!revenant_permutation(permuteMap))
        return kvImageInvalidParameter;
    vImagePixelCount width = destYp->width, height = destYp->height;
    if (src->width < width || src->height < height)
        return kvImageRoiLargerThanInputBuffer;
    vImagePixelCount chromaWidth = (width + 1) / 2, chromaHeight = (height + 1) / 2;
    if (destCbCr) {
        if (destCbCr->width < chromaWidth || destCbCr->height < chromaHeight)
            return kvImageRoiLargerThanInputBuffer;
    } else {
        if (!destCb || !destCr)
            return kvImageNullPointerArgument;
        if (destCb->width < chromaWidth || destCb->height < chromaHeight
            || destCr->width < chromaWidth || destCr->height < chromaHeight)
            return kvImageRoiLargerThanInputBuffer;
    }
    for (vImagePixelCount row = 0; row < height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *luma = (uint8_t *)destYp->data + row * destYp->rowBytes;
        for (vImagePixelCount column = 0; column < width; column++) {
            const uint8_t *pixel = in + column * 4;
            float red = (float)pixel[permuteMap[1]], green = (float)pixel[permuteMap[2]],
                  blue = (float)pixel[permuteMap[3]];
            luma[column] = (uint8_t)revenant_luma_of(conversion, (float[3]){red, green, blue});
        }
    }
    for (vImagePixelCount row = 0; row < chromaHeight; row++) {
        uint8_t *cbcr = destCbCr ? (uint8_t *)destCbCr->data + row * destCbCr->rowBytes : NULL;
        uint8_t *cbRow = destCb ? (uint8_t *)destCb->data + row * destCb->rowBytes : NULL;
        uint8_t *crRow = destCr ? (uint8_t *)destCr->data + row * destCr->rowBytes : NULL;
        for (vImagePixelCount column = 0; column < chromaWidth; column++) {
            uint32_t Cb, Cr;
            revenant_chroma_of(conversion, 1, src, width, height, row * 2, column * 2, 2, 2, permuteMap, &Cb, &Cr);
            if (cbcr) {
                cbcr[column * 2] = (uint8_t)Cb;
                cbcr[column * 2 + 1] = (uint8_t)Cr;
            } else {
                cbRow[column] = (uint8_t)Cb;
                crRow[column] = (uint8_t)Cr;
            }
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGB8888To420Yp8_CbCr8(const vImage_Buffer *src, const vImage_Buffer *destYp,
                                                  const vImage_Buffer *destCbCr, const vImage_ARGBToYpCbCr *info,
                                                  const uint8_t permuteMap[4], vImage_Flags flags)
{
    return revenant_argb_to_420(src, destYp, NULL, NULL, destCbCr, info, permuteMap, flags);
}

vImage_Error vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(const vImage_Buffer *src, const vImage_Buffer *destYp,
                                                    const vImage_Buffer *destCb, const vImage_Buffer *destCr,
                                                    const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                    vImage_Flags flags)
{
    return revenant_argb_to_420(src, destYp, destCb, destCr, NULL, info, permuteMap, flags);
}

vImage_Error vImageExtractChannel_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, long channelIndex,
                                           vImage_Flags flags)
{
    static const vImage_Flags revenant_channel_flags = kvImageDoNotTile | kvImageGetTempBufferSize
                                                     | kvImagePrintDiagnosticsToConsole;
    if (flags & ~revenant_channel_flags)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    if (channelIndex < 0 || channelIndex > 3)
        return kvImageInvalidParameter;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++)
            out[column] = in[column * 4 + (size_t)channelIndex];
    }
    return kvImageNoError;
}
