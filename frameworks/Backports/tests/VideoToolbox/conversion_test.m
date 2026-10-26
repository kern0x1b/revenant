#import "../Foundation/check.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>
#import <dlfcn.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <time.h>
#import "VTConvertBiPlanar.h"

extern OSStatus RevenantVTCreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CFDictionaryRef options, CGImageRef *imageOut);

static uint32_t revenant_state = 2463534242u;

static uint8_t revenant_random(uint8_t low, uint8_t high)
{
    revenant_state ^= revenant_state << 13;
    revenant_state ^= revenant_state >> 17;
    revenant_state ^= revenant_state << 5;
    return low + (uint8_t)(revenant_state % (high - low + 1));
}

static CVPixelBufferRef revenant_frame(OSType format, BOOL bt709)
{
    CVPixelBufferRef buffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, 32, 16, format, NULL, &buffer);
    CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, bt709 ? kCVImageBufferYCbCrMatrix_ITU_R_709_2 : kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate);
    CVPixelBufferLockBaseAddress(buffer, 0);
    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        const BOOL full = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        uint8_t *luma = CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
        const size_t lumaStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0);
        for (size_t row = 0; row < 16; row++)
            for (size_t column = 0; column < 32; column++)
                luma[row * lumaStride + column] = full ? revenant_random(0, 255) : revenant_random(16, 235);
        uint8_t *chroma = CVPixelBufferGetBaseAddressOfPlane(buffer, 1);
        const size_t chromaStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1);
        for (size_t row = 0; row < 8; row++)
            for (size_t column = 0; column < 32; column++)
                chroma[row * chromaStride + column] = full ? revenant_random(0, 255) : revenant_random(16, 240);
    } else {
        uint8_t *base = CVPixelBufferGetBaseAddress(buffer);
        const size_t stride = CVPixelBufferGetBytesPerRow(buffer);
        const size_t alphaIndex = format == kCVPixelFormatType_32ARGB ? 0 : 3;
        for (size_t row = 0; row < 16; row++)
            for (size_t column = 0; column < 32; column++) {
                uint8_t *pixel = base + row * stride + column * 4;
                const uint8_t alpha = revenant_random(0, 255);
                for (size_t channel = 0; channel < 4; channel++) {
                    pixel[channel] = channel == alphaIndex ? alpha : revenant_random(0, alpha);
                }
            }
    }
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return buffer;
}

static NSData *revenant_image_bytes(CGImageRef image)
{
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    return (__bridge_transfer NSData *)data;
}

static NSString *revenant_worst_pixel(CVPixelBufferRef frame, OSType format, NSData *expected, NSData *actual, int tolerance)
{
    const uint8_t *a = expected.bytes, *b = actual.bytes;
    NSUInteger worstIndex = 0;
    int worst = 0;
    for (NSUInteger index = 0; index < expected.length && index < actual.length; index++) {
        int difference = abs((int)a[index] - (int)b[index]);
        if (difference > worst) {
            worst = difference;
            worstIndex = index;
        }
    }
    if (worst <= tolerance)
        return @"";
    const NSUInteger pixel = worstIndex / 4, row = pixel / 32, column = pixel % 32;
    NSMutableString *text = [NSMutableString stringWithFormat:@"largest difference %d at row %lu column %lu: host %u %u %u %u backport %u %u %u %u", worst, (unsigned long)row, (unsigned long)column, a[pixel * 4], a[pixel * 4 + 1], a[pixel * 4 + 2], a[pixel * 4 + 3], b[pixel * 4], b[pixel * 4 + 1], b[pixel * 4 + 2], b[pixel * 4 + 3]];
    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        CVPixelBufferLockBaseAddress(frame, kCVPixelBufferLock_ReadOnly);
        const uint8_t *luma = CVPixelBufferGetBaseAddressOfPlane(frame, 0);
        const uint8_t *chroma = CVPixelBufferGetBaseAddressOfPlane(frame, 1);
        [text appendFormat:@" source Y %u Cb %u Cr %u", luma[row * CVPixelBufferGetBytesPerRowOfPlane(frame, 0) + column], chroma[(row / 2) * CVPixelBufferGetBytesPerRowOfPlane(frame, 1) + (column / 2) * 2], chroma[(row / 2) * CVPixelBufferGetBytesPerRowOfPlane(frame, 1) + (column / 2) * 2 + 1]];
        CVPixelBufferUnlockBaseAddress(frame, kCVPixelBufferLock_ReadOnly);
    }
    return text;
}

