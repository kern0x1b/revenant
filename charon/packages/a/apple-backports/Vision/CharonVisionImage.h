/* The image a request handler holds, as a pixel buffer of the size a model's image input wants.
 *
 * A header of static inline functions, and not a .m of its own, because two files of this library
 * call them and a C function two files share has to live in a file that exports no symbol: a .m
 * would put both in the dylib's exports, where the registry would owe an entry for a name Core ML
 * does not declare. It is the same reason CharonMLBridge.h and CharonMLConstraints.h are headers.
 *
 * Vision is where this belongs: a Core ML feature value takes a buffer, and turning what a handler
 * holds into one of the size the model asks for -- cropping, scaling, and the two ways a Core ML
 * image input says to do it -- is image handling, not model handling.
 *
 * The two options are the two Vision declares, and they are the two Core ML's own image
 * constructors use:
 *   - centre crop: the image is scaled until it covers the target and the middle is kept, so the
 *     answer is made of the middle of the picture at the model's own aspect;
 *   - scale fit: the image is scaled until it fits inside the target and the rest is left black,
 *     so nothing of the picture is cut away.
 *
 * A buffer that is already the size the model wants is handed on as it is, which is the case a
 * camera frame or a video frame is in and the one that costs nothing: the pixels are not touched
 * at all. A CGImage is drawn into a buffer, because a feature value of the image type takes a
 * buffer and this port carries no image feature value that takes a CGImage (facts/CoreML/CoreML.md
 * says why).
 */
#ifndef CHARON_VISION_IMAGE_H
#define CHARON_VISION_IMAGE_H

#import <CoreGraphics/CoreGraphics.h>

#include <stddef.h>
#include <stdint.h>

/* The resampler, in CharonVisionBilinear.c: separable bilinear, two taps, the half-pixel sample
 * centre, a truncated position and a value rounded half up, all chosen by the gradient table. */
extern void charon_vision_bilinear(const uint8_t *source, size_t sourceStride, size_t sourceWide,
                                   size_t sourceHigh, uint8_t *target, size_t targetStride, long insetX,
                                   long insetY, long drawWide, long drawHigh, long targetWide, long targetHigh);

#import <CoreVideo/CoreVideo.h>

/* The interpolation Core ML's own image constructor uses, as a macro so the check can compile this
 * same function with each of CoreGraphics' qualities and find the one that matches the framework
 * pixel for pixel -- tests/backports/host/vision/crop.m, which is how `High` was chosen. The default
 * is what the measurement says; a caller that wants a different one is the check, not a library. */
#ifndef CHARON_VISION_INTERPOLATION
#define CHARON_VISION_INTERPOLATION kCGInterpolationHigh
#endif

