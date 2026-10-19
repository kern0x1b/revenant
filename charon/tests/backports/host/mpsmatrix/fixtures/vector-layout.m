// vector-layout.m — what the host's own MPSVector and MPSMatrix hold after a program writes them.
//
// The startIndex table would not decode, and its answers carry low fractional bits where a product of
// two whole powers of two cannot: 2^-15 is what a float16 read looks like. So before any arithmetic on
// those numbers, read the buffers back and print what is in them - the bytes, the dataType and the
// rowBytes each object reports - so the inputs are known rather than assumed.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)

static void dump(const char *label, id<MTLBuffer> buffer, NSUInteger length)
{
    const unsigned char *bytes = (const unsigned char *)[buffer contents];
    P("  %-10s buffer %p length %zu  bytes:", label, (__bridge const void *)buffer, length);
    for (NSUInteger i = 0; i < MIN(length, (NSUInteger)16); i++) P(" %02x", bytes[i]);
    P("\n");
    P("  %-10s as float32:", label);
    for (NSUInteger i = 0; i < MIN(length / 4, (NSUInteger)8); i++)
        P(" %g", (double)(((const float *)bytes)[i]));
    P("\n");
}

int main(void) { @autoreleasepool {
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();

    // A vector of four factors, described exactly as MPSVector.h says: Float32, four long, one vector,
    // a four float stride.
    float factors[4] = {16, 32, 64, 128};
    id<MTLBuffer> fb = [d newBufferWithBytes:factors length:sizeof(factors) options:MTLResourceStorageModeShared];
    MPSVectorDescriptor *vd = [MPSVectorDescriptor vectorDescriptorWithLength:4 vectors:1
                                                                  vectorBytes:4 * sizeof(float) dataType:MPSDataTypeFloat32];
    MPSVector *v = [[MPSVector alloc] initWithBuffer:fb descriptor:vd];
    P("MPSVector: length %lu vectors %lu vectorBytes %lu dataType %d\n",
      (unsigned long)v.length, (unsigned long)v.vectors, (unsigned long)v.vectorBytes, (int)v.dataType);
    P("  v.data == fb: %d\n", v.data == fb);
    dump("vector", fb, sizeof(factors));

    // And a 1x4 matrix, the shape the probe used.
    float row[4] = {1, 2, 4, 8};
    id<MTLBuffer> mb = [d newBufferWithBytes:row length:sizeof(row) options:MTLResourceStorageModeShared];
    MPSMatrixDescriptor *md = [MPSMatrixDescriptor matrixDescriptorWithRows:1 columns:4 matrices:1
                                                                     rowBytes:4 * sizeof(float)
                                                                  matrixBytes:4 * sizeof(float) dataType:MPSDataTypeFloat32];
    MPSMatrix *m = [[MPSMatrix alloc] initWithBuffer:mb descriptor:md];
    P("MPSMatrix: rows %lu columns %lu matrices %lu rowBytes %lu matrixBytes %lu dataType %d\n",
      (unsigned long)m.rows, (unsigned long)m.columns, (unsigned long)m.matrices,
      (unsigned long)m.rowBytes, (unsigned long)m.matrixBytes, (int)m.dataType);
    P("  m.data == mb: %d\n", m.data == mb);
    dump("matrix", mb, sizeof(row));
} return 0; }
