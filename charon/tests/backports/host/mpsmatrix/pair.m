#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
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
