#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <mach/mach_time.h>
#import "check.h"
#import "RevenantMetal.h"

static NSUInteger revenant_align(NSUInteger size, NSUInteger alignment)
{
    return (size + alignment - 1) / alignment * alignment;
}

static BOOL revenant_power_of_two(NSUInteger value)
{
    return value != 0 && (value & (value - 1)) == 0;
}

static double revenant_microseconds(uint64_t ticks)
{
    static mach_timebase_info_data_t base;
    if (!base.denom)
        mach_timebase_info(&base);
    return (double)ticks * base.numer / base.denom / 1000.0;
}

static void revenant_fill(uint8_t *bytes, NSUInteger width, NSUInteger height, NSUInteger stride)
{
    memset(bytes, 0xAA, stride * height);
    for (NSUInteger y = 0; y < height; y++)
        for (NSUInteger x = 0; x < width; x++)
            for (NSUInteger channel = 0; channel < 4; channel++)
                bytes[y * stride + x * 4 + channel] = (uint8_t)(x * 7 + y * 13 + channel * 31);
}

static BOOL revenant_same(const uint8_t *seen, const uint8_t *expected, NSUInteger width, NSUInteger height, NSUInteger stride)
{
    for (NSUInteger y = 0; y < height; y++)
        if (memcmp(seen + y * stride, expected + y * stride, width * 4) != 0)
            return NO;
    return YES;
}

static BOOL revenant_throws(id<MTLDevice> device, NSUInteger format)
{
    @try {
        [device minimumLinearTextureAlignmentForPixelFormat:(MTLPixelFormat)format];
    } @catch (NSException *exception) {
        return [exception.name isEqualToString:NSInvalidArgumentException];
    }
    return NO;
}

