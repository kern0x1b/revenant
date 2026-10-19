#include <stddef.h>
#include <stdint.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

#define CHARON_VISION_POSITION(value) ((long)(value))

static double charon_vision_clamp(double at, double limit)
{
    if (at < 0.0) {
        return 0.0;
    }
    return at >= limit ? limit - 1.0 : at;
}

void charon_vision_bilinear(const uint8_t *source, size_t sourceStride,
                            size_t sourceWide, size_t sourceHigh,
                            uint8_t *target, size_t targetStride,
                            long insetX, long insetY, long drawWide, long drawHigh,
                            long targetWide, long targetHigh)
{
    long x, y, channel;
    double across = (double)sourceWide / (double)drawWide;
    double down = (double)sourceHigh / (double)drawHigh;
    for (y = 0; y < drawHigh && insetY + y < targetHigh && insetY + y >= 0; y++) {
        double sy = charon_vision_clamp(((double)y + 0.5) * down - 0.5, (double)sourceHigh);
        long y0 = CHARON_VISION_POSITION(sy);
        double fy = sy - (double)y0;
        long ya = y0 < 0 ? 0 : (y0 >= (long)sourceHigh ? (long)sourceHigh - 1 : y0);
        long yb = y0 + 1 < 0 ? 0 : (y0 + 1 >= (long)sourceHigh ? (long)sourceHigh - 1 : y0 + 1);
        for (x = 0; x < drawWide && insetX + x < targetWide && insetX + x >= 0; x++) {
            double sx = charon_vision_clamp(((double)x + 0.5) * across - 0.5, (double)sourceWide);
            long x0 = CHARON_VISION_POSITION(sx);
            double fx = sx - (double)x0;
            long xa = x0 < 0 ? 0 : (x0 >= (long)sourceWide ? (long)sourceWide - 1 : x0);
            long xb = x0 + 1 < 0 ? 0 : (x0 + 1 >= (long)sourceWide ? (long)sourceWide - 1 : x0 + 1);
            for (channel = 0; channel < 4; channel++) {
                double top = (1.0 - fx) * source[ya * sourceStride + xa * 4 + channel] +
                             fx * source[ya * sourceStride + xb * 4 + channel];
                double bottom = (1.0 - fx) * source[yb * sourceStride + xa * 4 + channel] +
                                fx * source[yb * sourceStride + xb * 4 + channel];
                long whole = (long)((1.0 - fy) * top + fy * bottom + 0.5);
                if (whole < 0) {
                    whole = 0;
                }
                if (whole > 255) {
                    whole = 255;
                }
                target[(size_t)(insetY + y) * targetStride + (size_t)(insetX + x) * 4 + (size_t)channel] =
                    (uint8_t)whole;
            }
        }
    }
}
