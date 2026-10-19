// gradient-jacobian.m — the whole ∂dX/∂dY of the host's batch-normalisation data gradient, by
// linearity, with no formula assumed.
//
// For a fixed source, dX is linear in dY, so running the host once per unit matrix e_ij gives the
// twelve columns of the Jacobian directly. Its structure is the formula: which entries are non-zero is
// the axis the operator runs over, whether the diagonal blocks are equal is whether the mean terms are
// there, and the diagonal itself is gamma over sigma - and which sigma is what the mean and variance
// arguments decide. Linearity is checked by comparing dY = e_1 + e_2 against the sum of the two
// single-unit answers.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <math.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)

#define N 4
#define C 3

static float src[N][C] = {{1, 3, 7}, {2, 9, 4}, {5, 1, 11}, {8, 6, 2}};
static float gmean[C] = {2, 5, 4};
static float gvar[C] = {7, 3, 9};
static float gam[C] = {1.5f, 0.75f, 2.0f};
static const float eps = 0.125f;

static void hostDX(const float *dy, float *out)
{
    static id<MTLDevice> device;
    static id<MTLCommandQueue> queue;
    if (!device) { device = MTLCreateSystemDefaultDevice(); queue = [device newCommandQueue]; }
    float sb[12], mb[3], vb[3], gb[3], ob[12];
    int t = 0;
    for (int c = 0; c < C; c++) for (int r = 0; r < N; r++) sb[t] = src[r][c];
    memcpy(mb, gmean, sizeof(mb)); memcpy(vb, gvar, sizeof(vb)); memcpy(gb, gam, sizeof(gb));
    id<MTLBuffer> inb = [device newBufferWithBytes:sb length:48 options:MTLResourceStorageModeShared];
    id<MTLBuffer> incb = [device newBufferWithBytes:dy length:48 options:MTLResourceStorageModeShared];
    id<MTLBuffer> mbuf = [device newBufferWithBytes:mb length:12 options:MTLResourceStorageModeShared];
    id<MTLBuffer> vbuf = [device newBufferWithBytes:vb length:12 options:MTLResourceStorageModeShared];
    id<MTLBuffer> gbuf = [device newBufferWithBytes:gb length:12 options:MTLResourceStorageModeShared];
    // A sentinel, so a zero of the formula and a byte the host never wrote are distinguishable.
    float sentinel[12];
    for (int i = 0; i < 12; i++) sentinel[i] = -1.0e30f;
    id<MTLBuffer> outb = [device newBufferWithBytes:sentinel length:48 options:MTLResourceStorageModeShared];
    MPSMatrixDescriptor *md = [MPSMatrixDescriptor matrixDescriptorWithRows:4 columns:3 matrices:1
                                                                     rowBytes:12 matrixBytes:48 dataType:MPSDataTypeFloat32];
    MPSVectorDescriptor *vd = [MPSVectorDescriptor vectorDescriptorWithLength:3 vectors:1
                                                                  vectorBytes:12 dataType:MPSDataTypeFloat32];
    id<MTLCommandBuffer> cb = [queue commandBufferWithUnretainedReferences];
    MPSMatrixBatchNormalizationGradient *g = [[MPSMatrixBatchNormalizationGradient alloc] initWithDevice:device];
    g.epsilon = eps;
    [g encodeToCommandBuffer:cb
             gradientMatrix:[[MPSMatrix alloc] initWithBuffer:incb descriptor:md]
                inputMatrix:[[MPSMatrix alloc] initWithBuffer:inb descriptor:md]
                 meanVector:[[MPSVector alloc] initWithBuffer:mbuf descriptor:vd]
             varianceVector:[[MPSVector alloc] initWithBuffer:vbuf descriptor:vd]
                gammaVector:[[MPSVector alloc] initWithBuffer:gbuf descriptor:vd]
                 betaVector:nil
    resultGradientForDataMatrix:[[MPSMatrix alloc] initWithBuffer:outb descriptor:md]
    resultGradientForGammaVector:nil
     resultGradientForBetaVector:nil];
    [cb commit]; [cb waitUntilCompleted];
    memcpy(out, [outb contents], 48);
}

int main(void) { @autoreleasepool {
    static float J[N * C][N * C];
    for (int j = 0; j < N * C; j++) {
        float e[12] = {0}, col[12];
        e[j] = 1.0f;
        hostDX(e, col);
        for (int i = 0; i < N * C; i++) J[i][j] = col[i];
    }

    // Linearity: dY = e_0 + e_1 must be the sum of the two columns.
    float two[12] = {0}, sum[12] = {0}, got[12];
    two[0] = 1.0f; two[1] = 1.0f;
    hostDX(two, got);
    for (int i = 0; i < 12; i++) sum[i] = J[i][0] + J[i][1];
    double worst = 0;
    for (int i = 0; i < 12; i++) { double d = fabs(got[i] - sum[i]); if (d > worst) worst = d; }
    P("linearity: dY = e_0 + e_1 against the sum of the two columns, largest difference %.3g%s\n",
      worst, worst < 1e-5 ? " - linear" : " - NOT LINEAR");

    P("\nelements the host leaves untouched, per unit column, and where they are\n");
    for (int j = 0; j < N * C; j++) {
        float e[12] = {0}, col[12];
        e[j] = 1.0f;
        hostDX(e, col);
        int untouched = 0;
        P("  e_%d:", j);
        for (int i = 0; i < 12; i++) {
            if (col[i] == -1.0e30f) { P(" %d", i); untouched++; }
        }
        if (!untouched) P(" (none)");
        P("\n");
    }

    P("\nthe Jacobian, rows = dX, columns = dY, each labelled by its element index in row-major order\n");
    P("        ");
    for (int j = 0; j < N * C; j++) P(" %7d", j);
    P("\n");
    for (int i = 0; i < N * C; i++) {
        P("  dX[%2d] ", i);
        for (int j = 0; j < N * C; j++) P(" %7.4f", J[i][j]);
        P("\n");
    }

    P("\nthe diagonal, and what the argument values divide to\n");
    for (int c = 0; c < C; c++) {
        int i = c * N + c;
        double diag = J[i][i];
        double given = gam[c] / sqrt(gvar[c] + eps);
        P("  column %d: dX[%d][%d] = %9.6f   gamma/sqrt(given var + eps) = %9.6f   ratio %.9f\n",
          c, i, i, diag, given, diag / given);
    }
    P("\nnon-zero entries per row (the axis): ");
    for (int i = 0; i < N * C; i++) {
        int n = 0;
        for (int j = 0; j < N * C; j++) if (J[i][j] != 0.0) n++;
        P("%d ", n);
    }
    P("\n");
} return 0; }
