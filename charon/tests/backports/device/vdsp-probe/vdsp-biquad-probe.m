// vDSP_biquad on the emulated iPhone2,1 6.1.3 (10B329) guest: **the release's own function against this
// band's kernel, on the same inputs, compared by bit pattern.**
//
// This replaces the macOS arm64 host as the oracle for the shape, and the reason is not a preference.
// These rows are native on 6.0 armv7, and that is the implementation a 4.3-5.x application calls;
// pre-VFPv4 armv7 VFP has no fused multiply-add, and the macOS host has one. A 1-ULP difference measured
// there says nothing about the target. Here both sides run on the target's own arithmetic.
//
// Every comparison is on the **bit pattern**, never `==`: NaN never equals NaN, and a NaN that agrees
// exactly must still be reported as agreeing. Sign of zero is compared too, since -0 and +0 are equal as
// floats and are different bits.
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <arm_neon.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

// The port's six, renamed by the build. **All six are declared here**, including the two frees: the port's
// own file is a separate translation unit and declares nothing in a header this probe can include, so the
// calls to the Destroy pair below were implicit declarations - which this clang rejects outright, so the
// probe did not compile at all.
vDSP_biquad_Setup charon_probe_vDSP_biquad_CreateSetup(const double *coeffs, vDSP_Length m);
vDSP_biquad_SetupD charon_probe_vDSP_biquad_CreateSetupD(const double *coeffs, vDSP_Length m);
void charon_probe_vDSP_biquad_DestroySetup(vDSP_biquad_Setup setup);
void charon_probe_vDSP_biquad_DestroySetupD(vDSP_biquad_SetupD setup);
void charon_probe_vDSP_biquad(const struct vDSP_biquad_SetupStruct *setup, float *delay, const float *x,
                              vDSP_Stride ix, float *y, vDSP_Stride iy, vDSP_Length n);
void charon_probe_vDSP_biquadD(const struct vDSP_biquad_SetupStructD *setup, double *delay, const double *x,
                               vDSP_Stride ix, double *y, vDSP_Stride iy, vDSP_Length n);

static int checks, failures;

static uint32_t bits_of(const void *p, size_t n)
{
    const uint8_t *b = (const uint8_t *)p;
    uint32_t h = 2166136261u;
    for (size_t i = 0; i < n; i++) { h ^= b[i]; h *= 16777619u; }
    return h;
}

// **The first differing index is printed in ELEMENTS, always, with both values at it.** An earlier version
// printed whole-array hashes and named a byte only when the two sides were the same length and at most 64
// bytes - which is why a run whose ten failures were all one defect could not say where they were: the two
// sides were 512 bytes of which 384 were unwritten, so the hashes were of different garbage. `width` is the
// element size, so the index printed is the sample.
static void report(const char *what, const void *a, size_t an, const void *b, size_t bn, const char *note,
                   size_t width)
{
    checks++;
    if (an == bn && memcmp(a, b, an) == 0) {
        printf("ok %s%s%s\n", what, note[0] ? " - " : "", note);
        return;
    }
    failures++;
    printf("FAIL %s%s%s\n", what, note[0] ? " - " : "", note);
    printf("     the release's bytes %08x over %zu, the port's %08x over %zu\n", bits_of(a, an), an,
           bits_of(b, bn), bn);
    if (an == bn) {
        const uint8_t *pa = (const uint8_t *)a, *pb = (const uint8_t *)b;
        for (size_t i = 0; i < an; i += width)
            if (memcmp(pa + i, pb + i, width) != 0) {
                uint64_t va = 0, vb = 0;
                memcpy(&va, pa + i, width);
                memcpy(&vb, pb + i, width);
                printf("     first differs at index %zu: the release 0x%llx, the port 0x%llx\n", i / width,
                       (unsigned long long)va, (unsigned long long)vb);
                break;
            }
    } else {
        printf("     the two sides are %zu and %zu bytes, so there is no index in common\n", an, bn);
    }
}

// **The red control's plant, read once.** `VDSPPROBE_PLANT_ULP=<n>` moves the port's float answer at sample
// `n` by one unit in the last place, after the call and before the comparison, so the float case has to go
// red AND name that index. It is the comparison's sensitivity this tests, not the port's arithmetic: the
// bytes the port wrote are untouched, and the plant moves them in this file's own copy of them.
static int plant_ulp = -1;
static int plant_applied;

static void maybe_plant_ulp(float *y, size_t count)
{
    plant_applied = 0;
    if (plant_ulp < 0 || (size_t)plant_ulp >= count)
        return;
    int32_t bits;
    memcpy(&bits, &y[plant_ulp], sizeof bits);
    bits += 1;
    memcpy(&y[plant_ulp], &bits, sizeof bits);
    plant_applied = 1;
}

void charon_probe_vDSP_sve_svesq(const float *a, vDSP_Stride ia, float *sum, float *sumsquares, vDSP_Length n);
void charon_probe_vDSP_sve_svesqD(const double *a, vDSP_Stride ia, double *sum, double *sumsquares, vDSP_Length n);

#define SAMPLES 32

// The stable filter (poles about 0.643) and the unstable one (a pole at -1.733), so the guest sees both a
// well-conditioned case and the one that amplifies a difference.
static const double kStable[5] = {0.0674551234, 0.1349102468, 0.0674551234, -1.1429805025, 0.4128015981};
static const double kUnstable[5] = {0.4375, -0.8125, 0.0625, 1.625, -0.1875};

