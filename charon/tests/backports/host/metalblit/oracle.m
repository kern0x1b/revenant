#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static NSMutableArray<NSString *> *names;
static NSMutableArray<NSData *> *blobs;
static NSMutableArray<NSString *> *lines;

static void record(NSString *name, const void *bytes, NSUInteger length)
{
    const uint8_t *source = bytes;
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger index = 0; index < length; index++)
        [hex appendFormat:@"%02x", source[index]];
    [names addObject:name];
    [blobs addObject:[NSData dataWithBytes:bytes length:length]];
    [lines addObject:[NSString stringWithFormat:@"static const char *const metalblit_%@ = \"%@\";\n", name, hex]];
}

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;

static void run(void (^encode)(id<MTLBlitCommandEncoder>))
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
    encode(blit);
    [blit endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    if (commandBuffer.error)
        [NSException raise:NSInternalInconsistencyException format:@"command buffer: %@", commandBuffer.error];
}

static NSData *bytesOf(id<MTLBuffer> buffer)
{
    return [NSData dataWithBytes:buffer.contents length:buffer.length];
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        device = MTLCreateSystemDefaultDevice();
        queue = [device newCommandQueue];
        names = [NSMutableArray array];
        blobs = [NSMutableArray array];
        lines = [NSMutableArray array];

        {
            id<MTLBuffer> buffer = [device newBufferWithLength:64 options:0];
            memset(buffer.contents, 0, 64);
            run(^(id<MTLBlitCommandEncoder> blit) {
                [blit fillBuffer:buffer range:NSMakeRange(8, 16) value:0xAB];
            });
            record(@"fill", bytesOf(buffer).bytes, 64);
        }

        {
            id<MTLBuffer> source = [device newBufferWithLength:64 options:0];
            id<MTLBuffer> destination = [device newBufferWithLength:64 options:0];
            uint8_t pattern[64];
            for (int index = 0; index < 64; index++)
                pattern[index] = (uint8_t)index;
            memcpy(source.contents, pattern, 64);
            memset(destination.contents, 0, 64);
            run(^(id<MTLBlitCommandEncoder> blit) {
                [blit copyFromBuffer:source sourceOffset:8 toBuffer:destination destinationOffset:40 size:16];
            });
            record(@"buffer_copy", bytesOf(destination).bytes, 64);
        }

        {
            id<MTLBuffer> buffer = [device newBufferWithLength:64 options:0];
            uint8_t pattern[64];
            for (int index = 0; index < 64; index++)
                pattern[index] = (uint8_t)index;
            memcpy(buffer.contents, pattern, 64);
            run(^(id<MTLBlitCommandEncoder> blit) {
                [blit copyFromBuffer:buffer sourceOffset:0 toBuffer:buffer destinationOffset:8 size:32];
            });
            record(@"buffer_overlap", bytesOf(buffer).bytes, 64);
            uint8_t moved[64];
            memcpy(moved, pattern, 64);
            memmove(moved + 8, moved, 32);
            record(@"buffer_overlap_memmove", moved, 64);
        }

        {
            MTLTextureDescriptor *descriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:8 height:8 mipmapped:NO];
            id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
            uint8_t pattern[8 * 8 * 4];
            for (int index = 0; index < 8 * 8 * 4; index++)
                pattern[index] = (uint8_t)(index & 0xff);
            [texture replaceRegion:MTLRegionMake2D(0, 0, 8, 8) mipmapLevel:0 withBytes:pattern bytesPerRow:32];
            id<MTLBuffer> buffer = [device newBufferWithLength:128 options:0];
            memset(buffer.contents, 0, 128);
            run(^(id<MTLBlitCommandEncoder> blit) {
                [blit copyFromTexture:texture sourceSlice:0 sourceLevel:0
                          sourceOrigin:MTLOriginMake(2, 3, 0) sourceSize:MTLSizeMake(4, 5, 1)
                               toBuffer:buffer destinationOffset:16
                     destinationBytesPerRow:64 destinationBytesPerImage:0];
            });
            record(@"region_readback", bytesOf(buffer).bytes, 128);
        }

        {
            MTLTextureDescriptor *descriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:2 height:2 mipmapped:NO];
            id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
            uint8_t pattern[16];
            for (int index = 0; index < 16; index++)
                pattern[index] = (uint8_t)(index + 1);
            [texture replaceRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0 withBytes:pattern bytesPerRow:8];
            uint8_t got[16] = {0};
            [texture getBytes:got bytesPerRow:8 fromRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0];
            record(@"bgra_written", pattern, 16);
            record(@"bgra_readback", got, 16);
        }

        NSUInteger mipLevels = 0;
        NSMutableString *geometry = [NSMutableString string];
        {
            MTLTextureDescriptor *descriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:16 height:8 mipmapped:YES];
            id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
            mipLevels = texture.mipmapLevelCount;
            [geometry appendFormat:@"static const int metalblit_mip_levels = %lu;\n", (unsigned long)mipLevels];
            for (NSUInteger level = 0; level < mipLevels; level++)
                [geometry appendFormat:@"static const int metalblit_level%lu_width = %lu;\n"
                                        "static const int metalblit_level%lu_height = %lu;\n"
                                        "static const int metalblit_level%lu_bytes_per_row = %lu;\n",
                                        (unsigned long)level, (unsigned long)(texture.width >> level),
                                        (unsigned long)level, (unsigned long)(texture.height >> level),
                                        (unsigned long)level, (unsigned long)((texture.width >> level) * 4)];
        }

        BOOL boxAverage = NO;
        BOOL roundsDown = NO;
        NSUInteger smallest = 0;
        {
            MTLTextureDescriptor *descriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:4 height:4 mipmapped:YES];
            id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
            uint8_t pattern[4 * 4 * 4];
            for (int index = 0; index < 4 * 4 * 4; index++)
                pattern[index] = (uint8_t)((index & 0x0f) * 16);
            [texture replaceRegion:MTLRegionMake2D(0, 0, 4, 4) mipmapLevel:0 withBytes:pattern bytesPerRow:16];
            run(^(id<MTLBlitCommandEncoder> blit) {
                [blit generateMipmapsForTexture:texture];
            });
            uint8_t level1[2 * 2 * 4] = {0};
            [texture getBytes:level1 bytesPerRow:8 fromRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:1];
            record(@"mip_level0", pattern, sizeof(pattern));
            record(@"mip_level1", level1, sizeof(level1));
            boxAverage = level1[0] == (uint8_t)((0x00 + 0x40 + 0x00 + 0x40) / 4)
                      && level1[1] == (uint8_t)((0x10 + 0x50 + 0x10 + 0x50) / 4)
                      && level1[2] == (uint8_t)((0x20 + 0x60 + 0x20 + 0x60) / 4)
                      && level1[3] == (uint8_t)((0x30 + 0x70 + 0x30 + 0x70) / 4);
        }

        {
            MTLTextureDescriptor *descriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:2 height:2 mipmapped:YES];
            id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
            uint8_t pattern[4] = {1, 2, 4, 8};
            [texture replaceRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0 withBytes:pattern bytesPerRow:2];
            run(^(id<MTLBlitCommandEncoder> blit) {
                [blit generateMipmapsForTexture:texture];
            });
            uint8_t level1[1] = {0};
            [texture getBytes:level1 bytesPerRow:1 fromRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:1];
            record(@"mip_rounding", level1, 1);
            roundsDown = level1[0] == 3;
        }

        {
            MTLTextureDescriptor *descriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:16 height:8 mipmapped:YES];
            id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
            smallest = texture.mipmapLevelCount - 1;
            uint8_t level[1] = {0};
            BOOL readable = YES;
            @try {
                [texture getBytes:level bytesPerRow:1 fromRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:smallest];
            } @catch (NSException *exception) {
                readable = NO;
            }
            record(@"mip_smallest_level", level, 1);
            [lines addObject:[NSString stringWithFormat:
                               @"static const int metalblit_smallest_level_readable = %d;\n", readable ? 1 : 0]];
        }

        NSMutableString *out = [NSMutableString string];
        [out appendString:@"// metalblit-expectations.h — what macOS Metal answers, read off a real device on this host by\n"
                           "// tests/backports/host/metalblit/oracle.m. tests/backports/device/metalblit.m holds the port to it.\n"
                           "// Nothing here is the port's answer; it is Apple's, measured.\n"
                           @"#ifndef METALBLIT_EXPECTATIONS_H\n#define METALBLIT_EXPECTATIONS_H\n\n"];
        for (NSString *line in lines)
            [out appendString:line];
        [out appendString:geometry];
        [out appendFormat:@"static const int metalblit_mip_is_a_box_average = %d;\n", boxAverage ? 1 : 0];
        [out appendFormat:@"static const int metalblit_mip_rounds_down = %d;\n", roundsDown ? 1 : 0];
        [out appendFormat:@"static const int metalblit_smallest_level = %lu;\n", (unsigned long)smallest];
        [out appendString:@"\n#endif\n"];
        [out writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("wrote %s\n", argv[1]);
    }
    return 0;
}
