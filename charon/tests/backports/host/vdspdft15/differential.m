// The port's single-precision vDSP_DFT_Interleaved family held against the host's own vDSP, and both held against a
// double-precision reference under the error bound the port's facts file states:
//
//     |out - ref| <= K * log2(N) * FLT_EPSILON * ||x||_2      with K = 1.538
//
// K is the host's own worst ratio over the accepted lengths (facts/Accelerate/vDSPDFTInterleaved.md, section 5), so
// the host has to sit inside it as well as the port. Two things are checked: which lengths each side accepts, over
// every length from 1 to 1024, and the transform's values, over the accepted lengths of the header's family.
//
// The port's objects are compiled with the charon_host_ names (run.sh), so their functions are declared here under
// those names and the host's under the real ones, in one binary.
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <float.h>
#include <math.h>
#include <stdint.h>

extern vDSP_DFT_Interleaved_Setup charon_host_vDSP_DFT_Interleaved_CreateSetup(vDSP_DFT_Interleaved_Setup Previous,
                                                                             vDSP_Length Length,
                                                                             vDSP_DFT_Direction Direction,
                                                                             vDSP_DFT_RealtoComplex RealtoComplex);
extern void charon_host_vDSP_DFT_Interleaved_Execute(const vDSP_DFT_Interleaved_Setup Setup, const DSPComplex *Iri,
                                                     DSPComplex *Ori);
extern void charon_host_vDSP_DFT_Interleaved_DestroySetup(vDSP_DFT_Interleaved_Setup Setup);

typedef struct {
    const char *name;
    vDSP_DFT_Interleaved_Setup (*create)(vDSP_DFT_Interleaved_Setup, vDSP_Length, vDSP_DFT_Direction,
                                         vDSP_DFT_RealtoComplex);
    void (*execute)(const vDSP_DFT_Interleaved_Setup, const DSPComplex *, DSPComplex *);
    void (*destroy)(vDSP_DFT_Interleaved_Setup);
} Impl;

static const Impl kHost = {"the host", vDSP_DFT_Interleaved_CreateSetup, vDSP_DFT_Interleaved_Execute,
                           vDSP_DFT_Interleaved_DestroySetup};
static const Impl kPort = {"the port", charon_host_vDSP_DFT_Interleaved_CreateSetup,
                           charon_host_vDSP_DFT_Interleaved_Execute, charon_host_vDSP_DFT_Interleaved_DestroySetup};

static const double kK = 1.538;

static int checks = 0;
static int failures = 0;

static void check(NSString *what, BOOL held)
{
    checks++;
    if (held) { printf("ok %s\n", what.UTF8String); }
    else { failures++; printf("FAIL %s\n", what.UTF8String); }
}

// The accepted lengths, the host's set: f * 2**n with f in {2, 3, 5, 9, 15} and n >= 2, 31 of them up to 1024.
static const vDSP_Length kAccepted[] = {8, 12, 16, 20, 24, 32, 36, 40, 48, 60, 64, 72, 80, 96, 120, 128, 144, 160,
                                        192, 240, 256, 288, 320, 384, 480, 512, 576, 640, 768, 960, 1024};

// Deterministic inputs, so both sides and both runs see the same numbers: a xorshift in [-1, 1).
static uint32_t rngState = 2463534242u;
static float nextSample(void)
{
    rngState ^= rngState << 13;
    rngState ^= rngState >> 17;
    rngState ^= rngState << 5;
    return (float)(rngState % 20001u) / 10000.0f - 1.0f;
}

// One transform through one implementation. A setup the implementation refuses is reported as NO and its output left
// zero, so a refusal cannot read as an answer.
static BOOL transform(const Impl *impl, vDSP_DFT_Direction direction, vDSP_DFT_RealtoComplex form, vDSP_Length n,
                      const DSPComplex *in, DSPComplex *out)
{
    vDSP_DFT_Interleaved_Setup setup = impl->create(NULL, n, direction, form);
    if (setup == NULL) {
        for (vDSP_Length k = 0; k < n; k++) { out[k].real = 0.0f; out[k].imag = 0.0f; }
        return NO;
    }
    impl->execute(setup, in, out);
    impl->destroy(setup);
    return YES;
}

// The double-precision references. A complex-to-complex transform of N values, unscaled; the inverse uses e^(+i...).
static void referenceComplex(const DSPComplex *in, vDSP_Length n, BOOL inverse, double *re, double *im)
{
    for (vDSP_Length k = 0; k < n; k++) {
        re[k] = 0.0;
        im[k] = 0.0;
        for (vDSP_Length j = 0; j < n; j++) {
            double angle = 2.0 * M_PI * (double)((j * k) % n) / (double)n * (inverse ? 1.0 : -1.0);
            double c = cos(angle), s = sin(angle);
            re[k] += (double)in[j].real * c - (double)in[j].imag * s;
            im[k] += (double)in[j].real * s + (double)in[j].imag * c;
        }
    }
}

// The real-to-complex packing of section 3 of the facts: the 2N real samples x[0..2N-1] are a 2N-point real DFT X,
// and the N outputs are (2 X_0, 2 X_N) packed in element 0 and 2 X_k in the others, k = 1 .. N-1.
static void referenceReal(const float *x, vDSP_Length n, double *re, double *im)
{
    vDSP_Length m = 2 * n;
    for (vDSP_Length k = 0; k <= n; k++) {
        double xr = 0.0, xi = 0.0;
        for (vDSP_Length j = 0; j < m; j++) {
            double angle = -2.0 * M_PI * (double)((j * k) % m) / (double)m;
            xr += (double)x[j] * cos(angle);
            xi += (double)x[j] * sin(angle);
        }
        if (k == 0) { re[0] = 2.0 * xr; }
        else if (k == n) { im[0] = 2.0 * xr; }
        else { re[k] = 2.0 * xr; im[k] = 2.0 * xi; }
    }
}