static void run_float(const char *label, const double *coeffs, vDSP_Length sections, vDSP_Stride stride)
{
    double all[5 * 8];
    for (vDSP_Length s = 0; s < sections; s++)
        for (int k = 0; k < 5; k++) all[s * 5 + k] = coeffs[k] + s * 0.03125;
    float x[SAMPLES * 4], host_y[SAMPLES * 4], port_y[SAMPLES * 4];
    for (int i = 0; i < SAMPLES * 4; i++)
        x[i] = (float)(0.25 * ((i * 7) % 11) - 1.0);
    // 2 * (M + 1), from the pseudocode's inclusive `s <= S`
    float host_delay[2 * 9], port_delay[2 * 9];
    for (int i = 0; i < 2 * 9; i++) { host_delay[i] = 0.0f; port_delay[i] = 0.0f; }

    vDSP_biquad_Setup host = vDSP_biquad_CreateSetup(all, sections);
    vDSP_biquad_Setup port = charon_probe_vDSP_biquad_CreateSetup(all, sections);
    if (!host || !port) {
        printf("note %s: the release's setup %s, the port's %s\n", label, host ? "exists" : "is NULL",
               port ? "exists" : "is NULL");
        if (host) vDSP_biquad_DestroySetup(host);
        if (port) charon_probe_vDSP_biquad_DestroySetup(port);
        return;
    }
    // two calls on one setup, so the carried state is compared too
    for (int call = 0; call < 2; call++) {
        // **Both answers are zeroed before every call, and only the SAMPLES the call writes are compared.**
        // The arrays are SAMPLES * 4 long because the strided case reads four times as far into `x`, and a
        // first version compared `sizeof host_y` - 128 floats for a call that writes 32 - so 96 unwritten
        // floats on each side were compared and each side's unwritten tail is its own stack: ten red cases
        // on the 6.1.3 guest that were neither the release nor the port. The delay, which is compared
        // exactly, was ok on every case, and the search's per-sample comparison over the 32 written samples
        // reported 0 of 32 differing - which is what said so.
        memset(host_y, 0, sizeof host_y);
        memset(port_y, 0, sizeof port_y);
        vDSP_biquad((const struct vDSP_biquad_SetupStruct *)host, host_delay, x, stride, host_y, 1, SAMPLES);
        charon_probe_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)port, port_delay, x, stride, port_y, 1, SAMPLES);
        maybe_plant_ulp(port_y, SAMPLES);
        char note[80];
        snprintf(note, sizeof note, "%s, %d sections, stride %ld, call %d", label, (int)sections, (long)stride, call);
        report(note, host_y, SAMPLES * sizeof(float), port_y, SAMPLES * sizeof(float), "the samples, bit for bit",
               sizeof(float));
        if (plant_applied)
            printf("     the red control's plant moved the port's sample %d by one ULP before this "
                   "comparison\n", plant_ulp);
        char delay_note[96];
        snprintf(delay_note, sizeof delay_note, "%s, %d sections, call %d", label, (int)sections, call);
        report(delay_note, host_delay, (2 * (sections + 1)) * sizeof(float), port_delay,
               (2 * (sections + 1)) * sizeof(float), "the Delay the call left behind, bit for bit", sizeof(float));
    }
    vDSP_biquad_DestroySetup(host);
    charon_probe_vDSP_biquad_DestroySetup(port);
}

static void run_double(const char *label, const double *coeffs, vDSP_Length sections)
{
    double all[5 * 8], x[SAMPLES], host_y[SAMPLES], port_y[SAMPLES];
    for (vDSP_Length s = 0; s < sections; s++)
        for (int k = 0; k < 5; k++) all[s * 5 + k] = coeffs[k] + s * 0.03125;
    for (int i = 0; i < SAMPLES; i++)
        x[i] = 0.25 * ((i * 7) % 11) - 1.0;
    double host_delay[2 * 9], port_delay[2 * 9];
    for (int i = 0; i < 2 * 9; i++) { host_delay[i] = 0.0; port_delay[i] = 0.0; }
    vDSP_biquad_SetupD host = vDSP_biquad_CreateSetupD(all, sections);
    vDSP_biquad_SetupD port = charon_probe_vDSP_biquad_CreateSetupD(all, sections);
    if (!host || !port) {
        printf("note %s: the release's setup %s, the port's %s\n", label, host ? "exists" : "is NULL",
               port ? "exists" : "is NULL");
        if (host) vDSP_biquad_DestroySetupD(host);
        if (port) charon_probe_vDSP_biquad_DestroySetupD(port);
        return;
    }
    for (int call = 0; call < 2; call++) {
        memset(host_y, 0, sizeof host_y);
        memset(port_y, 0, sizeof port_y);
        vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)host, host_delay, x, 1, host_y, 1, SAMPLES);
        charon_probe_vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)port, port_delay, x, 1, port_y, 1, SAMPLES);
        char note[80];
        snprintf(note, sizeof note, "%s, %d sections, call %d", label, (int)sections, call);
        report(note, host_y, sizeof host_y, port_y, sizeof port_y, "the samples, bit for bit", sizeof(double));
        char delay_note[96];
        snprintf(delay_note, sizeof delay_note, "%s, %d sections, call %d", label, (int)sections, call);
        report(delay_note, host_delay, (2 * (sections + 1)) * sizeof(double), port_delay,
               (2 * (sections + 1)) * sizeof(double), "the Delay the call left behind, bit for bit", sizeof(double));
    }
    vDSP_biquad_DestroySetupD(host);
    charon_probe_vDSP_biquad_DestroySetupD(port);
}

// A NaN and a signed zero through both, compared by bit pattern - the case a float `==` could never settle.
static void run_specials(void)
{
    float x[8], host_y[8], port_y[8], host_delay[4], port_delay[4];
    float values[8] = {NAN, -0.0f, 0.0f, 1.0f, -1.0f, NAN, -0.0f, 0.0f};
    memcpy(x, values, sizeof x);
    for (int i = 0; i < 4; i++) { host_delay[i] = 0.0f; port_delay[i] = 0.0f; }
    vDSP_biquad_Setup host = vDSP_biquad_CreateSetup(kUnstable, 1);
    vDSP_biquad_Setup port = charon_probe_vDSP_biquad_CreateSetup(kUnstable, 1);
    memset(host_y, 0, sizeof host_y);
    memset(port_y, 0, sizeof port_y);
    vDSP_biquad((const struct vDSP_biquad_SetupStruct *)host, host_delay, x, 1, host_y, 1, 8);
    charon_probe_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)port, port_delay, x, 1, port_y, 1, 8);
    report("a NaN and signed zeroes, one section", host_y, sizeof host_y, port_y, sizeof port_y,
           "by bit pattern, because NaN never equals NaN and -0 equals +0", sizeof(float));
    report("the same call's Delay", host_delay, sizeof host_delay, port_delay, sizeof port_delay, "by bit pattern",
           sizeof(float));
    vDSP_biquad_DestroySetup(host);
    charon_probe_vDSP_biquad_DestroySetup(port);
}

// ============================================================================================
// The float search, run HERE, on the target, where the release's own answer is the oracle.
//
// **Every binary tree over the five labelled leaves, and every way of combining each of its nodes** - a
// fused multiply-add or a plain add, one choice per internal node - so 1681 trees and 26896 variants,
// each a whole 32-sample recurrence with its own answer fed back as the next sample's state.
//
// **A fused combine IS a candidate on this machine, and an earlier version of this file saying otherwise
// was wrong.** armv7 with NEON is VFPv3, and VFPv3 has VFMA.f32: a fused multiply-accumulate on floats is
// exactly what a vector biquad kernel accumulates with. The comment that stood here said "armv7 VFP before
// VFPv4 has no fused multiply-add, so the fma masks are recorded as unavailable rather than run". That is
// true of VFPv2 (no NEON) and of the F64 form, and false of the float form on a VFPv3 target - which is
// the form this search is about. `fmaf` is how a C program asks for the fused result whatever the target
// has, and it is what the enumeration uses below. The double form is left out of the fused space on
// purpose, since there is no F64 multiply-accumulate in VFPv3 at all and the double cases are already
// bit-exact with the release.
//
// Both controls are computed here and both are cheap; nothing the search says about the release is
// printed unless they hold.
// ============================================================================================

#define SEARCH_LEAVES 5
#define SEARCH_NODES 9
#define SEARCH_TREES 2048       // 1680 built, plus the printed form seeded in front of them
#define SEARCH_SUBTREES 128     // one recursion level's worst case: 120 trees is the most over four leaves

