// The shears of vImage at 7.0, over the mapping CharonShear.h carries: 8 functions, every one
// of them the same two lines of arithmetic over a different pixel type and a different translate's type, and
// the refusals and the position arithmetic both measured rather than assumed
// (facts/Accelerate/vImageGeometry.md).
//
// One release per object, which is what the band machinery wants: this file's names are all first exported by
// the 7.0 caches and none of them by an earlier one, so it enters the build there and not below.

#import <Accelerate/Accelerate.h>
#include "CharonShear.h"

vImage_Error vImageHorizontalShearD_ARGB16S(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double horizontalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16S backColor, vImage_Flags flags)
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
    CharonShearBackS16(back, backColor, 4);
    return CharonShearRun(src, dest, &ours, CharonARGB16S, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShearD_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double horizontalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16U backColor, vImage_Flags flags)
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
    CharonShearBackU16(back, backColor, 4);
    return CharonShearRun(src, dest, &ours, CharonARGB16U, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_ARGB16S(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16S backColor, vImage_Flags flags)
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
    CharonShearBackS16(back, backColor, 4);
    return CharonShearRun(src, dest, &ours, CharonARGB16S, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16U backColor, vImage_Flags flags)
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
    CharonShearBackU16(back, backColor, 4);
    return CharonShearRun(src, dest, &ours, CharonARGB16U, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShearD_ARGB16S(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double verticalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16S backColor, vImage_Flags flags)
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
    CharonShearBackS16(back, backColor, 4);
    return CharonShearRun(src, dest, &ours, CharonARGB16S, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShearD_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double verticalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16U backColor, vImage_Flags flags)
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
    CharonShearBackU16(back, backColor, 4);
    return CharonShearRun(src, dest, &ours, CharonARGB16U, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_ARGB16S(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16S backColor, vImage_Flags flags)
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
    CharonShearBackS16(back, backColor, 4);
    return CharonShearRun(src, dest, &ours, CharonARGB16S, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16U backColor, vImage_Flags flags)
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
    CharonShearBackU16(back, backColor, 4);
    return CharonShearRun(src, dest, &ours, CharonARGB16U, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}
