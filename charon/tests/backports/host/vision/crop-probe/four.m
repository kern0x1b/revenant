/* four.m -- Core ML's own answer alone, four fits over it, and two candidate rules scored on it.
 *
 *   SDK=$(xcrun --show-sdk-path)
 *   xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$SDK" \
 *       -iframework "$SDK/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
 *       -Wno-unguarded-availability tests/backports/host/vision/crop-probe/four.m \
 *       -framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreML \
 *       -framework Vision -o /tmp/four && /tmp/four
 *
 *
 * The ramp is a position: the red channel of an output pixel is the fractional source column and
 * the green channel is the fractional source row. So the answer says which source point each pixel
 * sampled, and four straight lines over that -- R against x, R against y, G against x, G against y --
 * say whether the two channels follow the axis they should. R following y, or G following x, is a
 * transposition; R following x with a slope that is not 1/4.48 is Core ML's real scale.
 */
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <Foundation/Foundation.h>

static CGImageRef ramp(size_t wide, size_t high, int k)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context =
        CGBitmapContextCreate(NULL, wide, high, 8, 0, space, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGImageRef image = NULL;
    size_t x, y;
    CGColorSpaceRelease(space);
    if (context == NULL) { return NULL; }
    CGContextTranslateCTM(context, 0, (CGFloat)high);
    CGContextScaleCTM(context, 1, -1);
    for (y = 0; y < high; y++) for (x = 0; x < wide; x++) {
        CGContextSetRGBFillColor(context, (double)(x * k) / 255.0, (double)(y * k) / 255.0, 0, 1.0);
        CGContextFillRect(context, CGRectMake((CGFloat)x, (CGFloat)y, 1, 1));
    }
    image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

/* A straight line through (u, v) pairs, and the residual. */
static void fit(const char *what, const double *u, const double *v, size_t n)
{
    double n_ = (double)n, su = 0, sv = 0, suu = 0, suv = 0, squares = 0;
    size_t i;
    double slope, offset, rms;
    for (i = 0; i < n; i++) { su += u[i]; sv += v[i]; suu += u[i] * u[i]; suv += u[i] * v[i]; }
    slope = (n_ * suv - su * sv) / (n_ * suu - su * su);
    offset = (sv - slope * su) / n_;
    for (i = 0; i < n; i++) { double e = slope * u[i] + offset - v[i]; squares += e * e; }
    rms = sqrt(squares / n_);
    printf("  | %-22s | %.5f | %+.3f | %.4f | %zu |\n", what, slope, offset, rms, n);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        size_t sw = 100, sh = 50, tw = 224, th = 224;
        int k = 1;
        CGImageRef image = ramp(sw, sh, k);
        NSError *failure = nil;
        MLFeatureValue *value = [MLFeatureValue featureValueWithCGImage:image
                                                           pixelsWide:224
                                                           pixelsHigh:224
                                                      pixelFormatType:kCVPixelFormatType_32BGRA
                                                              options:@{ MLFeatureValueImageOptionCropAndScale :
                                                                         @(VNImageCropAndScaleOptionCenterCrop) }
                                                            error:&failure];
        CVPixelBufferRef buffer;
        const uint8_t *base;
        size_t stride, dx, dy, taken = 0, cap = 51264;
        static double ux[51264], uy[51264], vR[51264], vG[51264];
        double resA = 0, resB = 0;
        setvbuf(stdout, NULL, _IONBF, 0);
        if (value == nil) { printf("  Core ML refused: %s\n", failure.localizedDescription.UTF8String); return 1; }
        buffer = value.imageBufferValue;
        CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        base = (const uint8_t *)CVPixelBufferGetBaseAddress(buffer);
        stride = CVPixelBufferGetBytesPerRow(buffer);
        printf("  100x50 to 224x224 centre crop, k=%d, a cover of 4.48 on x and 4.48 on y; the answer is in "
               "source columns (red) and rows (green)\n", k);
        printf("  | what is fitted | slope | offset | rms | pixels |\n  | --- | --- | --- | --- | --- |\n");
        for (dy = 0; dy < th; dy++) for (dx = 0; dx < tw; dx++) {
            size_t at = dy * stride + dx * 4;
            if (base[at] == 0 && base[at + 1] == 0) { continue; }
            if (taken < cap) {
                ux[taken] = (double)dx; uy[taken] = (double)dy;
                vR[taken] = (double)base[at + 2]; vG[taken] = (double)base[at + 1];
                taken++;
            }
        }
        fit("red against x", ux, vR, taken);
        fit("red against y", uy, vR, taken);
        fit("green against x", ux, vG, taken);
        fit("green against y", uy, vG, taken);
        /* Two concrete rules, scored on every lit pixel rather than fitted, because a free fit will
         * find a line whatever the answer is and a rule has to be predicted. */
        {
            size_t i;
            for (i = 0; i < taken; i++) {
                /* A: the centre square of the source, scaled to the target with the half-pixel
                 * convention -- slope 50/224 = 0.2232, offset 25 - 0.5 + 0.5 * 0.2232. */
                double a = (ux[i] + 0.5) * (50.0 / 224.0) - 0.5 + 25.0;
                /* B: the port's rule -- the cover at 4.48, drawn 448 wide, cropped to 224 with the
                 * inset (448 - 224) / 2, sampled at the pixel centre. */
                double b = (ux[i] - 112.0 + 0.5) * (100.0 / 448.0) - 0.5;
                double ea = vR[i] - a, eb = vR[i] - b;
                resA += ea * ea;
                resB += eb * eb;
            }
        }
        printf("  | every lit pixel: %zu |\n", taken);
        printf("  | candidate | rms against the measured source columns |\n  | --- | --- |\n");
        printf("  | A: the centre square, 50/224 with the half-pixel centre and +25 | %.4f |\n",
               taken ? sqrt(resA / (double)taken) : 0.0);
        printf("  | B: the port's cover, 4.48, inset (448-224)/2 = 112 | %.4f |\n",
               taken ? sqrt(resB / (double)taken) : 0.0);
    }
    return 0;
}
