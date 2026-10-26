#if defined(REVENANT_HOST_BUILD)
#define VTCreateCGImageFromCVPixelBuffer RevenantVTCreateCGImageFromCVPixelBuffer
#endif

#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>
#import "VTConvertBiPlanar.h"

static BOOL RevenantVTIsBT709(CVPixelBufferRef pixelBuffer)
{
    CFTypeRef matrix = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    return matrix && CFEqual(matrix, kCVImageBufferYCbCrMatrix_ITU_R_709_2);
}

OSStatus VTCreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CFDictionaryRef options, CGImageRef *imageOut)
{
    if (imageOut)
        *imageOut = NULL;
    if (!pixelBuffer || !imageOut)
        return kVTParameterErr;

    const OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    const BOOL fullRange = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    const BOOL biPlanar = fullRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    const BOOL bgra = format == kCVPixelFormatType_32BGRA;
    const BOOL argb = format == kCVPixelFormatType_32ARGB;
    if (!biPlanar && !bgra && !argb)
        return kVTPixelTransferNotSupportedErr;

    const size_t width = CVPixelBufferGetWidth(pixelBuffer);
    const size_t height = CVPixelBufferGetHeight(pixelBuffer);
    const size_t rowBytes = width * 4;
    NSMutableData *pixels = [NSMutableData dataWithLength:rowBytes * height];

    if (CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess)
        return kVTParameterErr;
    if (biPlanar) {
#if defined(__ARM_NEON)
        RevenantVTConvertBiPlanarNEON(pixels.mutableBytes, rowBytes,
#else
        RevenantVTConvertBiPlanarScalar(pixels.mutableBytes, rowBytes,
#endif
                                      CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0), CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0),
                                      CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1), CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1),
                                      width, height, fullRange, RevenantVTIsBT709(pixelBuffer));
    } else {
        const uint8_t *source = CVPixelBufferGetBaseAddress(pixelBuffer);
        const size_t sourceStride = CVPixelBufferGetBytesPerRow(pixelBuffer);
        for (size_t row = 0; row < height; row++) {
            memcpy((uint8_t *)pixels.mutableBytes + row * rowBytes, source + row * sourceStride, rowBytes);
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    const CGBitmapInfo bitmapInfo = biPlanar ? (kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst)
                                  : bgra ? (kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst)
                                  : (kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
    CGImageRef image = CGImageCreate(width, height, 8, 32, rowBytes, colorSpace, bitmapInfo, provider, NULL, false, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    if (!image)
        return kVTAllocationFailedErr;
    *imageOut = image;
    return noErr;
}
