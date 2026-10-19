/* delta.m -- the same ramp through both sides, and the difference in source coordinates.
 *
 * The port's resampler is linked in from the library, so this is the code the check builds; the
 * Vision classes are renamed by the harness's rename header because this file also links the
 * framework's own.
 *
 *   SDK=$(xcrun --show-sdk-path)
 *   xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$SDK" \
 *       -iframework "$SDK/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
 *       -Wno-unguarded-availability -I tests/backports/host/vision/crop-probe \
 *       tests/backports/host/vision/crop-probe/delta.m \
 *       packages/a/apple-backports/Vision/CharonVisionBilinear.c \
 *       -framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreML \
 *       -framework Vision -o /tmp/delta && /tmp/delta
 *
 *
 * The ramp is fed to Core ML and to the port's own resampler, and for every output pixel the two
 * answers are decoded back into source coordinates (a value of v is the source column v / k) and
 * subtracted. The result is one number per axis per pixel, and what it is says which of the three
 * things is going on: a constant is a pixel-centre convention, a number that grows along the row is a
 * different scale, and a spread with no shape is a different kernel or its rounding.
 */
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>

/* The port's own resampler, compiled in: the kernel is a .c of the library and the placement is in
 * the header, so this is the same code the check builds. */
extern void charon_vision_bilinear(const uint8_t *source, size_t sourceStride, size_t sourceWide,
                                   size_t sourceHigh, uint8_t *target, size_t targetStride, long insetX,
                                   long insetY, long drawWide, long drawHigh, long targetWide, long targetHigh);

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

int main(int argc, char **argv)
{
    @autoreleasepool {
        size_t sw = 100, sh = 50, tw = 224, th = 224;
        int k = 1;
        double scale = MAX((double)tw / (double)sw, (double)th / (double)sh);
        long drawWide = (long)((double)sw * scale + 0.5), drawHigh = (long)((double)sh * scale + 0.5);
        long insetX = ((long)tw - drawWide) / 2, insetY = ((long)th - drawHigh) / 2;
        CGImageRef image = ramp(sw, sh, k);
        NSError *failure = nil;
        MLFeatureValue *value = [MLFeatureValue featureValueWithCGImage:image
                                                           pixelsWide:224
                                                           pixelsHigh:224
                                                      pixelFormatType:kCVPixelFormatType_32BGRA
                                                              options:@{ MLFeatureValueImageOptionCropAndScale :
                                                                         @(VNImageCropAndScaleOptionCenterCrop) }
                                                            error:&failure];
        CVPixelBufferRef source = NULL, want = value == nil ? NULL : value.imageBufferValue, mine = NULL;
        const uint8_t *a, *b;
        size_t strideA, strideB, dx, dy, taken = 0;
        double minX = 1e9, maxX = -1e9, sumX = 0, minY = 1e9, maxY = -1e9, sumY = 0;
        setvbuf(stdout, NULL, _IONBF, 0);
        if (want == NULL) { printf("  Core ML refused: %s\n", failure.localizedDescription.UTF8String); return 1; }
        if (CVPixelBufferCreate(kCFAllocatorDefault, sw, sh, kCVPixelFormatType_32BGRA, NULL, &source) !=
                kCVReturnSuccess ||
            CVPixelBufferCreate(kCFAllocatorDefault, tw, th, kCVPixelFormatType_32BGRA, NULL, &mine) !=
                kCVReturnSuccess ||
            CVPixelBufferLockBaseAddress(source, 0) != kCVReturnSuccess ||
            CVPixelBufferLockBaseAddress(mine, 0) != kCVReturnSuccess) {
            printf("  the buffers could not be made\n");
            return 1;
        }
        {
            CGContextRef into = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(source), sw, sh, 8,
                                                        CVPixelBufferGetBytesPerRow(source), CGColorSpaceCreateDeviceRGB(),
                                                        kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
            if (into != NULL) {
                CGContextDrawImage(into, CGRectMake(0, 0, (CGFloat)sw, (CGFloat)sh), image);
                CGContextRelease(into);
            }
        }
        memset(CVPixelBufferGetBaseAddress(mine), 0, CVPixelBufferGetBytesPerRow(mine) * th);
        charon_vision_bilinear((const uint8_t *)CVPixelBufferGetBaseAddress(source),
                               CVPixelBufferGetBytesPerRow(source), sw, sh,
                               (uint8_t *)CVPixelBufferGetBaseAddress(mine), CVPixelBufferGetBytesPerRow(mine),
                               insetX, insetY, drawWide, drawHigh, (long)tw, (long)th);
        CVPixelBufferLockBaseAddress(want, kCVPixelBufferLock_ReadOnly);
        a = (const uint8_t *)CVPixelBufferGetBaseAddress(want);
        strideA = CVPixelBufferGetBytesPerRow(want);
        b = (const uint8_t *)CVPixelBufferGetBaseAddress(mine);
        strideB = CVPixelBufferGetBytesPerRow(mine);
        printf("  100x50 to 224x224 centre crop: scale %g, drawn %ldx%ld, inset %ld,%ld, k=%d\n", scale, drawWide,
               drawHigh, insetX, insetY, k);
        printf("  | axis | min | max | mean | spread | the difference along the middle row, every eighth |\n");
        printf("  | --- | --- | --- | --- | --- | --- |\n");
        {
            double dminX = 1e9, dmaxX = -1e9, dsumX = 0, dminY = 1e9, dmaxY = -1e9, dsumY = 0;
            double along[16];
            size_t sample;
            for (dy = 0; dy < th; dy++) for (dx = 0; dx < tw; dx++) {
                size_t pa = dy * strideA + dx * 4, pb = dy * strideB + dx * 4;
                double dxr, dyr;
                if (a[pa] == 0 && a[pa + 1] == 0) { continue; }   /* a bar on one side or the other */
                dxr = (double)a[pa + 2] - (double)b[pb + 2];
                dyr = (double)a[pa + 1] - (double)b[pb + 1];
                taken++;
                if (dxr < dminX) { dminX = dxr; }
                if (dxr > dmaxX) { dmaxX = dxr; }
                dsumX += dxr;
                if (dyr < dminY) { dminY = dyr; }
                if (dyr > dmaxY) { dmaxY = dyr; }
                dsumY += dyr;
                if (dxr < minX) { minX = dxr; }
                if (dxr > maxX) { maxX = dxr; }
                if (dyr < minY) { minY = dyr; }
                if (dyr > maxY) { maxY = dyr; }
            }
            sumX = dsumX; sumY = dsumY;
            for (sample = 0; sample < 16; sample++) {
                size_t at = (size_t)sample * 16;
                along[sample] = (at < tw) ? (double)a[(th / 2) * strideA + at * 4 + 2] - (double)b[(th / 2) * strideB + at * 4 + 2] : 0;
            }
            printf("  | x (red) | %.0f | %.0f | %.3f | %.0f |", dminX, dmaxX, taken ? dsumX / (double)taken : 0,
                   dmaxX - dminX);
            for (sample = 0; sample < 16; sample++) { printf(" %.0f", along[sample]); }
            printf(" |\n  | y (green) | %.0f | %.0f | %.3f | %.0f |\n", dminY, dmaxY, taken ? dsumY / (double)taken : 0,
                   dmaxY - dminY);
        }
        printf("  | pixels compared: %zu of %zu |\n", taken, tw * th);
    }
    return 0;
}
