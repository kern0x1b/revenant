#pragma once

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <string.h>

enum {
    RevenantYpCbCrToARGBMagic = 0x43597041,
    RevenantARGBToYpCbCrMagic = 0x43597042
};

static inline float revenant_argb_scale(vImageARGBType type)
{
    switch (type) {
    case kvImageARGB8888:
        return 255.0f;
    case kvImageARGB16U:
        return 65535.0f;
    case kvImageARGB16Q12:
        return 4096.0f;
    default:
        return 0.0f;
    }
}

typedef struct RevenantToARGB {
    uint32_t magic;
    float Yp, Cr_R, Cr_G, Cb_G, Cb_B;
    float yScale, cScale;
    float Yp_bias, CbCr_bias;
    float YpMin, YpMax, CbCrMin, CbCrMax;
} RevenantToARGB;

typedef struct RevenantToYpCbCr {
    uint32_t magic;
    float R_Yp, G_Yp, B_Yp, R_Cb, G_Cb, B_Cb_R_Cr, G_Cr, B_Cr;
    float yScale, cScale;
    float Yp_bias, CbCr_bias;
    float YpMin, YpMax, CbCrMin, CbCrMax;
} RevenantToYpCbCr;

static inline const RevenantToARGB *revenant_to_argb(const vImage_YpCbCrToARGB *info)
{
    const RevenantToARGB *found = (const RevenantToARGB *)info;
    return found && found->magic == RevenantYpCbCrToARGBMagic ? found : NULL;
}

static inline const RevenantToYpCbCr *revenant_to_ypcbcr(const vImage_ARGBToYpCbCr *info)
{
    const RevenantToYpCbCr *found = (const RevenantToYpCbCr *)info;
    return found && found->magic == RevenantARGBToYpCbCrMagic ? found : NULL;
}

static inline float revenant_clamp(float value, float low, float high)
{
    return value < low ? low : (value > high ? high : value);
}

static inline BOOL revenant_permutation(const uint8_t permuteMap[4])
{
    uint8_t seen[4] = {0, 0, 0, 0};
    if (!permuteMap)
        return NO;
    for (unsigned index = 0; index < 4; index++) {
        if (permuteMap[index] > 3 || seen[permuteMap[index]])
            return NO;
        seen[permuteMap[index]] = 1;
    }
    return YES;
}

static inline float revenant_ypcbcr_luma_of(const RevenantToYpCbCr *conversion, float red, float green, float blue)
{
    return conversion->Yp_bias
        + (red * conversion->R_Yp + green * conversion->G_Yp + blue * conversion->B_Yp) * conversion->yScale;
}

static inline void revenant_ypcbcr_chroma_of(const RevenantToYpCbCr *conversion, float red, float green, float blue,
                                           float *Cb, float *Cr)
{
    *Cb = red * conversion->R_Cb + green * conversion->G_Cb + blue * conversion->B_Cb_R_Cr;
    *Cr = red * conversion->B_Cb_R_Cr + green * conversion->G_Cr + blue * conversion->B_Cr;
}

static inline void revenant_ypcbcr_of(const RevenantToYpCbCr *conversion, float red, float green, float blue,
                                    float *Yp, float *Cb, float *Cr)
{
    *Yp = revenant_ypcbcr_luma_of(conversion, red, green, blue);
    revenant_ypcbcr_chroma_of(conversion, red, green, blue, Cb, Cr);
    *Cb = conversion->CbCr_bias + *Cb * conversion->cScale;
    *Cr = conversion->CbCr_bias + *Cr * conversion->cScale;
}

static inline void revenant_argb_of(const RevenantToARGB *conversion, float luma, float cb, float cr,
                                  float *red, float *green, float *blue)
{
    float y = (luma - conversion->Yp_bias) * conversion->yScale * conversion->Yp;
    float b = (cb - conversion->CbCr_bias) * conversion->cScale;
    float r = (cr - conversion->CbCr_bias) * conversion->cScale;
    *red = y + r * conversion->Cr_R;
    *green = y + b * conversion->Cb_G + r * conversion->Cr_G;
    *blue = y + b * conversion->Cb_B;
}

static inline uint32_t revenant_grade(float value, float high)
{
    float rounded = roundf(value);
    return (uint32_t)revenant_clamp(rounded, 0.0f, high);
}

static inline uint32_t revenant_encode(float value, float low, float high)
{
    return (uint32_t)revenant_clamp(roundf(value), revenant_clamp(low, 0.0f, 65535.0f), revenant_clamp(high, 0.0f, 65535.0f));
}