static id<MTLTexture> revenant_bgra(id<MTLDevice> device, NSUInteger width, NSUInteger height)
{
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    return [device newTextureWithDescriptor:descriptor];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        RevenantMetalDevice *device = [RevenantMetalDevice shared];
        revenant_check(device != nil, "a Metal device exists", @"the shared device is nil");
        if (!device)
            return revenant_finish();

        struct { NSUInteger format; NSUInteger bytes; const char *name; } formats[] = {
            {MTLPixelFormatR8Unorm, 1, "R8Unorm"},
            {MTLPixelFormatRG8Unorm, 2, "RG8Unorm"},
            {MTLPixelFormatRGBA8Unorm, 4, "RGBA8Unorm"},
            {MTLPixelFormatBGRA8Unorm, 4, "BGRA8Unorm"},
            {MTLPixelFormatR16Float, 2, "R16Float"},
            {MTLPixelFormatRG16Float, 4, "RG16Float"},
            {MTLPixelFormatRGBA16Float, 8, "RGBA16Float"},
            {MTLPixelFormatR32Float, 4, "R32Float"},
            {MTLPixelFormatRGBA32Float, 16, "RGBA32Float"},
        };
        for (size_t index = 0; index < sizeof formats / sizeof formats[0]; index++) {
            NSUInteger alignment = [device minimumLinearTextureAlignmentForPixelFormat:(MTLPixelFormat)formats[index].format];
            NSString *name = [NSString stringWithFormat:@"the alignment of %s is %lu bytes, a power of two", formats[index].name, (unsigned long)formats[index].bytes];
            revenant_check((alignment == formats[index].bytes && revenant_power_of_two(alignment)) != revenant_negative, [name UTF8String], [NSString stringWithFormat:@"%lu", (unsigned long)alignment]);
        }

        revenant_check(revenant_throws(device, 0) != revenant_negative, "an invalid pixel format raises NSInvalidArgumentException", @"no exception");
        revenant_check(revenant_throws(device, 252) != revenant_negative, "a depth format raises NSInvalidArgumentException", @"no exception");
        revenant_check(revenant_throws(device, 253) != revenant_negative, "a stencil format raises NSInvalidArgumentException", @"no exception");
        revenant_check(revenant_throws(device, 160) != revenant_negative, "a compressed format raises NSInvalidArgumentException", @"no exception");

        NSUInteger alignment = [device minimumLinearTextureAlignmentForPixelFormat:MTLPixelFormatBGRA8Unorm];
        NSUInteger widths[] = {1, 3, 5, 7, 63, 64, 65, 255, 750, 1001};
        NSUInteger paddings[] = {alignment, 16, 64, 256};
        NSUInteger height = 5;
        BOOL exact[4] = {YES, YES, YES, YES};
        NSString *first[4] = {nil, nil, nil, nil};
        for (size_t w = 0; w < sizeof widths / sizeof widths[0]; w++) {
            NSUInteger width = widths[w];
            for (size_t p = 0; p < 4; p++) {
                NSUInteger stride = revenant_align(width * 4, paddings[p]);
                uint8_t *written = malloc(stride * height);
                uint8_t *read = malloc(stride * height);
                revenant_fill(written, width, height, stride);
                memset(read, 0x55, stride * height);
                id<MTLTexture> texture = revenant_bgra(device, width, height);
                [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:written bytesPerRow:stride];
                [texture getBytes:read bytesPerRow:stride fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];
                if (!revenant_same(read, written, width, height, stride)) {
                    exact[p] = NO;
                    if (!first[p])
                        first[p] = [NSString stringWithFormat:@"width %lu, stride %lu", (unsigned long)width, (unsigned long)stride];
                }
                free(written);
                free(read);
            }
        }
        revenant_check(exact[0] != revenant_negative, "BGRA rows at the device's own alignment come back byte for byte at every width", first[0] ?: @"");
        revenant_check(exact[1] != revenant_negative, "BGRA rows padded to 16 bytes come back byte for byte at every width", first[1] ?: @"");
        revenant_check(exact[2] != revenant_negative, "BGRA rows padded to 64 bytes come back byte for byte at every width", first[2] ?: @"");
        revenant_check(exact[3] != revenant_negative, "BGRA rows padded to 256 bytes come back byte for byte at every width", first[3] ?: @"");

        {
            NSUInteger sliceWidth = 63, sliceStride = revenant_align(sliceWidth * 4, 256);
            uint8_t *written = malloc(sliceStride * height);
            uint8_t *read = malloc(sliceStride * height);
            uint8_t *untouched = malloc(sliceStride * height);
            revenant_fill(written, sliceWidth, height, sliceStride);
            memset(read, 0x55, sliceStride * height);
            memset(untouched, 0x55, sliceStride * height);
            id<MTLTexture> texture = revenant_bgra(device, sliceWidth, height);
            MTLRegion region = MTLRegionMake2D(0, 0, sliceWidth, height);
            [texture replaceRegion:region mipmapLevel:0 slice:0 withBytes:written bytesPerRow:sliceStride bytesPerImage:0];
            [texture getBytes:read bytesPerRow:sliceStride bytesPerImage:0 fromRegion:region mipmapLevel:0 slice:0];
            revenant_check(revenant_same(read, written, sliceWidth, height, sliceStride) != revenant_negative, "the slice 0 forms of replaceRegion and getBytes round-trip BGRA rows byte for byte", @"");
            memset(read, 0x55, sliceStride * height);
            [texture getBytes:read bytesPerRow:sliceStride bytesPerImage:0 fromRegion:region mipmapLevel:0 slice:1];
            revenant_check((memcmp(read, untouched, sliceStride * height) == 0) != revenant_negative, "getBytes of slice 1 of a 2D texture is refused and writes nothing", @"");
            uint8_t *other = malloc(sliceStride * height);
            memset(other, 0x11, sliceStride * height);
            [texture replaceRegion:region mipmapLevel:0 slice:1 withBytes:other bytesPerRow:sliceStride bytesPerImage:0];
            [texture getBytes:read bytesPerRow:sliceStride bytesPerImage:0 fromRegion:region mipmapLevel:0 slice:0];
            revenant_check(revenant_same(read, written, sliceWidth, height, sliceStride) != revenant_negative, "replaceRegion of slice 1 of a 2D texture is refused and leaves slice 0 as it was", @"");
            free(other);
            free(written);
            free(read);
            free(untouched);
        }

        NSUInteger width = 1001, rows = 1001;
        for (size_t p = 0; p < 4; p += 3) {
            NSUInteger stride = revenant_align(width * 4, paddings[p]);
            uint8_t *bytes = malloc(stride * rows);
            revenant_fill(bytes, width, rows, stride);
            id<MTLTexture> texture = revenant_bgra(device, width, rows);
            enum { Rounds = 20 };
            [texture replaceRegion:MTLRegionMake2D(0, 0, width, rows) mipmapLevel:0 withBytes:bytes bytesPerRow:stride];
            uint64_t begin = mach_absolute_time();
            for (int round = 0; round < Rounds; round++)
                [texture replaceRegion:MTLRegionMake2D(0, 0, width, rows) mipmapLevel:0 withBytes:bytes bytesPerRow:stride];
            [device acquire];
            glFinish();
            [device relinquish];
            double replace = revenant_microseconds(mach_absolute_time() - begin) / Rounds;
            begin = mach_absolute_time();
            for (int round = 0; round < Rounds; round++)
                [texture getBytes:bytes bytesPerRow:stride fromRegion:MTLRegionMake2D(0, 0, width, rows) mipmapLevel:0];
            double readback = revenant_microseconds(mach_absolute_time() - begin) / Rounds;
            printf("info %lux%lu stride %lu: replaceRegion %.0f us, getBytes %.0f us\n", (unsigned long)width, (unsigned long)rows, (unsigned long)stride, replace, readback);
            fflush(stdout);
            free(bytes);
        }
    }
    return revenant_finish();
}
