#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) printf("  ok   %s\n", [what UTF8String]);
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("does this machine have a Metal device?\n");
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        check(device != nil, @"MTLCreateSystemDefaultDevice() answers");
        if (!device) {
            printf("hostdevice: %d check(s), %d failure(s)\n", checks, failures + 1);
            return 1;
        }
        printf("       it is %s, name \"%s\"\n",
               [[device description] UTF8String], [[device name] UTF8String]);
        printf("       lowPower=%d headless=%d hasUnifiedMemory=%d maxThreadsPerThreadgroup=%lu\n",
               (int)[device isLowPower], (int)[device isHeadless], (int)[device hasUnifiedMemory],
               (unsigned long)[device maxThreadsPerThreadgroup].width);

        MTLTextureDescriptor *descriptor =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                width:4 height:4 mipmapped:NO];
        id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
        check(texture != nil, @"the device makes a 4x4 RGBA8 texture");
        if (texture) {
            uint32_t pixels[16];
            for (unsigned i = 0; i < 16; i++) pixels[i] = 0x11223300u + i;
            [texture replaceRegion:MTLRegionMake2D(0, 0, 4, 4) mipmapLevel:0
                         withBytes:pixels bytesPerRow:4 * sizeof(uint32_t)];
            uint32_t back[16] = { 0 };
            [texture getBytes:back bytesPerRow:4 * sizeof(uint32_t)
                  fromRegion:MTLRegionMake2D(0, 0, 4, 4) mipmapLevel:0];
            check(back[0] == 0x11223300u && back[15] == 0x11223300u + 15,
                  @"a texel written to that texture reads back unchanged, first and last");
        }

        MTLRenderPipelineDescriptor *descriptorOnly = [MTLRenderPipelineDescriptor new];
        check(descriptorOnly != nil && descriptorOnly.colorAttachments != nil,
              @"a fresh MTLRenderPipelineDescriptor answers with no device at all");
        check(descriptorOnly.colorAttachments[0] != nil,
              @"its colour attachment array answers at index 0 with no device at all");
    }
    printf("hostdevice: %d check(s), %d failure(s)\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
