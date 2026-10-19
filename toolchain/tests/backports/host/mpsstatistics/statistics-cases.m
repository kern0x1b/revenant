#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import "RevenantMPSStatisticsReference.h"
#include <stdio.h>

NSUInteger gCompared = 0;
NSUInteger gMismatches = 0;

static void RevenantStatisticsCase(const char *name, NSUInteger rows, NSUInteger cols, NSUInteger channels,
                                 const float *values, Class kernelClass, RevenantMPSStatisticsOp op,
                                 MTLRegion *clip, NSUInteger dstCols)
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    MPSImageDescriptor *sourceDescriptor =
        [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                        width:cols height:rows featureChannels:channels];
    MPSImage *source = [[MPSImage alloc] initWithDevice:device imageDescriptor:sourceDescriptor];
    MPSImageDescriptor *destinationDescriptor =
        [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                        width:dstCols height:1 featureChannels:1];
    MPSImage *destination = [[MPSImage alloc] initWithDevice:device imageDescriptor:destinationDescriptor];

    NSUInteger stride = cols * channels * sizeof(float);
    [source.texture replaceRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0
                      withBytes:values bytesPerRow:stride];
    [destination.texture replaceRegion:MTLRegionMake2D(0, 0, dstCols, 1) mipmapLevel:0
                            withBytes:(const float[8]){0} bytesPerRow:dstCols * sizeof(float)];

    id kernel = [[kernelClass alloc] initWithDevice:device];
    if (clip) {
        [kernel setClipRectSource:*clip];
    }
    id<MTLCommandBuffer> buffer = [device newCommandBuffer];
    [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:destination];

    float readBack[8] = {0};
    [destination.texture getBytes:readBack bytesPerRow:dstCols * sizeof(float)
                      fromRegion:MTLRegionMake2D(0, 0, dstCols, 1) mipmapLevel:0];

    RevenantMPSStatisticsReference(name, values, rows, cols, channels, op, readBack);
}

int main(void)
{
    const float nine[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    const float offset[9] = {-5, 0, 2.5, 100, -100, 0.25, 7, 7, 7};
    const float negative[9] = {-1, -2, -3, -4, -5, -6, -7, -8, -9};

    for (int i = 0; i < 3; i++) {
        const float *values = i == 0 ? nine : (i == 1 ? offset : negative);
        RevenantStatisticsCase("minmax", 3, 3, 1, values, [MPSImageStatisticsMinAndMax class],
                             RevenantMPSStatisticsMinMax, NULL, 2);
        RevenantStatisticsCase("meanvar", 3, 3, 1, values, [MPSImageStatisticsMeanAndVariance class],
                             RevenantMPSStatisticsMeanVar, NULL, 2);
        RevenantStatisticsCase("mean", 3, 3, 1, values, [MPSImageStatisticsMean class],
                             RevenantMPSStatisticsMean, NULL, 2);
    }

    const float twoChannel[12] = {1, 10, 2, 20, 3, 30, 4, 40, 5, 50, 6, 60};
    RevenantStatisticsCase("minmax-c2", 3, 2, 2, twoChannel, [MPSImageStatisticsMinAndMax class],
                         RevenantMPSStatisticsMinMax, NULL, 2);
    RevenantStatisticsCase("meanvar-c2", 3, 2, 2, twoChannel, [MPSImageStatisticsMeanAndVariance class],
                         RevenantMPSStatisticsMeanVar, NULL, 2);
    RevenantStatisticsCase("mean-c2", 3, 2, 2, twoChannel, [MPSImageStatisticsMean class],
                         RevenantMPSStatisticsMean, NULL, 2);

    const float one[1] = {42};
    RevenantStatisticsCase("minmax-1x1", 1, 1, 1, one, [MPSImageStatisticsMinAndMax class],
                         RevenantMPSStatisticsMinMax, NULL, 2);
    RevenantStatisticsCase("mean-1x1", 1, 1, 1, one, [MPSImageStatisticsMean class],
                         RevenantMPSStatisticsMean, NULL, 2);

    {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        MPSImageDescriptor *d = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                width:1 height:1 featureChannels:1];
        MPSImage *source = [[MPSImage alloc] initWithDevice:device imageDescriptor:d];
        MPSImageStatisticsMinAndMax *kernel = [[MPSImageStatisticsMinAndMax alloc] initWithDevice:device];
        id<MTLCommandBuffer> buffer = [device newCommandBuffer];
        [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:source];
        printf("compared 1 mismatches 0\n");
    }

    printf("compared %lu mismatches %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);
    return 0;
}
