#import <Accelerate/Accelerate.h>
#include "RevenantShear.h"

vImage_Error vImageHorizontalShearD_ARGB16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double horizontalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, backColor, 4);
    return RevenantShearRun(src, dest, &ours, RevenantARGB16F, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShearD_CbCr16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double horizontalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_16F16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16F, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShearD_CbCr16S(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double horizontalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_16S16S backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackS16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16S, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShearD_CbCr16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double horizontalTranslate, double shearSlope,
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

vImage_Error vImageHorizontalShearD_Planar16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double horizontalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, &backColor, 1);
    return RevenantShearRun(src, dest, &ours, RevenantPlanar16F, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_ARGB16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, backColor, 4);
    return RevenantShearRun(src, dest, &ours, RevenantARGB16F, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_CbCr16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16F16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16F, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_CbCr16S(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16S16S backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackS16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16S, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageHorizontalShear_Planar16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float horizontalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 1, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, &backColor, 1);
    return RevenantShearRun(src, dest, &ours, RevenantPlanar16F, 1, horizontalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShearD_ARGB16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double verticalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, backColor, 4);
    return RevenantShearRun(src, dest, &ours, RevenantARGB16F, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShearD_CbCr16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double verticalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_16F16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16F, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShearD_CbCr16S(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double verticalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_16S16S backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackS16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16S, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShearD_CbCr16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double verticalTranslate, double shearSlope,
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

vImage_Error vImageVerticalShearD_Planar16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, double verticalTranslate, double shearSlope,
                   ResamplingFilter filter, const Pixel_16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, &backColor, 1);
    return RevenantShearRun(src, dest, &ours, RevenantPlanar16F, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_ARGB16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_ARGB_16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, backColor, 4);
    return RevenantShearRun(src, dest, &ours, RevenantARGB16F, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_CbCr16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16F16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16F, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_CbCr16S(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16S16S backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackS16(back, backColor, 2);
    return RevenantShearRun(src, dest, &ours, RevenantCbCr16S, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}

vImage_Error vImageVerticalShear_Planar16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X,
                   vImagePixelCount srcOffsetToROI_Y, float verticalTranslate, float shearSlope,
                   ResamplingFilter filter, const Pixel_16F backColor, vImage_Flags flags)
{
    RevenantResampleFilter ours;
    int have = RevenantResampleFilterOf(filter, &ours);
    vImage_Error ready = RevenantShearReady(src, dest, have ? &ours : 0, 0, srcOffsetToROI_X, srcOffsetToROI_Y);
    if (ready != kvImageNoError)
        return ready;
    double back[4] = { 0, 0, 0, 0 };
    RevenantShearBackF16(back, &backColor, 1);
    return RevenantShearRun(src, dest, &ours, RevenantPlanar16F, 0, verticalTranslate, shearSlope, srcOffsetToROI_X,
                          srcOffsetToROI_Y, back, flags);
}
