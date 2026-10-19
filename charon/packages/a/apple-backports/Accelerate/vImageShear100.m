// The shears of vImage at 10.0, over the mapping CharonShear.h carries: 6 functions, every one
// of them the same two lines of arithmetic over a different pixel type and a different translate's type, and
// the refusals and the position arithmetic both measured rather than assumed
// (facts/Accelerate/vImageGeometry.md).
//
// One release per object, which is what the band machinery wants: this file's names are all first exported by
// the 10.0 caches and none of them by an earlier one, so it enters the build there and not below.

#import <Accelerate/Accelerate.h>
#include "CharonShear.h"

vImage_Error vImageHorizontalShear_CbCr16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16U16U backColor, vImage_Flags flags)
{
    // The caller's own filter, read: `ours` is zeroed and the read refused for anything that is not one of
    // the two measured shapes, and CharonShearReady turns that into kvImageInvalidParameter - AFTER the
    // NULL-buffer refusal, which is the order the release makes them in.
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
    // The caller's own filter, read: `ours` is zeroed and the read refused for anything that is not one of
    // the two measured shapes, and CharonShearReady turns that into kvImageInvalidParameter - AFTER the
    // NULL-buffer refusal, which is the order the release makes them in.
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
    // The caller's own filter, read: `ours` is zeroed and the read refused for anything that is not one of
    // the two measured shapes, and CharonShearReady turns that into kvImageInvalidParameter - AFTER the
    // NULL-buffer refusal, which is the order the release makes them in.
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
    // The caller's own filter, read: `ours` is zeroed and the read refused for anything that is not one of
    // the two measured shapes, and CharonShearReady turns that into kvImageInvalidParameter - AFTER the
    // NULL-buffer refusal, which is the order the release makes them in.
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
    // The caller's own filter, read: `ours` is zeroed and the read refused for anything that is not one of
    // the two measured shapes, and CharonShearReady turns that into kvImageInvalidParameter - AFTER the
    // NULL-buffer refusal, which is the order the release makes them in.
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
    // The caller's own filter, read: `ours` is zeroed and the read refused for anything that is not one of
    // the two measured shapes, and CharonShearReady turns that into kvImageInvalidParameter - AFTER the
    // NULL-buffer refusal, which is the order the release makes them in.
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