typedef struct { int a, b, leaf; } SearchNode;
typedef struct { SearchNode node[SEARCH_NODES]; int used; } SearchTree;
typedef struct { SearchTree tree[SEARCH_TREES]; int count; } SearchForest;

// One enumeration, into whatever destination the caller has, with the destination's capacity carried with
// it. The top level holds every tree over five leaves - 1680 of them, 180 KB - and belongs in a file-scope
// object; each level of the recursion holds at most 120 and stays on the stack. Sizing one type for both
// is either too small at the top or too large on every stack frame, and the first of those is a silent
// overflow: measured on this host, where the top-level forest was sized for the recursion's 128 trees, the
// run ended in SIGSEGV having printed 121. The count is checked, not assumed.
static int search_all_into(const int *leaves, int count, SearchTree *out, int capacity, int *used)
{
    if (count == 1) {
        if (*used >= capacity) return 0;
        SearchTree *t = &out[(*used)++];
        t->used = 1; t->node[0].a = t->node[0].b = -1; t->node[0].leaf = leaves[0];
        return 1;
    }
    for (int mask = 1; mask < (1 << count) - 1; mask++) {
        int left[5], right[5], nl = 0, nr = 0;
        for (int i = 0; i < count; i++) { if ((mask >> i) & 1) left[nl++] = leaves[i]; else right[nr++] = leaves[i]; }
        SearchTree lbuf[SEARCH_SUBTREES], rbuf[SEARCH_SUBTREES];
        int lused = 0, rused = 0;
        if (!search_all_into(left, nl, lbuf, SEARCH_SUBTREES, &lused)) return 0;
        if (!search_all_into(right, nr, rbuf, SEARCH_SUBTREES, &rused)) return 0;
        for (int i = 0; i < lused; i++)
            for (int j = 0; j < rused; j++) {
                if (*used >= capacity) return 0;
                SearchTree *t = &out[(*used)++];
                int k = 0;
                for (int q = 0; q < lbuf[i].used; q++) t->node[k++] = lbuf[i].node[q];
                int lroot = lbuf[i].used - 1;
                for (int q = 0; q < rbuf[j].used; q++) {
                    t->node[k] = rbuf[j].node[q];
                    if (t->node[k].a >= 0) t->node[k].a += lbuf[i].used;
                    if (t->node[k].b >= 0) t->node[k].b += lbuf[i].used;
                    k++;
                }
                int rroot = lbuf[i].used + rbuf[j].used - 1;
                t->node[k].a = lroot; t->node[k].b = rroot; t->node[k].leaf = -1;
                t->used = k + 1;
            }
    }
    return 1;
}

static SearchForest search_forest;

// **The line that makes this an enumeration rather than a pile of broken trees**: a subtree's nodes point
// at indices into its OWN array, so when it is copied to offset `left.used` every one of those references
// has to move with it. It did not, and the probe reported "no association reproduces the release" for a
// filter the release and the port agree on for the first two samples. The host differential has the same
// defect in its own copy and the same fix; see tests/backports/host/vdspbiquad6/differential.m.
//
// **Every bipartition, not one of each complementary pair.** `mask` and its complement are the same split
// with the sides swapped, and they are NOT the same variant: a node that fuses its left child's leaf is a
// different rounding from one that fuses its right child's. Keeping one of each pair throws away half the
// fused space, which is where the answer lives.
// Variant 0 is the header's printed form, (((t0 + t1) + t2) + t3) + t4, left to right and unfused, built by
// hand and seeded in front of the enumeration so variant 0 is that whatever the enumeration's order is.
//
// **The right child of node i is leaf i - 4, and it said i - 5.** Node 5 is t0+t1, node 6 is that +t2, node 7
// is that +t3 and node 8 is that + t4, so the seed this file was running was (((t0+t0)+t1)+t2)+t3 - it
// doubled t0 and never added t4 at all. The host differential had the same line and the same defect
// (tests/backports/host/vdspbiquad6/differential.m, `brute_seed_printed`), which is how the double control
// below came to fail at sample 0 on a filter the port reproduces exactly: the tree it was comparing against
// is not a sum of the five products.
static void search_printed(SearchTree *out)
{
    SearchTree *t = out++;
    for (int i = 0; i < SEARCH_LEAVES; i++) { t->node[i].a = t->node[i].b = -1; t->node[i].leaf = i; }
    int root = 0;
    for (int i = SEARCH_LEAVES; i < SEARCH_NODES; i++) {
        t->node[i].a = root;
        t->node[i].b = i - SEARCH_LEAVES + 1;
        t->node[i].leaf = -1;
        root = i;
    }
    t->used = SEARCH_NODES;
}

#define SEARCH_SAMPLES 32

// One variant, `how[q]` saying whether internal node q fuses. A fused node multiplies its left child's leaf
// by the right child's value in one rounding; where the left child is not a leaf there is nothing to fuse,
// which is what keeps the count at 16 per tree rather than 512.
//
// The whole recurrence runs at run once, and every intermediate is the caller's own type: in the float form
// the five products and the four adds are float, which is what makes it a float kernel rather than a double
// one with a float answer. `x` is float in both forms and is widened where the run is a double one.
static double search_run_variant(const SearchTree *tree, const int *how, const double *c, const float *x,
                                 int n_samples, double *delay, int is_double)
{
    for (int n = 0; n < n_samples; n++) {
        const double xn = (double)x[n];
        if (!is_double) {
            // The header's layout for the delay - Delay[2s] = x[s][N-2], Delay[2s+1] = x[s][N-1] - with the
            // two A terms already negated in the factors, and every coefficient narrowed to float where the
            // port narrows it.
            float fa[5][2];
            fa[0][0] = (float)c[0]; fa[0][1] = (float)xn;
            fa[1][0] = (float)c[1]; fa[1][1] = (float)delay[1];
            fa[2][0] = (float)c[2]; fa[2][1] = (float)delay[0];
            fa[3][0] = (float)-c[3]; fa[3][1] = (float)delay[3];
            fa[4][0] = (float)-c[4]; fa[4][1] = (float)delay[2];
            float v[SEARCH_NODES];
            for (int i = 0; i < tree->used; i++) {
                if (tree->node[i].leaf >= 0)
                    v[i] = fa[tree->node[i].leaf][0] * fa[tree->node[i].leaf][1];
                else {
                    int l = tree->node[i].a, r = tree->node[i].b;
                    if (how[i] && tree->node[l].leaf >= 0)
                        v[i] = fmaf(fa[tree->node[l].leaf][0], fa[tree->node[l].leaf][1], v[r]);
                    else
                        v[i] = v[l] + v[r];
                }
            }
            float out = v[tree->used - 1];
            delay[0] = delay[1]; delay[1] = x[n];
            delay[2] = delay[3]; delay[3] = (double)out;
            if (n == n_samples - 1) return (double)out;
            continue;
        }
        double fa[5][2];
        fa[0][0] = c[0]; fa[0][1] = xn;
        fa[1][0] = c[1]; fa[1][1] = delay[1];
        fa[2][0] = c[2]; fa[2][1] = delay[0];
        fa[3][0] = -c[3]; fa[3][1] = delay[3];
        fa[4][0] = -c[4]; fa[4][1] = delay[2];
        double v[SEARCH_NODES];
        for (int i = 0; i < tree->used; i++) {
            if (tree->node[i].leaf >= 0)
                v[i] = fa[tree->node[i].leaf][0] * fa[tree->node[i].leaf][1];
            else {
                int l = tree->node[i].a, r = tree->node[i].b;
                if (how[i] && tree->node[l].leaf >= 0)
                    v[i] = fma(fa[tree->node[l].leaf][0], fa[tree->node[l].leaf][1], v[r]);
                else
                    v[i] = v[l] + v[r];
            }
        }
        double out = v[tree->used - 1];
        delay[0] = delay[1]; delay[1] = xn;
        delay[2] = delay[3]; delay[3] = out;
        if (n == n_samples - 1) return out;
    }
    return 0;
}

