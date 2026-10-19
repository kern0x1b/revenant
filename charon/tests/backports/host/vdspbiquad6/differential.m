#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

vDSP_biquad_Setup charon_host_vDSP_biquad_CreateSetup(const double *coeffs, vDSP_Length M);
vDSP_biquad_SetupD charon_host_vDSP_biquad_CreateSetupD(const double *coeffs, vDSP_Length M);
void charon_host_vDSP_biquad_DestroySetup(vDSP_biquad_Setup setup);
void charon_host_vDSP_biquad_DestroySetupD(vDSP_biquad_SetupD setup);
void charon_host_vDSP_biquad(const struct vDSP_biquad_SetupStruct *setup, float *delay, const float *x,
                             vDSP_Stride ix, float *y, vDSP_Stride iy, vDSP_Length n);
void charon_host_vDSP_biquadD(const struct vDSP_biquad_SetupStructD *setup, double *delay, const double *x,
                              vDSP_Stride ix, double *y, vDSP_Stride iy, vDSP_Length n);

static int checks;
static int failures;

#define SAMPLES 32

static const double kStable[5] = {0.0674551234, 0.1349102468, 0.0674551234, -1.1429805025, 0.4128015981};
static const double kUnstable[5] = {0.4375, -0.8125, 0.0625, 1.625, -0.1875};

static void fill_pattern(double *coeffs, vDSP_Length sections, const double *pattern)
{
    for (vDSP_Length section = 0; section < sections; section++)
        for (int i = 0; i < 5; i++)
            coeffs[section * 5 + i] = pattern[i] + section * 0.03125;
}

static void fill_input(float *x, int count, int offset)
{
    for (int i = 0; i < count; i++)
        x[i] = (float)(0.25 * ((i * 7 + offset * 3) % 11) - 1.0);
}

static void report(const char *what, int ok, const char *detail, int gating)
{
    checks++;
    if (ok) {
        printf("ok %s\n", what);
        return;
    }
    if (gating) {
        failures++;
        printf("FAIL %s: %s\n", what, detail);
        return;
    }
    printf("DIVERGES (recorded, not gating) %s: %s\n", what, detail);
}

static void run_float(const char *what, vDSP_Length sections, const double *pattern, int gating)
{
    double coeffs[5 * 8];
    float mine_x[SAMPLES], their_x[SAMPLES], mine_y[SAMPLES], their_y[SAMPLES];
    float mine_delay[2 * 8] = {0}, their_delay[2 * 8] = {0};
    char detail[256];
    fill_pattern(coeffs, sections, pattern);

    vDSP_biquad_Setup mine = charon_host_vDSP_biquad_CreateSetup(coeffs, sections);
    vDSP_biquad_Setup theirs = vDSP_biquad_CreateSetup(coeffs, sections);
    if (!mine || !theirs) {
        snprintf(detail, sizeof detail, "the port's setup is %s and the host's is %s", mine ? "not NULL" : "NULL",
                 theirs ? "not NULL" : "NULL");
        char label[128];
        snprintf(label, sizeof label, "%s with %d sections", what, (int)sections);
        report(label, 0, detail, 1);
        if (mine) charon_host_vDSP_biquad_DestroySetup(mine);
        if (theirs) vDSP_biquad_DestroySetup(theirs);
        return;
    }

    float hostm_y[SAMPLES];
    const float *hostm_x[1];
    float *hostm_ys[1];
    vDSP_biquadm_Setup hostm = vDSP_biquadm_CreateSetup(coeffs, sections, 1);

    int ok = 1, mform_agrees_with_port = 0, mform_agrees_with_single = 0, compared = 0;
    for (int call = 0; call < 2 && ok; call++) {
        fill_input(mine_x, SAMPLES, call);
        memcpy(their_x, mine_x, sizeof mine_x);
        memset(mine_y, 0x5a, sizeof mine_y);
        memset(their_y, 0x5a, sizeof their_y);
        memset(hostm_y, 0x5a, sizeof hostm_y);
        charon_host_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)mine, mine_delay, mine_x, 1, mine_y, 1,
                                SAMPLES);
        vDSP_biquad((const struct vDSP_biquad_SetupStruct *)theirs, their_delay, their_x, 1, their_y, 1, SAMPLES);
        if (hostm) {
            hostm_x[0] = mine_x;
            hostm_ys[0] = hostm_y;
            vDSP_biquadm(hostm, hostm_x, 1, hostm_ys, 1, SAMPLES);
        }
        for (int i = 0; i < SAMPLES; i++) {
            if (hostm) {
                compared++;
                if (hostm_y[i] == mine_y[i]) mform_agrees_with_port++;
                if (hostm_y[i] == their_y[i]) mform_agrees_with_single++;
            }
            if (mine_y[i] != their_y[i]) {
                snprintf(detail, sizeof detail,
                         "call %d, sample %d is %.9g where the host says %.9g, and the input was %.9g",
                         call, i, mine_y[i], their_y[i], mine_x[i]);
                ok = 0;
                break;
            }
        }
    }
    if (hostm) {
        vDSP_biquadm_DestroySetup(hostm);
        printf("  the host's m-form at N=1 agrees with the port on %d of %d samples, and with the host's single "
               "form on %d\n", mform_agrees_with_port, compared, mform_agrees_with_single);
    }
    printf("   (destroying the port's %d-section setup)\n", (int)sections); fflush(stdout);
    charon_host_vDSP_biquad_DestroySetup(mine);
    printf("   (the port's setup is gone; destroying the host's)\n"); fflush(stdout);
    vDSP_biquad_DestroySetup(theirs);
    printf("   (the host's setup is gone)\n"); fflush(stdout);
    report(what, ok, detail, gating);
    printf("   (after %s)\n", what);
}

