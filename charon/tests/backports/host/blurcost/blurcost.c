/* blurcost.c -- what the blur's shading costs, and where it runs.
 *
 * charon_blur_pixels is pure arithmetic over a pixel buffer: a box blur and a colour matrix. It is
 * the part of a UIVisualEffectView refresh that does not have to be on the main thread, and the facts
 * file that documents this area says the blur's filter is still there:
 *
 *   packages/a/apple-backports/facts/UIKit/UIVisualEffect.md:58-59
 *   "The shadow's shading is not part of this: since the client shades off the main thread the
 *    display link kept 60, 55 and 55 frames a second with a shadow refresh running ... The blur's
 *    box filter is still on the main thread."
 *
 * This times that function at the three sizes the same facts file reports a whole refresh at
 * (320x100, 540x300 and 768x1024), so the number here and the number there are about the same work.
 * It is the BEFORE figure for moving the shading off the main thread: what it does not measure is the
 * read, which stays on the main thread either way and is the cost the facts file bounds at 21-33 ms.
 *
 * The header is shimmed rather than imported: CharonBlur.h is an Objective-C header (it declares a
 * category), and this is a C program that links the one C function. The shim is here, in the test, and
 * declares the two functions with the same signatures; nothing in the package changes for it.
 */
#include "CharonBlur.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static double seconds(void)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (double)now.tv_sec + (double)now.tv_nsec * 1e-9;
}

/* The same buffer contents every run, so the timing is not the allocator's. */
static uint8_t *filled(size_t row_bytes, size_t height)
{
    uint8_t *pixels = malloc(row_bytes * height);
    if (!pixels) {
        perror("malloc");
        exit(2);
    }
    unsigned state = 0x12345678u;
    for (size_t i = 0; i < row_bytes * height; i++) {
        state = state * 1103515245u + 12345u;
        pixels[i] = (uint8_t)(state >> 16);
    }
    return pixels;
}

static void measure(const char *label, size_t width, size_t height, int rounds)
{
    size_t row_bytes = width * 4;
    uint8_t *pixels = filled(row_bytes, height);
    /* The parameters style 0 gives: radius 20, saturation 1.8, tint 0.97/0.97/0.97 at 0.82, which is
     * what a whole screen of a real blur runs with. */
    CharonBlurParameters parameters = {20, 1.8, 0.97, 0.97, 0.97, 0.82};

    charon_blur_pixels(pixels, width, height, row_bytes, parameters.radius, parameters.saturation,
                       parameters.tintRed, parameters.tintGreen, parameters.tintBlue, parameters.tintAlpha);
    double best = 0.0, total = 0.0;
    for (int round = 0; round < rounds; round++) {
        double started = seconds();
        charon_blur_pixels(pixels, width, height, row_bytes, parameters.radius, parameters.saturation,
                           parameters.tintRed, parameters.tintGreen, parameters.tintBlue, parameters.tintAlpha);
        double took = seconds() - started;
        total += took;
        if (round == 0 || took < best)
            best = took;
    }
    printf("  %-12s %4zux%-4zu  best %7.2f ms  mean %7.2f ms  (%.1f frames a second at best)\n",
           label, width, height, best * 1000.0, total * 1000.0 / rounds, 1.0 / best);
    free(pixels);
}

int main(void)
{
    printf("charon_blur_pixels, one call over a whole buffer, style 0 parameters\n");
    /* The three sizes UIVisualEffect.md reports a whole refresh at, and the biggest a device of this
     * class reports, so the third is the one that decides whether the main thread can keep up. */
    measure("320x100", 320, 100, 20);
    measure("540x300", 540, 300, 10);
    measure("768x1024", 768, 1024, 5);
    return 0;
}
