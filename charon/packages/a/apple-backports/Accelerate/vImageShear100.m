#import <Accelerate/Accelerate.h>
#include "CharonShear.h"

vImage_Error vImageHorizontalShear_CbCr16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16U16U backColor, vImage_Flags flags)
{
    CharonResampleFilter ours;
    int have = CharonResampleFilterOf(filter, &ours);
    vImage_Error ready = CharonShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    CharonShearBackU16(back, backColor, 2);
    return CharonShearRun(src, dest, &ours, CharonCbCr16U, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_CbCr8(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_88 backColor, vImage_Flags flags)
{
    CharonResampleFilter ours;
    int have = CharonResampleFilterOf(filter, &ours);
    vImage_Error ready = CharonShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    CharonShearBackU8(back, backColor, 2);
    return CharonShearRun(src, dest, &ours, CharonCbCr8, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_XRGB2101010W(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_32U backColor, vImage_Flags flags)
{
    CharonResampleFilter ours;
    int have = CharonResampleFilterOf(filter, &ours);
    vImage_Error ready = CharonShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    uint32_t word = backColor;
    for (unsigned channel = 0; channel < 4; channel++)
        back[channel] = (double)((word >> (channel * 10)) & 0x3FFu);
    return CharonShearRun(src, dest, &ours, CharonXRGB2101010W, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_CbCr16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16U16U backColor, vImage_Flags flags)
{
    CharonResampleFilter ours;
    int have = CharonResampleFilterOf(filter, &ours);
    vImage_Error ready = CharonShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    CharonShearBackU16(back, backColor, 2);
    return CharonShearRun(src, dest, &ours, CharonCbCr16U, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_CbCr8(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_88 backColor, vImage_Flags flags)
{
    CharonResampleFilter ours;
    int have = CharonResampleFilterOf(filter, &ours);
    vImage_Error ready = CharonShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    CharonShearBackU8(back, backColor, 2);
    return CharonShearRun(src, dest, &ours, CharonCbCr8, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_XRGB2101010W(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_32U backColor, vImage_Flags flags)
{
    CharonResampleFilter ours;
    int have = CharonResampleFilterOf(filter, &ours);
    vImage_Error ready = CharonShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    uint32_t word = backColor;
    for (unsigned channel = 0; channel < 4; channel++)
        back[channel] = (double)((word >> (channel * 10)) & 0x3FFu);
    return CharonShearRun(src, dest, &ours, CharonXRGB2101010W, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}
