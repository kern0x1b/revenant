/* coords.m -- the crop rect as an affine map, read off a coordinate picture.
 *
 * Build and run, from the repository root:
 *
 *   SDK=$(xcrun --show-sdk-path)
 *   xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$SDK" \
 *       -iframework "$SDK/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
 *       -Wno-unguarded-availability tests/backports/host/vision/crop-probe/coords.m \
 *       -framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreML \
 *       -framework Vision -o /tmp/coords
 *   /tmp/coords synthetic     the controls: maps the fit is given, which it must return
 *   /tmp/coords               the twelve real cases
 *
 * Its own controls are what make its numbers mean anything: the first has maps that land on whole
 * source pixels, so the answer must be exact, and it comes back with a residual of 0.0000; the rest
 * have a half-step, and come back within a quarter of a source pixel, which is the staircase of a
 * nearest-neighbour step and not an error in the fit.
 *
 * The source is R = x * k and G = y * k, k chosen so the largest value fits a byte. Every output
 * pixel then says which source point it was sampled from, and fitting x = a * dx + b and y = c * dy
 * + d by least squares over all of them gives the whole map -- the scale and the offset on each
 * axis -- instead of one run's midpoint.
 *
 * Run with no argument for the real cases, and with `synthetic` for the controls: a source and an
 * output built here, with a map that is known exactly, which the fit has to return. A fit that cannot
 * return a map it was handed is not a fit, and the real cases mean nothing until it can.
 */
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <Foundation/Foundation.h>

/* The source keeps this much off zero, so a pixel of (0, 0) in the *output* is unambiguously a bar
 * and not the picture's own origin. The real cases have no bias -- their picture is R = x * k -- and
 * the one pixel that collides is dropped by the fit, which is one pixel in thousands. */
#define CHARON_SYNTHETIC_BIAS 2

/* One fit over every pixel that is not a bar: the scale and the offset on each axis and the rms
 * residual, all in source pixels. `bias` is what the source keeps off zero. */
