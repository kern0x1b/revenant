// gradient-separating.m — identify which formula the host uses for the batch-norm data gradient.
//
// The case the differential uses cannot separate the variants: its given mean and its batch mean are
// both 4. This program chooses inputs where they differ, and where the given and batch variances
// differ, so every distinction is live:
//
//     given mean   2  5  4      against a batch mean of  3.25  5  6
//     given var    7  3  9      against a batch var of   3.6875  7  3
//
// The family is 64: sixteen of the standard form, and sixteen of the form that is not the standard
// formula at all, dX = gamma / sigma * dY with no mean terms. The check is two, not one, because a form
// with no mean terms cannot depend on which mean or which aggregation was chosen: the sixteen standard
// variants must be distinct from each other, and the plain sixteen distinct from the standard ones.
// Asking for sixty-four distinct is unaskable.
//
// The host is then run on the same inputs and every variant's answer for element (0, 0) is printed
// beside it, so the match is read off and not chosen.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <math.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)

#define N 4
#define C 3

static float src[N][C] = {{1, 3, 7}, {2, 9, 4}, {5, 1, 11}, {8, 6, 2}};
static float inc[N][C] = {{4, 2, 9}, {1, 7, 3}, {6, 3, 5}, {2, 8, 1}};
static float gmean[C] = {2, 5, 4};
static float gvar[C] = {7, 3, 9};
static float gam[C] = {1.5f, 0.75f, 2.0f};
static const float eps = 0.125f;

static double meanOf(const double *v, int n) { double s = 0; for (int i = 0; i < n; i++) s += v[i]; return s / n; }
static double varOf(const double *v, int n, double m) { double s = 0; for (int i = 0; i < n; i++) { double d = v[i] - m; s += d * d; } return s / n; }
static double sumOf(const double *a, const double *b, int n) { double s = 0; for (int i = 0; i < n; i++) s += a[i] * (b ? b[i] : 1.0); return s; }

// One variant at element (row, column). ms/vs choose the mean and variance between the given vector
// and the batch's own; ug the gamma; ag mean against sum; ax the axis the mean terms run over; and fm
// the standard formula against no mean terms at all.
static double variant(int c, int r, int ms, int vs, int ug, int ag, int ax, int fm)
{
    double dy[N], xh[N];
    for (int i = 0; i < N; i++) dy[i] = inc[i][c];
    double m, v, root, mdy, mdx;
    if (ax == 0) {
        double bmean = meanOf(dy, N);
        m = ms ? bmean : gmean[c];
        v = vs ? varOf(dy, N, bmean) : gvar[c];
        root = sqrt(v + eps);
        for (int i = 0; i < N; i++) xh[i] = (src[i][c] - m) / root;
        double dmean = ag ? meanOf(dy, N) : sumOf(dy, NULL, N);
        double prod = 0; for (int i = 0; i < N; i++) prod += dy[i] * xh[i];
        double xhmean = ag ? prod / N : prod;
        mdy = dmean;
        mdx = xhmean;
        double g = ug ? gam[c] : 1.0;
        if (fm) return g * dy[r] / root;
        return g * (dy[r] - mdy - xh[r] * mdx) / root;
    }
    double brow[C], bxh[C];
    for (int j = 0; j < C; j++) { brow[j] = inc[r][j]; bxh[j] = (src[r][j] - gmean[c]) / sqrt(gvar[c] + eps); }
    double bmean = meanOf(brow, C);
    m = ms ? bmean : gmean[c];
    v = vs ? varOf(brow, C, bmean) : gvar[c];
    root = sqrt(v + eps);
    double hx = (src[r][c] - m) / root;
    mdy = ag ? meanOf(brow, C) : sumOf(brow, NULL, C);
    double prod = 0; for (int j = 0; j < C; j++) prod += brow[j] * ((src[r][j] - m) / root);
    mdx = ag ? prod / C : prod;
    double g = ug ? gam[c] : 1.0;
    if (fm) return g * brow[c] / root;
    return g * (brow[c] - mdy - hx * mdx) / root;
}