static void run_double(const char *what, vDSP_Length sections, const double *pattern, int gating)
{
    double coeffs[5 * 8];
    double mine_x[SAMPLES], their_x[SAMPLES], mine_y[SAMPLES], their_y[SAMPLES];
    double mine_delay[2 * 8] = {0}, their_delay[2 * 8] = {0};
    char detail[256];
    fill_pattern(coeffs, sections, pattern);

    printf("   (double: creating two setups of %d sections)\n", (int)sections); fflush(stdout);
    vDSP_biquad_SetupD mine = charon_host_vDSP_biquad_CreateSetupD(coeffs, sections);
    printf("   (double: the port's setup is %s)\n", mine ? "not NULL" : "NULL"); fflush(stdout);
    vDSP_biquad_SetupD theirs = vDSP_biquad_CreateSetupD(coeffs, sections);
    printf("   (double: the host's setup is %s)\n", theirs ? "not NULL" : "NULL"); fflush(stdout);
    if (!mine || !theirs) {
        snprintf(detail, sizeof detail, "the port's setup is %s and the host's is %s", mine ? "not NULL" : "NULL",
                 theirs ? "not NULL" : "NULL");
        report(what, 0, detail, gating);
        if (mine) charon_host_vDSP_biquad_DestroySetupD(mine);
        if (theirs) vDSP_biquad_DestroySetupD(theirs);
        return;
    }

    int ok = 1;
    for (int call = 0; call < 2 && ok; call++) {
        for (int i = 0; i < SAMPLES; i++)
            mine_x[i] = 0.25 * ((i * 7 + call * 3) % 11) - 1.0;
        memcpy(their_x, mine_x, sizeof mine_x);
        memset(mine_y, 0x5a, sizeof mine_y);
        memset(their_y, 0x5a, sizeof their_y);
        printf("   (double call %d: the port)\n", call); fflush(stdout);
        charon_host_vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)mine, mine_delay, mine_x, 1, mine_y, 1,
                                 SAMPLES);
        vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)theirs, their_delay, their_x, 1, their_y, 1, SAMPLES);
        for (int i = 0; i < SAMPLES; i++)
            if (mine_y[i] != their_y[i]) {
                snprintf(detail, sizeof detail, "call %d, sample %d is %.17g where the host says %.17g, and the input was %.17g",
                         call, i, mine_y[i], their_y[i], mine_x[i]);
                ok = 0;
                break;
            }
    }
    charon_host_vDSP_biquad_DestroySetupD(mine);
    vDSP_biquad_DestroySetupD(theirs);
    report(what, ok, detail, gating);
}

static void run_refusals(void)
{
    double coeffs[40];
    fill_pattern(coeffs, 1, kUnstable);
    checks += 1;
    vDSP_biquad_Setup port_setup = charon_host_vDSP_biquad_CreateSetup(coeffs, 0);
    vDSP_biquad_Setup host_setup = vDSP_biquad_CreateSetup(coeffs, 0);
    if ((port_setup != NULL) != (host_setup != NULL))
        failures++, printf("FAIL a setup of no sections: the port answers %s and the host answers %s\n",
                           port_setup ? "a setup" : "NULL", host_setup ? "a setup" : "NULL");
    else
        printf("ok a setup of no sections: both answer %s\n", host_setup ? "a setup" : "NULL");
    if (port_setup) charon_host_vDSP_biquad_DestroySetup(port_setup);
    if (host_setup) vDSP_biquad_DestroySetup(host_setup);
    charon_host_vDSP_biquad_DestroySetup(NULL);
    vDSP_biquad_DestroySetup(NULL);
    charon_host_vDSP_biquad_DestroySetupD(NULL);
    vDSP_biquad_DestroySetupD(NULL);
    printf("ok a NULL setup is destroyed without a crash on either side\n");
}

struct charon_readback_single {
    vDSP_Length sections;
    double coeff[1];
};

#define KERNEL_SAMPLES 32

static void kernel_form(const double *c, const float *x, float *y, float *delay, int form, int narrow)
{
    float b0 = (float)c[0], b1 = (float)c[1], b2 = (float)c[2], a1 = (float)c[3], a2 = (float)c[4];
    if (narrow) {
        b0 = (float)c[0]; b1 = (float)c[1]; b2 = (float)c[2]; a1 = (float)c[3]; a2 = (float)c[4];
    }
    float xp1 = delay[0], xp2 = delay[1];
    float yp1 = delay[2], yp2 = delay[3];
    float w1 = xp1, w2 = xp2;
    float z1 = yp1, z2 = yp2;
    for (int n = 0; n < KERNEL_SAMPLES; n++) {
        float xn = x[n], out;
        if (form == 0) {
            out = b0 * xn + z1;
            float z1n = b1 * xn - a1 * out + z2;
            float z2n = b2 * xn - a2 * out;
            z1 = z1n; z2 = z2n;
        } else if (form == 1) {
            out = b0 * xn + w1;
            float w1n = xn + b1 * xp1 + w2 - a1 * yp1;
            float w2n = b2 * xp1 - a2 * yp1;
            w1 = w1n; w2 = w2n;
        } else {
            out = b0 * xn + b1 * xp1 + b2 * xp2 - a1 * yp1 - a2 * yp2;
        }
        y[n] = out;
        yp2 = yp1; yp1 = out;
        xp2 = xp1; xp1 = xn;
    }
    delay[0] = xp1; delay[1] = xp2;
    delay[2] = yp1; delay[3] = yp2;
}

