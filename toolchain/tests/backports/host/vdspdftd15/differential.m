#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <float.h>
#include <math.h>
#include <stdint.h>

extern vDSP_DFT_Interleaved_SetupD revenant_host_vDSP_DFT_Interleaved_CreateSetupD(vDSP_DFT_Interleaved_SetupD Previous,
                                                                               vDSP_Length Length,
                                                                               vDSP_DFT_Direction Direction,
                                                                               vDSP_DFT_RealtoComplex RealtoComplex);
extern void revenant_host_vDSP_DFT_Interleaved_ExecuteD(const vDSP_DFT_Interleaved_SetupD Setup,
                                                      const DSPDoubleComplex *Iri, DSPDoubleComplex *Ori);
extern void revenant_host_vDSP_DFT_Interleaved_DestroySetupD(vDSP_DFT_Interleaved_SetupD Setup);

typedef struct {
    const char *name;
    vDSP_DFT_Interleaved_SetupD (*create)(vDSP_DFT_Interleaved_SetupD, vDSP_Length, vDSP_DFT_Direction,
                                          vDSP_DFT_RealtoComplex);
    void (*execute)(const vDSP_DFT_Interleaved_SetupD, const DSPDoubleComplex *, DSPDoubleComplex *);
    void (*destroy)(vDSP_DFT_Interleaved_SetupD);
} Impl;

static const Impl kHost = {"the host", vDSP_DFT_Interleaved_CreateSetupD, vDSP_DFT_Interleaved_ExecuteD,
                           vDSP_DFT_Interleaved_DestroySetupD};
static const Impl kPort = {"the port", revenant_host_vDSP_DFT_Interleaved_CreateSetupD,
                           revenant_host_vDSP_DFT_Interleaved_ExecuteD, revenant_host_vDSP_DFT_Interleaved_DestroySetupD};

static const double kK = 2.63;

static int checks = 0;
static int failures = 0;

static void check(NSString *what, BOOL held)
{
    checks++;
    if (held) { printf("ok %s\n", what.UTF8String); }
    else { failures++; printf("FAIL %s\n", what.UTF8String); }
}

static const vDSP_Length kAccepted[] = {8, 12, 16, 20, 24, 32, 36, 40, 48, 60, 64, 72, 80, 96, 120, 128, 144, 160,
                                        192, 240, 256, 288, 320, 384, 480, 512, 576, 640, 768, 960, 1024};

static uint32_t rngState = 2463534242u;
static double nextSample(void)
{
    rngState ^= rngState << 13;
    rngState ^= rngState >> 17;
    rngState ^= rngState << 5;
    return (double)(rngState % 20001u) / 10000.0 - 1.0;
}

typedef struct {
    double hi, lo;
} DD;

static DD ddOf(double a)
{
    DD r = {a, 0.0};
    return r;
}

static DD quickTwoSum(double a, double b)
{
    double s = a + b;
    DD r = {s, b - (s - a)};
    return r;
}

static DD twoSum(double a, double b)
{
    double s = a + b;
    double bb = s - a;
    DD r = {s, (a - (s - bb)) + (b - bb)};
    return r;
}

static DD twoProd(double a, double b)
{
    double p = a * b;
    DD r = {p, fma(a, b, -p)};
    return r;
}

static DD ddAdd(DD a, DD b)
{
    DD s = twoSum(a.hi, b.hi);
    DD t = twoSum(a.lo, b.lo);
    s.lo += t.hi;
    s = quickTwoSum(s.hi, s.lo);
    s.lo += t.lo;
    return quickTwoSum(s.hi, s.lo);
}

static DD ddNeg(DD a)
{
    DD r = {-a.hi, -a.lo};
    return r;
}

static DD ddMul(DD a, DD b)
{
    DD p = twoProd(a.hi, b.hi);
    p.lo += a.hi * b.lo + a.lo * b.hi;
    return quickTwoSum(p.hi, p.lo);
}

static DD ddDivD(DD a, double d)
{
    double q1 = a.hi / d;
    DD r = ddAdd(a, ddNeg(twoProd(q1, d)));
    return quickTwoSum(q1, r.hi / d);
}

static const DD kHalfPi = {1.5707963267948966, 6.123233995736766e-17};

static void sinCosSmall(long num, long den, DD *s, DD *c)
{
    DD psi = ddDivD(ddMul(kHalfPi, ddOf((double)num)), (double)den);
    DD psi2 = ddMul(psi, psi);
    DD sinTerm = psi, cosTerm = ddOf(1.0);
    DD sinSum = psi, cosSum = cosTerm;
    for (int k = 1; k <= 30; k++) {
        sinTerm = ddNeg(ddDivD(ddMul(sinTerm, psi2), (double)((2 * k) * (2 * k + 1))));
        sinSum = ddAdd(sinSum, sinTerm);
        cosTerm = ddNeg(ddDivD(ddMul(cosTerm, psi2), (double)((2 * k - 1) * (2 * k))));
        cosSum = ddAdd(cosSum, cosTerm);
    }
    *s = sinSum;
    *c = cosSum;
}

