#import "CharonBlur.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

CharonBlurParameters charon_blur_parameters(UIBlurEffectStyle style)
{
    switch ((NSInteger)style) {
    case 0:
        return (CharonBlurParameters){20, 1.8, 0.97, 0.97, 0.97, 0.82};
    case 2:
        return (CharonBlurParameters){20, 1.8, 0.11, 0.11, 0.11, 0.73};
    case 5:
        return (CharonBlurParameters){20, 1.8, 0.97, 0.97, 0.97, 0.82};
    case 3:
    case 8: case 10: case 12: case 14: case 16: case 18: case 20: case 22: case 24: case 26: case 28:
        return (CharonBlurParameters){20, 1.8, 0.11, 0.11, 0.11, 0.73};
    default:
        return (CharonBlurParameters){30, 1.8, 1.0, 1.0, 1.0, 0.3};
    }
}

static void charon_box_pass(uint8_t *pixels, size_t width, size_t height, size_t rowBytes, int diameter, BOOL horizontal, uint8_t *scratch)
{
    int radius = diameter / 2;
    size_t length = horizontal ? width : height;
    size_t lines = horizontal ? height : width;
    size_t step = horizontal ? 4 : rowBytes;
    size_t advance = horizontal ? rowBytes : 4;
    for (size_t line = 0; line < lines; line++) {
        uint8_t *base = pixels + line * advance;
        for (int channel = 0; channel < 4; channel++) {
            unsigned sum = 0;
            for (int k = -radius; k <= radius; k++) {
                long at = k < 0 ? 0 : (k >= (long)length ? (long)length - 1 : k);
                sum += base[at * step + channel];
            }
            for (size_t i = 0; i < length; i++) {
                scratch[i] = (uint8_t)((sum + diameter / 2) / diameter);
                long leaving = (long)i - radius, entering = (long)i + radius + 1;
                long out = leaving < 0 ? 0 : leaving;
                long in = entering >= (long)length ? (long)length - 1 : entering;
                sum = sum - base[out * step + channel] + base[in * step + channel];
            }
            for (size_t i = 0; i < length; i++)
                base[i * step + channel] = scratch[i];
        }
    }
}

void charon_blur_pixels(uint8_t *pixels, size_t width, size_t height, size_t rowBytes, CGFloat sigma, CGFloat saturation, CGFloat tintRed, CGFloat tintGreen, CGFloat tintBlue, CGFloat tintAlpha)
{
    if (!width || !height)
        return;
    int diameter = (int)floor(sigma * 3.0 * sqrt(2.0 * M_PI) / 4.0 + 0.5);
    diameter |= 1;
    if (diameter < 3)
        diameter = 3;
    uint8_t *scratch = malloc(width > height ? width : height);
    for (int pass = 0; pass < 3; pass++) {
        charon_box_pass(pixels, width, height, rowBytes, diameter, YES, scratch);
        charon_box_pass(pixels, width, height, rowBytes, diameter, NO, scratch);
    }
    free(scratch);
    float matrix[3][3] = {
        {0.2126f + 0.7874f * saturation, 0.7152f - 0.7152f * saturation, 0.0722f - 0.0722f * saturation},
        {0.2126f - 0.2126f * saturation, 0.7152f + 0.2848f * saturation, 0.0722f - 0.0722f * saturation},
        {0.2126f - 0.2126f * saturation, 0.7152f - 0.7152f * saturation, 0.0722f + 0.9278f * saturation}};
    int tint[3] = {(int)lround(tintRed * tintAlpha * 255.0), (int)lround(tintGreen * tintAlpha * 255.0), (int)lround(tintBlue * tintAlpha * 255.0)};
    float keep = 1.0f - (float)tintAlpha;
    for (size_t y = 0; y < height; y++) {
        uint8_t *row = pixels + y * rowBytes;
        for (size_t x = 0; x < width; x++) {
            uint8_t *p = row + x * 4;
            float r = p[0], g = p[1], b = p[2];
            for (int c = 0; c < 3; c++) {
                float v = matrix[c][0] * r + matrix[c][1] * g + matrix[c][2] * b;
                v = v * keep + tint[c];
                p[c] = (uint8_t)(v < 0 ? 0 : v > 255 ? 255 : v + 0.5f);
            }
            p[3] = 255;
        }
    }
}
