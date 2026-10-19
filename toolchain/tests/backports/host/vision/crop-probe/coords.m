#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <Foundation/Foundation.h>

#define REVENANT_SYNTHETIC_BIAS 2

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
                continue;
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
        printf("| %s | %.5f | %+.3f | %.5f | %+.3f | %.4f | %zu |\n", what, 1.0 / a, b, 1.0 / c, d,
               sqrt(squares / n), (size_t)n);
    }
}

static void synthetic_case(double scaleX, double offsetX, double scaleY, double offsetY, int k, int sw,
                           int sh, int tw, int th)
{
    CVPixelBufferRef source = NULL, out = NULL;
    uint8_t *sbase, *obase;
    size_t sstride, ostride, x, y, dx, dy;
    char what[128];

    if (k * (sw - 1) + REVENANT_SYNTHETIC_BIAS > 255 || k * (sh - 1) + REVENANT_SYNTHETIC_BIAS > 255) {
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
            sbase[at + 1] = (uint8_t)(y * k + REVENANT_SYNTHETIC_BIAS);
            sbase[at + 2] = (uint8_t)(x * k + REVENANT_SYNTHETIC_BIAS);
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
                obase[at + 2] = 0;
                continue;
            }
            memcpy(obase + at + 1, sbase + (size_t)iy * sstride + (size_t)ix * 4 + 1, 3);
        }
    }
    snprintf(what, sizeof what, "synthetic, map x = %g*d + %g and y = %g*d + %g", scaleX, offsetX, scaleY,
             offsetY);
    fit(out, tw, th, k, REVENANT_SYNTHETIC_BIAS, what);
    CVPixelBufferUnlockBaseAddress(source, 0);
    CVPixelBufferUnlockBaseAddress(out, 0);
    CVPixelBufferRelease(source);
    CVPixelBufferRelease(out);
}

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
            synthetic_case(0.5, 1, 1, 3, 4, 64, 64, 64, 64);
            synthetic_case(2, 1, 1, 3, 4, 64, 64, 64, 64);
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