static inline CVPixelBufferRef charon_vision_pixels(CVPixelBufferRef source, size_t wide, size_t high,
                                            VNImageCropAndScaleOption option)
{
    /* The placement is rounded the way the kernel's own check rounds it, and the bars are the
     * kernel's own memset: CoreGraphics drew them once under a picture the kernel then drew over,
     * which is two resamplers and the CG one winning wherever the two disagreed. Core ML's
     * reference has `00 00 00 00` in the bars -- measured, not assumed -- which is what a cleared
     * buffer holds. */
    CVPixelBufferRef buffer = NULL;
    const uint8_t *bytes;
    uint8_t *out;
    size_t sw, sh, stride, outStride, drawWide, drawHigh;
    long insetX, insetY;
    CGFloat scale;

    if (source == NULL || wide == 0 || high == 0) {
        return NULL;
    }
    if (CVPixelBufferGetWidth(source) == wide && CVPixelBufferGetHeight(source) == high) {
        return (CVPixelBufferRef)CVPixelBufferRetain(source);
    }
    if (CVPixelBufferLockBaseAddress(source, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) {
        return NULL;
    }
    sw = CVPixelBufferGetWidth(source);
    sh = CVPixelBufferGetHeight(source);
    stride = CVPixelBufferGetBytesPerRow(source);
    bytes = (const uint8_t *)CVPixelBufferGetBaseAddress(source);
    if (bytes == NULL || sw == 0 || sh == 0 ||
        CVPixelBufferCreate(kCFAllocatorDefault, wide, high, kCVPixelFormatType_32BGRA, NULL, &buffer) !=
            kCVReturnSuccess ||
        CVPixelBufferLockBaseAddress(buffer, 0) != kCVReturnSuccess) {
        CVPixelBufferUnlockBaseAddress(source, kCVPixelBufferLock_ReadOnly);
        if (buffer != NULL) {
            CVPixelBufferRelease(buffer);
        }
        return NULL;
    }
    scale = option == VNImageCropAndScaleOptionScaleFit
                ? MIN((CGFloat)wide / (CGFloat)sw, (CGFloat)high / (CGFloat)sh)
                : MAX((CGFloat)wide / (CGFloat)sw, (CGFloat)high / (CGFloat)sh);
    drawWide = (size_t)((CGFloat)sw * scale + 0.5);
    drawHigh = (size_t)((CGFloat)sh * scale + 0.5);
    if (drawWide < 1) {
        drawWide = 1;
    }
    if (drawHigh < 1) {
        drawHigh = 1;
    }
    /* A cover is *not* clamped to the target: the picture is scaled past the target's edge and the
     * crop is what takes the middle out of it, so a 100x50 picture at 224x224 is drawn 448 wide with
     * an inset of -112 and the kernel writes only the 224 columns that land inside. Clamping the
     * drawn size instead is a scale fit wearing a cover's name, and it is what left the centre-crop
     * rows at 50029 of 50176. The kernel clips, so the overflow costs nothing. */
    insetX = ((long)wide - (long)drawWide) / 2;
    insetY = ((long)high - (long)drawHigh) / 2;
    out = (uint8_t *)CVPixelBufferGetBaseAddress(buffer);
    outStride = CVPixelBufferGetBytesPerRow(buffer);
    memset(out, 0, outStride * high);
    charon_vision_bilinear(bytes, stride, sw, sh, out, outStride, insetX, insetY, (long)drawWide,
                           (long)drawHigh, (long)wide, (long)high);
    CVPixelBufferUnlockBaseAddress(source, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return buffer;
}

/* A CGImage as a pixel buffer of its own size, which is how a picture a caller handed a request
 * handler becomes something a Core ML feature value of the image type can be built from: the
 * helper above resamples from a buffer, so a picture is drawn into one of its own size first and
 * both kinds of image go through one drawing path and one pair of crop-and-scale rules. */
static inline CVPixelBufferRef charon_vision_buffer_of_image(CGImageRef image)
{
    CVPixelBufferRef buffer = NULL;
    CGColorSpaceRef space;
    CGContextRef context;
    size_t wide, high;

    if (image == NULL) {
        return NULL;
    }
    wide = CGImageGetWidth(image);
    high = CGImageGetHeight(image);
    if (wide == 0 || high == 0 ||
        CVPixelBufferCreate(kCFAllocatorDefault, wide, high, kCVPixelFormatType_32BGRA, NULL, &buffer) !=
            kCVReturnSuccess ||
        CVPixelBufferLockBaseAddress(buffer, 0) != kCVReturnSuccess) {
        if (buffer != NULL) {
            CVPixelBufferRelease(buffer);
        }
        return NULL;
    }
    space = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(buffer), wide, high, 8,
                                    CVPixelBufferGetBytesPerRow(buffer), space,
                                    kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    if (space != NULL) {
        CGColorSpaceRelease(space);
    }
    if (context != NULL) {
        CGContextSetInterpolationQuality(context, CHARON_VISION_INTERPOLATION);
    }
    if (context == NULL) {
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        CVPixelBufferRelease(buffer);
        return NULL;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat)wide, (CGFloat)high), image);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return buffer;
}

#endif /* CHARON_VISION_IMAGE_H */
