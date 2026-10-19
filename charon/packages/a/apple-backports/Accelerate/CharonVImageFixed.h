// The Accelerate conversion band carries this header and measured the scalar fixed-point mappings against
// the host. The vImage geometry band needs the two half-precision conversions out of it -
// `charon_float_to_half` and `charon_half_to_float` - and takes a copy with this credit rather than a
// dependency across two bands, because a shared header is a build-time coupling between bands that one
// band's split would break. The measurements, the tables and the rest of the file are the conversion band's.
//
// The scalar fixed-point conversions of vImage: eight of iOS 7.0's, in Accelerate/vImageFixedPoint7.m, and
// iOS 10.0's two in Accelerate/vImageFixedPoint10.m beside them.
//
// Measured from the release's armv7 caches, 7.0 is the first held release that exports the eight and 10.3.4
// the first that exports the two, so the two files hold the API of one release each.
//
// Every mapping here was read off the host's own answers rather than off a comment: vImage's Conversion.h
// documents the layout of each format and not the arithmetic between them, so the tables the port answers
// are the host's, and the differential asks the same inputs again (facts/Accelerate/vImageFixedPoint.md,
// probes in .agent-work/runs/vimage/). The formats, from the headers and from the answers:
//
//   Pixel_8    eight bits unsigned, 0 to 255
//   Pixel_16U  sixteen bits unsigned, 0 to 65535
//   16Q12      sixteen bits *signed* with twelve fractional bits, so -8 to 7.996 and 4096 is 1.0
//   Pixel_F    a thirty-two bit IEEE float
//   16F        a sixteen bit IEEE half - the answer table is what settles that, since 1/65535 comes back
//              as 0x0100, which is the subnormal half 256 * 2**-24
//
// and the mappings, each verified against the host over a table that brackets both ends of the range:
//
//   16Q12 to 16U   round(value / 4096 * 65535), clamped to 0 .. 65535
//   16Q12 to 8     round(value / 4096 * 255), clamped to 0 .. 255
//   16Q12 to F     value / 4096.0f, exactly
//   F to 16Q12     round(value * 4096), clamped to -32768 .. 32767
//   8 to 16Q12     (value * 4096 + 127) / 255
//   16U to 16Q12   (value + 8) >> 4
//   16U to 16F     the half nearest value / 65535
//   16F to 16U     round(half * 65535), clamped to 0 .. 65535
//   16F to 16Q12   round(half * 4096), clamped to -32768 .. 32767
//   16Q12 to 16F   the half nearest value / 4096

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

// The refusals are the release's own and the same ones the pixel group answers: a flag outside the set the
// header lists is kvImageUnknownFlagsBit, GetTempBufferSize does no work and answers zero, a NULL buffer is
// kvImageNullPointerArgument, and a destination larger than the source is kvImageRoiLargerThanInputBuffer.
static inline vImage_Error charon_fixed_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    const vImage_Flags allowed = kvImageDoNotTile | kvImageGetTempBufferSize | kvImagePrintDiagnosticsToConsole;
    if (flags & ~allowed)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    return kvImageNoError;
}

// The saturation the tables show, and the round-to-nearest they show: a value above the top of the
// destination becomes the top and a value below the bottom the bottom, in the destination's own width.
static inline int32_t charon_sat(double value, int32_t low, int32_t high)
{
    double rounded = floor(value + 0.5);
    if (rounded < (double)low)
        return low;
    if (rounded > (double)high)
        return high;
    return (int32_t)rounded;
}

// float to the IEEE half nearest it, with the subnormal range and the overflow to infinity the host's
// answers show. The exponent is biased by 15 and the mantissa is ten bits, both of which the tables fix:
// 1.0 is 0x3C00 and 1/65535, which is 2**-16 and therefore subnormal, is 0x0100.
static inline uint16_t charon_float_to_half(float value)
{
    uint32_t bits;
    uint32_t sign, exponent, mantissa;
    int32_t biased;
    memcpy(&bits, &value, sizeof bits);
    sign = (bits >> 16) & 0x8000u;
    exponent = (bits >> 23) & 0xFFu;
    mantissa = bits & 0x7FFFFFu;
    if (exponent == 0xFFu) {
        // an infinity or a NaN, which the half keeps as itself with its mantissa's top bit
        return (uint16_t)(sign | 0x7C00u | (mantissa ? 0x200u : 0u));
    }
    biased = (int32_t)exponent - 127 + 15;
    if (exponent == 0) {
        // a float zero or a float subnormal: every float subnormal is below the half's smallest, so it is zero
        return (uint16_t)sign;
    }
    if (biased >= 0x1F) {
        return (uint16_t)(sign | 0x7C00u);   // too large for a half, which overflows to an infinity
    }
    if (biased <= 0) {
        // subnormal in the half: 2**-14 is the smallest normal, so the mantissa is shifted down by 1 - biased
        // and the bit that falls off the bottom is the rounding
        uint32_t shifted = mantissa | 0x800000u;
        int32_t shift = 14 - biased;
        uint32_t half_mantissa, rest;
        if (shift > 24)
            return (uint16_t)sign;
        half_mantissa = shifted >> shift;
        rest = shifted & ((1u << shift) - 1u);
        if (rest > (1u << (shift - 1)) || (rest == (1u << (shift - 1)) && (half_mantissa & 1u)))
            half_mantissa++;   // to nearest, ties to even
        // a round up to 0x400 is the smallest normal, 2**-14, whose exponent bit this adds: it is not masked off
        return (uint16_t)(sign | half_mantissa);
    }
    {
        uint32_t half_mantissa = mantissa >> 13;
        uint32_t rest = mantissa & 0x1FFFu;
        if (rest > 0x1000u || (rest == 0x1000u && (half_mantissa & 1u)))
            half_mantissa++;   // to nearest, ties to even
        if (half_mantissa == 0x400u) {
            half_mantissa = 0;
            biased++;
            if (biased >= 0x1F)
                return (uint16_t)(sign | 0x7C00u);
        }
        return (uint16_t)(sign | ((uint32_t)biased << 10) | half_mantissa);
    }
}

// The half to the float it stands for, which is exact for every one of them: a half is a float with a
// narrower exponent and mantissa.
static inline float charon_half_to_float(uint16_t half)
{
    uint32_t sign = (uint32_t)(half & 0x8000u) << 16;
    uint32_t exponent = (uint32_t)(half >> 10) & 0x1Fu;
    uint32_t mantissa = (uint32_t)(half & 0x3FFu);
    uint32_t bits;
    float value;
    if (exponent == 0) {
        if (mantissa == 0) {
            bits = sign;
        } else {
            // a subnormal half is mantissa * 2**-24; each shift that brings its top bit to bit 10 is one
            // binary place below 2**-14, so e counts the shifts from zero
            int32_t e = 0;
            uint32_t m = mantissa;
            while (!(m & 0x400u)) {
                m <<= 1;
                e--;
            }
            bits = sign | ((uint32_t)(127 - 15 + 1 + e) << 23) | ((m & 0x3FFu) << 13);
        }
    } else if (exponent == 0x1Fu) {
        bits = sign | 0x7F800000u | (mantissa << 13);
    } else {
        bits = sign | ((exponent + 127 - 15) << 23) | (mantissa << 13);
    }
    memcpy(&value, &bits, sizeof value);
    return value;
}
