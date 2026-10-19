/* probe.m - the coordinate conversions of Vision that iOS 14 and 15 added, each answer printed with %.17g so two
 * doubles compare by value: a deterministic grid of points, rectangles, image sizes and regions of interest, from the
 * same generator on both sides. Compiled once against the host's Vision framework and once against the port's
 * Vision14_0.m and Vision15_0.m (no framework linked on the port side). */
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <stdint.h>

static uint32_t state = 12345;

/* A value in [-0.5, 1.5): the range the points and regions of a picture take, and the range outside it. */
static double next(void)
{
    state = state * 1664525u + 1013904223u;
    return (double)(state >> 8) / 16777216.0 * 2.0 - 0.5;
}

static CGPoint next_point(void)
{
    CGPoint p = {next(), next()};
    return p;
}

static CGRect next_rect(void)
{
    CGRect r = {{next(), next()}, {next(), next()}};
    return r;
}

int main(void)
{
    /* Image sizes: a picture, the unit image, a tall and a wide one, and the empty ones the guards are for. */
    size_t sizes[][2] = {{640, 480}, {1, 1}, {3, 7}, {1920, 1080}, {0, 480}, {640, 0}, {0, 0}};
    /* Regions: the whole image, a sub-region, a zero-width, a zero-height and a negative-width one. */
    CGRect regions[] = {{{0, 0}, {1, 1}}, {{0.25, 0.5}, {0.5, 0.25}}, {{0.25, 0.5}, {0, 0.25}}, {{0.25, 0.5}, {0.5, 0}}, {{0.25, 0.5}, {-0.5, 0.25}}};
    for (int s = 0; s < 7; s++) {
        for (int r = 0; r < 5; r++) {
            size_t w = sizes[s][0], h = sizes[s][1];
            CGRect roi = regions[r];
            for (int i = 0; i < 8; i++) {
                CGPoint p = next_point();
                CGRect rect = next_rect();
                CGPoint a = VNImagePointForNormalizedPointUsingRegionOfInterest(p, w, h, roi);
                CGPoint b = VNNormalizedPointForImagePointUsingRegionOfInterest(p, w, h, roi);
                CGPoint c = VNNormalizedPointForImagePoint(p, w, h);
                printf("pt %zu %zu r%d i%d img=(%.17g,%.17g) norm=(%.17g,%.17g) plain=(%.17g,%.17g)\n",
                       w, h, r, i, a.x, a.y, b.x, b.y, c.x, c.y);
                CGRect d = VNImageRectForNormalizedRectUsingRegionOfInterest(rect, w, h, roi);
                CGRect e = VNNormalizedRectForImageRectUsingRegionOfInterest(rect, w, h, roi);
                printf("rc %zu %zu r%d i%d img=(%.17g,%.17g,%.17g,%.17g) norm=(%.17g,%.17g,%.17g,%.17g)\n",
                       w, h, r, i, d.origin.x, d.origin.y, d.size.width, d.size.height,
                       e.origin.x, e.origin.y, e.size.width, e.size.height);
            }
        }
    }
    printf("bc %s\n", [VNBarcodeSymbologyCodabar UTF8String]);
    printf("bc %s\n", [VNBarcodeSymbologyGS1DataBar UTF8String]);
    printf("bc %s\n", [VNBarcodeSymbologyGS1DataBarExpanded UTF8String]);
    printf("bc %s\n", [VNBarcodeSymbologyGS1DataBarLimited UTF8String]);
    printf("bc %s\n", [VNBarcodeSymbologyMicroPDF417 UTF8String]);
    printf("bc %s\n", [VNBarcodeSymbologyMicroQR UTF8String]);
    return 0;
}
