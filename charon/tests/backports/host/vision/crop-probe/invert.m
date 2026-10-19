#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <Foundation/Foundation.h>

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