static void twiddle(long m, long M, DD *c, DD *s)
{
    m %= M;
    long q = (4 * m) / M;
    long r = 4 * m - q * M;
    int swap = 0;
    long num = r;
    if (2 * r > M) {
        num = M - r;
        swap = 1;
    }
    DD sp, cp;
    sinCosSmall(num, M, &sp, &cp);
    DD sinPhi = swap ? cp : sp;
    DD cosPhi = swap ? sp : cp;
    switch (q) {
        case 0: *c = cosPhi; *s = sinPhi; break;
        case 1: *c = ddNeg(sinPhi); *s = cosPhi; break;
        case 2: *c = ddNeg(cosPhi); *s = ddNeg(sinPhi); break;
        default: *c = sinPhi; *s = ddNeg(cosPhi); break;
    }
}

typedef struct {
    DD *c, *s;
    long M;
} Table;

static Table tableFor(long M)
{
    Table t = {malloc(sizeof(DD) * (size_t)M), malloc(sizeof(DD) * (size_t)M), M};
    for (long m = 0; m < M; m++) { twiddle(m, M, &t.c[m], &t.s[m]); }
    return t;
}

static void freeTable(Table t)
{
    free(t.c);
    free(t.s);
}

static void referenceComplex(const DSPDoubleComplex *in, vDSP_Length n, BOOL inverse, DD *re, DD *im, const Table *t)
{
    for (vDSP_Length k = 0; k < n; k++) {
        DD accRe = ddOf(0.0), accIm = ddOf(0.0);
        for (vDSP_Length j = 0; j < n; j++) {
            long idx = (long)((j * k) % n);
            DD c = t->c[idx];
            DD s = inverse ? t->s[idx] : ddNeg(t->s[idx]);
            DD xr = ddOf(in[j].real), xi = ddOf(in[j].imag);
            accRe = ddAdd(accRe, ddAdd(ddMul(xr, c), ddNeg(ddMul(xi, s))));
            accIm = ddAdd(accIm, ddAdd(ddMul(xr, s), ddMul(xi, c)));
        }
        re[k] = accRe;
        im[k] = accIm;
    }
}

static void referenceReal(const double *x, vDSP_Length n, DD *re, DD *im, const Table *t)
{
    vDSP_Length m = 2 * n;
    for (vDSP_Length k = 0; k <= n; k++) {
        DD xr = ddOf(0.0), xi = ddOf(0.0);
        for (vDSP_Length j = 0; j < m; j++) {
            long idx = (long)((j * k) % m);
            xr = ddAdd(xr, ddMul(ddOf(x[j]), t->c[idx]));
            xi = ddAdd(xi, ddMul(ddOf(x[j]), ddNeg(t->s[idx])));
        }
        if (k == 0) { re[0] = ddAdd(xr, xr); }
        else if (k == n) { im[0] = ddAdd(xr, xr); }
        else {
            re[k] = ddAdd(xr, xr);
            im[k] = ddAdd(xi, xi);
        }
    }
}

static BOOL transform(const Impl *impl, vDSP_DFT_Direction direction, vDSP_DFT_RealtoComplex form, vDSP_Length n,
                      const DSPDoubleComplex *in, DSPDoubleComplex *out)
{
    vDSP_DFT_Interleaved_SetupD setup = impl->create(NULL, n, direction, form);
    if (setup == NULL) {
        for (vDSP_Length k = 0; k < n; k++) { out[k].real = 0.0; out[k].imag = 0.0; }
        return NO;
    }
    impl->execute(setup, in, out);
    impl->destroy(setup);
    return YES;
}

typedef struct {
    double worst;
    BOOL inside;
} Ratio;

static Ratio ratioAgainst(const DSPDoubleComplex *out, const DD *refRe, const DD *refIm, vDSP_Length n, double norm)
{
    double bound = kK * log2((double)n) * DBL_EPSILON * norm;
    Ratio r = {0.0, YES};
    for (vDSP_Length k = 0; k < n; k++) {
        double dr = (out[k].real - refRe[k].hi) - refRe[k].lo;
        double di = (out[k].imag - refIm[k].hi) - refIm[k].lo;
        double err = hypot(dr, di);
        double ratio = err / bound;
        if (ratio > r.worst) { r.worst = ratio; }
        if (err > bound) { r.inside = NO; }
    }
    return r;
}

