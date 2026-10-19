#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

void charon_host_vDSP_sve_svesq(const float *a, vDSP_Stride ia, float *sum, float *sumsquares, vDSP_Length n);
void charon_host_vDSP_sve_svesqD(const double *a, vDSP_Stride ia, double *sum, double *sumsquares, vDSP_Length n);

static int checks, failures;

static uint32_t bits_of(const void *p, size_t n)
{
    const uint8_t *b = (const uint8_t *)p;
    uint32_t h = 2166136261u;
    for (size_t i = 0; i < n; i++) { h ^= b[i]; h *= 16777619u; }
    return h;
}

static void report(const char *what, const void *mine, size_t n, const void *theirs, const char *note)
{
    checks++;
    if (memcmp(mine, theirs, n) == 0) {
        printf("ok %s%s%s\n", what, note[0] ? " - " : "", note);
        return;
    }
    failures++;
    printf("FAIL %s%s%s\n", what, note[0] ? " - " : "", note);
    printf("     the host's bytes %08x, the port's %08x\n", bits_of(theirs, n), bits_of(mine, n));
}

static int control(void)
{
    float in[4] = {1.0f, 2.0f, 3.0f, 4.0f};
    float sum = -1.0f, squares = -1.0f;
    charon_host_vDSP_sve_svesq(in, 1, &sum, &squares, 4);
    const float want_sum = 10.0f, want_squares = 30.0f;
    checks++;
    if (memcmp(&sum, &want_sum, sizeof sum) == 0 && memcmp(&squares, &want_squares, sizeof squares) == 0) {
        printf("ok CONTROL: the sequential form gives 10 and 30 for 1, 2, 3, 4, which is the hand value\\n");
        return 1;
    }
    failures++;
    printf("FAIL CONTROL: the sequential form gives %.9g and %.9g where the hand value is 10 and 30, so the "
           "differential reports nothing\\n", sum, squares);
    return 0;
}

#define ROWS_CAP 64

static void compare(const char *label, const float *a, vDSP_Stride stride, vDSP_Length n)
{
    float mine_sum = -1.0f, mine_sq = -1.0f, host_sum = -1.0f, host_sq = -1.0f;
    charon_host_vDSP_sve_svesq(a, stride, &mine_sum, &mine_sq, n);
    vDSP_sve_svesq(a, stride, &host_sum, &host_sq, n);
    char note[96];
    snprintf(note, sizeof note, "%s, N %d, stride %d, the sum", label, (int)n, (int)stride);
    report(note, &mine_sum, sizeof mine_sum, &host_sum, "by bit pattern");
    snprintf(note, sizeof note, "%s, N %d, stride %d, the sum of squares", label, (int)n, (int)stride);
    report(note, &mine_sq, sizeof mine_sq, &host_sq, "by bit pattern");
}

static void compare_double(const char *label, const double *a, vDSP_Stride stride, vDSP_Length n)
{
    double mine_sum = -1.0, mine_sq = -1.0, host_sum = -1.0, host_sq = -1.0;
    charon_host_vDSP_sve_svesqD(a, stride, &mine_sum, &mine_sq, n);
    vDSP_sve_svesqD(a, stride, &host_sum, &host_sq, n);
    char note[96];
    snprintf(note, sizeof note, "%s, N %d, stride %d, the sum", label, (int)n, (int)stride);
    report(note, &mine_sum, sizeof mine_sum, &host_sum, "by bit pattern");
    snprintf(note, sizeof note, "%s, N %d, stride %d, the sum of squares", label, (int)n, (int)stride);
    report(note, &mine_sq, sizeof mine_sq, &host_sq, "by bit pattern");
}

static float order_sequential(const float *v, int n)
{
    float s = 0;
    for (int i = 0; i < n; i++) s = s + v[i];
    return s;
}

static float order_blocked(const float *v, int n, int block)
{
    float s = 0;
    for (int base = 0; base < n; base += block) {
        float ps = 0;
        int end = base + block < n ? base + block : n;
        for (int i = base; i < end; i++) ps = ps + v[i];
        s = s + ps;
    }
    return s;
}

