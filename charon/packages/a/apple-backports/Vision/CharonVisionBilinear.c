/* kernel.c -- the resampler, as it is to be applied, in the file the next session pastes into
 * CharonVisionImage.h in place of the CoreGraphics draw.
 *
 * Separable bilinear, two taps, no prefilter -- the kernel Core ML's own image constructor was
 * measured to use, from the impulse responses in .agent-work/runs/crop-probe/kernel.m:
 *
 *   src  = (x + 0.5) * s - 0.5     the half-pixel sample centre, not align-corners
 *   two taps either side of it, weights 1 - |src - tap|
 *   the two axes independently, which is what makes it separable
 *   no area averaging when the scale is below one: a downscale point-samples
 *
 * A tap is clamped into the source at the edges, where both taps of a boundary destination pixel
 * fall inside the picture. Positions and the store round half up, which is the default the gradient
 * table has to confirm; CHARON_VISION_TRUNCATE is the other and the harness builds this file with
 * it, so a rounding that is not Core ML's shows up as a difference in the table.
 */
#include <stddef.h>
#include <stdint.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

/* The sample position is truncated. Round half up there leaves a maximum difference of 171 against
 * Core ML, over the gradient table; truncation leaves every pixel within one. */
#define CHARON_VISION_POSITION(value) ((long)(value))

/* A sample position, clamped into the source *before* it is split into two taps: clamping only
 * the taps leaves the weight outside 0..1 at the edges, and a weight below zero extrapolates past
 * the picture and inverts it -- which the gradient table shows as a maximum difference of 255. */
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
    /* `x` and `y` run over the drawn region; the inset is where the answer is stored, and is not
     * part of where the picture is sampled from. */
    double across = (double)sourceWide / (double)drawWide;
    double down = (double)sourceHigh / (double)drawHigh;
    /* A cover overflows the target on the side it was scaled for, and only the part that lands in
     * the target is written. */
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
                /* The value is truncated at the store when the position is: the round-half-up
                 * build puts 15505 pixels eight or more apart with a maximum of 171, and
                 * truncating both leaves every pixel within one. */
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