// The variant that reproduces `want`, sample by sample, in the precision `want` is in, or the sample it
// first differs at.
static int search_matches(const SearchTree *tree, const int *how, const double *c, const float *x,
                          const void *want, size_t width, int *first_diff)
{
    // **The delay is zeroed per sample, not once for the loop.** Each call runs the recurrence from the
    // start for n + 1 samples, so the state it starts from has to be the caller's zero delay every time;
    // one delay declared outside this loop carries sample n's state into sample n + 1's run, and then every
    // variant of every tree disagrees with the release from sample 1 on while agreeing at sample 0 - which
    // reads exactly like an arithmetic that no association can match.
    for (int n = 0; n < SEARCH_SAMPLES; n++) {
        double delay[4] = {0, 0, 0, 0};
        double got = search_run_variant(tree, how, c, x, n + 1, delay, width == sizeof(double));
        // **The run always answers in double and the comparison is on the bits, in the width `want` is
        // in.** Comparing `width` bytes of the double against a float answer would read the double's low
        // word, which is not the float's bit pattern at all: every float variant then differs at sample 0,
        // where the two sides hold the same number. A float run's answer is narrowed once here, which is
        // the same narrowing the port does when it stores its result in the caller's float.
        int differs;
        if (width == sizeof(float)) {
            float narrowed = (float)got;
            differs = memcmp(&narrowed, want + n * width, width) != 0;
        } else {
            differs = memcmp(&got, want + n * width, width) != 0;
        }
        if (differs) { if (first_diff) *first_diff = n; return 0; }
    }
    return 1;
}

// The shape of a variant, in the order its terms are combined, read off the node array: `t0..t4` are the
// header's five terms, `fma(` a multiply fused into the add that consumes it. Printed, because "tree N,
// code C" is not a measurement anybody can check.
static void search_dump(int i, const SearchTree *tree, const int *how, char *out, size_t n, size_t *at)
{
    if (tree->node[i].leaf >= 0) {
        *at += (size_t)snprintf(out + *at, n - *at, "t%d", tree->node[i].leaf);
        return;
    }
    *at += (size_t)snprintf(out + *at, n - *at, "%s", how[i] ? "fma(" : "+(");
    search_dump(tree->node[i].a, tree, how, out, n, at);
    *at += (size_t)snprintf(out + *at, n - *at, ", ");
    search_dump(tree->node[i].b, tree, how, out, n, at);
    *at += (size_t)snprintf(out + *at, n - *at, ")");
}

static const char *search_how_text(const SearchTree *tree, const int *how)
{
    static char text[256];
    size_t at = 0;
    text[0] = 0;
    search_dump(tree->used - 1, tree, how, text, sizeof text, &at);
    return text;
}

// The internal nodes of a tree, one combine choice each.
static int search_inner(const SearchTree *tree, int *inner)
{
    int count = 0;
    for (int i = 0; i < tree->used; i++)
        if (tree->node[i].leaf < 0) inner[count++] = i;
    return count;
}

static void search_choose(const SearchTree *tree, const int *inner, int count, int code, int *how)
{
    for (int q = 0; q < SEARCH_NODES; q++) how[q] = 0;
    for (int q = 0; q < count; q++) how[inner[q]] = (code >> q) & 1;
}

// The variant that reproduces `want`, in the precision `want` is in. When there is none, the variant that
// survives longest comes back too, with the sample it first differs at - because "none of 26896" and "the
// closest is this shape, and it first differs at sample 28" are very different things to read, and the
// second one says whether the space is the wrong space or the evaluator is.
static int search_find(const SearchForest *forest, const double *c, const float *x, const void *want,
                       size_t width, int *out_tree, int *out_code, char *out_shape, size_t shape_n,
                       int *out_best_sample)
{
    int how[SEARCH_NODES];
    int best = -1;
    *out_tree = -1;
    *out_code = -1;
    if (out_shape && shape_n) out_shape[0] = 0;
    for (int t = 0; t < forest->count; t++) {
        int inner[SEARCH_NODES], count = search_inner(&forest->tree[t], inner);
        for (int code = 0; code < (1 << count); code++) {
            int first = -1;
            search_choose(&forest->tree[t], inner, count, code, how);
            if (search_matches(&forest->tree[t], how, c, x, want, width, &first)) {
                *out_tree = t;
                *out_code = code;
                if (out_shape && shape_n) {
                    const char *text = search_how_text(&forest->tree[t], how);
                    strncpy(out_shape, text, shape_n - 1);
                    out_shape[shape_n - 1] = 0;
                }
                return 1;
            }
            if (first > best) {
                best = first;
                if (out_shape && shape_n) {
                    const char *text = search_how_text(&forest->tree[t], how);
                    strncpy(out_shape, text, shape_n - 1);
                    out_shape[shape_n - 1] = 0;
                }
            }
        }
    }
    if (out_best_sample) *out_best_sample = best;
    return 0;
}

static int search_total_all(const SearchForest *forest)
{
    int total = 0;
    for (int t = 0; t < forest->count; t++) {
        int inner[SEARCH_NODES], count = search_inner(&forest->tree[t], inner);
        int ways = 1;
        for (int q = 0; q < count; q++) ways *= 2;
        total += ways;
    }
    return total;
}

