#ifndef REVENANT_BLUR_COST_SHIM_H
#define REVENANT_BLUR_COST_SHIM_H

#include <stddef.h>
#include <stdint.h>

typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO ((BOOL)0)

typedef double CGFloat;

typedef long UIBlurEffectStyle;
typedef long NSInteger;

typedef struct {
    CGFloat radius;
    CGFloat saturation;
    CGFloat tintRed;
    CGFloat tintGreen;
    CGFloat tintBlue;
    CGFloat tintAlpha;
} RevenantBlurParameters;

RevenantBlurParameters revenant_blur_parameters(UIBlurEffectStyle style);

void revenant_blur_pixels(uint8_t *pixels, size_t width, size_t height, size_t rowBytes, CGFloat sigma,
                        CGFloat saturation, CGFloat tintRed, CGFloat tintGreen, CGFloat tintBlue,
                        CGFloat tintAlpha);

#endif