static void revenant_compare_frame(OSType format, BOOL bt709, int tolerance)
{
    NSString *name = [NSString stringWithFormat:@"format %u bt709 %d", (unsigned)format, bt709];
    const uint32_t seed = revenant_state;
    CVPixelBufferRef hostFrame = revenant_frame(format, bt709);
    revenant_state = seed;
    CVPixelBufferRef backportFrame = revenant_frame(format, bt709);
    CGImageRef hostImage = NULL, backportImage = NULL;
    const OSStatus hostStatus = VTCreateCGImageFromCVPixelBuffer(hostFrame, NULL, &hostImage);
    const OSStatus backportStatus = RevenantVTCreateCGImageFromCVPixelBuffer(backportFrame, NULL, &backportImage);
    revenant_check(hostStatus == noErr && backportStatus == noErr && hostImage && backportImage, [[NSString stringWithFormat:@"the frame converts: %@", name] UTF8String], [NSString stringWithFormat:@"host %d backport %d", (int)hostStatus, (int)backportStatus]);
    if (hostImage && backportImage) {
        revenant_check(CGImageGetWidth(hostImage) == CGImageGetWidth(backportImage) && CGImageGetHeight(hostImage) == CGImageGetHeight(backportImage) && CGImageGetBitmapInfo(hostImage) == CGImageGetBitmapInfo(backportImage), [[NSString stringWithFormat:@"the image geometry and bitmap info match: %@", name] UTF8String], [NSString stringWithFormat:@"host %zux%zu info %u backport %zux%zu info %u", CGImageGetWidth(hostImage), CGImageGetHeight(hostImage), (unsigned)CGImageGetBitmapInfo(hostImage), CGImageGetWidth(backportImage), CGImageGetHeight(backportImage), (unsigned)CGImageGetBitmapInfo(backportImage)]);
        NSData *hostBytes = revenant_image_bytes(hostImage);
        NSData *backportBytes = revenant_image_bytes(backportImage);
        NSString *detail = revenant_worst_pixel(hostFrame, format, hostBytes, backportBytes, tolerance);
        revenant_check(hostBytes.length == backportBytes.length && detail.length == 0, [[NSString stringWithFormat:@"the pixels match the host within %d: %@", tolerance, name] UTF8String], detail);
    }
    if (hostImage) CGImageRelease(hostImage);
    if (backportImage) CGImageRelease(backportImage);
    CVPixelBufferRelease(hostFrame);
    CVPixelBufferRelease(backportFrame);
}

#if defined(__ARM_NEON)
static void revenant_fill_random(uint8_t *bytes, size_t count, uint8_t low, uint8_t high)
{
    for (size_t index = 0; index < count; index++)
        bytes[index] = revenant_random(low, high);
}

static void revenant_compare_neon(size_t width, size_t height, BOOL fullRange, BOOL bt709)
{
    const size_t lumaStride = width + 3, chromaStride = (width + 1) / 2 * 2 + 5, rowBytes = width * 4;
    const size_t chromaRows = (height + 1) / 2;
    uint8_t *luma = malloc(lumaStride * height), *chroma = malloc(chromaStride * chromaRows);
    uint8_t *scalar = malloc(rowBytes * height), *neon = malloc(rowBytes * height);
    revenant_fill_random(luma, lumaStride * height, fullRange ? 0 : 16, fullRange ? 255 : 235);
    revenant_fill_random(chroma, chromaStride * chromaRows, fullRange ? 0 : 16, fullRange ? 255 : 240);
    RevenantVTConvertBiPlanarScalar(scalar, rowBytes, luma, lumaStride, chroma, chromaStride, width, height, fullRange, bt709);
    RevenantVTConvertBiPlanarNEON(neon, rowBytes, luma, lumaStride, chroma, chromaStride, width, height, fullRange, bt709);
    revenant_check(memcmp(scalar, neon, rowBytes * height) == 0, [[NSString stringWithFormat:@"NEON matches scalar bit for bit: width %zu height %zu full %d bt709 %d", width, height, fullRange, bt709] UTF8String], @"the NEON output differs from the scalar reference");
    free(luma);
    free(chroma);
    free(scalar);
    free(neon);
}