int main(int argc, char **argv) { @autoreleasepool {
    int swappedXY = (argc > 1 && argv[1][0] == 'x');
    int swappedMV = (argc > 1 && argv[1][0] == 'm');
    P("order: %s\n", swappedXY ? "gradient and source swapped" : (swappedMV ? "mean and variance swapped" : "as declared"));
    P("given mean %g %g %g   given var %g %g %g   gamma %g %g %g   eps %g\n",
      gmean[0], gmean[1], gmean[2], gvar[0], gvar[1], gvar[2], gam[0], gam[1], gam[2], eps);

    static double std16[16], plain16[16];
    static const char *names[16];
    int k = 0;
    for (int ms = 0; ms < 2; ms++) for (int vs = 0; vs < 2; vs++) for (int ug = 0; ug < 2; ug++)
    for (int ag = 0; ag < 2; ag++) {
        std16[k++] = variant(0, 0, ms, vs, ug, ag, 0, 0);
    }
    k = 0;
    for (int ms = 0; ms < 2; ms++) for (int vs = 0; vs < 2; vs++) for (int ug = 0; ug < 2; ug++)
    for (int ag = 0; ag < 2; ag++)
        plain16[k++] = variant(0, 0, ms, vs, ug, ag, 0, 1);
    // and the sixteen with the mean terms on the other axis, in both forms
    static double axisVectors[16], axisColumns[16];
    k = 0;
    for (int ms = 0; ms < 2; ms++) for (int vs = 0; vs < 2; vs++) for (int ug = 0; ug < 2; ug++)
    for (int ag = 0; ag < 2; ag++) {
        axisVectors[k] = variant(0, 0, ms, vs, ug, ag, 0, 0);
        axisColumns[k] = variant(0, 0, ms, vs, ug, ag, 1, 0);
        k++;
    }

    int dup = 0;
    for (int i = 0; i < 16; i++) for (int j = i + 1; j < 16; j++) if (std16[i] == std16[j]) dup++;
    int cross = 0;
    for (int i = 0; i < 16; i++) for (int j = 0; j < 16; j++) if (std16[i] == plain16[j]) cross++;
    for (int i = 0; i < 16; i++) for (int j = 0; j < 16; j++)
        if (std16[i] == axisColumns[j] || plain16[i] == axisColumns[j]) cross++;
    P("\nself-check: the standard sixteen distinct: %s (%d collisions)\n", dup ? "NO" : "yes", dup);
    P("self-check: the plain and axis forms distinct from the standard: %s (%d collisions)\n",
      cross ? "NO" : "yes", cross);

    // The host, on the same inputs.
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> q = [d newCommandQueue];
    float sb[12], ib[12], mb[3], vb[3], gb[3];
    int t = 0;
    for (int c = 0; c < C; c++) for (int r = 0; r < N; r++) { sb[t] = src[r][c]; ib[t] = inc[r][c]; t++; }
    memcpy(mb, gmean, sizeof(mb)); memcpy(vb, gvar, sizeof(vb)); memcpy(gb, gam, sizeof(gb));
    id<MTLBuffer> inb = [d newBufferWithBytes:sb length:48 options:MTLResourceStorageModeShared];
    id<MTLBuffer> incb = [d newBufferWithBytes:ib length:48 options:MTLResourceStorageModeShared];
    // the four argument slots, permuted as the mode asks
    id<MTLBuffer> A = swappedXY ? incb : inb;   // inputMatrix slot
    id<MTLBuffer> B = swappedXY ? inb : incb;    // gradientMatrix slot
    id<MTLBuffer> mbuf = [d newBufferWithBytes:swappedMV ? vb : mb length:12 options:MTLResourceStorageModeShared];
    id<MTLBuffer> vbuf = [d newBufferWithBytes:swappedMV ? mb : vb length:12 options:MTLResourceStorageModeShared];
    id<MTLBuffer> gbuf = [d newBufferWithBytes:gb length:12 options:MTLResourceStorageModeShared];
    id<MTLBuffer> outb = [d newBufferWithLength:48 options:MTLResourceStorageModeShared];
    MPSMatrixDescriptor *md = [MPSMatrixDescriptor matrixDescriptorWithRows:4 columns:3 matrices:1
                                                                     rowBytes:12 matrixBytes:48 dataType:MPSDataTypeFloat32];
    MPSVectorDescriptor *vd = [MPSVectorDescriptor vectorDescriptorWithLength:3 vectors:1
                                                                  vectorBytes:12 dataType:MPSDataTypeFloat32];
    id<MTLCommandBuffer> cb = [q commandBufferWithUnretainedReferences];
    MPSMatrixBatchNormalizationGradient *g = [[MPSMatrixBatchNormalizationGradient alloc] initWithDevice:d];
    g.epsilon = eps;
    [g encodeToCommandBuffer:cb
             gradientMatrix:[[MPSMatrix alloc] initWithBuffer:B descriptor:md]
                inputMatrix:[[MPSMatrix alloc] initWithBuffer:A descriptor:md]
                 meanVector:[[MPSVector alloc] initWithBuffer:mbuf descriptor:vd]
             varianceVector:[[MPSVector alloc] initWithBuffer:vbuf descriptor:vd]
                gammaVector:[[MPSVector alloc] initWithBuffer:gbuf descriptor:vd]
                 betaVector:nil
    resultGradientForDataMatrix:[[MPSMatrix alloc] initWithBuffer:outb descriptor:md]
    resultGradientForGammaVector:nil
     resultGradientForBetaVector:nil];
    [cb commit]; [cb waitUntilCompleted];
    float o[12] = {0}; memcpy(o, [outb contents], 48);
    P("\nhost dX:"); for (int i = 0; i < 12; i++) P(" %g", o[i]); P("\n");
    P("host dX at (row 0, column 0) = %.9g\n", o[0]);
    if (swappedXY) { P("  (variants below are for the declared order, not the swapped one)\n"); }
    P("\n");

    for (int i = 0; i < 16; i++)
        P("  %13.9f  mean %-5s var %-5s gamma %-7s agg %-4s axis vectors form %s\n",
          std16[i], (i & 1) ? "batch" : "given", (i & 2) ? "batch" : "given",
          (i & 4) ? "with" : "without", (i & 8) ? "sum" : "mean",
          std16[i] == o[0] ? "<== MATCHES THE HOST" : "");
} return 0; }
