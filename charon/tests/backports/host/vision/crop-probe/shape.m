/* shape.m -- on the targets that are not square, which rule is it: the centre *square* of the
 * source, or the largest centred rect of the target's aspect?
 *
 * A square target cannot tell them apart -- both give 50x50 of a 100x50 source -- so this scores
 * both on the two targets the corpus has that are not square, where they differ sharply: for
 * 16x8 to 32x8 the square is an 8x8 of a sixteen wide source, stretched 4x across and 1x down,
 * while the target's aspect takes the full width and four rows, which is the cover the port
 * already implements.
 *
 * Scored, not fitted: each rule predicts a source position for every destination pixel, and the
 * prediction is compared with the source position the ramp in Core ML's own answer reports.
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

static void one(size_t sw, size_t sh, size_t tw, size_t th)
{
    int k = (int)(255.0 / (double)(sw - 1 > sh - 1 ? sw - 1 : sh - 1));
    CGImageRef image = ramp(sw, sh, k);
    NSError *failure = nil;
    MLFeatureValue *value = [MLFeatureValue featureValueWithCGImage:image
                                                       pixelsWide:(NSInteger)tw
                                                       pixelsHigh:(NSInteger)th
                                                  pixelFormatType:kCVPixelFormatType_32BGRA
                                                          options:@{ MLFeatureValueImageOptionCropAndScale :
                                                                         @(VNImageCropAndScaleOptionCenterCrop) }
                                                            error:&failure];
    double side = (double)(sw < sh ? sw : sh);
    double sideX = (double)sw < (double)sh * (double)tw / (double)th ? (double)sw : (double)sh * (double)tw / (double)th;
    double sideY = sideX * (double)th / (double)tw;
    double sqX = 0, sqY = 0, arX = 0, arY = 0;
    size_t taken = 0, dx, dy;
    const uint8_t *base;
    size_t stride;
    printf("  | %zu x %zu to %zu x %zu, centre crop | the square is %gx%g, the target's aspect %gx%g |\n",
           sw, sh, tw, th, side, side, sideX, sideY);
    printf("  | rule | rms on x (source columns) | rms on y (source rows) | pixels |\n  | --- | --- | --- | --- |\n");
    if (value == nil) { printf("  | Core ML refused: %s | | | |\n", failure.localizedDescription.UTF8String); CGImageRelease(image); return; }
    CVPixelBufferLockBaseAddress(value.imageBufferValue, kCVPixelBufferLock_ReadOnly);
    base = (const uint8_t *)CVPixelBufferGetBaseAddress(value.imageBufferValue);
    stride = CVPixelBufferGetBytesPerRow(value.imageBufferValue);
    for (dy = 0; dy < th; dy++) for (dx = 0; dx < tw; dx++) {
        size_t at = dy * stride + dx * 4;
        double gotX, gotY, aX, aY, bX, bY;
        if (base[at] == 0 && base[at + 1] == 0) { continue; }
        gotX = (double)base[at + 2] / (double)k;
        gotY = (double)base[at + 1] / (double)k;
        aX = (sw - side) / 2.0 + (dx + 0.5) * (side / (double)tw) - 0.5;
        aY = (sh - side) / 2.0 + (dy + 0.5) * (side / (double)th) - 0.5;
        bX = (sw - sideX) / 2.0 + (dx + 0.5) * (sideX / (double)tw) - 0.5;
        bY = (sh - sideY) / 2.0 + (dy + 0.5) * (sideY / (double)th) - 0.5;
        sqX += (gotX - aX) * (gotX - aX); sqY += (gotY - aY) * (gotY - aY);
        arX += (gotX - bX) * (gotX - bX); arY += (gotY - bY) * (gotY - bY);
        taken++;
    }
    CVPixelBufferUnlockBaseAddress(value.imageBufferValue, kCVPixelBufferLock_ReadOnly);
    printf("  | the centre square, side %g | %.4f | %.4f | %zu |\n", side, taken ? sqrt(sqX / taken) : 0,
           taken ? sqrt(sqY / taken) : 0, taken);
    printf("  | the target's aspect, %gx%g | %.4f | %.4f | %zu |\n", sideX, sideY,
           taken ? sqrt(arX / taken) : 0, taken ? sqrt(arY / taken) : 0, taken);
    CGImageRelease(image);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        one(16, 8, 32, 8);
        one(10, 10, 30, 20);
        one(20, 10, 20, 20);
    }
    return 0;
}