static double revenant_seconds(void)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (double)now.tv_sec + (double)now.tv_nsec * 1e-9;
}

static void revenant_benchmark(void)
{
    const size_t width = 1920, height = 1080, lumaStride = width, chromaStride = width, rowBytes = width * 4, iterations = 100;
    uint8_t *luma = malloc(lumaStride * height), *chroma = malloc(chromaStride * (height / 2));
    uint8_t *out = malloc(rowBytes * height);
    revenant_fill_random(luma, lumaStride * height, 16, 235);
    revenant_fill_random(chroma, chromaStride * (height / 2), 16, 240);
    RevenantVTConvertBiPlanarScalar(out, rowBytes, luma, lumaStride, chroma, chromaStride, width, height, NO, YES);
    double start = revenant_seconds();
    for (size_t iteration = 0; iteration < iterations; iteration++)
        RevenantVTConvertBiPlanarScalar(out, rowBytes, luma, lumaStride, chroma, chromaStride, width, height, NO, YES);
    const double scalarSeconds = revenant_seconds() - start;
    RevenantVTConvertBiPlanarNEON(out, rowBytes, luma, lumaStride, chroma, chromaStride, width, height, NO, YES);
    start = revenant_seconds();
    for (size_t iteration = 0; iteration < iterations; iteration++)
        RevenantVTConvertBiPlanarNEON(out, rowBytes, luma, lumaStride, chroma, chromaStride, width, height, NO, YES);
    const double neonSeconds = revenant_seconds() - start;
    const double pixels = (double)(width * height * iterations) / 1e6;
    printf("benchmark 1920x1080 NV12 video range BT.709, %zu frames: scalar %.1f Mpix/s, NEON %.1f Mpix/s\n", iterations, pixels / scalarSeconds, pixels / neonSeconds);
    free(luma);
    free(chroma);
    free(out);
}
#endif

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    revenant_check((dlsym(RTLD_DEFAULT, "RevenantVTCreateCGImageFromCVPixelBuffer") != NULL) != revenant_negative, "VTCreateCGImageFromCVPixelBuffer implementation is present", @"RevenantVTCreateCGImageFromCVPixelBuffer");
    if (dlsym(RTLD_DEFAULT, "RevenantVTCreateCGImageFromCVPixelBuffer") == NULL)
        return revenant_finish();

    for (int fullRange = 0; fullRange < 2; fullRange++) {
        for (int bt709 = 0; bt709 < 2; bt709++) {
            const OSType format = fullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
            revenant_compare_frame(format, bt709, 1);
        }
    }
    revenant_compare_frame(kCVPixelFormatType_32BGRA, NO, 0);
    revenant_compare_frame(kCVPixelFormatType_32ARGB, NO, 0);

    CVPixelBufferRef tenBit = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, 32, 16, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, NULL, &tenBit);
    CGImageRef backportTenBit = NULL;
    const OSStatus backportTenBitStatus = RevenantVTCreateCGImageFromCVPixelBuffer(tenBit, NULL, &backportTenBit);
    revenant_check(backportTenBitStatus == kVTPixelTransferNotSupportedErr && backportTenBit == NULL, "the backport refuses a 10-bit format it does not convert", [NSString stringWithFormat:@"backport %d", (int)backportTenBitStatus]);
    if (backportTenBit) CGImageRelease(backportTenBit);
    CVPixelBufferRelease(tenBit);

    CGImageRef nilImage = NULL;
    revenant_check(RevenantVTCreateCGImageFromCVPixelBuffer(NULL, NULL, &nilImage) == kVTParameterErr && nilImage == NULL, "a NULL buffer is a parameter error", @"kVTParameterErr");

#if defined(__ARM_NEON)
    const size_t neonWidths[] = {1, 15, 16, 17, 37, 1920};
    for (size_t index = 0; index < sizeof(neonWidths) / sizeof(neonWidths[0]); index++)
        for (int fullRange = 0; fullRange < 2; fullRange++)
            for (int bt709 = 0; bt709 < 2; bt709++)
                revenant_compare_neon(neonWidths[index], 5, fullRange, bt709);
    revenant_benchmark();
#endif

    return revenant_finish();
}