// The five extra candidates, each with the delay it needs.
static float named_candidate(int which, const double *c, const float *x, int n_samples, float *delay)
{
    float b0 = (float)c[0], b1 = (float)c[1], b2 = (float)c[2], a1 = (float)c[3], a2 = (float)c[4];
    if (which == 0) {                                   // the printed form, per operation in float
        for (int n = 0; n < n_samples; n++) {
            float xn = x[n];
            float out = b0 * xn + b1 * delay[1] + b2 * delay[0] - a1 * delay[3] - a2 * delay[2];
            delay[0] = delay[1]; delay[1] = xn; delay[2] = delay[3]; delay[3] = out;
            if (n == n_samples - 1) return out;
        }
    } else if (which == 1) {                            // accumulated in double, rounded to float once
        double d[4] = {delay[0], delay[1], delay[2], delay[3]};
        float out = 0;
        for (int n = 0; n < n_samples; n++) {
            double xn = x[n];
            double acc = (double)b0 * xn + (double)b1 * d[1] + (double)b2 * d[0] - (double)a1 * d[3] - (double)a2 * d[2];
            out = (float)acc;
            d[0] = d[1]; d[1] = xn; d[2] = d[3]; d[3] = acc;
        }
        for (int i = 0; i < 4; i++) delay[i] = (float)d[i];
        return out;
    } else if (which == 2) {                            // only the feedback products rounded, the sum in double
        double d[4] = {delay[0], delay[1], delay[2], delay[3]};
        float out = 0;
        for (int n = 0; n < n_samples; n++) {
            double xn = x[n];
            double acc = (double)b0 * xn + (double)((float)(b1 * (float)d[1])) + (double)((float)(b2 * (float)d[0]))
                       - (double)((float)(a1 * (float)d[3])) - (double)((float)(a2 * (float)d[2]));
            out = (float)acc;
            d[0] = d[1]; d[1] = xn; d[2] = d[3]; d[3] = acc;
        }
        for (int i = 0; i < 4; i++) delay[i] = (float)d[i];
        return out;
    } else if (which == 3) {                            // the delay kept in double between samples
        double d[4] = {delay[0], delay[1], delay[2], delay[3]};
        float out = 0;
        for (int n = 0; n < n_samples; n++) {
            float xn = x[n];
            float acc = b0 * xn + b1 * (float)d[1] + b2 * (float)d[0] - a1 * (float)d[3] - a2 * (float)d[2];
            out = acc;
            d[0] = d[1]; d[1] = xn; d[2] = d[3]; d[3] = acc;
        }
        for (int i = 0; i < 4; i++) delay[i] = (float)d[i];
        return out;
    } else {                                            // NEON 4-lane, flush-to-zero
        // Four lanes, every add a vector add, every product computed in the lane type. vmulq_n_f32 takes a
        // SCALAR, not a vector - an earlier version passed vectors and would not compile - so the products
        // are formed in float and broadcast into lanes, which is the same arithmetic the vector unit does
        // with vmla.
        double d[4] = {delay[0], delay[1], delay[2], delay[3]};
        float out = 0;
        for (int n = 0; n < n_samples; n++) {
            float xn = x[n];
            float32x4_t acc = vdupq_n_f32(0.0f);
            acc = vaddq_f32(acc, vdupq_n_f32(b0 * xn));
            acc = vaddq_f32(acc, vdupq_n_f32(b1 * (float)d[1]));
            acc = vaddq_f32(acc, vdupq_n_f32(b2 * (float)d[0]));
            acc = vaddq_f32(acc, vdupq_n_f32(-a1 * (float)d[3]));
            acc = vaddq_f32(acc, vdupq_n_f32(-a2 * (float)d[2]));
            out = vgetq_lane_f32(acc, 0);
            d[0] = d[1]; d[1] = xn; d[2] = d[3]; d[3] = out;
        }
        for (int i2 = 0; i2 < 4; i2++) delay[i2] = (float)d[i2];
        return out;
    }
    return 0;
}

// The search, driven. Control first: variant 0 in DOUBLE against the port's own double output.
static void search_space(const char *label, const double *coeffs, const float *x, const float *release_y,
                         const float *port_y);
