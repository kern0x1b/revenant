/* invert.m -- the source position of each destination pixel, with the blend inverted analytically
 *
 * Build and run, from the repository root:
 *
 *   SDK=$(xcrun --show-sdk-path)
 *   xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$SDK" \
 *       -iframework "$SDK/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
 *       -Wno-unguarded-availability tests/backports/host/vision/crop-probe/invert.m \
 *       -framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreML \
 *       -framework Vision -o /tmp/invert && /tmp/invert
 *
 * instead of fitted.
 *
 * The source is a ramp: R = the column and G = the row, so R runs along x and G along y and each
 * channel is a function of one axis alone. A bilinear kernel puts a destination pixel between its
 * two neighbours, so the value that comes out is
 *
 *     (1 - f) * floor(s) + f * ceil(s) = floor(s) + f = s
 *
 * exactly, for a ramp that is the index itself. So the red channel of an output pixel *is* the
 * fractional source column and the green channel *is* the fractional source row: no fit, no
 * staircase, nothing to interpret. Both axes come out of one run, and the crop's start is
 * read off them directly.
 */
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <Foundation/Foundation.h>

/* R = the column, G = the row, both scaled so the largest position fits a byte. */
static CGImageRef ramp(size_t wide, size_t high, double scale, int k)
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

static void one(size_t sw, size_t sh, size_t tw, size_t th, VNImageCropAndScaleOption option,
                const char *name)
{
    double scale = option == VNImageCropAndScaleOptionScaleFit
                        ? MIN((double)tw / (double)sw, (double)th / (double)sh)
                        : MAX((double)tw / (double)sw, (double)th / (double)sh);
    size_t drawnW = (size_t)((double)sw * scale + 0.5), drawnH = (size_t)((double)sh * scale + 0.5);
    double spanX = drawnW > sw ? (double)(drawnW - 1) : (double)(sw - 1);
    double spanY = drawnH > sh ? (double)(drawnH - 1) : (double)(sh - 1);
    int k = (int)(255.0 / (spanX > spanY ? spanX : spanY));
    CGImageRef image = ramp(sw, sh, scale, k);
    NSError *failure = nil;
    MLFeatureValue *value = [MLFeatureValue featureValueWithCGImage:image
                                                       pixelsWide:(NSInteger)tw
                                                       pixelsHigh:(NSInteger)th
                                                  pixelFormatType:kCVPixelFormatType_32BGRA
                                                          options:@{ MLFeatureValueImageOptionCropAndScale :
                                                                         @(option) }
                                                            error:&failure];
    printf("| %zu x %zu to %zu x %zu, %s | scale %g, drawn %zu x %zu, k=%d |", sw, sh, tw, th, name, scale,
           drawnW, drawnH, k);
    if (value == nil || k == 0) {
        printf(" no answer |\n");
        CGImageRelease(image);
        return;
    }
    {
        /* Three destination pixels, with the source position each one says it sampled from, and
         * where the crop therefore starts: the first output pixel that is not a bar, minus half a
         * destination column, is the source position at the target's edge. */
        CVPixelBufferRef buffer = value.imageBufferValue;
        const uint8_t *base;
        size_t stride, dx, dy, firstX = 0, firstY = 0, middleX = 0;
        int haveX = 0, haveY = 0;
        if (buffer == NULL) { printf(" no buffer |\n"); CGImageRelease(image); return; }
        CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        base = (const uint8_t *)CVPixelBufferGetBaseAddress(buffer);
        stride = CVPixelBufferGetBytesPerRow(buffer);
        for (dy = 0; dy < th && !haveY; dy++) for (dx = 0; dx < tw; dx++) {
            size_t at = dy * stride + dx * 4;
            if (base[at] == 0 && base[at + 1] == 0) { continue; }
            if (!haveX) { firstX = dx; haveX = 1; }
            if (!haveY) { firstY = dy; haveY = 1; }
            if (dx == tw / 2) { middleX = dx; }
        }
        printf(" first lit output pixel %zu, %zu | at it the source is column %.3f, row %.3f |", firstX, firstY,
               base[firstY * stride + firstX * 4 + 2] / (double)k, base[firstY * stride + firstX * 4 + 1] / (double)k);
        printf(" at the middle the source column is %.3f |\n",
               base[firstY * stride + (tw / 2) * 4 + 2] / (double)k);
        CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        (void)middleX;
    }
    CGImageRelease(image);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        printf("| case | the geometry | where the first pixel came from | the middle |\n");
        printf("| --- | --- | --- | --- |\n");
        one(100, 50, 224, 224, VNImageCropAndScaleOptionCenterCrop, "centre crop");
        one(50, 100, 224, 224, VNImageCropAndScaleOptionCenterCrop, "centre crop");
        one(16, 8, 32, 8, VNImageCropAndScaleOptionCenterCrop, "centre crop");
        one(10, 10, 30, 20, VNImageCropAndScaleOptionCenterCrop, "centre crop");
        one(20, 10, 20, 20, VNImageCropAndScaleOptionCenterCrop, "centre crop");
        one(100, 50, 224, 224, VNImageCropAndScaleOptionScaleFit, "scale fit");
        one(50, 100, 224, 224, VNImageCropAndScaleOptionScaleFit, "scale fit");
        one(16, 8, 32, 8, VNImageCropAndScaleOptionScaleFit, "scale fit");
        one(10, 10, 30, 20, VNImageCropAndScaleOptionScaleFit, "scale fit");
    }
    return 0;
}
