#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <OpenGLES/ES2/gl.h>
#include <stdlib.h>
#include <string.h>
#include "../../src/Metal/RevenantMetal.h"

// The render-pass path of the CoreVideo texture cache. A render encoder draws into a CoreVideo BGRA texture, and the
// CPU reads the pixel buffer. A copy samples a CoreVideo texture through the clean texture coordinates that
// CVMetalTextureGetCleanTexCoords returns, so a flipped texture comes out in the orientation of its pixel buffer. Each
// comparison is exact and has a negative control that must differ.

static const size_t kSize = 64;
static NSMutableString *LOG;
static NSUInteger FAILURES;

static uint8_t outB(size_t x, size_t y) { return (uint8_t)((x * 2 + y * 9 + 23) % 256); }
static uint8_t outG(size_t x, size_t y) { return (uint8_t)((x * 7 + y * 2 + 11) % 256); }
static uint8_t outR(size_t x, size_t y) { return (uint8_t)((x * 3 + y * 5) % 256); }
// The bytes the copy test writes into its source, in BGRA memory order.
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

static id <MTLRenderPipelineState> pipeline(id <MTLDevice> device, id <MTLLibrary> library, NSString *fragment, NSError **error)
{
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = [library newFunctionWithName:@"cv_quad_vertex"];
    descriptor.fragmentFunction = [library newFunctionWithName:fragment];
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    return [device newRenderPipelineStateWithDescriptor:descriptor error:error];
}

// Draws the full target with a state, from an optional source texture and clean coordinates, and waits for the GPU.
static void draw(id <MTLDevice> device, id <MTLRenderPipelineState> state, id <MTLTexture> target,
    id <MTLTexture> source, id <MTLBuffer> coords)
{
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = target;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    id <MTLCommandBuffer> buffer = [[device newCommandQueue] commandBuffer];
    id <MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:state];
    if (source)
        [encoder setFragmentTexture:source atIndex:0];
    if (coords)
        [encoder setFragmentBuffer:coords offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [encoder endEncoding];
    [buffer commit];
    [buffer waitUntilCompleted];
    RevenantMetalDevice *backport = (RevenantMetalDevice *)device;
    [backport acquire];
    glFinish();
    [backport relinquish];
}

