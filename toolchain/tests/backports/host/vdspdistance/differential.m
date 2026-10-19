#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

void charon_host_vDSP_distancesq(const float *a, vDSP_Stride ia, const float *b, vDSP_Stride ib, float *c,
                                 vDSP_Length n);

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

static void run(const char *label, vDSP_Stride ia, vDSP_Stride ib, vDSP_Length n)
{
    float a[CAP], b[CAP], mine[CAP], theirs[CAP];
    for (vDSP_Length i = 0; i < CAP; i++) {
        a[i] = (float)(0.5 + (i % 5) * 1.25);
        b[i] = (float)(3.0 - (i % 3) * 0.5);
    }
    for (int i = 0; i < CAP; i++) {
        uint32_t gap = GAP;
        memcpy(&mine[i], &gap, sizeof gap);
        memcpy(&theirs[i], &gap, sizeof gap);
    }
    charon_host_vDSP_distancesq(a, ia, b, ib, mine, n);
    vDSP_distancesq(a, ia, b, ib, theirs, n);

    char note[96];
    snprintf(note, sizeof note, "IA %d, IB %d, N %ld, every element of C bit for bit", (int)ia, (int)ib, (long)n);
    if (memcmp(mine, theirs, sizeof mine) == 0) {
        report(label, 1, note);
        return;
    }
    for (int i = 0; i < CAP; i++)
        if (memcmp(&mine[i], &theirs[i], sizeof mine[i]) != 0) {
            uint32_t m, t;
            memcpy(&m, &mine[i], sizeof m);
            memcpy(&t, &theirs[i], sizeof t);
            snprintf(note, sizeof note, "IA %d, IB %d, N %ld: C[%d] is 0x%08x where the host says 0x%08x%s", (int)ia,
                     (int)ib, (long)n, i, m, t, i == 0 ? " - and C[0] is the answer" : " - and that is a GAP");
            break;
        }
    report(label, 0, note);
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        printf("the port's vDSP_distancesq against the real Accelerate\n");
        printf("  the formula: C[0] = sum((A[n] - B[n]) ** 2, 0 <= n < N) - one scalar out\n");
        run("no elements", 1, 1, 0);
        run("one element", 1, 1, 1);
        run("six elements, unit strides", 1, 1, 6);
        run("strides 3 and 1", 3, 1, 6);
        run("strides 1 and 4", 1, 4, 6);
        run("strides 2 and 5", 2, 5, 6);
        run("strides 7 and 2", 7, 2, 4);
        run("fourteen elements, stride 2", 2, 3, 14);
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