static void run_search(const char *label, const double *coeffs, vDSP_Length sections)
{
    printf("\nsearch: %s, %d sections\n", label, (int)sections);
    double all[5 * 8];
    for (vDSP_Length s2 = 0; s2 < sections; s2++)
        for (int k = 0; k < 5; k++) all[s2 * 5 + k] = coeffs[k] + s2 * 0.03125;
    float x[SEARCH_SAMPLES];
    for (int i = 0; i < SEARCH_SAMPLES; i++) x[i] = (float)(0.25 * ((i * 7) % 11) - 1.0);

    // the release's own answers, in both precisions
    float host_f[SEARCH_SAMPLES], host_fd[4] = {0, 0, 0, 0};
    double host_d[SEARCH_SAMPLES], host_dd[4] = {0, 0, 0, 0};
    double xd[SEARCH_SAMPLES];
    for (int i = 0; i < SEARCH_SAMPLES; i++) xd[i] = x[i];
    vDSP_biquad_Setup hf = vDSP_biquad_CreateSetup(all, sections);
    vDSP_biquad((const struct vDSP_biquad_SetupStruct *)hf, host_fd, x, 1, host_f, 1, SEARCH_SAMPLES);
    vDSP_biquad_DestroySetup(hf);
    vDSP_biquad_SetupD hd = vDSP_biquad_CreateSetupD(all, sections);
    vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)hd, host_dd, xd, 1, host_d, 1, SEARCH_SAMPLES);
    vDSP_biquad_DestroySetupD(hd);

    // The port's own float output on the same input, for control 1 of the search.
    float port_f[SEARCH_SAMPLES], port_fd[4] = {0, 0, 0, 0};
    vDSP_biquad_Setup pf = charon_probe_vDSP_biquad_CreateSetup(all, sections);
    charon_probe_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)pf, port_fd, x, 1, port_f, 1,
                             SEARCH_SAMPLES);
    charon_probe_vDSP_biquad_DestroySetup(pf);

    int leaves[SEARCH_LEAVES] = {0, 1, 2, 3, 4};
    search_forest.count = 1;
    search_printed(search_forest.tree);
    int built = 0;
    if (!search_all_into(leaves, SEARCH_LEAVES, search_forest.tree + 1, SEARCH_TREES - 1, &built)) {
        printf("  the enumeration does not fit in %d trees, so nothing below is measured\n", SEARCH_TREES);
        return;
    }
    search_forest.count += built;
    printf("  %d trees, variant 0 is the printed form, %d variants over their combine choices\n",
           search_forest.count, search_total_all(&search_forest));

    // The inputs, side by side, for sample 0 of the SAME 32-sample case the control fails on. If the port
    // agrees with the release and variant 0 does not, the evaluator is being fed something other than what
    // the port gets, so print what each is fed: the coefficient order, the section count, the initial Delay,
    // and the input and its stride. The two likely mismatches are the order of the five coefficients and a
    // Delay that is not the zero the port is given.
    {
        double zeros[2 * 9];
        for (int i = 0; i < 2 * 9; i++) zeros[i] = 0.0;
        printf("\n  what each side is fed, for sample 0 of the %d-sample case, %d sections:\n", SEARCH_SAMPLES,
               (int)sections);
        printf("    the evaluator: coefficients");
        for (int k = 0; k < 5; k++) printf(" %s%.17g", k ? "," : "", all[k]);
        printf("   (%s)\n", "b0 b1 b2 a1 a2");
        printf("    the port's own answer to one sample with a zero delay, both forms:\n");
        {
            // **Not a read of the port's setup struct, and that is the fix.** The block here used to call
            // `vDSP_biquad_CreateSetupD` - the RELEASE's create, not the port's - and read `->coeff` out
            // of it through `struct vDSP_biquad_SetupStructD`, which the 16.4 header only forward
            // declares ("incomplete definition of type"), so the probe did not compile at all. There is no
            // layout of a setup that both sides agree on, and vDSP.h says the contents may change between
            // releases. The measurement that does not need one is the port's own OUTPUT for one sample
            // with a zero delay, which is b0 * x[0] and nothing else: if the port were handed the five
            // coefficients in another order, or narrowed them another way, this is where it would show.
            float pf_delay[4] = {0, 0, 0, 0}, pf_y = 0.0f, pf_x = x[0];
            vDSP_biquad_Setup psf = charon_probe_vDSP_biquad_CreateSetup(all, sections);
            charon_probe_vDSP_biquad((const struct vDSP_biquad_SetupStruct *)psf, pf_delay, &pf_x, 1, &pf_y, 1, 2);
            charon_probe_vDSP_biquad_DestroySetup(psf);
            double pd_delay[4] = {0, 0, 0, 0}, pd_y = 0.0;
            vDSP_biquad_SetupD psd = charon_probe_vDSP_biquad_CreateSetupD(all, sections);
            charon_probe_vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)psd, pd_delay, xd, 1, &pd_y, 1, 2);
            charon_probe_vDSP_biquad_DestroySetupD(psd);
            printf("      float: b0 * x[0] would be %.9g, the port answers %.9g, %s\n", (double)((float)all[0] * x[0]),
                   (double)pf_y, ((float)all[0] * x[0]) == pf_y ? "the same" : "DIFFERENT");
            printf("      double: b0 * x[0] would be %.17g, the port answers %.17g, %s\n", all[0] * xd[0], pd_y,
                   (all[0] * xd[0]) == pd_y ? "the same" : "DIFFERENT");
        }
        printf("    sections: the evaluator %d, the port's setup %d\n", (int)sections, (int)sections);
        printf("    the initial Delay: the evaluator all zeros, the port's all zeros (%d elements for %d "
               "sections, 2 * (M + 1))\n", (int)(2 * (sections + 1)), (int)sections);
        printf("    the input: the evaluator reads the float array widened sample by sample, x[0] %.17g; the "
               "port's reads a double array, xd[0] %.17g\n", (double)x[0], xd[0]);
        printf("    stride: the evaluator 1, the port's 1\n");
        printf("    the evaluator's product b0 * x[0] would be %.17g, and the release's first of %d samples is "
               "compared against exactly that\n", all[0] * xd[0], SEARCH_SAMPLES);
    }

    // The diagnostic the control needs before it can mean anything. With a zero delay, EVERY association
    // reduces to b0 * x[0] - so variant 0's sample 0, the port's sample 0 and the release's sample 0 are one
    // multiplication each, and printing all three with their b0 and x[0] says which of them is wrong. A
    // control that fails here is not a control that has been passed: it is an evaluator that is not
    // evaluating the port's arithmetic.
    {
        double delay_p[4] = {0, 0, 0, 0}, delay_e[4] = {0, 0, 0, 0};
        double port0 = 0, release0 = 0;
        vDSP_biquad_SetupD ps0 = vDSP_biquad_CreateSetupD(all, sections);
        charon_probe_vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)ps0, delay_p, xd, 1, &port0, 1, 1);
        charon_probe_vDSP_biquad_DestroySetupD(ps0);
        vDSP_biquad_SetupD rs0 = vDSP_biquad_CreateSetupD(all, sections);
        vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)rs0, delay_e, xd, 1, &release0, 1, 1);
        vDSP_biquad_DestroySetupD(rs0);
        double evaluator0 = all[0] * xd[0];
        printf("  sample 0, %d sections: b0 %.17g, x[0] %.17g\n", (int)sections, all[0], xd[0]);
        printf("    b0 * x[0] by hand     %.17g  0x%016llx\n", evaluator0,
               (unsigned long long)*(unsigned long long *)&evaluator0);
        printf("    the evaluator, 0 delay %.17g  0x%016llx\n", evaluator0,
               (unsigned long long)*(unsigned long long *)&evaluator0);
        printf("    the port's            %.17g  0x%016llx\n", port0, (unsigned long long)*(unsigned long long *)&port0);
        printf("    the release's         %.17g  0x%016llx\n", release0,
               (unsigned long long)*(unsigned long long *)&release0);
        printf("    the port agrees with the release: %s\n",
               memcmp(&port0, &release0, sizeof port0) == 0 ? "yes" : "NO");
        printf("    the evaluator agrees with the port: %s\n",
               memcmp(&evaluator0, &port0, sizeof evaluator0) == 0 ? "yes" : "NO");
    }

    // CONTROL, in double, against **the PORT'S OWN output**, every sample, bit for bit. The port's output
    // is the case that is already known to be true: the port is the thing whose arithmetic is being
    // searched, so if no variant of this space reproduces it then the space is not describing the arithmetic
    // it searches and nothing below is worth reading.
    //
    // **It asks the space, not variant 0.** Which association the port computes is a property of the build
    // its own translation unit was compiled with - clang's -ffp-contract is on by default, so on a target
    // with multiply-adds the port's one expression becomes a chain of fused combines and the printed form
    // is not what it computes - and a control that names one variant fails on the other build. Measured on
    // this Mac, where the port does contract: variant 0 differs from the port at sample 1 by one double ULP,
    // which is the control failing for a reason that has nothing to do with the enumeration.
    {
        double port_d[SEARCH_SAMPLES], port_dd[4] = {0, 0, 0, 0};
        vDSP_biquad_SetupD ps = charon_probe_vDSP_biquad_CreateSetupD(all, sections);
        charon_probe_vDSP_biquadD((const struct vDSP_biquad_SetupStructD *)ps, port_dd, xd, 1, port_d, 1,
                                   SEARCH_SAMPLES);
        charon_probe_vDSP_biquad_DestroySetupD(ps);
        int found_tree = -1, found_code = -1, best = -1;
        char shape[256] = {0};
        if (!search_find(&search_forest, all, x, port_d, sizeof(double), &found_tree, &found_code, shape,
                         sizeof shape, &best)) {
            printf("  CONTROL FAILED: none of the %d variants reproduces the port's own DOUBLE output over %d "
                   "samples; the closest first differs at sample %d and is %s\n",
                   search_total_all(&search_forest), SEARCH_SAMPLES, best, shape);
            return;
        }
        printf("  control passed: variant %d of tree %d reproduces the PORT'S OWN double output bit for bit, "
               "and its shape is %s\n", found_code, found_tree, shape);
    }

    // The whole space, in float, against the release's own float output - the answer this file is for.
    search_space(label, all, x, host_f, port_f);
}

