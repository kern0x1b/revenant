#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import "check.h"
#import "RevenantMetal.h"

enum { revenant_side = 4 };

static uint8_t revenant_source[revenant_side][revenant_side * 4];

static void revenant_fill(void)
{
    for (int row = 0; row < revenant_side; row++) {
        for (int column = 0; column < revenant_side; column++) {
            uint8_t *pixel = revenant_source[row] + column * 4;
            pixel[0] = (uint8_t)(row * 60);
            pixel[1] = (uint8_t)(column * 60);
            pixel[2] = (uint8_t)(100 + row * 10 + column);
            pixel[3] = 255;
        }
    }
}

static BOOL revenant_close(const uint8_t *seen, const uint8_t *expected, size_t count)
{
    for (size_t index = 0; index < count; index++) {
        if (abs((int)seen[index] - (int)expected[index]) > 1)
            return NO;
    }
    return YES;
}

static NSString *revenant_hex(const uint8_t *bytes, size_t count)
{
    NSMutableString *text = [NSMutableString string];
    for (size_t index = 0; index < count; index++)
        [text appendFormat:@"%02x ", bytes[index]];
    return text;
}

static id<MTLTexture> revenant_texture(id<MTLDevice> device, NSUInteger side, MTLPixelFormat format)
{
    return [device newTextureWithDescriptor:[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:side height:side mipmapped:NO]];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        revenant_fill();
        id<MTLDevice> device = [RevenantMetalDevice shared];
        revenant_check(device != nil, "a Metal device exists", @"the shared device is nil");
        if (!device)
            return revenant_finish();
        NSDictionary *unmanaged = @{kCIContextWorkingColorSpace: [NSNull null], kCIContextOutputColorSpace: [NSNull null]};
        CIContext *context = [CIContext contextWithMTLDevice:device options:unmanaged];
        revenant_check((context != nil && [CIContext contextWithMTLDevice:device] != nil) != revenant_negative, "a context is made for the Metal device, with and without options", @"no context");
        if (!context)
            return revenant_finish();

        id<MTLTexture> source = revenant_texture(device, revenant_side, MTLPixelFormatRGBA8Unorm);
        [source replaceRegion:MTLRegionMake2D(0, 0, revenant_side, revenant_side) mipmapLevel:0 withBytes:revenant_source bytesPerRow:revenant_side * 4];
        CIImage *image = [CIImage imageWithMTLTexture:source options:@{kCIImageColorSpace: [NSNull null]}];
        revenant_check((image != nil && CGRectEqualToRect(image.extent, CGRectMake(0, 0, revenant_side, revenant_side))) != revenant_negative, "an image of a texture has the texture's size", [NSString stringWithFormat:@"%g,%g %gx%g", image.extent.origin.x, image.extent.origin.y, image.extent.size.width, image.extent.size.height]);
        if (!image)
            return revenant_finish();
        revenant_check(([CIImage imageWithMTLTexture:source options:nil].metalTexture == source && image.metalTexture == nil) != revenant_negative, "an image made without options returns its texture and one made with options does not", @"metalTexture differs");

        uint8_t bitmap[revenant_side][revenant_side * 4] = {{0}};
        [context render:image toBitmap:bitmap rowBytes:revenant_side * 4 bounds:image.extent format:kCIFormatRGBA8 colorSpace:NULL];
        BOOL turned = YES;
        for (int row = 0; row < revenant_side; row++)
            turned = turned && revenant_close(bitmap[row], revenant_source[revenant_side - 1 - row], revenant_side * 4);
        revenant_check(turned != revenant_negative, "the first row of a texture is the bottom row of its image", revenant_hex(bitmap[0], revenant_side * 4));

        id<MTLTexture> copy = revenant_texture(device, revenant_side, MTLPixelFormatRGBA8Unorm);
        [context render:image toMTLTexture:copy commandBuffer:nil bounds:image.extent colorSpace:NULL];
        uint8_t read[revenant_side][revenant_side * 4] = {{0}};
        [copy getBytes:read bytesPerRow:revenant_side * 4 fromRegion:MTLRegionMake2D(0, 0, revenant_side, revenant_side) mipmapLevel:0];
        BOOL same = YES;
        for (int row = 0; row < revenant_side; row++)
            same = same && revenant_close(read[row], revenant_source[row], revenant_side * 4);
        revenant_check(same != revenant_negative, "rendering an image of a texture into a texture gives the same rows back", revenant_hex(read[0], revenant_side * 4));

        id<MTLTexture> part = revenant_texture(device, 2, MTLPixelFormatRGBA8Unorm);
        [context render:image toMTLTexture:part commandBuffer:nil bounds:CGRectMake(1, 1, 2, 2) colorSpace:NULL];
        uint8_t portion[2][8] = {{0}};
        [part getBytes:portion bytesPerRow:8 fromRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0];
        revenant_check((revenant_close(portion[0], revenant_source[1] + 4, 8) && revenant_close(portion[1], revenant_source[2] + 4, 8)) != revenant_negative, "the bounds pick the rows and columns that land at the texture's origin", revenant_hex(portion[0], 16));

        id<MTLTexture> bgra = revenant_texture(device, revenant_side, MTLPixelFormatBGRA8Unorm);
        [context render:image toMTLTexture:bgra commandBuffer:nil bounds:image.extent colorSpace:NULL];
        uint8_t swapped[revenant_side][revenant_side * 4] = {{0}};
        [bgra getBytes:swapped bytesPerRow:revenant_side * 4 fromRegion:MTLRegionMake2D(0, 0, revenant_side, revenant_side) mipmapLevel:0];
        BOOL channels = YES;
        for (int row = 0; row < revenant_side; row++) {
            for (int pixel = 0; pixel < revenant_side; pixel++) {
                const uint8_t *from = revenant_source[row] + pixel * 4;
                const uint8_t *to = swapped[row] + pixel * 4;
                channels = channels && abs(to[0] - from[2]) <= 1 && abs(to[1] - from[1]) <= 1 && abs(to[2] - from[0]) <= 1 && abs(to[3] - from[3]) <= 1;
            }
        }
        revenant_check(channels != revenant_negative, "a BGRA texture receives the channels in BGRA order", revenant_hex(swapped[0], revenant_side * 4));

        CVPixelBufferRef buffer = NULL;
        CVReturn created = CVPixelBufferCreate(kCFAllocatorDefault, revenant_side, revenant_side, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)@{(id)kCVPixelBufferIOSurfacePropertiesKey: @{}}, &buffer);
        revenant_check(created == kCVReturnSuccess, "a pixel buffer is made", [NSString stringWithFormat:@"status %d", created]);
        if (created == kCVReturnSuccess) {
            [context render:image toCVPixelBuffer:buffer];
            CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t *base = CVPixelBufferGetBaseAddress(buffer);
            size_t stride = CVPixelBufferGetBytesPerRow(buffer);
            BOOL pixels = YES;
            for (int row = 0; row < revenant_side; row++) {
                for (int pixel = 0; pixel < revenant_side; pixel++) {
                    const uint8_t *from = revenant_source[revenant_side - 1 - row] + pixel * 4;
                    const uint8_t *to = base + row * stride + pixel * 4;
                    pixels = pixels && abs(to[0] - from[2]) <= 1 && abs(to[1] - from[1]) <= 1 && abs(to[2] - from[0]) <= 1 && abs(to[3] - from[3]) <= 1;
                }
            }
            revenant_check(pixels != revenant_negative, "rendering an image of a texture into a pixel buffer puts the top row first", revenant_hex(base, revenant_side * 4));
            CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
            CVPixelBufferRelease(buffer);
        }

        id<MTLTexture> single = revenant_texture(device, revenant_side, MTLPixelFormatR8Unorm);
        revenant_check(([CIImage imageWithMTLTexture:single options:nil] == nil) != revenant_negative, "a texture whose format the image cannot reference gives no image", @"an image was made");
    }
    return revenant_finish();
}
