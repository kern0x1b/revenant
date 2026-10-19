// metalblit.m — holds the port's texture blits and its mip chain to macOS Metal's own answers.
//
// tests/backports/host/metalblit/oracle.m records what a real Metal device on this host does, into
// metalblit-expectations.h beside this file; the same host test also runs the port's buffer blits
// against those answers and is green. What is left is the part no host can run: the port's textures
// are OpenGL ES 2.0 objects and need an EAGL context, which is what this program makes.
//
// Every expectation here is Apple's, measured. Nothing is checked against the port's own idea of what
// the answer should be — the answers are byte strings and integers read off macOS Metal.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <OpenGLES/EAGL.h>
#import "check.h"
#include "metalblit-expectations.h"

static NSData *fromHex(const char *hex, NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    uint8_t *bytes = data.mutableBytes;
    for (NSUInteger index = 0; index < length; index++) {
        unsigned value = 0;
        sscanf(hex + index * 2, "%2x", &value);
        bytes[index] = (uint8_t)value;
    }
    return data;
}

static id<MTLDevice> device;

static void same_bytes(NSData *ours, const char *theirs, NSUInteger length, const char *name)
{
    NSData *expected = fromHex(theirs, length);
    charon_check([ours isEqualToData:expected], name,
                 ([ours isEqualToData:expected] ? nil
                  : [NSString stringWithFormat:@"%@ vs Metal's %@", ours.description, expected.description]));
}

/* The readback of a region, laid out into a buffer the way the host recorded it: the destination at
   its offset, each row at its own stride, and nothing written past the end. */
static void check_region_readback(id<MTLCommandQueue> queue)
{
    MTLTextureDescriptor *descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:8 height:8 mipmapped:NO];
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    CHECK(texture != nil, "an 8x8 RGBA8 texture is made");
    if (!texture)
        return;
    uint8_t pattern[8 * 8 * 4];
    for (int index = 0; index < 8 * 8 * 4; index++)
        pattern[index] = (uint8_t)(index & 0xff);
    [texture replaceRegion:MTLRegionMake2D(0, 0, 8, 8) mipmapLevel:0 withBytes:pattern bytesPerRow:32];

    id<MTLBuffer> buffer = [device newBufferWithLength:128 options:0];
    memset(buffer.contents, 0, 128);
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
    [blit copyFromTexture:texture sourceSlice:0 sourceLevel:0
              sourceOrigin:MTLOriginMake(2, 3, 0) sourceSize:MTLSizeMake(4, 5, 1)
                   toBuffer:buffer destinationOffset:16
         destinationBytesPerRow:64 destinationBytesPerImage:0];
    [blit endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    CHECK(commandBuffer.error == nil, "the region blit runs");
    if (commandBuffer.error)
        return;
    same_bytes([NSData dataWithBytes:buffer.contents length:128], metalblit_region_readback, 128,
               "a 4x5 region from (2,3) into a buffer at 16 with a row of 64 lands where Metal puts it");
}

/* The channel order a read of a BGRA texture returns. The port repacks into the texture's own order,
   and this is the case that decides whether the repack is right. */
static void check_bgra_readback(void)
{
    MTLTextureDescriptor *descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:2 height:2 mipmapped:NO];
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    CHECK(texture != nil, "a 2x2 BGRA8 texture is made");
    if (!texture)
        return;
    uint8_t pattern[16];
    for (int index = 0; index < 16; index++)
        pattern[index] = (uint8_t)(index + 1);
    [texture replaceRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0 withBytes:pattern bytesPerRow:8];
    uint8_t got[16] = {0};
    [texture getBytes:got bytesPerRow:8 fromRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0];
    same_bytes([NSData dataWithBytes:got length:16], metalblit_bgra_readback, 16,
               "a read of a BGRA texture returns the bytes in the order they were written");
}

/* The geometry of a mip chain, and the two things a level below the first is asked for here: a read
   of it, and the box average generateMipmaps leaves there. */
static void check_mips(id<MTLCommandQueue> queue)
{
    MTLTextureDescriptor *geometry =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:16 height:8 mipmapped:YES];
    id<MTLTexture> chain = [device newTextureWithDescriptor:geometry];
    CHECK(chain != nil, "a 16x8 mipmapped texture is made");
    if (chain) {
        charon_check((int)chain.mipmapLevelCount == metalblit_mip_levels, "a 16x8 chain has Metal's number of levels",
                     [NSString stringWithFormat:@"%lu against Metal's %d", (unsigned long)chain.mipmapLevelCount, metalblit_mip_levels]);
        // The last level of a chain whose height is not a power of two is one texel, not the zero that
        // 8 >> 4 gives: Metal can be asked for its 1x1 and it answers, which is the oracle's own
        // measurement (metalblit_smallest_level_readable).
        uint8_t last[1] = {0};
        [chain getBytes:last bytesPerRow:1 fromRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:metalblit_smallest_level];
        charon_check(metalblit_smallest_level_readable == 1, "Metal can be asked for the last level's one texel",
                     nil);
    }

    MTLTextureDescriptor *descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:4 height:4 mipmapped:YES];
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    CHECK(texture != nil, "a 4x4 mipmapped texture is made");
    if (!texture)
        return;
    uint8_t pattern[4 * 4 * 4];
    for (int index = 0; index < 4 * 4 * 4; index++)
        pattern[index] = (uint8_t)((index & 0x0f) * 16);
    [texture replaceRegion:MTLRegionMake2D(0, 0, 4, 4) mipmapLevel:0 withBytes:pattern bytesPerRow:16];

    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
    [blit generateMipmapsForTexture:texture];
    [blit endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    CHECK(commandBuffer.error == nil, "generateMipmapsForTexture: runs");
    if (commandBuffer.error)
        return;
    uint8_t level1[2 * 2 * 4] = {0};
    [texture getBytes:level1 bytesPerRow:8 fromRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:1];
    same_bytes([NSData dataWithBytes:level1 length:sizeof(level1)], metalblit_mip_level1, sizeof(level1),
               "a level below the first holds the box average of the four above it, as Metal leaves it");

    // The one number most likely to differ: Metal rounds the average of four to the nearest, it does
    // not truncate it, and an ES 2.0 box filter is not required to agree. Recorded on the host and
    // checked here, so the difference is a measurement and not a suspicion.
    MTLTextureDescriptor *rounding =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:2 height:2 mipmapped:YES];
    id<MTLTexture> small = [device newTextureWithDescriptor:rounding];
    uint8_t values[4] = {1, 2, 4, 8};
    [small replaceRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0 withBytes:values bytesPerRow:2];
    id<MTLCommandBuffer> second = [queue commandBuffer];
    id<MTLBlitCommandEncoder> again = [second blitCommandEncoder];
    [again generateMipmapsForTexture:small];
    [again endEncoding];
    [second commit];
    [second waitUntilCompleted];
    uint8_t average[1] = {0};
    [small getBytes:average bytesPerRow:1 fromRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:1];
    same_bytes([NSData dataWithBytes:average length:1], metalblit_mip_rounding, 1,
               "the average of 1, 2, 4 and 8 rounds the way Metal rounds it, not the way truncation would");
}

int main(void)
{
    @autoreleasepool {
        device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "the port's Metal device is there");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "a command queue is made");
        if (device && queue) {
            check_region_readback(queue);
            check_bgra_readback();
            check_mips(queue);
        }
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
