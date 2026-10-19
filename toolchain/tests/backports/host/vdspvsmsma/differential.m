#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

void charon_host_vDSP_vsmsma(const float *a, vDSP_Stride ia, const float *b, const float *c, vDSP_Stride ic,
                            const float *d, float *e, vDSP_Stride ie, vDSP_Length n);

#define CAP 32
#define GAP 0x5a3a3a3a

static int checks, failures;

static void report(const char *what, int ok, const char *note)
{
    checks++;
    if (ok) { printf("ok %s%s%s\n", what, note[0] ? " - " : "", note); return; }
    failures++;
    printf("FAIL %s%s%s\n", what, note[0] ? " - " : "", note);
}

static int control(void)
{
    const float a[4] = {1, 2, 3, 4}, c[4] = {10, 20, 30, 40}, b[1] = {2}, d[1] = {3};
    const float want[4] = {32, 64, 96, 128};
    float e[CAP];
    for (int i = 0; i < CAP; i++) { uint32_t g = GAP; memcpy(&e[i], &g, sizeof g); }
    charon_host_vDSP_vsmsma(a, 1, b, c, 1, d, e, 2, 4);
    int ok = 1;
    for (int i = 0; i < 4; i++) if (memcmp(&e[i * 2], &want[i], sizeof want[i]) != 0) ok = 0;
    report("CONTROL: E = A*2 + C*3 over 1..4 at stride 2", ok,
           "32 64 96 128, exact in float, and B and D are one scalar each");
    printf("  the port says:");
    for (int i = 0; i < 8; i++) printf(" %g", e[i]);
    printf("\n  by hand:      32  0x5a3a3a3a  64  0x5a3a3a3a  96  0x5a3a3a3a  128  0x5a3a3a3a\n");
    for (int i = 0; i < CAP; i++) {
        uint32_t g = GAP;
        if (i % 2 == 0 && i < 8) continue;
        if (memcmp(&e[i], &g, sizeof g) != 0) {
            report("CONTROL: every element of E outside the stride's steps is untouched", 0, "a gap was written");
            return 0;
        }
    }
    report("CONTROL: every element of E outside the stride's steps is untouched", 1,
           "the gaps kept the fill they were given");
    return failures == 0;
}

static void run(const char *label, vDSP_Stride ia, vDSP_Stride ic, vDSP_Stride ie, vDSP_Length n)
{
    float a[CAP], c[CAP], b[1], d[1], mine[CAP], theirs[CAP];
    for (vDSP_Length i = 0; i < CAP; i++) {
        a[i] = (float)(1.0 + (i % 4) * 0.5);
        c[i] = (float)(10.0 - (i % 3) * 2.5);
    }
    b[0] = 2.0f;
    d[0] = 0.5f;
    for (int i = 0; i < CAP; i++) {
        uint32_t g = GAP;
        memcpy(&mine[i], &g, sizeof g);
        memcpy(&theirs[i], &g, sizeof g);
    }
    charon_host_vDSP_vsmsma(a, ia, b, c, ic, d, mine, ie, n);
    vDSP_vsmsma(a, ia, b, c, ic, d, theirs, ie, n);
    char note[120];
    if (memcmp(mine, theirs, sizeof mine) == 0) {
        snprintf(note, sizeof note, "IA %d, IC %d, IE %d, N %ld, every element of E bit for bit", (int)ia, (int)ic,
                 (int)ie, (long)n);
        report(label, 1, note);
        return;
    }
    for (int i = 0; i < CAP; i++)
        if (memcmp(&mine[i], &theirs[i], sizeof mine[i]) != 0) {
            uint32_t m, t;
            memcpy(&m, &mine[i], sizeof m);
            memcpy(&t, &theirs[i], sizeof t);
            snprintf(note, sizeof note, "IA %d, IC %d, IE %d, N %ld: E[%d] is 0x%08x where the host says 0x%08x%s",
                     (int)ia, (int)ic, (int)ie, (long)n, i, m, t, (i % ie) == 0 ? "" : " - and that is a GAP");
            break;
        }
    report(label, 0, note);
}

static void precision_case(void)
{
    const float b[1] = {0.1f}, d[1] = {1.0f / 3.0f};
    const float a[8] = {0x1.fffffep0f, 0x1.fffffep0f * 1.125f, 0x1.fffffep0f * 1.25f, 0x1.fffffep0f * 1.375f,
                        0x1.fffffep0f * 1.5f,   0x1.fffffep0f * 1.625f, 0x1.fffffep0f * 1.75f, 0x1.fffffep0f * 1.875f};
    const float c[8] = {0x1.55555p-3f, 0x1.55555p-3f * 1.25f, 0x1.55555p-3f * 1.5f, 0x1.55555p-3f * 1.75f,
                        0x1.55555p-3f * 2.0f,   0x1.55555p-3f * 2.25f, 0x1.55555p-3f * 2.5f, 0x1.55555p-3f * 2.75f};
    float mine[8], theirs[8];
    charon_host_vDSP_vsmsma(a, 1, b, c, 1, d, mine, 1, 8);
    vDSP_vsmsma(a, 1, b, c, 1, d, theirs, 1, 8);
    report("the arithmetic's precision, on products that are not exact", memcmp(mine, theirs, sizeof mine) == 0,
           "B = 0.1f, D = 1/3f, A and C with full significands - the release and the port bit for bit");
    for (int i = 0; i < 8; i++) {
        float pa = a[i] * b[0], pc = c[i] * d[0];
        float in_float = pa + pc;
        float in_double = (float)((double)a[i] * (double)b[0] + (double)c[i] * (double)d[0]);
        if (memcmp(&in_float, &in_double, sizeof in_float) == 0) continue;
        uint32_t f1, f2, f3;
        memcpy(&f1, &in_float, sizeof f1);
        memcpy(&f2, &in_double, sizeof f2);
        memcpy(&f3, &theirs[i], sizeof f3);
        printf("    element %d: float 0x%08x, all double 0x%08x, the release 0x%08x - it agrees with %s\n", i, f1, f2,
               f3, f3 == f1 ? "FLOAT" : "DOUBLE");
        break;
    }
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        printf("the port's vDSP_vsmsma against the real Accelerate\n");
        printf("  the formula: E[n] = A[n]*B[0] + C[n]*D[0] - B and D are one scalar each, no channels\n");
        if (!control()) {
            printf("%d checks, %d failures\n", checks, failures);
            return 1;
        }
        run("no elements", 1, 1, 1, 0);
        run("one element", 1, 1, 1, 1);
        run("six elements, unit strides", 1, 1, 1, 6);
        run("A strided 3, C unit", 3, 1, 1, 6);
        run("A unit, C strided 4", 1, 4, 1, 6);
        run("A and C strided 2 and 5", 2, 5, 1, 6);
        run("E strided 3, A and C unit", 1, 1, 3, 6);
        run("all three strided 2, 3, 4", 2, 3, 4, 5);
        precision_case();
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