static void which_kernel(void)
{
    static const char *names[3] = {"Direct Form I", "Direct Form II", "Direct Form II transposed (the printed form)"};
    double coeffs[5] = {0.4375, -0.8125, 0.0625, 1.625, -0.1875};
    float x[KERNEL_SAMPLES];
    for (int i = 0; i < KERNEL_SAMPLES; i++)
        x[i] = (float)(0.25 * ((i * 7) % 11) - 1.0);

    float host_y[KERNEL_SAMPLES], host_delay[4] = {0, 0, 0, 0};
    vDSP_biquad_Setup host = vDSP_biquad_CreateSetup(coeffs, 1);
    vDSP_biquad((const struct vDSP_biquad_SetupStruct *)host, host_delay, x, 1, host_y, 1, KERNEL_SAMPLES);
    vDSP_biquad_DestroySetup(host);

    vDSP_biquad_Setup mine_setup = charon_host_vDSP_biquad_CreateSetup(coeffs, 1);
    const struct charon_readback_single *mine_struct = (const struct charon_readback_single *)mine_setup;
    printf("  the port's setup: %d sections, coeff is a %s\n", (int)mine_struct->sections,
           sizeof(mine_struct->coeff[0]) == sizeof(double) ? "double" : "float");
    for (int i = 0; i < 5; i++) {
        float narrowed = (float)mine_struct->coeff[i];
        unsigned bits;
        memcpy(&bits, &narrowed, sizeof bits);
        printf("    coeff[%d] stored %-24.17g  narrowed to float %.9g (0x%08x)   the caller sent %-24.17g%s\n", i,
               mine_struct->coeff[i], narrowed, bits, coeffs[i],
               narrowed == (float)coeffs[i] ? "" : "   <-- NOT the value sent");
    }
    printf("  the host, one section, %d samples, delay %g %g %g %g\n", KERNEL_SAMPLES,
           host_delay[0], host_delay[1], host_delay[2], host_delay[3]);
    for (int form = 0; form < 3; form++)
        for (int narrow = 0; narrow < 2; narrow++) {
            float y[KERNEL_SAMPLES], delay[4] = {0, 0, 0, 0};
            kernel_form(coeffs, x, y, delay, form, narrow);
            int same = 1, first = -1;
            for (int i = 0; i < KERNEL_SAMPLES; i++)
                if (y[i] != host_y[i]) { same = 0; if (first < 0) first = i; }
            printf("    %-42s coefficients %-9s %s", names[form], narrow ? "narrowed per step" : "as floats",
                   same ? "MATCHES the host on every sample\n" : "");
            if (!same)
                printf("first differs at %d: %-16.9g against the host's %-16.9g\n", first, y[first], host_y[first]);
        }
}

#define VARIANT_SAMPLES 32

static int variant_matches(int which, const double *c, const float *x, const float *host_y)
{
    float delay[4] = {0, 0, 0, 0};
    float b0 = (float)c[0], b1 = (float)c[1], b2 = (float)c[2], a1 = (float)c[3], a2 = (float)c[4];
    for (int n = 0; n < VARIANT_SAMPLES; n++) {
        float xn = x[n], xp1 = delay[0], xp2 = delay[1], yp1 = delay[2], yp2 = delay[3], out;
        if (which == 0) {
            out = b0 * xn + b1 * xp1 + b2 * xp2 - a1 * yp1 - a2 * yp2;
        } else if (which == 1) {
            out = fmaf(b0, xn, 0.0f);
            out = fmaf(b1, xp1, out);
            out = fmaf(b2, xp2, out);
            out = fmaf(-a1, yp1, out);
            out = fmaf(-a2, yp2, out);
        } else if (which == 2) {
            double acc = (double)b0 * xn + (double)b1 * xp1 + (double)b2 * xp2
                       - (double)a1 * yp1 - (double)a2 * yp2;
            out = (float)acc;
        } else {
            out = b0 * xn + (b1 * xp1 + b2 * xp2) - (a1 * yp1 + a2 * yp2);
        }
        if (out != host_y[n])
            return n;
        delay[1] = delay[0]; delay[0] = xn; delay[3] = delay[2]; delay[2] = out;
    }
    return -1;
}

static void variant_table(void)
{
    double coeffs[5] = {0.4375, -0.8125, 0.0625, 1.625, -0.1875};
    float x[VARIANT_SAMPLES];
    for (int i = 0; i < VARIANT_SAMPLES; i++)
        x[i] = (float)(0.25 * ((i * 7) % 11) - 1.0);
    float host_y[VARIANT_SAMPLES], host_delay[4] = {0, 0, 0, 0};
    vDSP_biquad_Setup host = vDSP_biquad_CreateSetup(coeffs, 1);
    vDSP_biquad((const struct vDSP_biquad_SetupStruct *)host, host_delay, x, 1, host_y, 1, VARIANT_SAMPLES);
    vDSP_biquad_DestroySetup(host);
    printf("  the host over %d samples, output[19] %.9g, delay %.9g %.9g %.9g %.9g\n", VARIANT_SAMPLES,
           host_y[19], host_delay[0], host_delay[1], host_delay[2], host_delay[3]);
    static const char *names[4] = {"the printed form, one expression", "the printed form, fused at each multiply-add",
                                   "the printed form accumulated in double and rounded once a sample",
                                   "reassociated as b0*x + (b1*x1 + b2*x2) - (a1*y1 + a2*y2)"};
    for (int which = 0; which < 4; which++) {
        int at = variant_matches(which, coeffs, x, host_y);
        printf("    %-58s %s\n", names[which],
               at < 0 ? "MATCHES the host on every sample" : "");
        if (at >= 0)
            printf("      first differs at %d\n", at);
    }
}

#define BRUTE_SAMPLES 32
#define BRUTE_NODES 9
#define BRUTE_TREES 2048

typedef struct { int a, b, leaf, fused; } BruteNode;
typedef struct { BruteNode node[BRUTE_NODES]; int used; } BruteTree;
typedef struct { BruteTree tree[BRUTE_TREES]; int count; } BruteForest;

static void brute_seed_printed(BruteForest *out)
{
    BruteTree *t = &out->tree[out->count++];
    for (int i = 0; i < 5; i++) { t->node[i].a = t->node[i].b = -1; t->node[i].leaf = i; t->node[i].fused = 0; }
    int root = 0;
    for (int i = 5; i < 9; i++) {
        t->node[i].leaf = -1;
        t->node[i].a = root;
        t->node[i].b = i - 4;
        t->node[i].fused = 0;
        root = i;
    }
    t->used = 9;
}

