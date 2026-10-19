#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "check.h"

typedef struct CGColorTransform *CGColorTransformRef;
CGColorTransformRef CGColorTransformCreate(CGColorSpaceRef, CFDictionaryRef);
CGColorRef CGColorTransformConvertColor(CGColorTransformRef, CGColorRef, CGColorRenderingIntent);
void CGColorTransformRelease(CGColorTransformRef);

// The release's own answer for the grey of a colour: one pixel of a device grey bitmap.
static CGFloat pixel_grey(CGColorRef colour)
{
    uint8_t byte = 0;
    CGColorSpaceRef grey = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(&byte, 1, 1, 8, 1, grey, kCGImageAlphaNone);
    // Opaque: a translucent colour would be composited over the bitmap's black.
    CGColorRef opaque = CGColorCreateCopyWithAlpha(colour, 1);
    CGContextSetFillColorWithColor(context, opaque);
    CGColorRelease(opaque);
    CGContextFillRect(context, CGRectMake(0, 0, 1, 1));
    CGContextRelease(context);
    CGColorSpaceRelease(grey);
    return byte / 255.0;
}

static void show(const char *what, CGColorRef c)
{
    if (!c) {
        printf("measure %s NULL\n", what);
        return;
    }
    size_t n = CGColorGetNumberOfComponents(c);
    const CGFloat *k = CGColorGetComponents(c);
    printf("measure %s model %d retain %ld:", what, CGColorSpaceGetModel(CGColorGetColorSpace(c)), CFGetRetainCount(c));
    for (size_t i = 0; i < n; i++)
        printf(" %.6f", k[i]);
    printf("\n");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to([NSString stringWithUTF8String:argv[1]]);
        CGColorSpaceRef grey = CGColorSpaceCreateDeviceGray(), rgb = CGColorSpaceCreateDeviceRGB(), cmyk = CGColorSpaceCreateDeviceCMYK();
        CGFloat values[][4] = {{1, 0, 0, 0.5}, {0, 1, 0, 1}, {0, 0, 1, 1}, {0.2, 0.4, 0.6, 1}};
        for (int i = 0; i < 4; i++) {
            CGColorRef colour = CGColorCreate(rgb, values[i]);
            CGColorTransformRef transform = CGColorTransformCreate(grey, NULL);
            CHECK(transform != NULL, "the release makes a transform to device grey");
            CGColorRef converted = CGColorTransformConvertColor(transform, colour, kCGRenderingIntentDefault);
            char label[96];
            snprintf(label, sizeof label, "rgb %d to grey", i);
            show(label, converted);
            CHECK(converted && CGColorSpaceGetModel(CGColorGetColorSpace(converted)) == kCGColorSpaceModelMonochrome, "the converted colour is grey");
            if (converted) {
                CGFloat expected = pixel_grey(colour);
                printf("measure rgb %d pixel grey %.6f\n", i, expected);
                CHECK(fabs(CGColorGetComponents(converted)[0] - expected) <= 1.0 / 255 + 1e-6, "the grey is the release's own pixel grey");
                CHECK(CGColorGetComponents(converted)[1] == values[i][3], "the alpha is kept");
                CHECK(CFGetRetainCount(converted) == 1, "the converted colour is the caller's");
                CGColorRelease(converted);
            }
            CGColorTransformRelease(transform);
            CGColorTransformRef back = CGColorTransformCreate(cmyk, NULL);
            snprintf(label, sizeof label, "rgb %d to cmyk", i);
            CGColorRef four = CGColorTransformConvertColor(back, colour, kCGRenderingIntentDefault);
            show(label, four);
            CHECK(four && CGColorGetNumberOfComponents(four) == 5, "a cmyk colour has five components");
            if (four)
                CGColorRelease(four);
            CGColorTransformRelease(back);
            CGColorRelease(colour);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
