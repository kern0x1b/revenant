#import <Accelerate/Accelerate.h>
#include "RevenantShear.h"

vImage_Error vImageHorizontalShear_CbCr16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16U16U backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackU16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16U, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_CbCr8(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_88 backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackU8(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr8, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_XRGB2101010W(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_32U backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    uint32_t word = backColor;
    for (unsigned channel = 0; channel < 4; channel++)
        back[channel] = (double)((word >> (channel * 10)) & 0x3FFu);
    return RevenantShearRun(src, dest, &ours, RevenantXRGB2101010W, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_CbCr16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16U16U backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackU16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16U, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_CbCr8(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_88 backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackU8(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr8, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_XRGB2101010W(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_32U backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    uint32_t word = backColor;
    for (unsigned channel = 0; channel < 4; channel++)
        back[channel] = (double)((word >> (channel * 10)) & 0x3FFu);
    return RevenantShearRun(src, dest, &ours, RevenantXRGB2101010W, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}