static void fit(CVPixelBufferRef buffer, size_t tw, size_t th, int k, int bias, const char *what)
{
    const uint8_t *base;
    size_t stride, dx, dy;
    double n = 0, sx = 0, sy = 0, sxx = 0, syy = 0, sr = 0, sg = 0, sxr = 0, syg = 0;
    double squares = 0;
    if (buffer == NULL) {
        printf("| %s | Core ML refused | | | | | |\n", what);
        return;
    }
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    base = (const uint8_t *)CVPixelBufferGetBaseAddress(buffer);
    stride = CVPixelBufferGetBytesPerRow(buffer);
    for (dy = 0; dy < th; dy++) {
        for (dx = 0; dx < tw; dx++) {
            const uint8_t *pixel = base + dy * stride + dx * 4;
            double r = pixel[2], g = pixel[1], xx, yy;
            if (r == 0 && g == 0) {
                continue;   /* a bar */
            }
            xx = (r - (double)bias) / (double)k;
            yy = (g - (double)bias) / (double)k;
            n += 1;
            sx += dx; sy += dy;
            sxx += (double)dx * dx; syy += (double)dy * dy;
            sr += xx; sg += yy;
            sxr += xx * dx; syg += yy * dy;
        }
    }
    if (n < 2) {
        CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        printf("| %s | nothing sampled | | | | | |\n", what);
        return;
    }
    {
        double detX = n * sxx - sx * sx, detY = n * syy - sy * sy;
        double a = (n * sxr - sx * sr) / detX, b = (sr - a * sx) / n;
        double c = (n * syg - sy * sg) / detY, d = (sg - c * sy) / n;
        for (dy = 0; dy < th; dy++) {
            for (dx = 0; dx < tw; dx++) {
                const uint8_t *pixel = base + dy * stride + dx * 4;
                double r = pixel[2], g = pixel[1], ex, ey;
                if (r == 0 && g == 0) {
                    continue;
                }
                ex = a * (double)dx + b - (r - (double)bias) / (double)k;
                ey = c * (double)dy + d - (g - (double)bias) / (double)k;
                squares += ex * ex + ey * ey;
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        /* The offset is the source position at destination 0, which is `b` and `d` themselves --
         * they are already in source pixels. Dividing them by the slope again, which this did, turns
         * a map's +4 into -2 on a slope of 0.5 and a map's -8 into +24 on a slope of a third: a
         * convention of the print, not a staircase, and a staircase could not have produced a
         * quarter-pixel residual. */
        printf("| %s | %.5f | %+.3f | %.5f | %+.3f | %.4f | %zu |\n", what, 1.0 / a, b, 1.0 / c, d,
               sqrt(squares / n), (size_t)n);
    }
}

/* One control: a source of sw x sh with R = kx + bias and G = ky + bias, an output built from
 * it by a known map with nearest neighbour -- so every output pixel is exactly a source pixel -- and
 * the fit on that, which has to return the map it was given. The builder refuses to run rather than
 * wrap a byte. */
static void synthetic_case(double scaleX, double offsetX, double scaleY, double offsetY, int k, int sw,
                           int sh, int tw, int th)
{
    CVPixelBufferRef source = NULL, out = NULL;
    uint8_t *sbase, *obase;
    size_t sstride, ostride, x, y, dx, dy;
    char what[128];

    if (k * (sw - 1) + CHARON_SYNTHETIC_BIAS > 255 || k * (sh - 1) + CHARON_SYNTHETIC_BIAS > 255) {
        printf("| synthetic, k=%d over %d x %d | the builder would wrap a byte | | | | | |\n", k, sw, sh);
        return;
    }
    if (CVPixelBufferCreate(kCFAllocatorDefault, sw, sh, kCVPixelFormatType_32BGRA, NULL, &source) !=
            kCVReturnSuccess ||
        CVPixelBufferCreate(kCFAllocatorDefault, tw, th, kCVPixelFormatType_32BGRA, NULL, &out) !=
            kCVReturnSuccess ||
        CVPixelBufferLockBaseAddress(source, 0) != kCVReturnSuccess ||
        CVPixelBufferLockBaseAddress(out, 0) != kCVReturnSuccess) {
        printf("| synthetic | the buffers could not be made | | | | | |\n");
        return;
    }
    sbase = (uint8_t *)CVPixelBufferGetBaseAddress(source);
    sstride = CVPixelBufferGetBytesPerRow(source);
    obase = (uint8_t *)CVPixelBufferGetBaseAddress(out);
    ostride = CVPixelBufferGetBytesPerRow(out);
    for (y = 0; y < (size_t)sh; y++) {
        for (x = 0; x < (size_t)sw; x++) {
            size_t at = y * sstride + x * 4;
            sbase[at] = 0;
            sbase[at + 1] = (uint8_t)(y * k + CHARON_SYNTHETIC_BIAS);
            sbase[at + 2] = (uint8_t)(x * k + CHARON_SYNTHETIC_BIAS);
            sbase[at + 3] = 255;
        }
    }
    for (dy = 0; dy < (size_t)th; dy++) {
        for (dx = 0; dx < (size_t)tw; dx++) {
            double sx = (double)dx / scaleX + offsetX, sy = (double)dy / scaleY + offsetY;
            long ix = (long)llround(sx), iy = (long)llround(sy);
            size_t at = dy * ostride + dx * 4;
            obase[at] = 0;
            obase[at + 3] = 255;
            if (ix < 0 || iy < 0 || ix >= sw || iy >= sh) {
                obase[at + 1] = 0;
                obase[at + 2] = 0;   /* outside the source: a bar */
                continue;
            }
            memcpy(obase + at + 1, sbase + (size_t)iy * sstride + (size_t)ix * 4 + 1, 3);
        }
    }
    snprintf(what, sizeof what, "synthetic, map x = %g*d + %g and y = %g*d + %g", scaleX, offsetX, scaleY,
             offsetY);
    fit(out, tw, th, k, CHARON_SYNTHETIC_BIAS, what);
    CVPixelBufferUnlockBaseAddress(source, 0);
    CVPixelBufferUnlockBaseAddress(out, 0);
    CVPixelBufferRelease(source);
    CVPixelBufferRelease(out);
}

/* The coordinate picture, for the real cases: no bias, and drawn top-down so that (0,0) is the top
 * left corner -- a CGContext's origin is the bottom left, and a picture drawn in one origin and read
 * in the other comes out mirrored. */
static CGImageRef coordinates(size_t wide, size_t high, int k)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context =
        CGBitmapContextCreate(NULL, wide, high, 8, 0, space, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGImageRef image = NULL;
    size_t x, y;
    CGColorSpaceRelease(space);
    if (context == NULL) {
        return NULL;
    }
    CGContextTranslateCTM(context, 0, (CGFloat)high);
    CGContextScaleCTM(context, 1, -1);
    CGContextSetRGBFillColor(context, 0, 0, 0, 1.0);
    CGContextFillRect(context, CGRectMake(0, 0, (CGFloat)wide, (CGFloat)high));
    for (y = 0; y < high; y++) {
        for (x = 0; x < wide; x++) {
            CGContextSetRGBFillColor(context, (double)(x * k) / 255.0, (double)(y * k) / 255.0, 0, 1.0);
            CGContextFillRect(context, CGRectMake((CGFloat)x, (CGFloat)y, 1, 1));
        }
    }
    image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        printf("| case | scale x | offset x | scale y | offset y | rms residual | pixels |\n");
        printf("| --- | --- | --- | --- | --- | --- | --- |\n");
        if (argc > 1) {
            /* Integer maps, so the output is exactly the source and nothing rounds: every figure
             * below has to come back exactly. */
            synthetic_case(0.5, 1, 1, 3, 4, 64, 64, 64, 64);
            synthetic_case(2, 1, 1, 3, 4, 64, 64, 64, 64);
            /* And the fractional ones, where the nearest-neighbour step is half a source pixel
             * and the answer is allowed a half-step. */
            synthetic_case(2, 0, 0.5, 4, 4, 64, 64, 64, 64);
            synthetic_case(1.5, 2, 3, -8, 4, 64, 64, 60, 40);
            return 0;
        }
        {
            struct {
                size_t sw, sh, tw, th;
                VNImageCropAndScaleOption option;
                const char *name;
            } cases[] = {
                {100, 50, 224, 224, VNImageCropAndScaleOptionCenterCrop, "centre crop"},
                {50, 100, 224, 224, VNImageCropAndScaleOptionCenterCrop, "centre crop"},
                {16, 8, 32, 8, VNImageCropAndScaleOptionCenterCrop, "centre crop"},
                {10, 10, 30, 20, VNImageCropAndScaleOptionCenterCrop, "centre crop"},
                {20, 10, 20, 20, VNImageCropAndScaleOptionCenterCrop, "centre crop"},
                {100, 50, 224, 224, VNImageCropAndScaleOptionScaleFit, "scale fit"},
                {50, 100, 224, 224, VNImageCropAndScaleOptionScaleFit, "scale fit"},
                {16, 8, 32, 8, VNImageCropAndScaleOptionScaleFit, "scale fit"},
                {10, 10, 30, 20, VNImageCropAndScaleOptionScaleFit, "scale fit"},
                {5, 10, 30, 20, VNImageCropAndScaleOptionScaleFit, "scale fit"},
                {10, 20, 30, 10, VNImageCropAndScaleOptionScaleFit, "scale fit"},
            };
            size_t index;
            for (index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
                int k = (int)(255.0 / (double)(cases[index].sw - 1 > cases[index].sh - 1 ? cases[index].sw - 1
                                                                                        : cases[index].sh - 1));
                CGImageRef image = coordinates(cases[index].sw, cases[index].sh, k);
                NSError *failure = nil;
                MLFeatureValue *value = [MLFeatureValue featureValueWithCGImage:image
                                                                   pixelsWide:(NSInteger)cases[index].tw
                                                                   pixelsHigh:(NSInteger)cases[index].th
                                                              pixelFormatType:kCVPixelFormatType_32BGRA
                                                                      options:@{
                                                                          MLFeatureValueImageOptionCropAndScale :
                                                                              @(cases[index].option)
                                                                      }
                                                                        error:&failure];
                char what[160];
                snprintf(what, sizeof what, "%zu x %zu to %zu x %zu, %s", cases[index].sw, cases[index].sh,
                         cases[index].tw, cases[index].th, cases[index].name);
                fit(value == nil ? NULL : value.imageBufferValue, cases[index].tw, cases[index].th, k, 0, what);
                CGImageRelease(image);
            }
        }
    }
    return 0;
}