static float order_pairwise(const float *v, int n)
{
    if (n == 1) return v[0];
    int half = n / 2;
    return order_pairwise(v, half) + order_pairwise(v + half, n - half);
}

static void order_case(void)
{
    static const float v[6] = {1e30f, 1.0f, -1e30f, 1.0f, 1e-30f, 3.0f};
    float mine = -1.0f, mine_q = -1.0f, host = -1.0f, host_q = -1.0f;
    charon_host_vDSP_sve_svesq(v, 1, &mine, &mine_q, 6);
    vDSP_sve_svesq(v, 1, &host, &host_q, 6);
    float seq = order_sequential(v, 6), blk2 = order_blocked(v, 6, 2), blk4 = order_blocked(v, 6, 4),
          pair = order_pairwise(v, 6);
    report("the order, on 1e30 against 1 with a tail", &mine, sizeof mine, &host, "the port and the release, bit for bit");
    printf("  the host %.9g; sequential %.9g; blocked 2 %.9g; blocked 4 %.9g; pairwise %.9g\n", host, seq, blk2, blk4, pair);
    printf("  the orders that give the host's own answer:");
    if (memcmp(&seq, &host, sizeof seq) == 0) printf(" sequential");
    if (memcmp(&blk2, &host, sizeof blk2) == 0) printf(" blocked-2");
    if (memcmp(&blk4, &host, sizeof blk4) == 0) printf(" blocked-4");
    if (memcmp(&pair, &host, sizeof pair) == 0) printf(" pairwise");
    printf("\n");
    checks++;
    if (memcmp(&seq, &blk4, sizeof seq) != 0)
        printf("  (the case separates them: sequential and blocked-4 differ)\n");
    else
        printf("  (this case does NOT separate them - sequential and blocked-4 agree)\n");
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        order_case();
        if (!control()) {
            printf("%d checks, %d failures\n", checks, failures);
            return 1;
        }
        float a[ROWS_CAP];
        for (int i = 0; i < ROWS_CAP; i++) a[i] = (float)(0.5 + (i % 7) * 1.25);
        compare("ordinary data", a, 1, 16);
        compare("ordinary data, a longer run", a, 1, ROWS_CAP);
        compare("ordinary data, strided", a, 3, 16);
        compare("one element", a, 1, 1);
        compare("no elements", a, 1, 0);

        float nan_middle[4] = {1.0f, NAN, 3.0f, 4.0f};
        compare("a NaN in the middle", nan_middle, 1, 4);
        float signed_zero[4] = {0.0f, -0.0f, 0.0f, -0.0f};
        compare("signed zeroes", signed_zero, 1, 4);
        float denormal[4] = {1e-42f, 1e-42f, 1e-42f, 1e-42f};
        compare("four denormals", denormal, 1, 4);
        float huge[4] = {3.4e38f, 3.4e38f, 3.4e38f, 3.4e38f};
        compare("four at the top of the range", huge, 1, 4);
        float cancelling[6] = {1e30f, 1.0f, -1e30f, 1.0f, 1e-30f, 3.0f};
        compare("a range that overflows a naive sum", cancelling, 1, 6);

        double d[ROWS_CAP];
        for (int i = 0; i < ROWS_CAP; i++) d[i] = 0.5 + (i % 7) * 1.25;
        compare_double("ordinary data in double", d, 1, 16);
        compare_double("ordinary data in double, a longer run", d, 1, ROWS_CAP);
        double dnan[4] = {1.0, NAN, 3.0, 4.0};
        compare_double("a NaN in the middle, in double", dnan, 1, 4);
        double ddenormal[4] = {1e-310, 1e-310, 1e-310, 1e-310};
        compare_double("four denormals, in double", ddenormal, 1, 4);
        double dcancel[6] = {1e300, 1.0, -1e300, 1.0, 1e-300, 3.0};
        compare_double("a range that overflows a naive sum, in double", dcancel, 1, 6);
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