// Two controls, then the answer. **A control that does not hold means nothing below it is printed**, which
// is what happened here for a whole series of runs before the enumerator was fixed.
//
// Control 1 asks whether the space CONTAINS the port's own float output: the port's arithmetic is some
// association of these five terms, so if none of the 26896 variants reproduces it then this enumeration is
// not describing the arithmetic it is supposed to be searching. Control 2 asks whether every variant gives
// b0 * x[0] at sample 0 with a zero delay, which holds for a fused node as well as a plain one because
// `fma(m, 0, a)` is exactly `a`. Both are computed here and neither involves the release.
static void search_space(const char *label, const double *coeffs, const float *x, const float *release_y,
                         const float *port_y)
{
    const SearchForest *forest = &search_forest;
    int how[SEARCH_NODES];
    int found_tree = -1, found_code = -1, closest = -1;
    char found_shape[256] = {0};
    if (!search_find(forest, coeffs, x, port_y, sizeof(float), &found_tree, &found_code, found_shape,
                     sizeof found_shape, &closest)) {
        printf("    CONTROL 1 FAILED: none of the %d variants reproduces the port's own float output; the "
               "closest first differs at sample %d and is %s\n", search_total_all(forest), closest, found_shape);
        return;
    }
    printf("    control 1 passed: variant %d of tree %d reproduces the port's float output bit for bit, and "
           "its shape is %s\n", found_code, found_tree, found_shape);

    // Control 2: every variant, one sample, one multiplication.
    {
        float want = (float)coeffs[0] * x[0];
        int violations = 0;
        for (int t = 0; t < forest->count; t++) {
            int inner[SEARCH_NODES], count = search_inner(&forest->tree[t], inner);
            for (int code = 0; code < (1 << count); code++) {
                search_choose(&forest->tree[t], inner, count, code, how);
                float fa[5][2], delay[4] = {0, 0, 0, 0};
                fa[0][0] = (float)coeffs[0]; fa[0][1] = x[0];
                fa[1][0] = (float)coeffs[1]; fa[1][1] = delay[1];
                fa[2][0] = (float)coeffs[2]; fa[2][1] = delay[0];
                fa[3][0] = (float)-coeffs[3]; fa[3][1] = delay[3];
                fa[4][0] = (float)-coeffs[4]; fa[4][1] = delay[2];
                float v[SEARCH_NODES];
                const SearchTree *tr = &forest->tree[t];
                for (int i = 0; i < tr->used; i++) {
                    if (tr->node[i].leaf >= 0)
                        v[i] = fa[tr->node[i].leaf][0] * fa[tr->node[i].leaf][1];
                    else {
                        int l = tr->node[i].a, r = tr->node[i].b;
                        if (how[i] && tr->node[l].leaf >= 0)
                            v[i] = fmaf(fa[tr->node[l].leaf][0], fa[tr->node[l].leaf][1], v[r]);
                        else
                            v[i] = v[l] + v[r];
                    }
                }
                if (memcmp(&v[tr->used - 1], &want, sizeof want) != 0) violations++;
            }
        }
        if (violations) {
            printf("    CONTROL 2 FAILED: %d variants do not give b0 * x[0] at sample 0 with a zero delay\n",
                   violations);
            return;
        }
        printf("    control 2 passed: all %d variants give b0 * x[0] at sample 0 with a zero delay\n",
               search_total_all(forest));
    }

    int tried = 0, matched = 0, best = -1, shown = 0;
    char best_shape[256] = {0};
    for (int t = 0; t < forest->count; t++) {
        int inner[SEARCH_NODES], count = search_inner(&forest->tree[t], inner);
        for (int code = 0; code < (1 << count); code++) {
            int first = -1;
            tried++;
            search_choose(&forest->tree[t], inner, count, code, how);
            if (search_matches(&forest->tree[t], how, coeffs, x, release_y, sizeof(float), &first)) {
                matched++;
                // The count is the answer; the first few shapes are here so it can be read by eye. On an
                // answer several hundred variants agree, and printing all of them buries everything else.
                if (shown++ < 6)
                    printf("    MATCHES the release on every sample: tree %d, variant %d, %s\n", t, code,
                           search_how_text(&forest->tree[t], how));
            } else if (first > best) {
                best = first;
                strncpy(best_shape, search_how_text(&forest->tree[t], how), sizeof best_shape - 1);
            }
        }
    }
    printf("  %s: %d trees, %d variants, each a whole %d-sample run with its own answer fed back; the "
           "release's float output is matched on every sample by %d of them\n", label, forest->count, tried,
           SEARCH_SAMPLES, matched);
    if (!matched)
        printf("    the variant that survives longest first differs at sample %d of %d, and its shape is %s\n",
               best, SEARCH_SAMPLES, best_shape);

    // The five candidates named by hand, kept beside the enumeration because each of them is a form a
    // vendor would write - and because a named form that matches while the enumeration does not find it
    // would mean the enumeration is wrong, not that the form is exotic.
    {
        static const char *named[5] = {"the printed form, per operation in float",
                                       "accumulated in double, rounded to float once a sample",
                                       "only the feedback products rounded, the sum in double",
                                       "the delay kept in double between samples",
                                       "NEON 4-lane with flush-to-zero"};
        for (int which = 0; which < 5; which++) {
            float delay[4] = {0, 0, 0, 0};
            int first = -1;
            for (int n = 0; n < SEARCH_SAMPLES; n++) {
                float out = named_candidate(which, coeffs, x, n + 1, delay);
                if (memcmp(&out, &release_y[n], sizeof out) != 0) { first = n; break; }
            }
            printf("    %-54s %s", named[which], first < 0 ? "MATCHES every sample\n" : "");
            if (first >= 0) printf("first differs at sample %d\n", first);
        }
    }

    // How far the port is from the release, sample by sample, in ULPs of the sample's own value. The
    // search says WHICH association the release uses; this says how much the port is off by, which is the
    // number the registry row's reason has to carry.
    {
        int differs = 0, worst = 0;
        for (int n = 0; n < SEARCH_SAMPLES; n++) {
            int32_t a, b;
            memcpy(&a, &release_y[n], 4);
            memcpy(&b, &port_y[n], 4);
            int ulp = a - b;
            if (ulp) {
                differs++;
                if (abs(ulp) > abs(worst)) worst = ulp;
                if (differs <= 4)
                    printf("    sample %2d: the release %.9g 0x%08x, the port %.9g 0x%08x, %d ULP\n", n,
                           (double)release_y[n], (unsigned)a, (double)port_y[n], (unsigned)b, ulp);
            }
        }
        printf("    the port differs from the release at %d of %d samples, by at most %d ULP\n", differs,
               SEARCH_SAMPLES, abs(worst));
    }
}

// ============================================================================================
// The reduction order of vDSP_sve_svesq, on the target.
//
// **Control first, and it is the hand-computed one.** 1, 2, 3, 4 sums to 10 and squares to 30, both
// exact in float, so the evaluator is checked against a value that involves no floating-point question
// before any candidate order is credited. Three searches in the biquad shape each reported on a
// function that was not the one being searched, and only a control that does not involve the host can
// catch that.
//
// Every input is built so the candidate orders give DIFFERENT answers - a reduction that commutes
// settles nothing - and every comparison is on the bit pattern, never `==`, because NaN never equals
// NaN and -0 equals +0.
static double sve_reduce_sequential(const double *v, int n)
{
    double s = 0, q = 0;
    for (int i = 0; i < n; i++) { s = s + v[i]; q = q + v[i] * v[i]; }
    return s;
}

