#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <OpenGLES/ES2/gl.h>
#include <stdlib.h>
#include <string.h>
#include "../../src/Metal/RevenantMetal.h"

// The backport's CVMetalTextureCache on the Metal device: NV12 planes and a BGRA buffer bound as MTLTextures, read back
// with getBytes, written with replaceRegion and read by the CPU from the pixel buffer. Each comparison is exact and has
// a negative control that must differ, or a refusal that must hold.

static const size_t kSize = 64;
static NSMutableString *LOG;
static NSUInteger FAILURES;

static uint8_t yAt(size_t x, size_t y) { return (uint8_t)(x * 7 + y * 13); }
static uint8_t cbAt(size_t x, size_t y) { return (uint8_t)(x * 5 + y * 3 + 9); }
static uint8_t crAt(size_t x, size_t y) { return (uint8_t)(x * 11 + y * 17 + 40); }
static uint8_t outB(size_t x, size_t y) { return (uint8_t)((x * 2 + y * 9 + 23) % 256); }
static uint8_t outG(size_t x, size_t y) { return (uint8_t)((x * 7 + y * 2 + 11) % 256); }
static uint8_t outR(size_t x, size_t y) { return (uint8_t)((x * 3 + y * 5) % 256); }
// The bytes the replaceRegion test writes, in BGRA memory order.
static uint8_t wrB(size_t x, size_t y) { return (uint8_t)(x * 5 + y * 7 + 3); }
static uint8_t wrG(size_t x, size_t y) { return (uint8_t)(x * 2 + y * 11 + 9); }
static uint8_t wrR(size_t x, size_t y) { return (uint8_t)(x * 13 + y * 4 + 21); }

static void check(NSString *name, BOOL ok)
{
    if (!ok)
        FAILURES++;
    [LOG appendFormat:@"%@ %@\n", ok ? @"PASS" : @"FAIL", name];
}

// Counts the bytes of got that differ from expected, and returns the largest difference.
static NSUInteger mismatches(const uint8_t *got, const uint8_t *expected, size_t count, int *largest)
{
    NSUInteger bad = 0;
    *largest = 0;
    for (size_t i = 0; i < count; i++) {
        int delta = abs((int)got[i] - (int)expected[i]);
        if (delta > *largest)
            *largest = delta;
        if (delta != 0)
            bad++;
    }
    return bad;
}

static void report(NSString *name, NSUInteger bad, int largest, BOOL negativeControl)
{
    BOOL passed = negativeControl ? bad > 0 : bad == 0;
    if (!passed)
        FAILURES++;
    [LOG appendFormat:@"%@ %@ bad=%lu largest=%d%s\n", passed ? @"PASS" : @"FAIL", name, (unsigned long)bad, largest,
        negativeControl ? " (negative control: must differ)" : ""];
}

