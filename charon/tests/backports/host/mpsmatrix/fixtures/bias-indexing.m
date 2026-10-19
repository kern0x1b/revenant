#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)
// How does the release index MPSMatrixSum's bias? The same sum with four bias vectors: the
// difference from an all-zero bias says the rule directly.
static float runWith(id<MTLDevice> d, id<MTLCommandQueue> q, const float *bias, NSUInteger biasLen, int transpose) {
    float A[6] = {1,2,3,4,5,6}, B[6] = {10,20,30,40,50,60};
    float out[6]; memset(out, 0, sizeof(out));
    id<MTLBuffer> ab=[d newBufferWithBytes:A length:24 options:MTLResourceStorageModeShared];
    id<MTLBuffer> bb=[d newBufferWithBytes:B length:24 options:MTLResourceStorageModeShared];
    // A sentinel in every element, so a zero in the answer is a value the release wrote and a -1 is a
    // byte it never touched. The transposed case's third column reads zero, and zero is what a fresh
    // buffer already contains, so without this the two cannot be told apart.
    float sentinel[6] = {-1, -1, -1, -1, -1, -1};
    id<MTLBuffer> ob=[d newBufferWithBytes:sentinel length:24 options:MTLResourceStorageModeShared];
    MPSMatrixDescriptor *md=[MPSMatrixDescriptor matrixDescriptorWithRows:2 columns:3 matrices:1 rowBytes:12 matrixBytes:24 dataType:MPSDataTypeFloat32];
    MPSVector *bv = bias ? [[MPSVector alloc] initWithBuffer:[d newBufferWithBytes:bias length:biasLen*4 options:MTLResourceStorageModeShared]
                                 descriptor:[MPSVectorDescriptor vectorDescriptorWithLength:biasLen vectors:1 vectorBytes:biasLen*4 dataType:MPSDataTypeFloat32]] : nil;
    MPSMatrixSum *k=[[MPSMatrixSum alloc] initWithDevice:d count:2 rows:2 columns:3 transpose:transpose];
    P("    kernel rows %lu columns %lu transpose %d; result descriptor %lu x %lu rowBytes %lu\n",
      (unsigned long)k.rows, (unsigned long)k.columns, (int)transpose,
      (unsigned long)md.columns, (unsigned long)md.rows, (unsigned long)md.rowBytes);
    id<MTLCommandBuffer> cb=[q commandBufferWithUnretainedReferences];
    [k encodeToCommandBuffer:cb sourceMatrices:@[[[MPSMatrix alloc] initWithBuffer:ab descriptor:md],
                                                     [[MPSMatrix alloc] initWithBuffer:bb descriptor:md]]
                  resultMatrix:[[MPSMatrix alloc] initWithBuffer:ob descriptor:md]
                  scaleVector:nil offsetVector:nil biasVector:bv startIndex:0];
    [cb commit]; [cb waitUntilCompleted];
    memcpy(out, ob.contents, 24);
    P("    bias=");
    for (NSUInteger i=0;i<biasLen;i++) P(" %g", bias[i]);
    P(" ->");
    for (int i=0;i<6;i++) P(" %g", out[i]);
    P("\n");
    return 0;
}
int main(void){ @autoreleasepool {
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> q = [d newCommandQueue];
    P("transpose NO, sum = 11 22 33 / 44 55 66 (three columns)\n");
    float zero[3] = {0,0,0};
    float same[3] = {7,7,7};
    float cols[3] = {1,10,100};
    float rows[3] = {1,10,100};
    runWith(d,q,zero,3,0); runWith(d,q,same,3,0); runWith(d,q,cols,3,0);
    P("\ntranspose YES, the same six values read the other way\n");
    runWith(d,q,zero,3,1); runWith(d,q,same,3,1); runWith(d,q,rows,3,1);
} return 0; }
