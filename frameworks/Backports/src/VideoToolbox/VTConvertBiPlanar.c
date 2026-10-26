#include "VTConvertBiPlanar.h"

#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

static const int16_t RevenantVTCoefficients[4][4] = {
    {1634, -401, -833, 2065},
    {1836, -218, -546, 2163},
    {1436, -352, -731, 1814},
    {1613, -192, -479, 1900},
};

static const int16_t *RevenantVTCoefficientsFor(bool fullRange, bool bt709)
{
    return RevenantVTCoefficients[(fullRange ? 2 : 0) + (bt709 ? 1 : 0)];
}

static uint8_t RevenantVTClamp(int value)
{
    return value < 0 ? 0 : value > 255 ? 255 : (uint8_t)value;
}

static int RevenantVTRoundQ10(int value)
{
    return (value + 512) >> 10;
}

static void RevenantVTConvertRowScalar(uint8_t *out, const uint8_t *luma, const uint8_t *chroma, size_t from, size_t to, bool fullRange, bool bt709)
{
    const int16_t *k = RevenantVTCoefficientsFor(fullRange, bt709);
    for (size_t column = from; column < to; column++) {
        const int Y = luma[column];
        const uint8_t *pair = chroma + (column / 2) * 2;
        const int Cb = pair[0] - 128;
        const int Cr = pair[1] - 128;
        const int scaled = fullRange ? Y << 10 : (Y - 16) * 1192;
        const int red = scaled + k[0] * Cr;
        const int green = scaled + k[1] * Cb + k[2] * Cr;
        const int blue = scaled + k[3] * Cb;
        uint8_t *pixel = out + column * 4;
        pixel[0] = RevenantVTClamp(RevenantVTRoundQ10(blue));
        pixel[1] = RevenantVTClamp(RevenantVTRoundQ10(green));
        pixel[2] = RevenantVTClamp(RevenantVTRoundQ10(red));
        pixel[3] = 255;
    }
}

void RevenantVTConvertBiPlanarScalar(uint8_t *out, size_t rowBytes, const uint8_t *luma, size_t lumaStride, const uint8_t *chroma, size_t chromaStride, size_t width, size_t height, bool fullRange, bool bt709)
{
    for (size_t row = 0; row < height; row++)
        RevenantVTConvertRowScalar(out + row * rowBytes, luma + row * lumaStride, chroma + (row / 2) * chromaStride, 0, width, fullRange, bt709);
}

#if defined(__ARM_NEON)

static uint8x8_t RevenantVTNarrowQ10(int32x4_t low, int32x4_t high)
{
    const int32x4_t half = vdupq_n_s32(512);
    const uint16x8_t wide = vcombine_u16(vqmovun_s32(vshrq_n_s32(vaddq_s32(low, half), 10)), vqmovun_s32(vshrq_n_s32(vaddq_s32(high, half), 10)));
    return vqmovn_u16(wide);
}

static void RevenantVTConvert8NEON(uint8_t *out, uint8x8_t y8, uint8x8_t cb8, uint8x8_t cr8, const int16_t *k, bool fullRange)
{
    const int16x8_t y = vreinterpretq_s16_u16(vmovl_u8(y8));
    const int16x8_t cb = vsubq_s16(vreinterpretq_s16_u16(vmovl_u8(cb8)), vdupq_n_s16(128));
    const int16x8_t cr = vsubq_s16(vreinterpretq_s16_u16(vmovl_u8(cr8)), vdupq_n_s16(128));
    int32x4_t scaledLow, scaledHigh;
    if (fullRange) {
        scaledLow = vshlq_n_s32(vmovl_s16(vget_low_s16(y)), 10);
        scaledHigh = vshlq_n_s32(vmovl_s16(vget_high_s16(y)), 10);
    } else {
        const int16x8_t offset = vsubq_s16(y, vdupq_n_s16(16));
        scaledLow = vmull_n_s16(vget_low_s16(offset), 1192);
        scaledHigh = vmull_n_s16(vget_high_s16(offset), 1192);
    }
    const int32x4_t redLow = vmlal_n_s16(scaledLow, vget_low_s16(cr), k[0]);
    const int32x4_t redHigh = vmlal_n_s16(scaledHigh, vget_high_s16(cr), k[0]);
    const int32x4_t greenLow = vmlal_n_s16(vmlal_n_s16(scaledLow, vget_low_s16(cb), k[1]), vget_low_s16(cr), k[2]);
    const int32x4_t greenHigh = vmlal_n_s16(vmlal_n_s16(scaledHigh, vget_high_s16(cb), k[1]), vget_high_s16(cr), k[2]);
    const int32x4_t blueLow = vmlal_n_s16(scaledLow, vget_low_s16(cb), k[3]);
    const int32x4_t blueHigh = vmlal_n_s16(scaledHigh, vget_high_s16(cb), k[3]);
    uint8x8x4_t bgra;
    bgra.val[0] = RevenantVTNarrowQ10(blueLow, blueHigh);
    bgra.val[1] = RevenantVTNarrowQ10(greenLow, greenHigh);
    bgra.val[2] = RevenantVTNarrowQ10(redLow, redHigh);
    bgra.val[3] = vdup_n_u8(255);
    vst4_u8(out, bgra);
}

static void RevenantVTConvertRowNEON(uint8_t *out, const uint8_t *luma, const uint8_t *chroma, size_t width, bool fullRange, bool bt709)
{
    const int16_t *k = RevenantVTCoefficientsFor(fullRange, bt709);
    size_t column = 0;
    for (; column + 16 <= width; column += 16) {
        const uint8x16_t y = vld1q_u8(luma + column);
        const uint8x8x2_t cbcr = vld2_u8(chroma + column);
        const uint8x8x2_t cb = vzip_u8(cbcr.val[0], cbcr.val[0]);
        const uint8x8x2_t cr = vzip_u8(cbcr.val[1], cbcr.val[1]);
        RevenantVTConvert8NEON(out + column * 4, vget_low_u8(y), cb.val[0], cr.val[0], k, fullRange);
        RevenantVTConvert8NEON(out + (column + 8) * 4, vget_high_u8(y), cb.val[1], cr.val[1], k, fullRange);
    }
    RevenantVTConvertRowScalar(out, luma, chroma, column, width, fullRange, bt709);
}

void RevenantVTConvertBiPlanarNEON(uint8_t *out, size_t rowBytes, const uint8_t *luma, size_t lumaStride, const uint8_t *chroma, size_t chromaStride, size_t width, size_t height, bool fullRange, bool bt709)
{
    for (size_t row = 0; row < height; row++)
        RevenantVTConvertRowNEON(out + row * rowBytes, luma + row * lumaStride, chroma + (row / 2) * chromaStride, width, fullRange, bt709);
}

#endif
