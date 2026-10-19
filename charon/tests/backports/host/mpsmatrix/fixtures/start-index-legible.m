// start-index-legible.m — what does MPSMatrixSum's startIndex move into, in numbers a float16 can hold.
//
// The earlier table's products reached 2^62 and the host evaluated them in float16, so the answers were
// not whole powers of two and nothing could be read off them. Here every value is small: four sources of
// {1, 1, 1, 1} scaled by four factors of {2, 4, 8, 16}, so every product is 2, 4, 8 or 16, the largest is
// 64 against float16's 65504, and a sum of terms reads as a set of powers of two that can be attributed
// to pairs. Three sources and four factors as well, so "the factors stop" and "the pairs stop" cannot
// both fit.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)

static void once(id<MTLDevice> d, id<MTLCommandQueue> q, NSUInteger sourceCount, NSUInteger factorCount,
                 NSUInteger count, NSUInteger start)
{
    float sources[4][4] = {{1,1,1,1}, {2,2,2,2}, {4,4,4,4}, {8,8,8,8}};
    float factors[4] = {2, 4, 8, 16};
    float sentinel[4] = {-1, -1, -1, -1};
    id<MTLBuffer> ob = [d newBufferWithBytes:sentinel length:sizeof(sentinel) options:MTLResourceStorageModeShared];
    NSMutableArray *matrices = [NSMutableArray array];
    for (NSUInteger i = 0; i < sourceCount; i++) {
        id<MTLBuffer> b = [d newBufferWithBytes:sources[i] length:sizeof(sources[i]) options:MTLResourceStorageModeShared];
        MPSMatrixDescriptor *md = [MPSMatrixDescriptor matrixDescriptorWithRows:1 columns:4 matrices:1
                                                                         rowBytes:4 * sizeof(float)
                                                                      matrixBytes:4 * sizeof(float) dataType:MPSDataTypeFloat32];
        [matrices addObject:[[MPSMatrix alloc] initWithBuffer:b descriptor:md]];
    }
    MPSMatrixDescriptor *rd = [MPSMatrixDescriptor matrixDescriptorWithRows:1 columns:4 matrices:1
                                                                 rowBytes:4 * sizeof(float)
                                                              matrixBytes:4 * sizeof(float) dataType:MPSDataTypeFloat32];
    MPSVector *fv = [[MPSVector alloc] initWithBuffer:[d newBufferWithBytes:factors length:factorCount * sizeof(float) options:MTLResourceStorageModeShared]
                                    descriptor:[MPSVectorDescriptor vectorDescriptorWithLength:factorCount vectors:1
                                                                                     vectorBytes:factorCount * sizeof(float) dataType:MPSDataTypeFloat32]];
    MPSMatrixSum *k = [[MPSMatrixSum alloc] initWithDevice:d count:count rows:1 columns:4 transpose:NO];
    id<MTLCommandBuffer> cb = [q commandBufferWithUnretainedReferences];
    [k encodeToCommandBuffer:cb sourceMatrices:matrices
                 resultMatrix:[[MPSMatrix alloc] initWithBuffer:ob descriptor:rd]
                 scaleVector:fv offsetVector:nil biasVector:nil startIndex:start];
    [cb commit];
    [cb waitUntilCompleted];
    float out[4] = {0, 0, 0, 0};
    memcpy(out, [ob contents], sizeof(out));
    P("  %lu sources, %lu factors, count %lu, start %lu ->", (unsigned long)sourceCount, (unsigned long)factorCount,
      (unsigned long)count, (unsigned long)start);
    for (int i = 0; i < 4; i++) P(" %g", out[i]);
    P("\n");
}

int main(void) { @autoreleasepool {
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> q = [d newCommandQueue];
    P("source i holds i+1 in every column; factor j is 2^(j+1). A pair (i, j) gives (i+1)*2^(j+1).\n"
      "Every product is at most 64, well inside float16's 65504, so a sum reads as a set of terms.\n\n");
    for (NSUInteger start = 0; start <= 4; start++) once(d, q, 4, 4, 2, start);
    P("\nThree sources and four factors: if the sources were the bound, the answers would change.\n\n");
    for (NSUInteger start = 0; start <= 4; start++) once(d, q, 3, 4, 2, start);
} return 0; }