// The worst ratio of |out - ref| to the bound over one output, and whether any element is outside it.
typedef struct {
    double worst;
    BOOL inside;
} Ratio;

static Ratio ratioAgainst(const DSPComplex *out, const double *refRe, const double *refIm, vDSP_Length n,
                          double norm)
{
    double bound = kK * log2((double)n) * FLT_EPSILON * norm;
    Ratio r = {0.0, YES};
    for (vDSP_Length k = 0; k < n; k++) {
        double err = hypot((double)out[k].real - refRe[k], (double)out[k].imag - refIm[k]);
        double ratio = err / bound;
        if (ratio > r.worst) { r.worst = ratio; }
        if (err > bound) { r.inside = NO; }
    }
    return r;
}

// Which lengths each side accepts, over every length from 1 to 1024, both forms. Each side is checked against the
// header-free definition of the set in the facts: a length is accepted by one side iff it is accepted by the other.
static void compareAcceptedLengths(void)
{
    vDSP_DFT_RealtoComplex forms[] = {vDSP_DFT_Interleaved_ComplextoComplex, vDSP_DFT_Interleaved_RealtoComplex};
    const char *formNames[] = {"complex-to-complex", "real-to-complex"};
    for (int f = 0; f < 2; f++) {
        vDSP_Length disagreements = 0, hostAccepts = 0;
        for (vDSP_Length n = 1; n <= 1024; n++) {
            vDSP_DFT_Interleaved_Setup hostSetup = kHost.create(NULL, n, vDSP_DFT_FORWARD, forms[f]);
            vDSP_DFT_Interleaved_Setup portSetup = kPort.create(NULL, n, vDSP_DFT_FORWARD, forms[f]);
            if (hostSetup != NULL) { hostAccepts++; }
            if ((hostSetup != NULL) != (portSetup != NULL)) { disagreements++; }
            if (hostSetup) { kHost.destroy(hostSetup); }
            if (portSetup) { kPort.destroy(portSetup); }
        }
        check([NSString stringWithFormat:@"the port accepts exactly the lengths the host accepts, %s, over 1 to 1024 (host accepts %llu, disagreements %llu)",
               formNames[f], (unsigned long long)hostAccepts, (unsigned long long)disagreements],
              disagreements == 0 && hostAccepts == 31);
    }
}

// The values, over the accepted lengths, for one transform: every trial of every length, held to the bound on both
// sides. Reported as the worst ratio over the whole sweep, which is the figure the bound was measured from.
static void compareValues(const char *what, vDSP_DFT_Direction direction, vDSP_DFT_RealtoComplex form)
{
    const int trials = 8;
    double worstHost = 0.0, worstPort = 0.0;
    BOOL hostInside = YES, portInside = YES, portAccepts = YES;
    for (size_t i = 0; i < sizeof(kAccepted) / sizeof(kAccepted[0]); i++) {
        vDSP_Length n = kAccepted[i];
        for (int t = 0; t < trials; t++) {
            DSPComplex in[1024], hostOut[1024], portOut[1024];
            double refRe[1024], refIm[1024];
            double norm = 0.0;
            if (form == vDSP_DFT_Interleaved_RealtoComplex) {
                // 2N real samples packed as N complex values, the same memory the port reads and the host reads
                float *x = &in[0].real;
                for (vDSP_Length j = 0; j < 2 * n; j++) { x[j] = nextSample(); norm += (double)x[j] * x[j]; }
                referenceReal(x, n, refRe, refIm);
            } else {
                for (vDSP_Length j = 0; j < n; j++) {
                    in[j].real = nextSample();
                    in[j].imag = nextSample();
                    norm += (double)in[j].real * in[j].real + (double)in[j].imag * in[j].imag;
                }
                referenceComplex(in, n, direction == vDSP_DFT_INVERSE, refRe, refIm);
            }
            norm = sqrt(norm);
            if (!transform(&kHost, direction, form, n, in, hostOut)) { hostInside = NO; }
            if (!transform(&kPort, direction, form, n, in, portOut)) { portAccepts = NO; }
            Ratio h = ratioAgainst(hostOut, refRe, refIm, n, norm);
            Ratio p = ratioAgainst(portOut, refRe, refIm, n, norm);
            if (h.worst > worstHost) { worstHost = h.worst; }
            if (p.worst > worstPort) { worstPort = p.worst; }
            if (!h.inside) { hostInside = NO; }
            if (!p.inside) { portInside = NO; }
        }
    }
    printf("stage %s: worst ratio to the bound over %zu lengths x %d trials: host %.3f, port %.3f (K = %.3f)\n",
           what, sizeof(kAccepted) / sizeof(kAccepted[0]), trials, worstHost, worstPort, kK);
    check([NSString stringWithFormat:@"the host's %s is inside the bound at every element", what], hostInside);
    check([NSString stringWithFormat:@"the port's %s is inside the bound at every element", what], portInside && portAccepts);
}

int main(void)
{
    @autoreleasepool {
        compareAcceptedLengths();
        compareValues("complex-to-complex forward", vDSP_DFT_FORWARD, vDSP_DFT_Interleaved_ComplextoComplex);
        compareValues("complex-to-complex inverse", vDSP_DFT_INVERSE, vDSP_DFT_Interleaved_ComplextoComplex);
        compareValues("real-to-complex forward", vDSP_DFT_FORWARD, vDSP_DFT_Interleaved_RealtoComplex);
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
