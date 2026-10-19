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
    measure("320x100", 320, 100, 20);
    measure("540x300", 540, 300, 10);
    measure("768x1024", 768, 1024, 5);
    return 0;
}