static CVPixelBufferRef newBuffer(OSType format, size_t size)
{
    NSDictionary *attributes = @{ (__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    CVPixelBufferRef buffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size, size, format,
        (__bridge CFDictionaryRef)attributes, &buffer);
    if (status != kCVReturnSuccess) {
        [LOG appendFormat:@"CVPixelBufferCreate %u status %d\n", (unsigned)format, (int)status];
        return NULL;
    }
    return buffer;
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        LOG = [NSMutableString string];
        id <MTLDevice> device = MTLCreateSystemDefaultDevice();
        [LOG appendFormat:@"device %@\n", NSStringFromClass([device class])];
        if (!device) {
            printf("FAIL no Metal device\n");
            return 1;
        }

        CVMetalTextureCacheRef cache = NULL;
        CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, device, NULL, &cache);
        check(@"cache created on the Metal device", status == kCVReturnSuccess && cache != NULL);
        CVMetalTextureCacheRef none = NULL;
        check(@"cache refused for a nil device (negative control)", CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, nil, NULL, &none) != kCVReturnSuccess && none == NULL);
        check(@"cache and texture type ids are set", CVMetalTextureCacheGetTypeID() != 0 && CVMetalTextureGetTypeID() != 0);

        uint8_t *got = malloc(kSize * kSize * 4);
        uint8_t *expected = malloc(kSize * kSize * 4);
        int largest = 0;

        // NV12: the luma plane as R8Unorm and the chroma plane as RG8Unorm.
        CVPixelBufferRef nv12 = newBuffer(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kSize);
        if (nv12 && cache) {
            CVPixelBufferLockBaseAddress(nv12, 0);
            uint8_t *luma = CVPixelBufferGetBaseAddressOfPlane(nv12, 0);
            size_t lumaStride = CVPixelBufferGetBytesPerRowOfPlane(nv12, 0);
            for (size_t y = 0; y < kSize; y++)
                for (size_t x = 0; x < kSize; x++)
                    luma[y * lumaStride + x] = yAt(x, y);
            uint8_t *chroma = CVPixelBufferGetBaseAddressOfPlane(nv12, 1);
            size_t chromaStride = CVPixelBufferGetBytesPerRowOfPlane(nv12, 1);
            for (size_t y = 0; y < kSize / 2; y++)
                for (size_t x = 0; x < kSize / 2; x++) {
                    chroma[y * chromaStride + 2 * x] = cbAt(x, y);
                    chroma[y * chromaStride + 2 * x + 1] = crAt(x, y);
                }
            CVPixelBufferUnlockBaseAddress(nv12, 0);

            CVMetalTextureRef lumaRef = NULL;
            status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, nv12, NULL, MTLPixelFormatR8Unorm, kSize, kSize, 0, &lumaRef);
            id <MTLTexture> lumaTexture = CVMetalTextureGetTexture(lumaRef);
            check(@"luma plane as R8Unorm", status == kCVReturnSuccess && lumaTexture != nil && lumaTexture.pixelFormat == MTLPixelFormatR8Unorm && lumaTexture.width == kSize && lumaTexture.height == kSize);
            if (lumaTexture) {
                [lumaTexture getBytes:got bytesPerRow:kSize fromRegion:MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel:0];
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++)
                        expected[y * kSize + x] = yAt(x, y);
                report(@"luma plane read back exact", mismatches(got, expected, kSize * kSize, &largest), largest, NO);
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++)
                        expected[y * kSize + x] = cbAt(x / 2, y / 2);
                report(@"luma plane against chroma (negative control)", mismatches(got, expected, kSize * kSize, &largest), largest, YES);
            }

            CVMetalTextureRef chromaRef = NULL;
            status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, nv12, NULL, MTLPixelFormatRG8Unorm, kSize / 2, kSize / 2, 1, &chromaRef);
            id <MTLTexture> chromaTexture = CVMetalTextureGetTexture(chromaRef);
            check(@"chroma plane as RG8Unorm", status == kCVReturnSuccess && chromaTexture != nil && chromaTexture.pixelFormat == MTLPixelFormatRG8Unorm && chromaTexture.width == kSize / 2 && chromaTexture.height == kSize / 2);
            if (chromaTexture) {
                [chromaTexture getBytes:got bytesPerRow:kSize fromRegion:MTLRegionMake2D(0, 0, kSize / 2, kSize / 2) mipmapLevel:0];
                for (size_t y = 0; y < kSize / 2; y++)
                    for (size_t x = 0; x < kSize / 2; x++) {
                        expected[y * kSize + 2 * x] = cbAt(x, y);
                        expected[y * kSize + 2 * x + 1] = crAt(x, y);
                    }
                report(@"chroma plane read back exact, red and green", mismatches(got, expected, (kSize / 2) * kSize, &largest), largest, NO);
                for (size_t y = 0; y < kSize / 2; y++)
                    for (size_t x = 0; x < kSize / 2; x++) {
                        expected[y * kSize + 2 * x] = cbAt(x, y);
                        expected[y * kSize + 2 * x + 1] = cbAt(x, y);
                    }
                report(@"chroma green against red (negative control)", mismatches(got, expected, (kSize / 2) * kSize, &largest), largest, YES);
            }
            if (lumaRef)
                CFRelease(lumaRef);
            if (chromaRef)
                CFRelease(chromaRef);
            CVPixelBufferRelease(nv12);
        }

        // BGRA: the CPU writes the buffer, the texture reads it, and replaceRegion writes it back for the CPU to read.
        CVPixelBufferRef bgra = newBuffer(kCVPixelFormatType_32BGRA, kSize);
        if (bgra && cache) {
            CVPixelBufferLockBaseAddress(bgra, 0);
            uint8_t *base = CVPixelBufferGetBaseAddress(bgra);
            size_t stride = CVPixelBufferGetBytesPerRow(bgra);
            for (size_t y = 0; y < kSize; y++)
                for (size_t x = 0; x < kSize; x++) {
                    uint8_t *p = base + y * stride + x * 4;
                    p[0] = outB(x, y); p[1] = outG(x, y); p[2] = outR(x, y); p[3] = 255;
                }
            CVPixelBufferUnlockBaseAddress(bgra, 0);

            CVMetalTextureRef bgraRef = NULL;
            status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, bgra, NULL, MTLPixelFormatBGRA8Unorm, kSize, kSize, 0, &bgraRef);
            id <MTLTexture> bgraTexture = CVMetalTextureGetTexture(bgraRef);
            check(@"BGRA buffer as BGRA8Unorm", status == kCVReturnSuccess && bgraTexture != nil && bgraTexture.pixelFormat == MTLPixelFormatBGRA8Unorm);
            if (bgraTexture) {
                [bgraTexture getBytes:got bytesPerRow:kSize * 4 fromRegion:MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel:0];
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *e = expected + (y * kSize + x) * 4;
                        e[0] = outB(x, y); e[1] = outG(x, y); e[2] = outR(x, y); e[3] = 255;
                    }
                report(@"BGRA texture read back exact", mismatches(got, expected, kSize * kSize * 4, &largest), largest, NO);
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *e = expected + (y * kSize + x) * 4;
                        e[0] = outR(x, y); e[1] = outG(x, y); e[2] = outB(x, y); e[3] = 255;
                    }
                report(@"BGRA texture against red and blue swapped (negative control)", mismatches(got, expected, kSize * kSize * 4, &largest), largest, YES);

                uint8_t *written = malloc(kSize * kSize * 4);
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *w = written + (y * kSize + x) * 4;
                        w[0] = wrB(x, y); w[1] = wrG(x, y); w[2] = wrR(x, y); w[3] = 255;
                    }
                [bgraTexture replaceRegion:MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel:0 withBytes:written bytesPerRow:kSize * 4];
                RevenantMetalDevice *backport = (RevenantMetalDevice *)device;
                [backport acquire];
                glFinish();
                [backport relinquish];

                CVPixelBufferLockBaseAddress(bgra, kCVPixelBufferLock_ReadOnly);
                base = CVPixelBufferGetBaseAddress(bgra);
                stride = CVPixelBufferGetBytesPerRow(bgra);
                for (size_t y = 0; y < kSize; y++)
                    memcpy(got + y * kSize * 4, base + y * stride, kSize * 4);
                CVPixelBufferUnlockBaseAddress(bgra, kCVPixelBufferLock_ReadOnly);
                report(@"replaceRegion seen by the CPU in the pixel buffer, exact", mismatches(got, written, kSize * kSize * 4, &largest), largest, NO);
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *w = written + (y * kSize + x) * 4;
                        uint8_t t = w[0];
                        w[0] = w[2];
                        w[2] = t;
                    }
                report(@"replaceRegion against red and blue swapped (negative control)", mismatches(got, written, kSize * kSize * 4, &largest), largest, YES);
                free(written);

                [LOG appendFormat:@"INFO flipped %d\n", CVMetalTextureIsFlipped(bgraRef)];
                float ll[2], lr[2], ur[2], ul[2];
                CVMetalTextureGetCleanTexCoords(bgraRef, ll, lr, ur, ul);
                [LOG appendFormat:@"INFO clean ll(%g,%g) lr(%g,%g) ur(%g,%g) ul(%g,%g)\n", ll[0], ll[1], lr[0], lr[1], ur[0], ur[1], ul[0], ul[1]];
            }

            CVMetalTextureRef refused = NULL;
            status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, bgra, NULL, MTLPixelFormatR16Unorm, kSize, kSize, 0, &refused);
            check(@"16-bit format refused (negative control)", status != kCVReturnSuccess && refused == NULL);

            CVMetalTextureCacheFlush(cache, 0);
            check(@"flush after use", YES);
            if (bgraRef)
                CFRelease(bgraRef);
            CVPixelBufferRelease(bgra);
        }

        // IOSurface-backed texture through the device, the path the CoreVideo texture now shares with: the CPU writes
        // the surface, the texture reads it back exactly.
        NSDictionary *surfaceProperties = @{ (__bridge NSString *)kIOSurfaceWidth: @(kSize), (__bridge NSString *)kIOSurfaceHeight: @(kSize),
                                             (__bridge NSString *)kIOSurfaceBytesPerElement: @4, (__bridge NSString *)kIOSurfacePixelFormat: @(0x42475241) };
        IOSurfaceRef surface = IOSurfaceCreate((__bridge CFDictionaryRef)surfaceProperties);
        check(@"IOSurface created", surface != NULL);
        if (surface) {
            IOSurfaceLock(surface, 0, NULL);
            uint8_t *surfaceBase = IOSurfaceGetBaseAddress(surface);
            size_t surfaceStride = IOSurfaceGetBytesPerRow(surface);
            for (size_t y = 0; y < kSize; y++)
                for (size_t x = 0; x < kSize; x++) {
                    uint8_t *p = surfaceBase + y * surfaceStride + x * 4;
                    p[0] = outB(x, y); p[1] = outG(x, y); p[2] = outR(x, y); p[3] = 255;
                }
            IOSurfaceUnlock(surface, 0, NULL);
            MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:kSize height:kSize mipmapped:NO];
            id <MTLTexture> surfaceTexture = [device newTextureWithDescriptor:descriptor iosurface:surface plane:0];
            check(@"IOSurface texture created", surfaceTexture != nil);
            if (surfaceTexture) {
                [surfaceTexture getBytes:got bytesPerRow:kSize * 4 fromRegion:MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel:0];
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *e = expected + (y * kSize + x) * 4;
                        e[0] = outB(x, y); e[1] = outG(x, y); e[2] = outR(x, y); e[3] = 255;
                    }
                report(@"IOSurface texture read back exact", mismatches(got, expected, kSize * kSize * 4, &largest), largest, NO);
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *e = expected + (y * kSize + x) * 4;
                        e[0] = outR(x, y); e[1] = outG(x, y); e[2] = outB(x, y); e[3] = 255;
                    }
                report(@"IOSurface texture against red and blue swapped (negative control)", mismatches(got, expected, kSize * kSize * 4, &largest), largest, YES);
            }
            CFRelease(surface);
        }

        if (cache)
            CFRelease(cache);
        free(got);
        free(expected);
        [LOG appendFormat:@"CVMETAL-DONE failures %lu\n", (unsigned long)FAILURES];
        printf("%s", [LOG UTF8String]);
        return FAILURES ? 1 : 0;
    }
}
