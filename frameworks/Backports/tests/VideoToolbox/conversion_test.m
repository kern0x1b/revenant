#import "../Foundation/check.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>
#import <dlfcn.h>

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

    return revenant_finish();
}
