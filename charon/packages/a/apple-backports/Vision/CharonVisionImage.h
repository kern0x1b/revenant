#ifndef CHARON_VISION_IMAGE_H
#define CHARON_VISION_IMAGE_H

#import <CoreGraphics/CoreGraphics.h>

#include <stddef.h>
#include <stdint.h>

extern void charon_vision_bilinear(const uint8_t *source, size_t sourceStride, size_t sourceWide,
                                   size_t sourceHigh, uint8_t *target, size_t targetStride, long insetX,
                                   long insetY, long drawWide, long drawHigh, long targetWide, long targetHigh);

#import <CoreVideo/CoreVideo.h>

#ifndef CHARON_VISION_INTERPOLATION
#define CHARON_VISION_INTERPOLATION kCGInterpolationHigh
#endif

static inline CVPixelBufferRef charon_vision_pixels(CVPixelBufferRef source, size_t wide, size_t high,
                                            VNImageCropAndScaleOption option)
{
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

#endif