// The coordinates of a texture as the fragment shader takes them: lower left, lower right, upper right, upper left.
static id <MTLBuffer> coordinates(id <MTLDevice> device, const float corners[8])
{
    return [device newBufferWithBytes:corners length:8 * sizeof(float) options:MTLResourceStorageModeShared];
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
        NSError *error = nil;
        NSString *path = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"cvrender.metallib"];
        id <MTLLibrary> library = [device newLibraryWithURL:[NSURL fileURLWithPath:path] error:&error];
        check(@"library loaded from the staged metallib", library != nil);
        [LOG appendFormat:@"functions vertex %@ fill %@ copy %@\n",
            [library newFunctionWithName:@"cv_quad_vertex"] ? @"yes" : @"no",
            [library newFunctionWithName:@"cv_fill"] ? @"yes" : @"no",
            [library newFunctionWithName:@"cv_copy"] ? @"yes" : @"no"];
        error = nil;
        id <MTLRenderPipelineState> fill = library ? pipeline(device, library, @"cv_fill", &error) : nil;
        if (!fill)
            [LOG appendFormat:@"fill pipeline error %@\n", error];
        check(@"fill pipeline created", fill != nil);
        error = nil;
        id <MTLRenderPipelineState> copy = library ? pipeline(device, library, @"cv_copy", &error) : nil;
        if (!copy)
            [LOG appendFormat:@"copy pipeline error %@\n", error];
        check(@"copy pipeline created", copy != nil);

        CVMetalTextureCacheRef cache = NULL;
        CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, device, NULL, &cache);
        check(@"cache created on the Metal device", status == kCVReturnSuccess && cache != NULL);
        if (!fill || !copy || !cache) {
            printf("%s", [LOG UTF8String]);
            return 1;
        }

        uint8_t *got = malloc(kSize * kSize * 4);
        uint8_t *expected = malloc(kSize * kSize * 4);
        int largest = 0;

        // 1. A render pass writes into a CoreVideo BGRA texture, and the CPU reads the pixel buffer.
        CVPixelBufferRef target = newBuffer(kCVPixelFormatType_32BGRA, kSize);
        CVMetalTextureRef targetRef = NULL;
        status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, target, NULL,
            MTLPixelFormatBGRA8Unorm, kSize, kSize, 0, &targetRef);
        id <MTLTexture> targetTexture = CVMetalTextureGetTexture(targetRef);
        check(@"BGRA pixel buffer as a render target", status == kCVReturnSuccess && targetTexture != nil);
        if (targetTexture) {
            draw(device, fill, targetTexture, nil, nil);
            CVPixelBufferLockBaseAddress(target, kCVPixelBufferLock_ReadOnly);
            uint8_t *base = CVPixelBufferGetBaseAddress(target);
            size_t stride = CVPixelBufferGetBytesPerRow(target);
            for (size_t y = 0; y < kSize; y++)
                memcpy(got + y * kSize * 4, base + y * stride, kSize * 4);
            CVPixelBufferUnlockBaseAddress(target, kCVPixelBufferLock_ReadOnly);
            for (size_t y = 0; y < kSize; y++)
                for (size_t x = 0; x < kSize; x++) {
                    uint8_t *e = expected + (y * kSize + x) * 4;
                    e[0] = outB(x, y); e[1] = outG(x, y); e[2] = outR(x, y); e[3] = 255;
                }
            report(@"render pass into the CoreVideo texture, read by the CPU exact", mismatches(got, expected, kSize * kSize * 4, &largest), largest, NO);
            for (size_t y = 0; y < kSize; y++)
                for (size_t x = 0; x < kSize; x++) {
                    uint8_t *e = expected + (y * kSize + x) * 4;
                    e[0] = outR(x, y); e[1] = outG(x, y); e[2] = outB(x, y); e[3] = 255;
                }
            report(@"render pass against red and blue swapped (negative control)", mismatches(got, expected, kSize * kSize * 4, &largest), largest, YES);
        }

        // 2. A copy samples a CoreVideo texture through its clean coordinates into a plain texture.
        CVPixelBufferRef source = newBuffer(kCVPixelFormatType_32BGRA, kSize);
        CVMetalTextureRef sourceRef = NULL;
        status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, source, NULL,
            MTLPixelFormatBGRA8Unorm, kSize, kSize, 0, &sourceRef);
        id <MTLTexture> sourceTexture = CVMetalTextureGetTexture(sourceRef);
        check(@"BGRA pixel buffer as a source texture", status == kCVReturnSuccess && sourceTexture != nil);
        if (sourceTexture) {
            CVPixelBufferLockBaseAddress(source, 0);
            uint8_t *base = CVPixelBufferGetBaseAddress(source);
            size_t stride = CVPixelBufferGetBytesPerRow(source);
            for (size_t y = 0; y < kSize; y++)
                for (size_t x = 0; x < kSize; x++) {
                    uint8_t *p = base + y * stride + x * 4;
                    p[0] = wrB(x, y); p[1] = wrG(x, y); p[2] = wrR(x, y); p[3] = 255;
                }
            CVPixelBufferUnlockBaseAddress(source, 0);

            float clean[8], unflipped[8] = {0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f};
            CVMetalTextureGetCleanTexCoords(sourceRef, &clean[0], &clean[2], &clean[4], &clean[6]);
            [LOG appendFormat:@"INFO flipped %d clean ll(%g,%g) lr(%g,%g) ur(%g,%g) ul(%g,%g)\n", CVMetalTextureIsFlipped(sourceRef),
                clean[0], clean[1], clean[2], clean[3], clean[4], clean[5], clean[6], clean[7]];

            MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:kSize height:kSize mipmapped:NO];
            descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
            id <MTLTexture> copied = [device newTextureWithDescriptor:descriptor];
            draw(device, copy, copied, sourceTexture, coordinates(device, clean));
            for (size_t y = 0; y < kSize; y++)
                for (size_t x = 0; x < kSize; x++) {
                    uint8_t *e = expected + (y * kSize + x) * 4;
                    e[0] = wrB(x, y); e[1] = wrG(x, y); e[2] = wrR(x, y); e[3] = 255;
                }
            [copied getBytes:got bytesPerRow:kSize * 4 fromRegion:MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel:0];
            report(@"copy through the clean coordinates keeps the buffer orientation, exact", mismatches(got, expected, kSize * kSize * 4, &largest), largest, NO);

            // The negative control samples with the unflipped corners, which must turn the copy over.
            id <MTLTexture> unflippedCopy = [device newTextureWithDescriptor:descriptor];
            draw(device, copy, unflippedCopy, sourceTexture, coordinates(device, unflipped));
            [unflippedCopy getBytes:got bytesPerRow:kSize * 4 fromRegion:MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel:0];
            report(@"copy with the unflipped corners (negative control)", mismatches(got, expected, kSize * kSize * 4, &largest), largest, YES);
        }

        // 3. Flush the cache, and the references are released.
        CVMetalTextureCacheFlush(cache, 0);
        check(@"flush after the render and copy", YES);
        if (targetRef)
            CFRelease(targetRef);
        if (sourceRef)
            CFRelease(sourceRef);
        if (target)
            CVPixelBufferRelease(target);
        if (source)
            CVPixelBufferRelease(source);
        CFRelease(cache);
        free(got);
        free(expected);
        [LOG appendFormat:@"CVRENDER-DONE failures %lu\n", (unsigned long)FAILURES];
        printf("%s", [LOG UTF8String]);
        return FAILURES ? 1 : 0;
    }
}
