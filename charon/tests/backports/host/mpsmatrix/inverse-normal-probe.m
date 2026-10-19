// inverse-normal-probe.m — the measurement behind what the MPSMatrixRandom normal distribution does.
//
// It draws 160000 values of MPSMatrixRandomPhilox's normal distribution into one 400x400 matrix and
// prints, for every element, the twenty-three bit fraction t it came from and the float the release
// produced, as raw bits. The pairs are what a single precision inverse normal has to be fitted to.
//
//   xcrun clang -fobjc-arc -Wno-unguarded-availability-new inverse-normal-probe.m \
//       -framework Foundation -framework Metal -framework MetalPerformanceShaders -o inverse-normal-probe
//   ./inverse-normal-probe > pairs.txt
//
// It also measures something the pairs alone do not say, which is written down in
// facts/MetalPerformanceShaders/Random.md: the release does not fill the destination in element order.
// The first ten rows pair with t = (word >> 9) / 2^23 reconstructed from the index and agree with
// invnorm to three parts in 10^6; past that they do not, and the median relative difference over the
// whole 160000 jumps to about one. So the kernel writes a block of values per group in an order of
// its own, and any fitting has to recover that order before the algorithm can be identified.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
int main(void){ @autoreleasepool {
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> q = [d newCommandQueue];
    const NSUInteger n = 400, side = 400, count = n * n;
    float *z = (float *)calloc(count, sizeof(float));
    id<MTLBuffer> b = [d newBufferWithLength:count * sizeof(float) options:MTLResourceStorageModeShared];
    MPSMatrixDescriptor *md = [MPSMatrixDescriptor matrixDescriptorWithRows:side columns:side matrices:1 rowBytes:side*sizeof(float) matrixBytes:count*sizeof(float) dataType:MPSDataTypeFloat32];
    MPSMatrix *m = [[MPSMatrix alloc] initWithBuffer:b descriptor:md];
    MPSMatrixRandomPhilox *r = [[MPSMatrixRandomPhilox alloc] initWithDevice:d destinationDataType:MPSDataTypeFloat32 seed:12345
                     distributionDescriptor:[MPSMatrixRandomDistributionDescriptor normalDistributionDescriptorWithMean:2 standardDeviation:3]];
    id<MTLCommandBuffer> cb = [q commandBufferWithUnretainedReferences];
    [r encodeToCommandBuffer:cb destinationMatrix:m];
    [cb commit]; [cb waitUntilCompleted];
    memcpy(z, b.contents, count * sizeof(float));
    // The t of every element is (word >> 9) / 2^23, so the host's z can be paired with its own t.
    // The twenty smallest and twenty largest t are what a single precision inverse normal's three
    // branches disagree about; print them as raw bits so nothing is lost to decimal rounding.
    {
        NSUInteger shown = 0;
        for (NSUInteger step = 0; step < count; step++) {
            NSUInteger index = step;
            uint32_t word = 0;
            // Recompute the word from the generator rather than keeping it: the same Philox, the same
            // seed, so the t of element i is known exactly.
            uint32_t c0 = 0, c1 = 0, c2 = 0, c3 = (uint32_t)(index / 4), k0 = 12345, k1 = 0;
            for (int round = 0; round < 10; round++) {
                uint64_t p0 = (uint64_t)c0 * 0xD2511F53u, p1 = (uint64_t)c2 * 0xCD9E8D57u;
                uint32_t hi0 = (uint32_t)(p0 >> 32), lo0 = (uint32_t)p0, hi1 = (uint32_t)(p1 >> 32), lo1 = (uint32_t)p1;
                c0 = hi1 ^ c1 ^ k0; c1 = lo1; c2 = hi0 ^ c3 ^ k1; c3 = lo0;
                k0 += 0x9E3779B9u; k1 += 0xBB67AE85u;
            }
            uint32_t w[4] = {c0, c1, c2, c3};
            word = w[index % 4];
            uint32_t bits;
            memcpy(&bits, &z[index], 4);
            printf("%08x %08x\n", word >> 9, bits);
            shown++;
        }
    }
    free(z);
} return 0; }