static void brute_all(const int *leaves, int count, BruteForest *out)
{
    if (count == 1) {
        BruteTree *t = &out->tree[out->count++];
        t->used = 1;
        t->node[0].a = t->node[0].b = -1;
        t->node[0].leaf = leaves[0];
        t->node[0].fused = 0;
        return;
    }
    for (int mask = 1; mask < (1 << count) - 1; mask++) {
        int left[5], right[5], nl = 0, nr = 0;
        for (int i = 0; i < count; i++) {
            if ((mask >> i) & 1) left[nl++] = leaves[i];
            else right[nr++] = leaves[i];
        }
        BruteForest lf, rf;
        lf.count = 0;
        rf.count = 0;
        brute_all(left, nl, &lf);
        brute_all(right, nr, &rf);
        for (int i = 0; i < lf.count; i++)
            for (int j = 0; j < rf.count; j++) {
                BruteTree *t = &out->tree[out->count++];
                int k = 0;
                for (int q = 0; q < lf.tree[i].used; q++) t->node[k++] = lf.tree[i].node[q];
                int lroot = lf.tree[i].used - 1;
                for (int q = 0; q < rf.tree[j].used; q++) {
                    t->node[k] = rf.tree[j].node[q];
                    if (t->node[k].a >= 0) t->node[k].a += lf.tree[i].used;
                    if (t->node[k].b >= 0) t->node[k].b += lf.tree[i].used;
                    k++;
                }
                int rroot = lf.tree[i].used + rf.tree[j].used - 1;
                t->node[k].a = lroot;
                t->node[k].b = rroot;
                t->node[k].leaf = -1;
                t->node[k].fused = 0;
                t->used = k + 1;
            }
    }
}

static int brute_matches(const BruteTree *tree, const int *how, const double *coeffs, const float *x,
                         const float *host_y, int is_double, int *first_diff)
{
    double delay[4] = {0, 0, 0, 0};
    for (int n = 0; n < BRUTE_SAMPLES; n++) {
        double xn = x[n], xp1 = delay[1], xp2 = delay[0], yp1 = delay[3], yp2 = delay[2];
        double fa[5][2];
        fa[0][0] = coeffs[0]; fa[0][1] = xn;
        fa[1][0] = coeffs[1]; fa[1][1] = xp1;
        fa[2][0] = coeffs[2]; fa[2][1] = xp2;
        fa[3][0] = -coeffs[3]; fa[3][1] = yp1;
        fa[4][0] = -coeffs[4]; fa[4][1] = yp2;
        double got;
        if (is_double) {
            double v[BRUTE_NODES];
            for (int i = 0; i < tree->used; i++) {
                if (tree->node[i].leaf >= 0) {
                    v[i] = fa[tree->node[i].leaf][0] * fa[tree->node[i].leaf][1];
                } else {
                    int l = tree->node[i].a, r = tree->node[i].b;
                    if (how[i] && tree->node[l].leaf >= 0)
                        v[i] = fma(fa[tree->node[l].leaf][0], fa[tree->node[l].leaf][1], v[r]);
                    else
                        v[i] = v[l] + v[r];
                }
            }
            got = v[tree->used - 1];
            if (got != (double)host_y[n]) { *first_diff = n; return 0; }
        } else {
            float v[BRUTE_NODES];
            for (int i = 0; i < tree->used; i++) {
                if (tree->node[i].leaf >= 0) {
                    v[i] = (float)fa[tree->node[i].leaf][0] * (float)fa[tree->node[i].leaf][1];
                } else {
                    int l = tree->node[i].a, r = tree->node[i].b;
                    if (how[i] && tree->node[l].leaf >= 0)
                        v[i] = fmaf((float)fa[tree->node[l].leaf][0], (float)fa[tree->node[l].leaf][1], v[r]);
                    else
                        v[i] = v[l] + v[r];
                }
            }
            got = (double)v[tree->used - 1];
            if ((float)got != host_y[n]) { *first_diff = n; return 0; }
        }
        delay[0] = delay[1]; delay[1] = xn; delay[2] = delay[3]; delay[3] = got;
    }
    return 1;
}

static void brute_dump(int i, const BruteTree *tree, const int *how, char *out, size_t n, size_t *at)
{
    if (tree->node[i].leaf >= 0) {
        *at += (size_t)snprintf(out + *at, n - *at, "t%d", tree->node[i].leaf);
        return;
    }
    *at += (size_t)snprintf(out + *at, n - *at, "%s", how[i] ? "fma(" : "+(");
    brute_dump(tree->node[i].a, tree, how, out, n, at);
    *at += (size_t)snprintf(out + *at, n - *at, ", ");
    brute_dump(tree->node[i].b, tree, how, out, n, at);
    *at += (size_t)snprintf(out + *at, n - *at, ")");
}

static const char *brute_how_text(const BruteTree *tree, const int *how)
{
    static char text[256];
    size_t at = 0;
    text[0] = 0;
    brute_dump(tree->used - 1, tree, how, text, sizeof text, &at);
    return text;
}

static int brute_inner(const BruteTree *tree, int *inner)
{
    int n = 0;
    for (int i = 0; i < tree->used; i++)
        if (tree->node[i].leaf < 0) inner[n++] = i;
    return n;
}

static void brute_choose(const BruteTree *tree, const int *inner, int count, int code, int *how)
{
    for (int q = 0; q < BRUTE_NODES; q++) how[q] = 0;
    for (int q = 0; q < count; q++) how[inner[q]] = (code >> q) & 1;
}

static int brute_total(const BruteTree *tree)
{
    int inner[BRUTE_NODES], n = brute_inner(tree, inner);
    int total = 1;
    for (int q = 0; q < n; q++) total *= 2;
    return total;
}

