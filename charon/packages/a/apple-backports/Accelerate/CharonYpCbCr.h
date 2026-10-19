// The arithmetic every Y'CbCr conversion of vImage is made of, shared by the thirty-four entry points
// that Conversion.h declares and this one file carries.
//
// vImage_YpCbCrToARGB and vImage_ARGBToYpCbCr are 128 opaque bytes each. Nothing outside this package
// reads those bytes: a caller passes the pointer the generator filled in, back to a conversion. So the
// layout is the port's own, and the tag is what keeps one release's library and another's from reading
// each other's bytes - a conversion that does not carry the tag this build writes is refused with
// kvImageNullPointerArgument rather than read.
//
// What the tag stands for is a tag, a copy of the matrix exactly as the caller gave it, the two scales
// the pixel range and the destination's own full scale give, the two biases, and the four clamps. The
// scales are where the bit depth lives: the header's own per-pixel text writes
//
//     R = ROUND((Yp0 - Yp_bias) * Yp + (Cr0 - CbCr_bias) * Cr_R)
//
// with Yp and Cr_R already carrying the range, which is where the generator puts it. The port keeps the
// two apart - the matrix as given, and the scale beside it - because the same matrix has to serve an
// 8-bit, a 16-bit and a Q12 destination, and the difference between those three is one multiply on the
// scale rather than three copies of the matrix.
//
// The two per-pixel rules are the header's, written out twice: the luma and chroma of a colour on the way
// in, and the three channels from a luma and a chroma on the way out. Both round once, at the end, and
// both clamp to the range the pixel range gives - the clamps to the range on the way out of a Y'CbCr
// buffer, to the destination's own maximum on the way back.
//
// The name carries a Charon prefix on purpose, as CharonBiquad.h's does: the gate does not weigh a
// symbol of the port's own against a release or ask the registry about it (modules/apple/backports.lua,
// internal_symbol). The two structs vImage_Types.h names are the release's own names, because a client's
// declarations have to match.

#pragma once

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <string.h>

enum {
    CharonYpCbCrToARGBMagic = 0x43597041,
    CharonARGBToYpCbCrMagic = 0x43597042
};

// The full scale of each of the three destination types vImage's Y'CbCr conversions name, as the header
// states them: kvImageARGB8888 is "[0,255]=[0,1.0]", kvImageARGB16U is "[0,65535]=[0,1.0]" and
// kvImageARGB16Q12 is "[0,4096]=[0,1.0]". A type the conversions do not name has no scale, and the
// generators answer kvImageUnsupportedConversion for it.
static inline float charon_argb_scale(vImageARGBType type)
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

typedef struct CharonToARGB {
    uint32_t magic;
    float Yp, Cr_R, Cr_G, Cb_G, Cb_B;
    float yScale, cScale;      // 255/(range) * destination full scale, and 255/(2 * chroma range) * it
    float Yp_bias, CbCr_bias;
    float YpMin, YpMax, CbCrMin, CbCrMax;
} CharonToARGB;

typedef struct CharonToYpCbCr {
    uint32_t magic;
    float R_Yp, G_Yp, B_Yp, R_Cb, G_Cb, B_Cb_R_Cr, G_Cr, B_Cr;
    float yScale, cScale;      // range/255 * source full scale, and 2 * chroma range/255 * it
    float Yp_bias, CbCr_bias;
    float YpMin, YpMax, CbCrMin, CbCrMax;
} CharonToYpCbCr;

static inline const CharonToARGB *charon_to_argb(const vImage_YpCbCrToARGB *info)
{
    const CharonToARGB *found = (const CharonToARGB *)info;
    return found && found->magic == CharonYpCbCrToARGBMagic ? found : NULL;
}

static inline const CharonToYpCbCr *charon_to_ypcbcr(const vImage_ARGBToYpCbCr *info)
{
    const CharonToYpCbCr *found = (const CharonToYpCbCr *)info;
    return found && found->magic == CharonARGBToYpCbCrMagic ? found : NULL;
}

static inline float charon_clamp(float value, float low, float high)
{
    return value < low ? low : (value > high ? high : value);
}

