#import <Accelerate/Accelerate.h>
#include <math.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

static inline vImage_Error revenant_fixed_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
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

static inline int32_t revenant_sat(double value, int32_t low, int32_t high)
{
    double rounded = floor(value + 0.5);
    if (rounded < (double)low)
        return low;
    if (rounded > (double)high)
        return high;
    return (int32_t)rounded;
}

static inline uint16_t revenant_float_to_half(float value)
{
    uint32_t bits;
    uint32_t sign, exponent, mantissa;
    int32_t biased;
    memcpy(&bits, &value, sizeof bits);
    sign = (bits >> 16) & 0x8000u;
    exponent = (bits >> 23) & 0xFFu;
    mantissa = bits & 0x7FFFFFu;
    if (exponent == 0xFFu) {
        return (uint16_t)(sign | 0x7C00u | (mantissa ? 0x200u : 0u));
    }
    biased = (int32_t)exponent - 127 + 15;
    if (exponent == 0) {
        return (uint16_t)sign;
    }
    if (biased >= 0x1F) {
        return (uint16_t)(sign | 0x7C00u);
    }
    if (biased <= 0) {
        uint32_t shifted = mantissa | 0x800000u;
        int32_t shift = 14 - biased;
        uint32_t half_mantissa, rest;
        if (shift > 24)
            return (uint16_t)sign;
        half_mantissa = shifted >> shift;
        rest = shifted & ((1u << shift) - 1u);
        if (rest > (1u << (shift - 1)) || (rest == (1u << (shift - 1)) && (half_mantissa & 1u)))
            half_mantissa++;
        return (uint16_t)(sign | half_mantissa);
    }
    {
        uint32_t half_mantissa = mantissa >> 13;
        uint32_t rest = mantissa & 0x1FFFu;
        if (rest > 0x1000u || (rest == 0x1000u && (half_mantissa & 1u)))
            half_mantissa++;
        if (half_mantissa == 0x400u) {
            half_mantissa = 0;
            biased++;
            if (biased >= 0x1F)
                return (uint16_t)(sign | 0x7C00u);
        }
        return (uint16_t)(sign | ((uint32_t)biased << 10) | half_mantissa);
    }
}

static inline float revenant_half_to_float(uint16_t half)
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