static int brute_total_all(const BruteForest *forest)
{
    int total = 0;
    for (int t = 0; t < forest->count; t++) total += brute_total(&forest->tree[t]);
    return total;
}

static int brute_controls(const BruteForest *forest, const double *coeffs, const float *x, const float *port_y)
{
    int found_tree = -1, found_code = -1, how[BRUTE_NODES];
    for (int t = 0; t < forest->count && found_tree < 0; t++) {
        int inner[BRUTE_NODES], n = brute_inner(&forest->tree[t], inner);
        for (int code = 0; code < (1 << n); code++) {
            int at = -1;
            brute_choose(&forest->tree[t], inner, n, code, how);
            if (brute_matches(&forest->tree[t], how, coeffs, x, port_y, 0, &at)) {
                found_tree = t;
                found_code = code;
                break;
            }
        }
    }
    if (found_tree < 0) {
        printf("    CONTROL 1 FAILED: none of the %d variants reproduces the port on every sample, so this"
               " space does not contain the port's arithmetic\n", brute_total_all(forest));
        return 0;
    }
    float want = (float)coeffs[0] * x[0];
    int violations = 0;
    for (int t = 0; t < forest->count; t++) {
        int inner[BRUTE_NODES], n = brute_inner(&forest->tree[t], inner);
        for (int code = 0; code < (1 << n); code++) {
            double delay[4] = {0, 0, 0, 0};
            double xn = x[0], fa[5][2];
            fa[0][0] = coeffs[0]; fa[0][1] = xn;
            fa[1][0] = coeffs[1]; fa[1][1] = delay[1];
            fa[2][0] = coeffs[2]; fa[2][1] = delay[0];
            fa[3][0] = -coeffs[3]; fa[3][1] = delay[3];
            fa[4][0] = -coeffs[4]; fa[4][1] = delay[2];
            float v[BRUTE_NODES];
            const BruteTree *tr = &forest->tree[t];
            brute_choose(tr, inner, n, code, how);
            for (int i = 0; i < tr->used; i++) {
                if (tr->node[i].leaf >= 0)
                    v[i] = (float)fa[tr->node[i].leaf][0] * (float)fa[tr->node[i].leaf][1];
                else {
                    int l = tr->node[i].a, r = tr->node[i].b;
                    if (how[i] && tr->node[l].leaf >= 0)
                        v[i] = fmaf((float)fa[tr->node[l].leaf][0], (float)fa[tr->node[l].leaf][1], v[r]);
                    else
                        v[i] = v[l] + v[r];
                }
            }
            if (v[tr->used - 1] != want) violations++;
        }
    }
    if (violations) {
        printf("    CONTROL 2 FAILED: %d variants do not give b0 * x[0] at sample 0 with a zero delay\n", violations);
        return 0;
    }
    printf("    control 1 passed: variant %d of the space reproduces the port bit for bit (tree %d, and the\n"
           "      combines %s)\n", found_code, found_tree, brute_how_text(&forest->tree[found_tree], how));
    printf("    control 2 passed: all %d variants give b0 * x[0] at sample 0 with a zero delay\n",
           brute_total_all(forest));
    return 1;
}

static int brute_search(const char *label, const double *coeffs, const float *x, const float *host_y,
                        const float *port_y)
{
    int leaves[5] = {0, 1, 2, 3, 4};
    BruteForest forest;
    forest.count = 0;
    brute_seed_printed(&forest);
    brute_all(leaves, 5, &forest);
    if (!brute_controls(&forest, coeffs, x, port_y)) {
        return 0;
    }
    int tried = 0, matched_float = 0, how[BRUTE_NODES];
    int best_float = -1;
    char best_shape[256] = {0};
    for (int t = 0; t < forest.count; t++) {
        int inner[BRUTE_NODES], n = brute_inner(&forest.tree[t], inner);
        for (int code = 0; code < (1 << n); code++) {
            int diff = -1;
            tried++;
            brute_choose(&forest.tree[t], inner, n, code, how);
            if (brute_matches(&forest.tree[t], how, coeffs, x, host_y, 0, &diff)) matched_float++;
            else if (diff > best_float) {
                best_float = diff;
                strncpy(best_shape, brute_how_text(&forest.tree[t], how), sizeof best_shape - 1);
            }
        }
    }
    printf("  %s: %d trees over the five labelled leaves, %d variants, each one a whole run of the"
           " recurrence with its own answer fed back; float %s\n", label, forest.count, tried,
           matched_float ? "MATCHES the host on every sample" : "matches none");
    if (!matched_float)
        printf("    the variant that survives longest first differs at sample %d of %d, and it is: %s\n",
               best_float, BRUTE_SAMPLES, best_shape);
    return 0;
}

static void brute_report(void)
{
    double stable[5] = {0.0674551234, 0.1349102468, 0.0674551234, -1.1429805025, 0.4128015981};
    double unstable[5] = {0.4375, -0.8125, 0.0625, 1.625, -0.1875};
    float x[BRUTE_SAMPLES];
    for (int i = 0; i < BRUTE_SAMPLES; i++)
        x[i] = (float)(0.25 * ((i * 7) % 11) - 1.0);
    float host_y[BRUTE_SAMPLES], delay[4];
    for (int filter = 0; filter < 2; filter++) {
        const double *c = filter ? unstable : stable;
        delay[0] = delay[1] = delay[2] = delay[3] = 0.0f;
        vDSP_biquad_Setup host = vDSP_biquad_CreateSetup(c, 1);
        vDSP_biquad((const struct vDSP_biquad_SetupStruct *)host, delay, x, 1, host_y, 1, BRUTE_SAMPLES);
        vDSP_biquad_DestroySetup(host);
        float port_y[BRUTE_SAMPLES], port_delay[4] = {0, 0, 0, 0};
        vDSP_biquad_Setup ps = charon_host_vDSP_biquad_CreateSetup(c, 1);
        charon_host_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)ps, port_delay, x, 1, port_y, 1,
                                BRUTE_SAMPLES);
        charon_host_vDSP_biquad_DestroySetup(ps);
        printf("  %s\n", filter ? "the unstable filter, pole -1.733" : "the stable filter, pole about 0.643");
        brute_search(filter ? "the unstable filter, pole -1.733" : "the stable filter, pole about 0.643", c, x,
                     host_y, port_y);
    }
}

