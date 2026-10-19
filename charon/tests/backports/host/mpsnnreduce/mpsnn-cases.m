#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import "CharonNNReduceReference.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

NSUInteger gCompared = 0;
NSUInteger gMismatches = 0;

static id<MTLDevice> CharonDevice(void)
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        fprintf(stderr, "no Metal device on this host, so there is nothing to walk an image with\n");
        exit(2);
    }
    return device;
}

static const float kSource[3 * 4 * 4] = {
     1,  10,  -1, 0.5,   2,  20,  -2, 1.5,   3,  30,  -3, 2.5,   4,  40,  -4, 3.5,
     5,  50,  -5, 4.5,   6,  60,  -6, 5.5,   7,  70,  -7, 6.5,   8,  80,  -8, 7.5,
     9,  90,  -9, 8.5,  10, 100, -10, 9.5,  11, 110, -11, 10.5,  12, 120, -12, 11.5,
};

#define ROWS 3
#define COLS 4
#define CHANNELS 4

static MPSImage *CharonMakeSource(id<MTLDevice> device)
{
    MPSImageDescriptor *descriptor =
        [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                         width:COLS
                                                        height:ROWS
                                                featureChannels:CHANNELS];
    MPSImage *image = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];
    [[image texture] replaceRegion:MTLRegionMake2D(0, 0, COLS, ROWS) mipmapLevel:0
                          withBytes:kSource bytesPerRow:COLS * CHANNELS * sizeof(float)];
    return image;
}

static void CharonReadBack(MPSImage *image, float *out, NSUInteger cols, NSUInteger rows, NSUInteger channels)
{
    memset(out, 0, cols * rows * channels * sizeof(float));
    [[image texture] getBytes:out bytesPerRow:cols * channels * sizeof(float)
                     fromRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0];
}

static Class CharonReduceClass(int index)
{
    Class classes[12] = {
        [MPSNNReduceRowMin class],              [MPSNNReduceColumnMin class],
        [MPSNNReduceFeatureChannelsMin class],  [MPSNNReduceRowMax class],
        [MPSNNReduceColumnMax class],           [MPSNNReduceFeatureChannelsMax class],
        [MPSNNReduceRowMean class],             [MPSNNReduceColumnMean class],
        [MPSNNReduceFeatureChannelsMean class], [MPSNNReduceRowSum class],
        [MPSNNReduceColumnSum class],           [MPSNNReduceFeatureChannelsSum class],
    };
    return classes[index];
}

static const char *CharonReduceName(int index)
{
    static const char *names[12] = {
        "reduce-row-min",              "reduce-column-min",              "reduce-feature-channels-min",
        "reduce-row-max",              "reduce-column-max",              "reduce-feature-channels-max",
        "reduce-row-mean",             "reduce-column-mean",             "reduce-feature-channels-mean",
        "reduce-row-sum",              "reduce-column-sum",              "reduce-feature-channels-sum",
    };
    return names[index];
}

static int CharonReduceByColumn(int index)  { return (index % 3) == 1; }
static int CharonReduceByFeature(int index) { return (index % 3) == 2; }
static CharonNNReduceOp CharonReduceOp(int index) { return (CharonNNReduceOp)(index / 3); }

