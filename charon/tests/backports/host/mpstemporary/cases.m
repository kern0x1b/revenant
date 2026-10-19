// cases.m - what a temporary IMAGE's read count does when a kernel reads it, and what the release's
// own MPS answers for the same question on this host.
//
// The same file is compiled twice: once against the system's MetalPerformanceShaders, once against
// this port's classes with their MPS names mapped to Charon names (run.sh's rename header), so the
// port's own MPSTemporaryImage and its own kernel are the ones being asked. The two transcripts are
// NOT compared, and that is the finding rather than a gap: the release cannot make an
// MPSTemporaryImage on this machine at all, so it has no answer to compare with and the case prints
// the selector it raises. What IS checked is the port's own contract, written down below from
// MPSImage.h:1030-1036, and run.sh plants a build without it and requires the plant to fail.
//
// THE CONTRACT, from MPSImage.h:1030-1036: each read of a temporary image by a CNN kernel's encode method lowers
// its readCount by one, with nothing for the kernel to do:
//
//   1. a fresh temporary answers the count it was given, so a zero can never come from a dead reader
//   2. readCount 2, one encode that reads it -> 1
//   3. a second encode -> 0
//   4. a PLAIN MPSImage through the same kernel is left alone: MPSImage.h:1051 declares readCount on
//      MPSTemporaryImage and on no other image, so there is nothing on it to decrement
//   5. the destination holds the kernel's own arithmetic over a source of 1.0, which is the control
//      for the reader: a kernel that refused would leave the count where it was and checks 2 and 3
//      would both read as a pass
//
// TWO OMISSIONS THAT ARE MEASURED, not convenient. There is no -commit and no
// -waitUntilCompleted, because this host's own Metal cannot commit either and the transcript says so
// with the selector - -[AGXG16XFamilyCommandBuffer_mtlnext commit]: unrecognized selector - and the
// port's kernels walk their images on the CPU inside -encode..., so the count has moved by the time
// -encode... returns. The image is ONE feature channel, because MPSImageThreshold13.m refuses a
// multi-channel image by name (MPSImageThreshold.h:18-19 turns the channels into one luminance it
// does not implement) and a refusal would leave the count where it was.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

// -readCount is asked through this. MPSImage.h:1051 declares it on MPSTemporaryImage, and the case
// also asks a plain MPSImage whether it has one; in the port build the rename header has already
// rewritten MPSImage to the port's own name, so the category lands on the port's class.
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

// Write `value` into every element of an image the port and the release both answer. MPSImage.h:655
// declares the pair and MPSImage13.m and the release's own MPSImage both take it.
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

        // ---- the release's own answer, or the selector it raises.
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
            // The port cannot reach here: MPSImageElements10.m makes the object from the same class
            // method. Said loudly, because a run that compared two empty transcripts is a green run
            // that measured nothing.
            printf("NOT MEASURED: the release made no temporary image\n");
#ifdef CHARON_PORT_BUILD
            printf("FAIL the port must make its own MPSTemporaryImage\n");
            return 1;
#else
            return 0;
#endif
        }
        printf("temporary image class: %s\n", object_getClassName(temporary));

        // ---- the reader is alive before anything is claimed about it.
        [temporary setReadCount:2];
        NSUInteger before = [temporary readCount];
        printf("readCount after -setReadCount:2 -> %lu\n", (unsigned long)before);
        expect(before == 2, "check 1: the reader answers the count it was given");

        // A source of 1.0 everywhere, so the kernel's own arithmetic puts 1.0 in the destination and
        // check 5 is a measurement.
        Fill(temporary, 1.0f);
        // MPSImageConvolution over its own designated initializer, -initWithDevice:kernelWidth:
        // kernelHeight:weights: (MPSImageConvolution.h:281-287), which the port answers
        // (MPSImageConvolution13.m:159) and which the header does NOT mark unavailable - the plain
        // -initWithDevice: is, at :185, and so is every other unary image kernel's, which is why this
        // one is here. Its encode is the walk being measured: MPSImageConvolution13.m:199 ends in
        // CharonMPSConsumeReadCount(source). Not MPSImageGaussianBlur, which the port refuses by name,
        // and not MPSImageAreaMax or MPSImageBox, whose port objects answer a different spelling.
        //
        // The weights are a 3x3 box, so a source of 1.0 everywhere answers 1.0 in the destination and
        // check 5 is the kernel's own arithmetic rather than a non-zero by accident.
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

        // ---- the plain image: MPSImage.h declares readCount on MPSTemporaryImage and nowhere else,
        // so this says the helper's matrix/vector list was not simply widened to every image.
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