#define SURVEY_OFFSETS 16

static float survey_f[1024];
static double survey_d[1024];

static int survey_one(const char *label, const double *c)
{
    unsigned host_f[SURVEY_OFFSETS][SAMPLES];
    unsigned long long host_d[SURVEY_OFFSETS][SAMPLES];
    unsigned port_f[SAMPLES];
    unsigned long long port_d[SAMPLES];
    int distinct_f = 1, distinct_d = 1, port_stable_f = 1, port_stable_d = 1;
    int worst_f = 0, worst_d = 0;

    for (int k = 0; k < SURVEY_OFFSETS; k++) {
        float *x = survey_f + k, *y = survey_f + 64 + k, *d = survey_f + 128 + k;
        for (int i = 0; i < SAMPLES; i++) x[i] = (float)(0.25 * ((i * 7) % 11) - 1.0);
        memset(d, 0, 4 * sizeof(float));
        memset(y, 0x5a, SAMPLES * sizeof(float));
        vDSP_biquad_Setup host = vDSP_biquad_CreateSetup(c, 1);
        vDSP_biquad((const struct vDSP_biquad_SetupStruct *)host, d, x, 1, y, 1, SAMPLES);
        vDSP_biquad_DestroySetup(host);
        for (int i = 0; i < SAMPLES; i++) memcpy(&host_f[k][i], &y[i], sizeof y[i]);

        double *xd = survey_d + k, *yd = survey_d + 64 + k, *dd = survey_d + 128 + k;
        for (int i = 0; i < SAMPLES; i++) xd[i] = (double)(float)(0.25 * ((i * 7) % 11) - 1.0);
        memset(dd, 0, 4 * sizeof(double));
        memset(yd, 0x5a, SAMPLES * sizeof(double));
        vDSP_biquad_SetupD hostd = vDSP_biquad_CreateSetupD(c, 1);
        vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)hostd, dd, xd, 1, yd, 1, SAMPLES);
        vDSP_biquad_DestroySetupD(hostd);
        for (int i = 0; i < SAMPLES; i++) memcpy(&host_d[k][i], &yd[i], sizeof yd[i]);

        float *px = survey_f + k, *py = survey_f + 64 + k, *pd = survey_f + 128 + k;
        for (int i = 0; i < SAMPLES; i++) px[i] = (float)(0.25 * ((i * 7) % 11) - 1.0);
        memset(pd, 0, 4 * sizeof(float));
        memset(py, 0x5a, SAMPLES * sizeof(float));
        vDSP_biquad_Setup ps = charon_host_vDSP_biquad_CreateSetup(c, 1);
        charon_host_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)ps, pd, px, 1, py, 1, SAMPLES);
        charon_host_vDSP_biquad_DestroySetup(ps);
        if (k == 0) for (int i = 0; i < SAMPLES; i++) memcpy(&port_f[i], &py[i], sizeof py[i]);
        else for (int i = 0; i < SAMPLES; i++)
            if (memcmp(&port_f[i], &py[i], sizeof py[i]) != 0) port_stable_f = 0;

        double *pxd = survey_d + k, *pyd = survey_d + 64 + k, *pdd = survey_d + 128 + k;
        for (int i = 0; i < SAMPLES; i++) pxd[i] = (double)(float)(0.25 * ((i * 7) % 11) - 1.0);
        memset(pdd, 0, 4 * sizeof(double));
        memset(pyd, 0x5a, SAMPLES * sizeof(double));
        vDSP_biquad_SetupD psd = charon_host_vDSP_biquad_CreateSetupD(c, 1);
        charon_host_vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)psd, pdd, pxd, 1, pyd, 1, SAMPLES);
        charon_host_vDSP_biquad_DestroySetupD(psd);
        if (k == 0) for (int i = 0; i < SAMPLES; i++) memcpy(&port_d[i], &pyd[i], sizeof pyd[i]);
        else for (int i = 0; i < SAMPLES; i++)
            if (memcmp(&port_d[i], &pyd[i], sizeof pyd[i]) != 0) port_stable_d = 0;
    }

    for (int k = 1; k < SURVEY_OFFSETS; k++) {
        if (memcmp(host_f[0], host_f[k], sizeof host_f[k]) != 0) distinct_f++;
        if (memcmp(host_d[0], host_d[k], sizeof host_d[k]) != 0) distinct_d++;
    }
    for (int i = 0; i < SAMPLES; i++) {
        unsigned lo = host_f[0][i], hi = host_f[0][i];
        unsigned long long dlo = host_d[0][i], dhi = host_d[0][i];
        for (int k = 1; k < SURVEY_OFFSETS; k++) {
            if (host_f[k][i] < lo) lo = host_f[k][i];
            if (host_f[k][i] > hi) hi = host_f[k][i];
            if (host_d[k][i] < dlo) dlo = host_d[k][i];
            if (host_d[k][i] > dhi) dhi = host_d[k][i];
        }
        if ((int)(hi - lo) > worst_f) worst_f = (int)(hi - lo);
        if ((int)(dhi - dlo) > worst_d) worst_d = (int)(dhi - dlo);
    }
    printf("  %s, one section, %d samples, the same coefficients and input and a zero delay, the caller's"
           " buffers walked through %d offsets of one %s:\n", label, SAMPLES, SURVEY_OFFSETS,
           "float");
    printf("    the host's float answer takes %d distinct values over the %d offsets, moving by at most %d ULPs\n",
           distinct_f, SURVEY_OFFSETS, worst_f);
    printf("    the host's double answer takes %d distinct values over the same offsets, moving by at most"
           " %d ULPs\n", distinct_d, worst_d);
    printf("    the port's answer is %s at every offset, in float and in double\n",
           port_stable_f && port_stable_d ? "the same" : "NOT the same");
    return port_stable_f && port_stable_d;
}

