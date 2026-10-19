#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <arm_neon.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

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
    for (int call = 0; call < 2; call++) {
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

#define SEARCH_LEAVES 5
#define SEARCH_NODES 9
#define SEARCH_TREES 2048
#define SEARCH_SUBTREES 128

typedef struct { int a, b, leaf; } SearchNode;
typedef struct { SearchNode node[SEARCH_NODES]; int used; } SearchTree;
typedef struct { SearchTree tree[SEARCH_TREES]; int count; } SearchForest;

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

static double search_run_variant(const SearchTree *tree, const int *how, const double *c, const float *x,
                                 int n_samples, double *delay, int is_double)
{
    for (int n = 0; n < n_samples; n++) {
        const double xn = (double)x[n];
        if (!is_double) {
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

static int search_matches(const SearchTree *tree, const int *how, const double *c, const float *x,
                          const void *want, size_t width, int *first_diff)
{
    for (int n = 0; n < SEARCH_SAMPLES; n++) {
        double delay[4] = {0, 0, 0, 0};
        double got = search_run_variant(tree, how, c, x, n + 1, delay, width == sizeof(double));
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

static float named_candidate(int which, const double *c, const float *x, int n_samples, float *delay)
{
    float b0 = (float)c[0], b1 = (float)c[1], b2 = (float)c[2], a1 = (float)c[3], a2 = (float)c[4];
    if (which == 0) {
        for (int n = 0; n < n_samples; n++) {
            float xn = x[n];
            float out = b0 * xn + b1 * delay[1] + b2 * delay[0] - a1 * delay[3] - a2 * delay[2];
            delay[0] = delay[1]; delay[1] = xn; delay[2] = delay[3]; delay[3] = out;
            if (n == n_samples - 1) return out;
        }
    } else if (which == 1) {
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
    } else if (which == 2) {
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
    } else if (which == 3) {
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
    } else {
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

    search_space(label, all, x, host_f, port_f);
}

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

static double sve_reduce_sequential(const double *v, int n)
{
    double s = 0, q = 0;
    for (int i = 0; i < n; i++) { s = s + v[i]; q = q + v[i] * v[i]; }
    return s;
}

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

static double sve_reduce_pairwise(const double *v, int n)
{
    if (n == 1) return v[0];
    int half = n / 2;
    return sve_reduce_pairwise(v, half) + sve_reduce_pairwise(v + half, n - half);
}

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
        printf("\nprobe: the reduction order of vDSP_sve_svesq\n");
        sve_search_reductions();
        printf("probe: %d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
