#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <stdint.h>

static uint32_t state = 12345;

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
    size_t sizes[][2] = {{640, 480}, {1, 1}, {3, 7}, {1920, 1080}, {0, 480}, {640, 0}, {0, 0}};
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