static void compareAcceptedLengths(void)
{
    vDSP_DFT_RealtoComplex forms[] = {vDSP_DFT_Interleaved_ComplextoComplex, vDSP_DFT_Interleaved_RealtoComplex};
    const char *formNames[] = {"complex-to-complex", "real-to-complex"};
    for (int f = 0; f < 2; f++) {
        vDSP_Length disagreements = 0, hostAccepts = 0;
        for (vDSP_Length n = 1; n <= 1024; n++) {
            vDSP_DFT_Interleaved_SetupD hostSetup = kHost.create(NULL, n, vDSP_DFT_FORWARD, forms[f]);
            vDSP_DFT_Interleaved_SetupD portSetup = kPort.create(NULL, n, vDSP_DFT_FORWARD, forms[f]);
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

static void checkReference(void)
{
    double worstIdentity = 0.0, worstLibm = 0.0;
    for (size_t i = 0; i < sizeof(kAccepted) / sizeof(kAccepted[0]); i++) {
        for (long M = (long)kAccepted[i]; M <= (long)2 * (long)kAccepted[i]; M *= 2) {
            Table t = tableFor(M);
            for (long m = 0; m < M; m++) {
                DD sq = ddAdd(ddMul(t.c[m], t.c[m]), ddMul(t.s[m], t.s[m]));
                double dev = fabs((sq.hi - 1.0) + sq.lo);
                if (dev > worstIdentity) { worstIdentity = dev; }
                double angle = 2.0 * M_PI * (double)m / (double)M;
                double dc = fabs(t.c[m].hi - cos(angle)), ds = fabs(t.s[m].hi - sin(angle));
                if (dc > worstLibm) { worstLibm = dc; }
                if (ds > worstLibm) { worstLibm = ds; }
            }
            freeTable(t);
        }
    }
    check([NSString stringWithFormat:@"the double-double twiddles satisfy cos^2 + sin^2 = 1 to 1e-30 (worst %.2e) and agree with libm to 1e-15 (worst %.2e)", worstIdentity, worstLibm],
          worstIdentity < 1e-30 && worstLibm < 4e-15);
}

static void compareValues(const char *what, vDSP_DFT_Direction direction, vDSP_DFT_RealtoComplex form)
{
    const int trials = 24;
    double worstHost = 0.0, worstPort = 0.0;
    BOOL hostInside = YES, portInside = YES, portAccepts = YES;
    for (size_t i = 0; i < sizeof(kAccepted) / sizeof(kAccepted[0]); i++) {
        vDSP_Length n = kAccepted[i];
        Table t = tableFor(form == vDSP_DFT_Interleaved_RealtoComplex ? 2 * (long)n : (long)n);
        for (int tr = 0; tr < trials; tr++) {
            DSPDoubleComplex in[1024], hostOut[1024], portOut[1024];
            DD refRe[1024], refIm[1024];
            double norm = 0.0;
            if (form == vDSP_DFT_Interleaved_RealtoComplex) {
                double *x = &in[0].real;
                for (vDSP_Length j = 0; j < 2 * n; j++) { x[j] = nextSample(); norm += x[j] * x[j]; }
                referenceReal(x, n, refRe, refIm, &t);
            } else {
                for (vDSP_Length j = 0; j < n; j++) {
                    in[j].real = nextSample();
                    in[j].imag = nextSample();
                    norm += in[j].real * in[j].real + in[j].imag * in[j].imag;
                }
                referenceComplex(in, n, direction == vDSP_DFT_INVERSE, refRe, refIm, &t);
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
        freeTable(t);
    }
    printf("stage %s: worst ratio to the bound over %zu lengths x %d trials: host %.3f, port %.3f (K = %.3f)\n",
           what, sizeof(kAccepted) / sizeof(kAccepted[0]), trials, worstHost, worstPort, kK);
    check([NSString stringWithFormat:@"the host's %s is inside the bound at every element", what], hostInside);
    check([NSString stringWithFormat:@"the port's %s is inside the bound at every element", what], portInside && portAccepts);
}

int main(void)
{
    @autoreleasepool {
        checkReference();
        compareAcceptedLengths();
        compareValues("complex-to-complex forward", vDSP_DFT_FORWARD, vDSP_DFT_Interleaved_ComplextoComplex);
        compareValues("complex-to-complex inverse", vDSP_DFT_INVERSE, vDSP_DFT_Interleaved_ComplextoComplex);
        compareValues("real-to-complex forward", vDSP_DFT_FORWARD, vDSP_DFT_Interleaved_RealtoComplex);
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
