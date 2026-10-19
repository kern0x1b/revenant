#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

@interface MPSImage (CharonProbeReadCount)
- (NSUInteger)readCount;
- (void)setReadCount:(NSUInteger)count;
@end

static int failures = 0;

static void expect(BOOL holds, const char *what)
{
    printf("%s: %s\n", holds ? "ok  " : "FAIL", what);
    if (!holds)
        failures++;
}

static MTLTextureDescriptor *TextureDescriptor(void)
{
    MTLTextureDescriptor *td = [[MTLTextureDescriptor alloc] init];
    td.textureType = MTLTextureType2D;
    td.width = 4;
    td.height = 4;
    td.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    td.storageMode = MTLStorageModePrivate;
    td.pixelFormat = MTLPixelFormatR32Float;
    return td;
}

static const MTLRegion Region = {0, 0, 0, 4, 4, 1};

static void Fill(MPSImage *image, float value)
{
    float pixels[4 * 4];
    for (NSUInteger i = 0; i < 4 * 4; i++)
        pixels[i] = value;
    [image writeBytes:pixels dataLayout:MPSDataLayoutFeatureChannelsxHeightxWidth
           bytesPerRow:4 * sizeof(float) region:Region featureChannelInfo:(MPSImageReadWriteParams){0}
           imageIndex:0];
}

static NSUInteger NonZeroFloats(MPSImage *image)
{
    float pixels[4 * 4];
    memset(pixels, 0, sizeof(pixels));
    [image readBytes:pixels dataLayout:MPSDataLayoutFeatureChannelsxHeightxWidth
          bytesPerRow:4 * sizeof(float) region:Region featureChannelInfo:(MPSImageReadWriteParams){0}
          imageIndex:0];
    NSUInteger nonZero = 0;
    for (NSUInteger i = 0; i < 4 * 4; i++)
        if (pixels[i] != 0.0f)
            nonZero++;
    return nonZero;
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            printf("FAIL no Metal device on this host\n");
            return 1;
        }
        printf("device: %s\n", [[device name] UTF8String]);
        id<MTLCommandBuffer> buffer = (id<MTLCommandBuffer>)[device newCommandBuffer];

        MPSImageDescriptor *descriptor =
            [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                             width:4 height:4 featureChannels:1];
        MPSImage *destination = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];

        MPSImage *temporary = nil;
        @try {
            temporary = [MPSTemporaryImage temporaryImageWithCommandBuffer:buffer imageDescriptor:descriptor];
            printf("temporary image: made through +temporaryImageWithCommandBuffer:imageDescriptor:\n");
        } @catch (NSException *exception) {
            printf("temporary image: THE RELEASE ANSWERED NOTHING: %s\n", [[exception reason] UTF8String]);
            @try {
                id<MPSImageAllocator> allocator = [MPSTemporaryImage defaultAllocator];
                printf("default allocator: %s\n", object_getClassName(allocator));
                temporary = [allocator imageForCommandBuffer:buffer imageDescriptor:descriptor kernel:nil];
                printf("temporary image: made through the allocator\n");
            } @catch (NSException *second) {
                printf("allocator path: THE RELEASE ANSWERED NOTHING: %s\n", [[second reason] UTF8String]);
            }
        }

        if (!temporary) {
            printf("NOT MEASURED: the release made no temporary image\n");
#ifdef CHARON_PORT_BUILD
            printf("FAIL the port must make its own MPSTemporaryImage\n");
            return 1;
#else
            return 0;
#endif
        }
        printf("temporary image class: %s\n", object_getClassName(temporary));

        [temporary setReadCount:2];
        NSUInteger before = [temporary readCount];
        printf("readCount after -setReadCount:2 -> %lu\n", (unsigned long)before);
        expect(before == 2, "check 1: the reader answers the count it was given");

        Fill(temporary, 1.0f);
        float oneNinth = 1.0f / 9.0f;
        float weights[9] = {oneNinth, oneNinth, oneNinth, oneNinth, oneNinth,
                            oneNinth, oneNinth, oneNinth, oneNinth};
        MPSImageConvolution *kernel = [[MPSImageConvolution alloc] initWithDevice:device
                                                                        kernelWidth:3 kernelHeight:3
                                                                             weights:weights];

        [kernel encodeToCommandBuffer:buffer sourceImage:temporary destinationImage:destination];
        NSUInteger afterOne = [temporary readCount];
        printf("readCount after one encode -> %lu\n", (unsigned long)afterOne);

        id<MTLCommandBuffer> second = (id<MTLCommandBuffer>)[device newCommandBuffer];
        [kernel encodeToCommandBuffer:second sourceImage:temporary destinationImage:destination];
        NSUInteger afterTwo = [temporary readCount];
        printf("readCount after two encodes -> %lu\n", (unsigned long)afterTwo);

#ifdef CHARON_PORT_BUILD
        expect(afterOne == 1, "check 2: one encode that reads the temporary takes 2 to 1");
        expect(afterTwo == 0, "check 3: the next takes it to 0");

        MPSImage *plain = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];
        Fill(plain, 1.0f);
        id<MTLCommandBuffer> third = (id<MTLCommandBuffer>)[device newCommandBuffer];
        [kernel encodeToCommandBuffer:third sourceImage:plain destinationImage:destination];
        BOOL plainHasNoCount = ![plain respondsToSelector:NSSelectorFromString(@"readCount")];
        printf("a plain MPSImage responds to -readCount: %d\n", (int)plainHasNoCount);
        expect(plainHasNoCount, "check 4: a plain MPSImage carries no read count to decrement");

        NSUInteger written = NonZeroFloats(destination);
        printf("destination values that are not zero: %lu of 16\n", (unsigned long)written);
        expect(written == 16, "check 5: the destination holds the kernel's own answer, so the count "
                              "moved because a kernel read the source");
#else
        printf("readCount after one encode -> %lu (not asserted: the release's own object)\n",
               (unsigned long)afterOne);
        (void)afterTwo;
#endif
        printf("failures: %d\n", failures);
        return failures == 0 ? 0 : 1;
    }
}
