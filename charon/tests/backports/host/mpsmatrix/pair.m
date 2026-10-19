// pair.m — the pairing that makes the release's normal distribution measurable.
//
// Two draws of the same shape and the same seed: one uniform over 0..1 and one normal with mean 2 and
// deviation 3. Both kernels walk the same counter in the same order, so the uniform's fraction at a
// position is the fraction that position's normal value came from - which is what makes 160000
// (t, z) pairs available whatever order they fill the destination in. Reconstructing t from the element
// index instead does not work: the fill is blocked by the shape, so a 4x4 destination pairs by index
// and a 400x400 one does not.
//
//   xcrun clang -fobjc-arc -Wno-unguarded-availability-new pair.m \
//       -framework Foundation -framework Metal -framework MetalPerformanceShaders -o pair
//   ./pair > pairs.txt
//
// Each line is the uniform value's bits and the normal value's bits, at the same position. What the
// release's inverse normal is, and how far this port's is from it, is written down in
// facts/MetalPerformanceShaders/Random.md.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
// Two draws of the same shape and the same seed, one uniform over 0..1 and one normal with mean 2 and
// deviation 3. If both kernels walk the same counter in the same order, the uniform's fraction at a
// position is the normal's fraction at that position, whatever order they fill in.
static void draw(id<MTLDevice> d, MPSMatrixRandomDistributionDescriptor *dist, float *out, NSUInteger side)
{
    id<MTLCommandQueue> q = [d newCommandQueue];
    id<MTLBuffer> b = [d newBufferWithLength:side*side*sizeof(float) options:MTLResourceStorageModeShared];
    MPSMatrixDescriptor *md = [MPSMatrixDescriptor matrixDescriptorWithRows:side columns:side matrices:1
                                                                     rowBytes:side*sizeof(float) matrixBytes:side*side*sizeof(float) dataType:MPSDataTypeFloat32];
    MPSMatrix *m = [[MPSMatrix alloc] initWithBuffer:b descriptor:md];
    MPSMatrixRandomPhilox *r = [[MPSMatrixRandomPhilox alloc] initWithDevice:d destinationDataType:MPSDataTypeFloat32
                                                                        seed:12345 distributionDescriptor:dist];
    id<MTLCommandBuffer> cb = [q commandBufferWithUnretainedReferences];
    [r encodeToCommandBuffer:cb destinationMatrix:m];
    [cb commit]; [cb waitUntilCompleted];
    memcpy(out, b.contents, side*side*sizeof(float));
}
int main(void){ @autoreleasepool {
    const NSUInteger side = 400, count = side*side;
    float *uniform = (float *)calloc(count, sizeof(float));
    float *normal = (float *)calloc(count, sizeof(float));
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    draw(d, [MPSMatrixRandomDistributionDescriptor uniformDistributionDescriptorWithMinimum:0 maximum:1], uniform, side);
    draw(d, [MPSMatrixRandomDistributionDescriptor normalDistributionDescriptorWithMean:2 standardDeviation:3], normal, side);
    for (NSUInteger i = 0; i < count; i++) {
        uint32_t tu, zn;
        memcpy(&tu, &uniform[i], 4);
        memcpy(&zn, &normal[i], 4);
        printf("%08x %08x\n", tu, zn);
    }
} return 0; }