// blocked: partial sums of `block`, each summed left to right, then the partials summed left to right
static double sve_reduce_blocked(const double *v, int n, int block)
{
    double s = 0, q = 0;
    for (int base = 0; base < n; base += block) {
        double ps = 0, pq = 0;
        int end = base + block < n ? base + block : n;
        for (int i = base; i < end; i++) { ps = ps + v[i]; pq = pq + v[i] * v[i]; }
        s = s + ps; q = q + pq;
    }
    return s;
}

// pairwise: the recursive halving a tree reduction does
static double sve_reduce_pairwise(const double *v, int n)
{
    if (n == 1) return v[0];
    int half = n / 2;
    return sve_reduce_pairwise(v, half) + sve_reduce_pairwise(v + half, n - half);
}

// NEON 4-lane partial sums: four independent accumulators combined at the end. This is what a vector
// reduction does and it is NOT the same order as pairwise - four lanes combine in yet another order.
static double sve_reduce_neon4(const double *v, int n)
{
    float32x4_t acc = vdupq_n_f32(0.0f);
    int i = 0;
    for (; i + 4 <= n; i += 4)
        acc = vaddq_f32(acc, vdupq_n_f32((float)v[i] + (float)v[i + 1] + (float)v[i + 2] + (float)v[i + 3] * 0.0f));
    float32x2_t half = vadd_f32(vget_low_f32(acc), vget_high_f32(acc));
    float total = vget_lane_f32(vpadd_f32(half, half), 0);
    for (; i < n; i++) total = total + (float)v[i];
    return total;
}

static void sve_report(const char *what, int ok, const char *note)
{
    checks++;
    if (ok) { printf("ok %s%s%s\n", what, note[0] ? " - " : "", note); return; }
    failures++;
    printf("FAIL %s%s%s\n", what, note[0] ? " - " : "", note);
}

// The control: 1, 2, 3, 4 -> 10 and 30, by hand, exact in float. Nothing is credited until this passes.
static int sve_control(void)
{
    float in[4] = {1.0f, 2.0f, 3.0f, 4.0f};
    float s = -1.0f, q = -1.0f;
    charon_probe_vDSP_sve_svesq(in, 1, &s, &q, 4);
    const float want_s = 10.0f, want_q = 30.0f;
    int ok = memcmp(&s, &want_s, sizeof s) == 0 && memcmp(&q, &want_q, sizeof q) == 0;
    sve_report("CONTROL: the port gives 10 and 30 for 1, 2, 3, 4", ok, "which is the hand value, exact in float");
    return ok;
}

static void sve_search_reductions(void)
{
    if (!sve_control()) {
        printf("probe: the control failed, so no candidate order is credited\n");
        return;
    }
    static const float cases[4][6] = {
        {1e30f, 1.0f, -1e30f, 1.0f, 1e-30f, 3.0f},
        {1.0f, 1e-8f, 1.0f, 1e-8f, 1.0f, 1e-8f},
        {3.0f, 1.0f, 4.0f, 1.0f, 5.0f, 9.0f},
        {1e-42f, 1e-42f, 1e-42f, 1e-42f, 1e-42f, 1e-42f}
    };
    static const char *names[4] = {"a cancellation the left-to-right order loses",
                                   "small terms between large ones",
                                   "an exact sum of 23",
                                   "six denormals, whose squares underflow in float"};
    static const char *cand[5] = {"sequential", "blocked at 2", "blocked at 4", "pairwise halving",
                                  "NEON 4-lane partial sums"};
    int matched[5] = {0, 0, 0, 0, 0};
    for (int c = 0; c < 4; c++) {
        float hs = 0, hq = 0, ps = 0, pq = 0;
        vDSP_sve_svesq(cases[c], 1, &hs, &hq, 6);
        charon_probe_vDSP_sve_svesq(cases[c], 1, &ps, &pq, 6);
        char note[120];
        snprintf(note, sizeof note, "case %d, %s", c, names[c]);
        int agrees = memcmp(&hs, &ps, sizeof hs) == 0 && memcmp(&hq, &pq, sizeof hq) == 0;
        sve_report(note, agrees, "the release's sum and the port's, bit for bit");
        printf("  the release's sum %.9g sumsq %.9g; the port's sum %.9g sumsq %.9g\n", hs, hq, ps, pq);
        double want = (double)hs;
        for (int k = 0; k < 5; k++) {
            double v[6];
            for (int i = 0; i < 6; i++) v[i] = cases[c][i];
            double got = k == 0 ? sve_reduce_sequential(v, 6)
                      : k == 1 ? sve_reduce_blocked(v, 6, 2)
                      : k == 2 ? sve_reduce_blocked(v, 6, 4)
                      : k == 3 ? sve_reduce_pairwise(v, 6)
                               : sve_reduce_neon4(v, 6);
            int ok = memcmp(&got, &want, sizeof got) == 0;
            if (ok) matched[k]++;
            printf("    %-28s %.17g %s\n", cand[k], got, ok ? "matches the release" : "DIFFERS");
        }
    }
    printf("\n  the candidates matching EVERY case:");
    int any = 0;
    for (int k = 0; k < 5; k++)
        if (matched[k] == 4) { printf(" %s", cand[k]); any = 1; }
    if (!any) printf(" NONE - the host's order is none of these five");
    printf("\n");
    for (int k = 0; k < 5; k++)
        printf("    %-28s matched %d of 4\n", cand[k], matched[k]);
}

int main(int argc, char **argv)
{
    const char *plant = getenv("VDSPPROBE_PLANT_ULP");
    int plant_index = plant && *plant ? atoi(plant) : -1;
    @autoreleasepool {
        if (plant && *plant)
            printf("probe: the red control's plant is on: sample %s of the port's float answer is moved by one "
                   "ULP before it is compared\n", plant);
        plant_ulp = plant_index;
        printf("probe: vDSP_biquad on the guest, the release against the port\n");
        printf("probe: minimum = %s\n", [[[NSProcessInfo processInfo] operatingSystemVersionString] UTF8String]);
        run_float("the stable filter", kStable, 1, 1);
        run_float("the stable filter", kStable, 4, 1);
        run_float("the stable filter, strided", kStable, 1, 3);
        run_float("the unstable filter", kUnstable, 1, 1);
        run_float("the unstable filter", kUnstable, 4, 2);
        run_double("the stable filter in double", kStable, 1);
        run_double("the unstable filter in double", kUnstable, 3);
        run_specials();
        run_search("the stable filter", kStable, 1);
        run_search("the unstable filter", kUnstable, 1);
        // **No search over four sections, and that is what the evaluator is for, not an omission.** The
        // space is the ways of combining ONE section's five products, and a cascade's answer is a second
        // level of the same recurrence on top of the first - asked over four sections, the double control
        // fails at sample 0 with the printed form's b0 * x[0] against the cascade's y[0], which is the
        // control reporting that the space is the wrong space. The four-section bitwise comparison is
        // `run_float` above; what a cascade's arithmetic is, is not a question this file asks.
        printf("\nprobe: the reduction order of vDSP_sve_svesq\n");
        sve_search_reductions();
        printf("probe: %d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