int main(int argc, const char **argv)
{
    int fromSystem = (argc > 1 && strcmp(argv[1], "--system") == 0);
    id<MTLDevice> device = CharonDevice();
    id<MTLCommandQueue> queue = [device newCommandQueue];

    printf("compared %lu mismatches %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);

    for (int index = 0; index < 12; index++) {
        Class kernelClass = CharonReduceClass(index);
        NSString *present = kernelClass ? NSStringFromClass(kernelClass) : @"(nil)";
        printf("port  %-28s class %s\n", CharonReduceName(index), [present UTF8String]);

        if (fromSystem) {
            @try {
                id oneBuffer = [queue commandBufferWithUnretainedReferences];
                id kernel = [[kernelClass alloc] initWithDevice:device];
                MPSImage *source = CharonMakeSource(device);
                [kernel encodeToCommandBuffer:oneBuffer sourceImage:source destinationImage:source];
                [oneBuffer commit];
                [oneBuffer waitUntilCompleted];
                printf("      system: encoded\n");
            } @catch (NSException *exception) {
                printf("      system: %s: %s\n", [[exception name] UTF8String],
                       [[exception reason] UTF8String]);
            }
            continue;
        }

        MPSImage *source = CharonMakeSource(device);
        NSUInteger dstCols = CharonReduceByFeature(index) ? COLS : (CharonReduceByColumn(index) ? COLS : 1);
        NSUInteger dstRows = CharonReduceByFeature(index) ? ROWS : (CharonReduceByColumn(index) ? 1 : ROWS);
        NSUInteger dstChannels = CharonReduceByFeature(index) ? 1 : CHANNELS;
        MPSImageDescriptor *descriptor =
            [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                             width:dstCols
                                                            height:dstRows
                                                    featureChannels:dstChannels];
        MPSImage *destination = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];

        id kernel = [[kernelClass alloc] initWithDevice:device];
        id commandBuffer = [queue commandBufferWithUnretainedReferences];
        int weighted = 0;
        if (CharonReduceByFeature(index) && [kernel respondsToSelector:@selector(setWeight:)]) {
            [kernel setWeight:0.5f];
            weighted = 1;
        }

        [kernel encodeToCommandBuffer:commandBuffer sourceImage:source destinationImage:destination];
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        float got[ROWS * COLS * CHANNELS];
        CharonReadBack(destination, got, dstCols, dstRows, dstChannels);

        CharonNNReduceReference(CharonReduceName(index), kSource, ROWS, COLS, CHANNELS,
                                CharonReduceByColumn(index), CharonReduceByFeature(index),
                                CharonReduceOp(index), 0.5f, weighted, got, dstCols, dstChannels);
    }

    {
        Class kernelClass = CharonReduceClass(9);
        MPSImage *source = CharonMakeSource(device);
        MPSImageDescriptor *tooSmall =
            [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                             width:1
                                                            height:1
                                                    featureChannels:1];
        MPSImage *destination = [[MPSImage alloc] initWithDevice:device imageDescriptor:tooSmall];
        const float sentinel = -12345.0f;
        [[destination texture] replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0
                                 withBytes:&sentinel bytesPerRow:sizeof(float)];
        id refusalBuffer = [queue commandBufferWithUnretainedReferences];
        id kernel = [[kernelClass alloc] initWithDevice:device];
        [kernel encodeToCommandBuffer:refusalBuffer sourceImage:source destinationImage:destination];
        [refusalBuffer commit];
        [refusalBuffer waitUntilCompleted];
        float got[1] = {0.0f};
        CharonReadBack(destination, got, 1, 1, 1);
        gCompared++;
        if (got[0] != sentinel) {
            gMismatches++;
            printf("\n  MISMATCH a destination too small for the count was written to anyway: %g,"
                   " and the value there was %g before the encode\n", got[0], sentinel);
        }
        printf("\n  refusal reduce-row-sum into a 1x1x1 destination: left as it was (%g)\n", got[0]);
    }

    {
        MPSImage *source = CharonMakeSource(device);
        id sum = [[CharonReduceClass(11) alloc] initWithDevice:device];
        [sum setWeight:0.5f];

        for (int which = 2; which <= 5; which += 3) {
            MPSImageDescriptor *descriptor =
                [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                 width:COLS
                                                                height:ROWS
                                                        featureChannels:1];
            MPSImage *destination = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];
            id kernel = [[CharonReduceClass(which) alloc] initWithDevice:device];
            id buffer = [queue commandBufferWithUnretainedReferences];
            [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:destination];
            [buffer commit];
            [buffer waitUntilCompleted];
            float got[ROWS * COLS];
            CharonReadBack(destination, got, COLS, ROWS, 1);
            CharonNNReduceReference(CharonReduceName(which), kSource, ROWS, COLS, CHANNELS,
                                    0, 1, CharonReduceOp(which), 1.0f, 0, got, COLS, 1);
        }
    }

    printf("compared %lu mismatches %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);
    return 0;
}
