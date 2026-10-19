// crash-probe.m — the two destinations MPSMatrixRandom has that the MPS of macOS 26.5 does not answer.
// Run on its own, never from the differential: the first of these cases takes the process down inside
// the system framework, and an oracle that dies cannot answer the rest of a comparison.
//
//   xcrun clang -fobjc-arc -Wno-unguarded-availability-new crash-probe.m \
//       -framework Foundation -framework Metal -framework MetalPerformanceShaders -o crash-probe
//   ./crash-probe vector    # MPSVector destination
//   ./crash-probe batch     # a batch range over a matrix destination
//   ./crash-probe float32   # a Float32 destination, which the release does answer, kept as a control:
//                            # a run of this that answers is what says the others are the release's own
//                            # refusals rather than this harness's mistake.
//   ./crash-probe batch     # a batch range over a matrix destination
//
// Each prints what it asked for and then either the words the release produced or the line it died on.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

static id<MTLDevice> gDevice;

static void fill(MPSMatrixRandomPhilox *kernel, id destination, const char *what)
{
    printf("%s: asking\n", what);
    fflush(stdout);
    id<MTLCommandQueue> queue = [gDevice newCommandQueue];
    id<MTLCommandBuffer> buffer = [queue commandBufferWithUnretainedReferences];
    [kernel encodeToCommandBuffer:buffer destinationMatrix:destination];
    [buffer commit];
    [buffer waitUntilCompleted];
    printf("%s: answered\n", what);
    fflush(stdout);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        gDevice = MTLCreateSystemDefaultDevice();
        const char *which = argc > 1 ? argv[1] : "float32";

        if (strcmp(which, "float32") == 0) {
            float out[16];
            memset(out, 0, sizeof(out));
            id<MTLBuffer> storage = [gDevice newBufferWithLength:sizeof(out) options:MTLResourceStorageModeShared];
            MPSMatrixDescriptor *descriptor = [MPSMatrixDescriptor matrixDescriptorWithRows:4 columns:4 matrices:1 rowBytes:16 matrixBytes:64 dataType:MPSDataTypeFloat32];
            MPSMatrix *destination = [[MPSMatrix alloc] initWithBuffer:storage descriptor:descriptor];
            MPSMatrixRandomPhilox *kernel = [[MPSMatrixRandomPhilox alloc] initWithDevice:gDevice
                                                                   destinationDataType:MPSDataTypeFloat32
                                                                                   seed:0
                                                                     distributionDescriptor:[MPSMatrixRandomDistributionDescriptor uniformDistributionDescriptorWithMinimum:0 maximum:1]];
            fill(kernel, destination, "float32 destination, uniform 0..1");
            memcpy(out, storage.contents, sizeof(out));
            for (int i = 0; i < 8; i++)
                printf("  %.9g\n", out[i]);
            return 0;
        }

        if (strcmp(which, "vector") == 0) {
            struct { NSUInteger length, vectors; size_t vectorBytes; } shapes[] = {
                {4, 1, 16}, {8, 1, 32}, {16, 1, 64}, {2, 2, 16}, {4, 4, 16}, {1, 1, 4}, {8, 4, 32}
            };
            for (unsigned i = 0; i < sizeof(shapes) / sizeof(shapes[0]); i++) {
                size_t bytes = (shapes[i].vectors - 1) * shapes[i].vectorBytes + shapes[i].length * 4;
                uint32_t out[64];
                memset(out, 0, sizeof(out));
                id<MTLBuffer> storage = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
                MPSVectorDescriptor *descriptor = [MPSVectorDescriptor vectorDescriptorWithLength:shapes[i].length
                                                                                          vectors:shapes[i].vectors
                                                                                      vectorBytes:shapes[i].vectorBytes
                                                                                         dataType:MPSDataTypeUInt32];
                MPSVector *destination = [[MPSVector alloc] initWithBuffer:storage descriptor:descriptor];
                MPSMatrixRandomPhilox *kernel = [[MPSMatrixRandomPhilox alloc] initWithDevice:gDevice destinationDataType:MPSDataTypeUInt32 seed:0];
                char what[128];
                snprintf(what, sizeof(what), "vector destination length=%lu vectors=%lu vectorBytes=%lu",
                         (unsigned long)shapes[i].length, (unsigned long)shapes[i].vectors, (unsigned long)shapes[i].vectorBytes);
                @autoreleasepool {
                    fill(kernel, destination, what);
                }
            }
            return 0;
        }

        if (strcmp(which, "batch") == 0) {
            uint32_t out[12];
            memset(out, 0, sizeof(out));
            id<MTLBuffer> storage = [gDevice newBufferWithLength:sizeof(out) options:MTLResourceStorageModeShared];
            MPSMatrixDescriptor *descriptor = [MPSMatrixDescriptor matrixDescriptorWithRows:4 columns:1 matrices:3 rowBytes:4 matrixBytes:16 dataType:MPSDataTypeUInt32];
            MPSMatrix *destination = [[MPSMatrix alloc] initWithBuffer:storage descriptor:descriptor];
            MPSMatrixRandomPhilox *kernel = [[MPSMatrixRandomPhilox alloc] initWithDevice:gDevice destinationDataType:MPSDataTypeUInt32 seed:0];
            kernel.batchStart = 1;
            kernel.batchSize = 2;
            fill(kernel, destination, "batch range 1..3 of a 4x1x3 destination");
            return 0;
        }

        printf("usage: crash-probe float32 | vector | batch\n");
        return 2;
    }
}
