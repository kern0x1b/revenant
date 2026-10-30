#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdlib.h>
#include <string.h>

static NSMutableString *REVENANT_LOG;
static NSUInteger REVENANT_FAILURES;

static void revenant_check(BOOL ok, NSString *name)
{
    if (!ok)
        REVENANT_FAILURES++;
    [REVENANT_LOG appendFormat:@"%@ %@\n", ok ? @"PASS" : @"FAIL", name];
}

static const uint8_t REVENANT_BLUE[4] = {0, 0, 255, 255};
static const uint8_t REVENANT_ORANGE[4] = {255, 128, 64, 255};
static const uint8_t REVENANT_CLEAR[4] = {0, 0, 0, 0};

static id<MTLTexture> revenant_grid_texture(id<MTLDevice> device)
{
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:4 height:4 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    uint8_t blue[4 * 4 * 4];
    for (NSUInteger i = 0; i < sizeof blue; i += 4)
        memcpy(blue + i, REVENANT_BLUE, 4);
    [texture replaceRegion:MTLRegionMake2D(0, 0, 4, 4) mipmapLevel:0 withBytes:blue bytesPerRow:16];
    return texture;
}

static void revenant_expect(uint8_t *expected, const uint8_t inside[4], const uint8_t outside[4], BOOL (^written)(NSUInteger x, NSUInteger y))
{
    for (NSUInteger y = 0; y < 4; y++)
        for (NSUInteger x = 0; x < 4; x++)
            memcpy(expected + (y * 4 + x) * 4, written(x, y) ? inside : outside, 4);
}

static NSUInteger revenant_mismatches(id<MTLTexture> texture, const uint8_t *expected)
{
    uint8_t bytes[4 * 4 * 4];
    [texture getBytes:bytes bytesPerRow:16 fromRegion:MTLRegionMake2D(0, 0, 4, 4) mipmapLevel:0];
    NSUInteger bad = 0;
    for (NSUInteger i = 0; i < sizeof bytes; i++)
        if (abs((int)bytes[i] - (int)expected[i]) > 1)
            bad++;
    return bad;
}

static id<MTLComputePipelineState> revenant_pipeline(id<MTLDevice> device, NSString *name)
{
    NSError *error = nil;
    id<MTLLibrary> library = [device newLibraryWithURL:[NSURL fileURLWithPath:@"/var/revenant/dispatch/dispatch.metallib"] error:&error];
    id<MTLFunction> function = [library newFunctionWithName:name];
    if (!function) {
        [REVENANT_LOG appendFormat:@"INFO no function %@ in the library: %@\n", name, error];
        return nil;
    }
    id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];
    if (!pipeline)
        [REVENANT_LOG appendFormat:@"INFO %@ did not link: %@\n", name, error];
    return pipeline;
}

static void revenant_dispatch(id<MTLDevice> device, id<MTLComputePipelineState> pipeline, id<MTLTexture> texture, MTLSize groups, MTLSize threads)
{
    id<MTLCommandBuffer> buffer = [[device newCommandQueue] commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
    [encoder setComputePipelineState:pipeline];
    [encoder setTexture:texture atIndex:0];
    [encoder dispatchThreadgroups:groups threadsPerThreadgroup:threads];
    [encoder endEncoding];
    [buffer commit];
    [buffer waitUntilCompleted];
}

static void revenant_dispatch_checks(id<MTLDevice> device)
{
    uint8_t expected[4 * 4 * 4];
    MTLSize one = MTLSizeMake(1, 1, 1);

    id<MTLComputePipelineState> ok = revenant_pipeline(device, @"k_ok");
    revenant_check(ok != nil, @"the translated kernel k_ok links as a compute pipeline");
    if (ok) {
        id<MTLTexture> texture = revenant_grid_texture(device);
        revenant_dispatch(device, ok, texture, MTLSizeMake(4, 4, 1), one);
        revenant_expect(expected, REVENANT_ORANGE, REVENANT_BLUE, ^BOOL(NSUInteger x, NSUInteger y) { return x == 0; });
        revenant_check(revenant_mismatches(texture, expected) == 0, @"k_ok over a 4x4 grid writes column 0 and discards the rest");

        texture = revenant_grid_texture(device);
        revenant_dispatch(device, ok, texture, MTLSizeMake(2, 2, 1), one);
        revenant_expect(expected, REVENANT_ORANGE, REVENANT_BLUE, ^BOOL(NSUInteger x, NSUInteger y) { return x == 0 && y < 2; });
        revenant_check(revenant_mismatches(texture, expected) == 0, @"a 2x2 grid writes only its own texels");

        texture = revenant_grid_texture(device);
        revenant_dispatch(device, ok, texture, MTLSizeMake(2, 2, 1), MTLSizeMake(2, 2, 1));
        revenant_expect(expected, REVENANT_ORANGE, REVENANT_BLUE, ^BOOL(NSUInteger x, NSUInteger y) { return x == 0; });
        revenant_check(revenant_mismatches(texture, expected) == 0, @"two groups of two threads cover the same 4x4 grid");
    }

    id<MTLComputePipelineState> local = revenant_pipeline(device, @"k_local");
    revenant_check(local != nil, @"the translated kernel k_local, with an alloca local, links as a compute pipeline");
    if (local) {
        id<MTLTexture> texture = revenant_grid_texture(device);
        revenant_dispatch(device, local, texture, MTLSizeMake(4, 4, 1), one);
        revenant_expect(expected, REVENANT_ORANGE, REVENANT_CLEAR, ^BOOL(NSUInteger x, NSUInteger y) { return x == 0; });
        revenant_check(revenant_mismatches(texture, expected) == 0, @"k_local writes every thread, the stored local reaching the join");
    }

    id<MTLComputePipelineState> ult = revenant_pipeline(device, @"k_ult");
    revenant_check(ult != nil, @"the translated kernel k_ult links as a compute pipeline");
    if (ult) {
        id<MTLTexture> texture = revenant_grid_texture(device);
        revenant_dispatch(device, ult, texture, MTLSizeMake(4, 4, 1), one);
        revenant_expect(expected, REVENANT_ORANGE, REVENANT_BLUE, ^BOOL(NSUInteger x, NSUInteger y) { return x < y; });
        revenant_check(revenant_mismatches(texture, expected) == 0, @"k_ult writes where x is below y, as an unsigned compare");
    }

    id<MTLComputePipelineState> cube = revenant_pipeline(device, @"k_cube");
    if (cube) {
        id<MTLTexture> texture = revenant_grid_texture(device);
        revenant_dispatch(device, cube, texture, MTLSizeMake(4, 4, 1), one);
        revenant_expect(expected, REVENANT_BLUE, REVENANT_BLUE, ^BOOL(NSUInteger x, NSUInteger y) { return YES; });
        revenant_check(revenant_mismatches(texture, expected) == 0, @"k_cube, which samples a cube, is refused and leaves its texture as it was");
    }
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        REVENANT_LOG = [NSMutableString string];
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        revenant_check(device != nil, @"MTLCreateSystemDefaultDevice returns a device");
        if (device)
            revenant_dispatch_checks(device);
        [REVENANT_LOG appendFormat:@"REVENANT-DONE failures %lu\n", (unsigned long)REVENANT_FAILURES];
        [REVENANT_LOG writeToFile:@"/var/revenant/dispatch-probe.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("%s", [REVENANT_LOG UTF8String]);
        return REVENANT_FAILURES ? 1 : 0;
    }
}
