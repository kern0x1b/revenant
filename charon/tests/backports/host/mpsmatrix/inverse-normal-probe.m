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
    {
        NSUInteger shown = 0;
        for (NSUInteger step = 0; step < count; step++) {
            NSUInteger index = step;
            uint32_t word = 0;
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
