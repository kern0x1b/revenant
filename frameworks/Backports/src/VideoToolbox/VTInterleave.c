#include "VTInterleave.h"

#include <string.h>

#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

void RevenantVTCopyPlane(uint8_t *out, size_t outStride, const uint8_t *in, size_t inStride, size_t width, size_t height)
{
    for (size_t row = 0; row < height; row++)
        memcpy(out + row * outStride, in + row * inStride, width);
}

void RevenantVTInterleaveChromaScalar(uint8_t *out, size_t outStride, const uint8_t *blue, size_t blueStride, const uint8_t *red, size_t redStride, size_t width, size_t height)
{
    for (size_t row = 0; row < height; row++) {
        uint8_t *destination = out + row * outStride;
        const uint8_t *b = blue + row * blueStride;
        const uint8_t *r = red + row * redStride;
        for (size_t column = 0; column < width; column++) {
            destination[2 * column] = b[column];
            destination[2 * column + 1] = r[column];
        }
    }
}

#if defined(__ARM_NEON)
void RevenantVTInterleaveChromaNEON(uint8_t *out, size_t outStride, const uint8_t *blue, size_t blueStride, const uint8_t *red, size_t redStride, size_t width, size_t height)
{
    for (size_t row = 0; row < height; row++) {
        uint8_t *destination = out + row * outStride;
        const uint8_t *b = blue + row * blueStride;
        const uint8_t *r = red + row * redStride;
        size_t column = 0;
        for (; column + 16 <= width; column += 16) {
            uint8x16x2_t pair;
            pair.val[0] = vld1q_u8(b + column);
            pair.val[1] = vld1q_u8(r + column);
            vst2q_u8(destination + 2 * column, pair);
        }
        for (; column < width; column++) {
            destination[2 * column] = b[column];
            destination[2 * column + 1] = r[column];
        }
    }
}
#endif
