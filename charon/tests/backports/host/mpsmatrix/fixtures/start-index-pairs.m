// start-index-pairs.m — what does MPSMatrixSum's startIndex move into?
//
// The same sum at several startIndex values, with every source and every scale factor a distinct power
// of two, so the answer says which pair went in. If it is the factors that stop, a factor that is
// missing leaves a gap; if it is the (factor, source) list that stops, the sum is over the first
// sources with the factors from startIndex. The two differ and the table tells them apart.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)

static void once(id<MTLDevice> d, id<MTLCommandQueue> q, const float *sources, NSUInteger sourceCount,
                 const float *factors, NSUInteger factorCount, NSUInteger count, NSUInteger start)
{
    // Four factors, four sources, each a different power of two: source 0 is 1, source 1 is 2, source 2
    // is 4, source 3 is 8; factor 0 is 16, factor 1 is 32, factor 2 is 64, factor 3 is 128.
    NSUInteger resultLength = 1 * 4 * sizeof(float);
    float sentinel[4] = {-1, -1, -1, -1};
    id<MTLBuffer> ob = [d newBufferWithBytes:sentinel length:resultLength options:MTLResourceStorageModeShared];
    NSMutableArray *matrices = [NSMutableArray array];
    for (NSUInteger i = 0; i < sourceCount; i++) {
        float one[4] = {sources[i * 4], sources[i * 4 + 1], sources[i * 4 + 2], sources[i * 4 + 3]};
        id<MTLBuffer> b = [d newBufferWithBytes:one length:sizeof(one) options:MTLResourceStorageModeShared];
        MPSMatrixDescriptor *md = [MPSMatrixDescriptor matrixDescriptorWithRows:1 columns:4 matrices:1
                                                                         rowBytes:4 * sizeof(float) matrixBytes:4 * sizeof(float) dataType:MPSDataTypeFloat32];
        [matrices addObject:[[MPSMatrix alloc] initWithBuffer:b descriptor:md]];
    }
    MPSMatrixDescriptor *rd = [MPSMatrixDescriptor matrixDescriptorWithRows:1 columns:4 matrices:1
                                                                 rowBytes:4 * sizeof(float) matrixBytes:4 * sizeof(float) dataType:MPSDataTypeFloat32];
    MPSMatrixSum *k = [[MPSMatrixSum alloc] initWithDevice:d count:count rows:1 columns:4 transpose:NO];
    MPSVector *fv = [[MPSVector alloc] initWithBuffer:[d newBufferWithBytes:factors length:factorCount * sizeof(float) options:MTLResourceStorageModeShared]
                                    descriptor:[MPSVectorDescriptor vectorDescriptorWithLength:factorCount vectors:1
                                                                                     vectorBytes:factorCount * sizeof(float) dataType:MPSDataTypeFloat32]];
    id<MTLCommandBuffer> cb = [q commandBufferWithUnretainedReferences];
    [k encodeToCommandBuffer:cb sourceMatrices:matrices
                 resultMatrix:[[MPSMatrix alloc] initWithBuffer:ob descriptor:rd]
                 scaleVector:fv offsetVector:nil biasVector:nil startIndex:start];
    [cb commit];
    [cb waitUntilCompleted];
    float out[4] = {0, 0, 0, 0};
    memcpy(out, [ob contents], sizeof(out));
    P("  count %lu start %lu of %lu factors and %lu sources ->", (unsigned long)count, (unsigned long)start,
      (unsigned long)factorCount, (unsigned long)sourceCount);
    for (int i = 0; i < 4; i++) P(" %g", out[i]);
    P("\n");
}

int main(void) { @autoreleasepool {
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> q = [d newCommandQueue];
    // Four sources of four values, and four factors of four values, every one a different power of two.
    float sources[16] = {1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768};
    float factors[16] = {65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608,
                          16777216, 33554432, 67108864, 134217728, 268435456, 536870912, 1073741824, 2147483648};
    P("source i's four values start at 2^(0+4i); factor i's four start at 2^(16+4i).\n"
      "A single source and a single factor would give the product, so a sum of the two is a pair.\n"
      "\nNOT YET DECODED. The answers do not decompose as sums of those products: they carry low\n"
      "fractional bits where a product of two powers of two cannot, and they are three orders of\n"
      "magnitude below the smallest product the inputs allow. Whatever the host consumed here is not\n"
      "the scale vector as this program built it, so the table cannot yet say which pair went in, and\n"
      "no rule has been derived from it.\n\n");
    for (NSUInteger start = 0; start <= 3; start++) {
        once(d, q, sources, 4, factors, 4, 2, start);
    }
    P("\nThe same with three sources and four factors, so the two lists are different lengths.\n\n");
    for (NSUInteger start = 0; start <= 3; start++) {
        once(d, q, sources, 3, factors, 4, 2, start);
    }
} return 0; }
