/* The shim CharonBlur.m sees instead of its own header, for blurcost.c.
 *
 * CharonBlur.h is an Objective-C header: it declares a category on UIBlurEffect, so a C program
 * cannot include it. blurcost.c links the one C function out of CharonBlur.m, and needs only the two
 * plain types that header brings in through UIKit. They are declared here instead, in the test.
 *
 * This is a shim and not a second copy of anything: the signatures below are the ones in
 * packages/a/apple-backports/UIKit/CharonBlur.h, and if one changes the link fails, which is the
 * point of keeping them adjacent.
 */
#ifndef CHARON_BLUR_COST_SHIM_H
#define CHARON_BLUR_COST_SHIM_H

#include <stddef.h>
#include <stdint.h>

/* YES and NO, which UIKit's Objective-C header brings in. The booleans the box pass is given are
 * written YES/NO in the package's own source, so the shim has to name them the same way. */
typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO ((BOOL)0)

/* CoreGraphics' CGFloat, which UIKit brings in. Double on every platform this port builds. */
typedef double CGFloat;

/* The one typed value the parameters switch on, and the type the package's own source casts to
 * inside charon_blur_parameters. Both are a long on every platform this port builds. */
typedef long UIBlurEffectStyle;
typedef long NSInteger;

typedef struct {
    CGFloat radius;
    CGFloat saturation;
    CGFloat tintRed;
    CGFloat tintGreen;
    CGFloat tintBlue;
    CGFloat tintAlpha;
} CharonBlurParameters;

CharonBlurParameters charon_blur_parameters(UIBlurEffectStyle style);

void charon_blur_pixels(uint8_t *pixels, size_t width, size_t height, size_t rowBytes, CGFloat sigma,
                        CGFloat saturation, CGFloat tintRed, CGFloat tintGreen, CGFloat tintBlue,
                        CGFloat tintAlpha);

#endif