static void alignment_survey(void)
{
    checks += 1;
    int stable = survey_one("the stable filter, poles about 0.643", kStable);
    int unstable = survey_one("the unstable filter, pole -1.733", kUnstable);
    if (stable && unstable)
        printf("ok the port's answer does not move with the caller's buffer alignment, and the host's does\n");
    else
        printf("FAIL the port's own answer moves with the caller's buffer alignment, which no scalar kernel"
               " should do\n");
    if (!stable || !unstable) failures++;
}

static void initial_state(void)
{
    double stable[5] = {0.0674551234, 0.1349102468, 0.0674551234, -1.1429805025, 0.4128015981};
    float x[8];
    for (int i = 0; i < 8; i++)
        x[i] = (float)(0.25 * ((i * 7) % 11) - 1.0);
    printf("  the stable filter, coefficients %g %g %g %g %g\n", stable[0], stable[1], stable[2], stable[3], stable[4]);
    printf("  the input's first three samples %g %g %g, and b0 * x[0] = %.17g\n", x[0], x[1], x[2],
           (double)((float)stable[0] * x[0]));

    float host_delay[4] = {0, 0, 0, 0}, host_y[8];
    float port_delay[4] = {0, 0, 0, 0}, port_y[8];
    vDSP_biquad_Setup hs = vDSP_biquad_CreateSetup(stable, 1);
    vDSP_biquad((const struct vDSP_biquad_SetupStruct *)hs, host_delay, x, 1, host_y, 1, 8);
    vDSP_biquad_DestroySetup(hs);
    vDSP_biquad_Setup ps = charon_host_vDSP_biquad_CreateSetup(stable, 1);
    charon_host_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)ps, port_delay, x, 1, port_y, 1, 8);
    charon_host_vDSP_biquad_DestroySetup(ps);

    printf("    sample 0: the host %.9g, the port %.9g, b0*x0 %.9g\n", host_y[0], port_y[0],
           (float)stable[0] * x[0]);
    printf("    sample 1: the host %.9g, the port %.9g\n", host_y[1], port_y[1]);
    printf("    Delay after the call, the host: %.9g %.9g %.9g %.9g\n", host_delay[0], host_delay[1], host_delay[2],
           host_delay[3]);
    printf("    Delay after the call, the port: %.9g %.9g %.9g %.9g\n", port_delay[0], port_delay[1], port_delay[2],
           port_delay[3]);
    printf("    the input's last two samples, which the pseudocode says land in Delay[0] and Delay[1]: %g %g\n",
           x[6], x[7]);
}

static void zero_sections(void)
{
    double coeffs[5] = {0.4375, -0.8125, 0.0625, 1.625, -0.1875};
    vDSP_biquad_Setup single = vDSP_biquad_CreateSetup(coeffs, 0);
    vDSP_biquad_SetupD single_d = vDSP_biquad_CreateSetupD(coeffs, 0);
    vDSP_biquadm_Setup multi = vDSP_biquadm_CreateSetup(coeffs, 0, 1);
    vDSP_biquadm_Setup multi_zero_channels = vDSP_biquadm_CreateSetup(coeffs, 1, 0);
    printf("  M = 0, one channel : the single form %s, the m-form %s\n", single ? "answers a setup" : "answers NULL",
           multi ? "answers a setup" : "answers NULL");
    printf("  M = 0, D           : the single form %s\n", single_d ? "answers a setup" : "answers NULL");
    printf("  M = 1, N = 0       : the m-form %s\n",
           multi_zero_channels ? "answers a setup" : "answers NULL");
    if (single) vDSP_biquad_DestroySetup(single);
    if (single_d) vDSP_biquad_DestroySetupD(single_d);
    if (multi) vDSP_biquadm_DestroySetup(multi);
    if (multi_zero_channels) vDSP_biquadm_DestroySetup(multi_zero_channels);
}

