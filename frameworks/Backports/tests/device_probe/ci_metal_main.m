#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <OpenGLES/ES2/gl.h>
#import <mach/mach_time.h>
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

static double revenant_now(void)
{
    static mach_timebase_info_data_t base;
    if (!base.denom)
        mach_timebase_info(&base);
    return (double)mach_absolute_time() * base.numer / base.denom / 1e9;
}

static void revenant_through_memory(CIContext *context, CIImage *image, id<MTLTexture> texture, CGRect bounds, CGColorSpaceRef space)
{
    NSUInteger width = texture.width, height = texture.height;
    CGAffineTransform flip = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-bounds.origin.x, -bounds.origin.y), CGAffineTransformMake(1, 0, 0, -1, 0, (CGFloat)height));
    NSMutableData *pixels = [NSMutableData dataWithLength:width * 4 * height];
    [context render:[image imageByApplyingTransform:flip] toBitmap:pixels.mutableBytes rowBytes:width * 4 bounds:CGRectMake(0, 0, width, height) format:kCIFormatRGBA8 colorSpace:space];
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:pixels.bytes bytesPerRow:width * 4];
}

static int revenant_largest_difference(id<MTLTexture> first, id<MTLTexture> second)
{
    NSUInteger count = first.width * 4 * first.height;
    NSMutableData *left = [NSMutableData dataWithLength:count], *right = [NSMutableData dataWithLength:count];
    [first getBytes:left.mutableBytes bytesPerRow:first.width * 4 fromRegion:MTLRegionMake2D(0, 0, first.width, first.height) mipmapLevel:0];
    [second getBytes:right.mutableBytes bytesPerRow:second.width * 4 fromRegion:MTLRegionMake2D(0, 0, second.width, second.height) mipmapLevel:0];
    int worst = 0;
    for (NSUInteger index = 0; index < count; index++)
        worst = MAX(worst, abs((int)((const uint8_t *)left.bytes)[index] - (int)((const uint8_t *)right.bytes)[index]));
    return worst;
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

        {
            uint8_t ramp[16 * 16 * 4];
            for (int index = 0; index < 256; index++) {
                ramp[index * 4] = (uint8_t)index; ramp[index * 4 + 1] = (uint8_t)(255 - index); ramp[index * 4 + 2] = (uint8_t)(index / 2); ramp[index * 4 + 3] = 255;
            }
            id<MTLTexture> rampTexture = revenant_texture(device, 16, MTLPixelFormatRGBA8Unorm);
            [rampTexture replaceRegion:MTLRegionMake2D(0, 0, 16, 16) mipmapLevel:0 withBytes:ramp bytesPerRow:64];
            CIImage *rampImage = [CIImage imageWithMTLTexture:rampTexture options:nil];
            CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
            CGColorSpaceRef genericRGB = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
            id workingSpaces[] = {[NSNull null], (__bridge id)genericRGB, nil};
            const char *workingNames[] = {"no working space", "generic RGB working space", "default working space"};
            CGColorSpaceRef callSpaces[] = {NULL, deviceRGB, genericRGB};
            const char *callNames[] = {"no colour space", "device RGB", "generic RGB"};
            int worst = 0;
            NSMutableString *report = [NSMutableString string];
            int defaultNone = 0, defaultDevice = 0;
            for (int working = 0; working < 3; working++) {
                NSDictionary *options = workingSpaces[working] ? @{kCIContextWorkingColorSpace: workingSpaces[working]} : nil;
                CIContext *managed = [CIContext contextWithMTLDevice:device options:options];
                for (int call = 0; call < 3; call++) {
                    id<MTLTexture> expected = revenant_texture(device, 16, MTLPixelFormatRGBA8Unorm);
                    id<MTLTexture> actual = revenant_texture(device, 16, MTLPixelFormatRGBA8Unorm);
                    revenant_through_memory(managed, rampImage, expected, rampImage.extent, callSpaces[call]);
                    [managed render:rampImage toMTLTexture:actual commandBuffer:nil bounds:rampImage.extent colorSpace:callSpaces[call]];
                    int difference = revenant_largest_difference(expected, actual);
                    worst = MAX(worst, difference);
                    [report appendFormat:@"%s with %s: %d; ", workingNames[working], callNames[call], difference];
                    if (working == 2 && call == 0)
                        defaultNone = revenant_largest_difference(actual, rampTexture);
                    if (working == 2 && call == 1)
                        defaultDevice = revenant_largest_difference(actual, rampTexture);
                }
            }
            printf("colour matrix, largest difference from CoreImage's own render through memory: %s\n", report.UTF8String);
            revenant_check((worst <= 2) != revenant_negative, "a render gives the values CoreImage gives through memory for every working space and colour space of the call", report);
            revenant_check((defaultNone <= 1 && defaultDevice > 8) != revenant_negative, "under the default working space the colour space of the call changes the values, so the comparison above can tell them apart", [NSString stringWithFormat:@"none differs from the source by %d, device RGB by %d", defaultNone, defaultDevice]);
            CGColorSpaceRelease(deviceRGB);
            CGColorSpaceRelease(genericRGB);
        }
        {
            uint8_t translucent[revenant_side * revenant_side * 4];
            for (int index = 0; index < revenant_side * revenant_side; index++) {
                translucent[index * 4] = 0x80; translucent[index * 4 + 1] = 0x40; translucent[index * 4 + 2] = 0x20; translucent[index * 4 + 3] = 0x80;
            }
            id<MTLTexture> faint = revenant_texture(device, revenant_side, MTLPixelFormatRGBA8Unorm);
            [faint replaceRegion:MTLRegionMake2D(0, 0, revenant_side, revenant_side) mipmapLevel:0 withBytes:translucent bytesPerRow:revenant_side * 4];
            CIImage *faintImage = [CIImage imageWithMTLTexture:faint options:@{kCIImageColorSpace: [NSNull null]}];
            uint8_t filler[6 * 6 * 4];
            memset(filler, 0x77, sizeof filler);
            id<MTLTexture> expected = revenant_texture(device, 6, MTLPixelFormatRGBA8Unorm);
            id<MTLTexture> actual = revenant_texture(device, 6, MTLPixelFormatRGBA8Unorm);
            [expected replaceRegion:MTLRegionMake2D(0, 0, 6, 6) mipmapLevel:0 withBytes:filler bytesPerRow:24];
            [actual replaceRegion:MTLRegionMake2D(0, 0, 6, 6) mipmapLevel:0 withBytes:filler bytesPerRow:24];
            CGRect wide = CGRectMake(-1, -1, 6, 6);
            revenant_through_memory(context, faintImage, expected, wide, NULL);
            [context render:faintImage toMTLTexture:actual commandBuffer:nil bounds:wide colorSpace:NULL];
            int replaced = revenant_largest_difference(expected, actual);
            revenant_check((replaced <= 1) != revenant_negative, "a render replaces what the texture held, translucent pixels and the margin outside the image included", [NSString stringWithFormat:@"largest difference %d", replaced]);
        }
        {
            RevenantMetalDevice *shared = [RevenantMetalDevice shared];
            GLuint own = 0;
            [shared acquire];
            glGenFramebuffers(1, &own);
            glBindFramebuffer(GL_FRAMEBUFFER, own);
            glViewport(3, 5, 7, 9);
            glEnable(GL_SCISSOR_TEST);
            glScissor(1, 2, 3, 4);
            glClearColor(0.25f, 0.5f, 0.75f, 1.0f);
            glColorMask(GL_FALSE, GL_TRUE, GL_FALSE, GL_TRUE);
            while (glGetError() != GL_NO_ERROR) {}
            [shared relinquish];
            id<MTLTexture> target = revenant_texture(device, revenant_side, MTLPixelFormatRGBA8Unorm);
            [context render:image toMTLTexture:target commandBuffer:nil bounds:image.extent colorSpace:NULL];
            [shared acquire];
            GLenum raised = glGetError();
            GLint framebuffer = 0, viewport[4] = {0}, box[4] = {0};
            GLfloat clear[4] = {0};
            GLboolean mask[4] = {0};
            glGetIntegerv(GL_FRAMEBUFFER_BINDING, &framebuffer);
            glGetIntegerv(GL_VIEWPORT, viewport);
            glGetIntegerv(GL_SCISSOR_BOX, box);
            glGetFloatv(GL_COLOR_CLEAR_VALUE, clear);
            glGetBooleanv(GL_COLOR_WRITEMASK, mask);
            BOOL scissor = glIsEnabled(GL_SCISSOR_TEST) == GL_TRUE;
            glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
            glDisable(GL_SCISSOR_TEST);
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            glDeleteFramebuffers(1, &own);
            [shared relinquish];
            BOOL kept = raised == GL_NO_ERROR && framebuffer == (GLint)own && viewport[0] == 3 && viewport[1] == 5 && viewport[2] == 7 && viewport[3] == 9 && scissor && box[0] == 1 && box[1] == 2 && box[2] == 3 && box[3] == 4 && clear[0] == 0.25f && clear[1] == 0.5f && clear[2] == 0.75f && mask[0] == GL_FALSE && mask[1] == GL_TRUE && mask[2] == GL_FALSE;
            revenant_check(kept != revenant_negative, "a render raises no GL error and leaves the framebuffer, viewport, scissor, clear colour and colour mask of the context as they were", [NSString stringWithFormat:@"GL error 0x%x, framebuffer %d (own %u), viewport %d %d %d %d, scissor %d box %d %d %d %d, mask %d %d %d", raised, framebuffer, own, viewport[0], viewport[1], viewport[2], viewport[3], scissor, box[0], box[1], box[2], box[3], mask[0], mask[1], mask[2]]);
        }
        {
            RevenantMetalDevice *shared = [RevenantMetalDevice shared];
            GLenum names[] = {GL_TEXTURE_MIN_FILTER, GL_TEXTURE_MAG_FILTER, GL_TEXTURE_WRAP_S, GL_TEXTURE_WRAP_T};
            GLint before[4] = {0}, after[4] = {0};
            [shared acquire];
            GLint bound = 0;
            glGetIntegerv(GL_TEXTURE_BINDING_2D, &bound);
            glBindTexture(GL_TEXTURE_2D, [(RevenantMetalTexture *)source name]);
            for (int index = 0; index < 4; index++)
                glGetTexParameteriv(GL_TEXTURE_2D, names[index], &before[index]);
            glBindTexture(GL_TEXTURE_2D, (GLuint)bound);
            [shared relinquish];
            id<MTLTexture> sink = revenant_texture(device, revenant_side, MTLPixelFormatRGBA8Unorm);
            [context render:[image imageByApplyingTransform:CGAffineTransformMakeScale(0.7, 0.7)] toMTLTexture:sink commandBuffer:nil bounds:CGRectMake(0, 0, 3, 3) colorSpace:NULL];
            [shared acquire];
            glBindTexture(GL_TEXTURE_2D, [(RevenantMetalTexture *)source name]);
            for (int index = 0; index < 4; index++)
                glGetTexParameteriv(GL_TEXTURE_2D, names[index], &after[index]);
            glBindTexture(GL_TEXTURE_2D, (GLuint)bound);
            [shared relinquish];
            BOOL unchanged = memcmp(before, after, sizeof before) == 0;
            revenant_check(unchanged != revenant_negative, "a render leaves the filter and wrap parameters of the texture it reads as they were", [NSString stringWithFormat:@"min %x->%x mag %x->%x wrapS %x->%x wrapT %x->%x", before[0], after[0], before[1], after[1], before[2], after[2], before[3], after[3]]);
        }
        {
            id<MTLTexture> half = revenant_texture(device, revenant_side, MTLPixelFormatRGBA16Float);
            [context render:image toMTLTexture:half commandBuffer:nil bounds:image.extent colorSpace:NULL];
            CIImage *wrapped = [[CIImage alloc] initWithTexture:[(RevenantMetalTexture *)half name] size:CGSizeMake(revenant_side, revenant_side) flipped:NO colorSpace:NULL];
            uint8_t back[revenant_side][revenant_side * 4] = {{0}};
            [context render:wrapped toBitmap:back rowBytes:revenant_side * 4 bounds:wrapped.extent format:kCIFormatRGBA8 colorSpace:NULL];
            BOOL halves = YES;
            for (int row = 0; row < revenant_side; row++)
                halves = halves && revenant_close(back[row], revenant_source[revenant_side - 1 - row], revenant_side * 4);
            revenant_check(halves != revenant_negative, "a half-float texture receives the image", revenant_hex(back[0], revenant_side * 4));
        }
        {
            RevenantMetalDevice *shared = [RevenantMetalDevice shared];
            [shared acquire];
            while (glGetError() != GL_NO_ERROR) {}
            [shared relinquish];
            id<MTLTexture> full = revenant_texture(device, revenant_side, MTLPixelFormatRGBA32Float);
            [shared acquire];
            GLenum created = glGetError();
            [shared relinquish];
            [context render:image toMTLTexture:full commandBuffer:nil bounds:image.extent colorSpace:NULL];
            [shared acquire];
            GLenum rendered = glGetError();
            GLint previous = 0;
            glGetIntegerv(GL_FRAMEBUFFER_BINDING, &previous);
            glBindFramebuffer(GL_FRAMEBUFFER, [(RevenantMetalTexture *)full renderTarget]);
            GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)previous);
            [shared relinquish];
            revenant_check((status != GL_FRAMEBUFFER_COMPLETE && &kCIFormatRGBAf == NULL && rendered == GL_NO_ERROR) != revenant_negative, "a render into a full-float texture returns without a GL error: the GPU has no framebuffer for it and this system has no full-float bitmap format", [NSString stringWithFormat:@"framebuffer status 0x%x, GL error after creating the texture 0x%x and after the render 0x%x, format symbol %p", status, created, rendered, (void *)&kCIFormatRGBAf]);
            printf("full-float texture: error after creating it 0x%x, after the render 0x%x, framebuffer status 0x%x\n", created, rendered, status);
        }
        {
            CIContext *software = [CIContext contextWithMTLDevice:device options:@{kCIContextWorkingColorSpace: [NSNull null], kCIContextOutputColorSpace: [NSNull null], kCIContextUseSoftwareRenderer: @YES}];
            id<MTLTexture> expected = revenant_texture(device, revenant_side, MTLPixelFormatRGBA8Unorm);
            id<MTLTexture> actual = revenant_texture(device, revenant_side, MTLPixelFormatRGBA8Unorm);
            revenant_through_memory(software, image, expected, image.extent, NULL);
            [software render:image toMTLTexture:actual commandBuffer:nil bounds:image.extent colorSpace:NULL];
            int software_difference = revenant_largest_difference(expected, actual);
            revenant_check((software_difference <= 1) != revenant_negative, "a context made for the software renderer renders the same rows", [NSString stringWithFormat:@"largest difference %d", software_difference]);
        }
        for (NSUInteger edge = 512; edge <= 1024; edge *= 2) {
            NSUInteger height = edge * 3 / 4;
            id<MTLTexture> big = [device newTextureWithDescriptor:[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:edge height:height mipmapped:NO]];
            NSMutableData *noise = [NSMutableData dataWithLength:edge * 4 * height];
            uint32_t state = 7;
            uint8_t *bytes = noise.mutableBytes;
            for (NSUInteger index = 0; index < edge * 4 * height; index++) {
                state = state * 1664525u + 1013904223u;
                bytes[index] = state >> 24;
            }
            [big replaceRegion:MTLRegionMake2D(0, 0, edge, height) mipmapLevel:0 withBytes:bytes bytesPerRow:edge * 4];
            CIImage *adjusted = [[CIImage imageWithMTLTexture:big options:@{kCIImageColorSpace: [NSNull null]}] imageByApplyingTransform:CGAffineTransformMakeScale(0.9, 0.9)];
            id<MTLTexture> frame = [device newTextureWithDescriptor:[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:edge height:height mipmapped:NO]];
            CGRect all = CGRectMake(0, 0, edge * 0.9, height * 0.9);
            [context render:adjusted toMTLTexture:frame commandBuffer:nil bounds:all colorSpace:NULL];
            double started = revenant_now();
            for (int count = 0; count < 10; count++)
                revenant_through_memory(context, adjusted, frame, all, NULL);
            double memory = (revenant_now() - started) / 10;
            started = revenant_now();
            for (int count = 0; count < 10; count++)
                [context render:adjusted toMTLTexture:frame commandBuffer:nil bounds:all colorSpace:NULL];
            RevenantMetalDevice *shared = [RevenantMetalDevice shared];
            [shared acquire];
            glFinish();
            [shared relinquish];
            double native = (revenant_now() - started) / 10;
            printf("timing %lux%lu: through memory %.1f ms, render:toMTLTexture: %.1f ms (the GPU finished)\n", (unsigned long)edge, (unsigned long)height, memory * 1000, native * 1000);
        }

        id<MTLTexture> single = revenant_texture(device, revenant_side, MTLPixelFormatR8Unorm);
        revenant_check(([CIImage imageWithMTLTexture:single options:nil] == nil) != revenant_negative, "a texture whose format the image cannot reference gives no image", @"an image was made");
    }
    return revenant_finish();
}
