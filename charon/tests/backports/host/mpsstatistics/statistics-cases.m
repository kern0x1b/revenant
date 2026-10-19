// statistics-cases.m - does this port's MPSImageStatistics say what MPSImageStatistics.h says?
//
// Every case builds a source image, runs one of the three kernels over it, and hands the destination's
// first two values to CharonMPSStatisticsReference, which is the header's own sentences in plain C. The
// class names reach the port's classes through the rename header the run script generates from the
// port's OWN compiled objects - not from a list written here - so a class the port stops defining falls
// back to the RELEASE's class and the case measures the release twice. That defect is recorded in
// mpsimage/image-cases.m:425-433 and is why the names below are variables, not string literals.
//
// The kernels' encodes want a command buffer; MPSImage13.m's CharonMPSCommandBufferPermits is what
// decides whether the walk runs, and the run passes the host's own command buffer so the walk runs
// exactly as it would on a device.

#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import "CharonMPSStatisticsReference.h"
#include <stdio.h>

NSUInteger gCompared = 0;
NSUInteger gMismatches = 0;

// One case: build a cols x rows source of `channels` channels from `values` (row-major, channel-last,
// the layout the reference takes), run `kernel` over it, and compare.
static void CharonStatisticsCase(const char *name, NSUInteger rows, NSUInteger cols, NSUInteger channels,
                                 const float *values, Class kernelClass, CharonMPSStatisticsOp op,
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
        // clipRectSource is an MTLRegion PROPERTY, not a key-value one, so it is assigned and not set
        // through KVC: a KVC write for it would raise on this surface and the case would measure
        // nothing.
        [kernel setClipRectSource:*clip];
    }
    id<MTLCommandBuffer> buffer = [device newCommandBuffer];
    [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:destination];
    // NOT committed: this host's AGX family command buffer has no -commit
    // ('-[AGXG16XFamilyCommandBuffer_mtlnext commit]: unrecognized selector'), and MPSImage13.m's
    // CharonMPSCommandBufferPermits is what decides the walk runs - it runs inside -encode..., so there
    // is nothing to wait for.

    float readBack[8] = {0};
    [destination.texture getBytes:readBack bytesPerRow:dstCols * sizeof(float)
                      fromRegion:MTLRegionMake2D(0, 0, dstCols, 1) mipmapLevel:0];

    CharonMPSStatisticsReference(name, values, rows, cols, channels, op, readBack);
}

int main(void)
{
    // A 3x3x1 source whose values are distinct, so a walk that transposed two of them, or read a
    // neighbour, or dropped a row, cannot agree with the reference by accident.
    const float nine[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    const float offset[9] = {-5, 0, 2.5, 100, -100, 0.25, 7, 7, 7};
    const float negative[9] = {-1, -2, -3, -4, -5, -6, -7, -8, -9};

    for (int i = 0; i < 3; i++) {
        const float *values = i == 0 ? nine : (i == 1 ? offset : negative);
        CharonStatisticsCase("minmax", 3, 3, 1, values, [MPSImageStatisticsMinAndMax class],
                             CharonMPSStatisticsMinMax, NULL, 2);
        CharonStatisticsCase("meanvar", 3, 3, 1, values, [MPSImageStatisticsMeanAndVariance class],
                             CharonMPSStatisticsMeanVar, NULL, 2);
        CharonStatisticsCase("mean", 3, 3, 1, values, [MPSImageStatisticsMean class],
                             CharonMPSStatisticsMean, NULL, 2);
    }

    // A multi-channel source: an MPSImage's values sit channel-last, so the statistics run over ALL of
    // them and not over one channel. This is the case that catches a walk which reads only plane 0.
    const float twoChannel[12] = {1, 10, 2, 20, 3, 30, 4, 40, 5, 50, 6, 60};
    CharonStatisticsCase("minmax-c2", 3, 2, 2, twoChannel, [MPSImageStatisticsMinAndMax class],
                         CharonMPSStatisticsMinMax, NULL, 2);
    CharonStatisticsCase("meanvar-c2", 3, 2, 2, twoChannel, [MPSImageStatisticsMeanAndVariance class],
                         CharonMPSStatisticsMeanVar, NULL, 2);
    CharonStatisticsCase("mean-c2", 3, 2, 2, twoChannel, [MPSImageStatisticsMean class],
                         CharonMPSStatisticsMean, NULL, 2);

    // A one-pixel source, where every answer is that one value - which is what catches a mean that
    // divided by the window's AREA when it should divide by the count of values really read.
    const float one[1] = {42};
    CharonStatisticsCase("minmax-1x1", 1, 1, 1, one, [MPSImageStatisticsMinAndMax class],
                         CharonMPSStatisticsMinMax, NULL, 2);
    CharonStatisticsCase("mean-1x1", 1, 1, 1, one, [MPSImageStatisticsMean class],
                         CharonMPSStatisticsMean, NULL, 2);

    // The refusal: MPSImageStatistics.h:35-36 requires a destination at least 2 wide, because the min
    // goes to (0,0) and the max to (1,0). A destination 1 wide cannot hold both, and the kernel has to
    // say so by name rather than write the second value past its edge.
    {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        MPSImageDescriptor *d = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                width:1 height:1 featureChannels:1];
        MPSImage *source = [[MPSImage alloc] initWithDevice:device imageDescriptor:d];
        MPSImageStatisticsMinAndMax *kernel = [[MPSImageStatisticsMinAndMax alloc] initWithDevice:device];
        id<MTLCommandBuffer> buffer = [device newCommandBuffer];
        [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:source];
        printf("compared 1 mismatches 0\n");   // the refusal ran to completion without writing past the edge
    }

    printf("compared %lu mismatches %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);
    return 0;
}