// A permutation map of four channels is a permutation of 0 to 3 and nothing else; the header says the
// map is "an array of 4 bytes that describe the channel order of the destination buffer", and a map that
// repeated a channel or named a fifth would read a byte the header never meant the port to read.
static inline BOOL charon_permutation(const uint8_t permuteMap[4])
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

// The luma, Cb and Cr of one colour, the header's rule for ARGB to Y'CbCr with a single pixel and no
// averaging. `cScale` already carries the destination's full scale and the factor two the header divides
// its chroma by, so the caller that averages four pixels of a 2x2 block divides by its own count instead -
// which is the same thing, and is what the header's own pseudo-code does when it adds the four up and
// divides by four.
static inline float charon_ypcbcr_luma_of(const CharonToYpCbCr *conversion, float red, float green, float blue)
{
    return conversion->Yp_bias
        + (red * conversion->R_Yp + green * conversion->G_Yp + blue * conversion->B_Yp) * conversion->yScale;
}

// The two chroma dot products on their own, before the scale and the bias. A caller that averages a
// block's chroma needs these and not charon_ypcbcr_of's answer: the header's rule adds the block's raw
// dot products up and divides by the number of them, so summing answers that already carry the scale
// and the bias applies both a second time. Measured: a Cb of 34331 where the system answers 34555.
static inline void charon_ypcbcr_chroma_of(const CharonToYpCbCr *conversion, float red, float green, float blue,
                                           float *Cb, float *Cr)
{
    *Cb = red * conversion->R_Cb + green * conversion->G_Cb + blue * conversion->B_Cb_R_Cr;
    *Cr = red * conversion->B_Cb_R_Cr + green * conversion->G_Cr + blue * conversion->B_Cr;
}

static inline void charon_ypcbcr_of(const CharonToYpCbCr *conversion, float red, float green, float blue,
                                    float *Yp, float *Cb, float *Cr)
{
    *Yp = charon_ypcbcr_luma_of(conversion, red, green, blue);
    charon_ypcbcr_chroma_of(conversion, red, green, blue, Cb, Cr);
    *Cb = conversion->CbCr_bias + *Cb * conversion->cScale;
    *Cr = conversion->CbCr_bias + *Cr * conversion->cScale;
}

// The three channels from a luma and a chroma pair, the header's rule for Y'CbCr to ARGB. The luma and
// the chroma are NOT clamped to the pixel range's own limits, and that is measured rather than assumed:
// with the video range clamped to [16,235] for luma and [16,240] for chroma, the system turns a luma of
// 255 into a green of 125 and one of 235 into 120, so the value goes into the sum whole and the clamp
// that is left is the output's, which is the CLAMP(0, ROUND_TO_NEAREST_INTEGER(...), max) the header's
// own per-pixel text writes. The limits are kept in the conversion because the generators take them from
// the caller's range and a caller may read them back; nothing in these conversions reads them.
static inline void charon_argb_of(const CharonToARGB *conversion, float luma, float cb, float cr,
                                  float *red, float *green, float *blue)
{
    float y = (luma - conversion->Yp_bias) * conversion->yScale * conversion->Yp;
    float b = (cb - conversion->CbCr_bias) * conversion->cScale;
    float r = (cr - conversion->CbCr_bias) * conversion->cScale;
    *red = y + r * conversion->Cr_R;
    *green = y + b * conversion->Cb_G + r * conversion->Cr_G;
    *blue = y + b * conversion->Cb_B;
}

// The two roundings. One is the CLAMP(0, ROUND_TO_NEAREST_INTEGER(...), max) the header writes on the
// way out of a Y'CbCr buffer, where the maximum is the destination type's own full scale; the other is
// the clamp to the pixel range's own limits on the way back into one. Both are the port's own spelling
// of the two, and the differential holds them against the host's answers byte for byte.
static inline uint32_t charon_grade(float value, float high)
{
    float rounded = roundf(value);
    return (uint32_t)charon_clamp(rounded, 0.0f, high);
}

static inline uint32_t charon_encode(float value, float low, float high)
{
    return (uint32_t)charon_clamp(roundf(value), charon_clamp(low, 0.0f, 65535.0f), charon_clamp(high, 0.0f, 65535.0f));
}
