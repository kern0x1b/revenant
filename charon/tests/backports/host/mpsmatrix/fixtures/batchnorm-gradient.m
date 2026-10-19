// batchnorm-gradient.m — does the host compute MPSMatrixBatchNormalizationGradient at all?
//
// The three gradient cases come back zeros from the release against real values here, which is not
// rounding. So: does the encode report an error, is the destination the buffer being read back, and
// does the host need a state object from the forward pass before the gradient means anything?
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)

int main(void) { @autoreleasepool {
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> q = [d newCommandQueue];
    float src[12] = {1,2,3, 4,5,7, 2,8,1, 9,1,5};
    float inc[12] = {1,2,3, 4,5,7, 2,8,1, 9,1,5};
    float mean[3] = {4,5,4}, var[3] = {8,6,6}, gam[3] = {1.5f, 0.75f, 2.0f};
    id<MTLBuffer> inb  = [d newBufferWithBytes:src length:48 options:MTLResourceStorageModeShared];
    id<MTLBuffer> incb = [d newBufferWithBytes:inc length:48 options:MTLResourceStorageModeShared];
    id<MTLBuffer> mb   = [d newBufferWithBytes:mean length:12 options:MTLResourceStorageModeShared];
    id<MTLBuffer> vb   = [d newBufferWithBytes:var length:12 options:MTLResourceStorageModeShared];
    id<MTLBuffer> gb   = [d newBufferWithBytes:gam length:12 options:MTLResourceStorageModeShared];
    id<MTLBuffer> outb = [d newBufferWithLength:48 options:MTLResourceStorageModeShared];
    // A sentinel in both per-parameter destinations: a fresh buffer is already zero, so writing zero
    // and writing nothing are indistinguishable without it.
    float sentinel[3] = {-1.0f, -1.0f, -1.0f};
    id<MTLBuffer> ggb  = [d newBufferWithBytes:sentinel length:sizeof(sentinel) options:MTLResourceStorageModeShared];
    id<MTLBuffer> gbb  = [d newBufferWithBytes:sentinel length:sizeof(sentinel) options:MTLResourceStorageModeShared];

    MPSMatrixDescriptor *md = [MPSMatrixDescriptor matrixDescriptorWithRows:4 columns:3 matrices:1
                                                                     rowBytes:12 matrixBytes:48 dataType:MPSDataTypeFloat32];
    MPSMatrix *in = [[MPSMatrix alloc] initWithBuffer:inb descriptor:md];
    MPSMatrix *ig = [[MPSMatrix alloc] initWithBuffer:incb descriptor:md];
    MPSMatrix *out = [[MPSMatrix alloc] initWithBuffer:outb descriptor:md];
    MPSVectorDescriptor *vd = [MPSVectorDescriptor vectorDescriptorWithLength:3 vectors:1 vectorBytes:12 dataType:MPSDataTypeFloat32];
    MPSVector *mv = [[MPSVector alloc] initWithBuffer:mb descriptor:vd];
    MPSVector *vv = [[MPSVector alloc] initWithBuffer:vb descriptor:vd];
    MPSVector *gv = [[MPSVector alloc] initWithBuffer:gb descriptor:vd];
    MPSVector *gg = [[MPSVector alloc] initWithBuffer:ggb descriptor:vd];
    MPSVector *gbeta = [[MPSVector alloc] initWithBuffer:gbb descriptor:vd];
    P("identity: out.data == outb %d, gg.data == ggb %d, gbeta.data == gbb %d\n",
      out.data == outb, gg.data == ggb, gbeta.data == gbb);

    // The forward first, and its status, so the gradient is asked after a pass that ran.
    id<MTLCommandBuffer> fwd = [q commandBufferWithUnretainedReferences];
    MPSMatrixBatchNormalization *f = [[MPSMatrixBatchNormalization alloc] initWithDevice:d];
    f.epsilon = 0.001f;
    [f encodeToCommandBuffer:fwd inputMatrix:in meanVector:mv varianceVector:vv gammaVector:gv betaVector:nil resultMatrix:out];
    [fwd commit]; [fwd waitUntilCompleted];
    P("forward: status %d error %s\n", (int)fwd.status, fwd.error ? fwd.error.localizedDescription.UTF8String : "(none)");
    float fv[12] = {0}; memcpy(fv, [outb contents], 48);
    P("forward wrote:"); for (int i = 0; i < 12; i++) P(" %g", fv[i]); P("\n");

    // The gradient, and its status.
    id<MTLCommandBuffer> cb = [q commandBufferWithUnretainedReferences];
    MPSMatrixBatchNormalizationGradient *g = [[MPSMatrixBatchNormalizationGradient alloc] initWithDevice:d];
    g.epsilon = 0.001f;
    [g encodeToCommandBuffer:cb gradientMatrix:ig inputMatrix:in meanVector:mv varianceVector:vv
                gammaVector:gv betaVector:nil resultGradientForDataMatrix:out
           resultGradientForGammaVector:gg resultGradientForBetaVector:gbeta];
    [cb commit]; [cb waitUntilCompleted];
    P("gradient: status %d error %s\n", (int)cb.status, cb.error ? cb.error.localizedDescription.UTF8String : "(none)");
    float d12[12] = {0}, g3[3] = {0}, b3[3] = {0};
    memcpy(d12, [outb contents], 48); memcpy(g3, [ggb contents], 12); memcpy(b3, [gbb contents], 12);
    P("gradient data:"); for (int i = 0; i < 12; i++) P(" %g", d12[i]);
    P("\ngradient gamma:"); for (int i = 0; i < 3; i++) P(" %g", g3[i]);
    P("\ngradient beta:"); for (int i = 0; i < 3; i++) P(" %g", b3[i]);
    P("\n");
} return 0; }