static void delay_layout(void)
{
    static const float slot[4] = {2.0f, 3.0f, 5.0f, 7.0f};
    static const char *coefficient[5] = {"b0 * x", "b1", "b2", "a1", "a2"};
    int agree = 1;
    for (int which = 0; which < 2; which++) {
        printf("  %s, one coefficient and one delay slot at a time, the input 1:\n",
               which ? "the double form" : "the float form");
        printf("     %-8s", "coef\\slot");
        for (int s = 0; s < 4; s++) printf(" D[%d]=%-6g", s, (double)slot[s]);
        printf("\n");
        for (int coeff = 0; coeff < 5; coeff++) {
            double one[5] = {0, 0, 0, 0, 0};
            one[coeff] = 1.0;
            printf("     %-8s", coefficient[coeff]);
            for (int s = 0; s < 4; s++) {
                float dh[4] = {0, 0, 0, 0}, dp[4] = {0, 0, 0, 0}, x[2] = {1.0f, 1.0f}, mine[2] = {0, 0},
                      theirs[2] = {0, 0};
                double ddh[4] = {0, 0, 0, 0}, ddp[4] = {0, 0, 0, 0}, dx[2] = {1.0, 1.0}, mine_d[2] = {0, 0},
                       theirs_d[2] = {0, 0};
                dh[s] = dp[s] = slot[s];
                ddh[s] = ddp[s] = (double)slot[s];
                vDSP_biquad_Setup host = vDSP_biquad_CreateSetup(one, 1);
                vDSP_biquad((const struct vDSP_biquad_SetupStruct *)host, dh, x, 1, theirs, 1, 2);
                vDSP_biquad_DestroySetup(host);
                vDSP_biquad_Setup port = charon_host_vDSP_biquad_CreateSetup(one, 1);
                charon_host_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)port, dp, x, 1, mine, 1, 2);
                charon_host_vDSP_biquad_DestroySetup(port);
                vDSP_biquad_SetupD host_d = vDSP_biquad_CreateSetupD(one, 1);
                vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)host_d, ddh, dx, 1, theirs_d, 1, 2);
                vDSP_biquad_DestroySetupD(host_d);
                vDSP_biquad_SetupD port_d = charon_host_vDSP_biquad_CreateSetupD(one, 1);
                charon_host_vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)port_d, ddp, dx, 1, mine_d, 1, 2);
                charon_host_vDSP_biquad_DestroySetupD(port_d);
                int same = mine[0] == theirs[0] && mine_d[0] == theirs_d[0];
                if (!same) agree = 0;
                printf(" %11.9g%s", (double)theirs[0], same ? "" : " (the port differs)");
            }
            printf("\n");
        }
    }
    double stable[5] = {0.0674551234, 0.1349102468, 0.0674551234, -1.1429805025, 0.4128015981};
    printf("  the caller's own coefficients, one at a time, and the product this program computes for it:\n");
    for (int which = 0; which < 2; which++) {
        printf("     %-8s", which ? "double" : "float");
        for (int s = 0; s < 4; s++) printf(" D[%d]=%-6g", s, (double)slot[s]);
        printf("\n");
        for (int coeff = 0; coeff < 5; coeff++) {
            double one[5] = {0, 0, 0, 0, 0};
            one[coeff] = stable[coeff];
            printf("     %-8s", coefficient[coeff]);
            for (int s = 0; s < 4; s++) {
                float dh[4] = {0, 0, 0, 0}, dp[4] = {0, 0, 0, 0}, x[2] = {1.0f, 1.0f}, mine[2] = {0, 0},
                      theirs[2] = {0, 0};
                double ddh[4] = {0, 0, 0, 0}, ddp[4] = {0, 0, 0, 0}, dx[2] = {1.0, 1.0}, mine_d[2] = {0, 0},
                       theirs_d[2] = {0, 0};
                dh[s] = dp[s] = slot[s];
                ddh[s] = ddp[s] = (double)slot[s];
                vDSP_biquad_Setup host = vDSP_biquad_CreateSetup(one, 1);
                vDSP_biquad((const struct vDSP_biquad_SetupStruct *)host, dh, x, 1, theirs, 1, 2);
                vDSP_biquad_DestroySetup(host);
                vDSP_biquad_Setup port = charon_host_vDSP_biquad_CreateSetup(one, 1);
                charon_host_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)port, dp, x, 1, mine, 1, 2);
                charon_host_vDSP_biquad_DestroySetup(port);
                vDSP_biquad_SetupD host_d = vDSP_biquad_CreateSetupD(one, 1);
                vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)host_d, ddh, dx, 1, theirs_d, 1, 2);
                vDSP_biquad_DestroySetupD(host_d);
                vDSP_biquad_SetupD port_d = charon_host_vDSP_biquad_CreateSetupD(one, 1);
                charon_host_vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)port_d, ddp, dx, 1, mine_d, 1, 2);
                charon_host_vDSP_biquad_DestroySetupD(port_d);
                static const int lands[5] = {-1, 1, 0, 3, 2};
                int here = lands[coeff] < 0 || lands[coeff] == s;
                float want_f = here ? (float)stable[coeff] * (lands[coeff] < 0 ? 1.0f : slot[s]) : 0.0f;
                double want_d = here ? stable[coeff] * (lands[coeff] < 0 ? 1.0 : (double)slot[s]) : 0.0;
                if (coeff >= 3) {
                    want_f = -want_f;
                    want_d = -want_d;
                }
                int same = mine[0] == theirs[0] && theirs[0] == want_f && mine_d[0] == theirs_d[0] &&
                           theirs_d[0] == want_d;
                if (!same) agree = 0;
                printf(" %11.9g%s", (double)theirs[0], same ? "" : " (differs, or not the product above)");
            }
            printf("\n");
        }
    }

    checks += 1;
    if (agree)
        printf("ok each coefficient multiplies the delay slot both sides use, at the width both sides use,"
               " with the sign both sides use\n");
    else {
        failures++;
        printf("FAIL the two sides read the delay differently, or read a coefficient at another width;"
               " the grids above say where\n");
    }
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        run_float("vDSP_biquad over one section, two calls, stable", 1, kStable, 0);
        run_float("vDSP_biquad over four sections, two calls, stable", 4, kStable, 0);
        run_double("vDSP_biquadD over one section, two calls, stable", 1, kStable, 0);
        run_double("vDSP_biquadD over three sections, two calls, stable", 3, kStable, 0);
        run_float("vDSP_biquad over one section, two calls, UNSTABLE (pole -1.733)", 1, kUnstable, 0);
        run_float("vDSP_biquad over four sections, two calls, UNSTABLE (pole -1.733)", 4, kUnstable, 0);
        run_double("vDSP_biquadD over one section, two calls, UNSTABLE (pole -1.733)", 1, kUnstable, 0);
        run_double("vDSP_biquadD over three sections, two calls, UNSTABLE (pole -1.733)", 3, kUnstable, 0);
        printf("   (which delay slot does each coefficient multiply?)\n");
        delay_layout();
        printf("   (is the host's answer a function of its inputs?)\n");
        alignment_survey();
        printf("   (the initial state)\n");
        initial_state();
        printf("   (brute force: every association, every fused subset)\n");
        brute_report();
        printf("   (the variant table on the unstable input)\n");
        variant_table();
        printf("   (which kernel)\n");
        which_kernel();
        printf("   (zero sections)\n");
        zero_sections();
        run_refusals();
        printf("   (after the refusals)\n");
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
