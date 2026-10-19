// The port's vDSP_distancesq against the real Accelerate, in the shape the coordinator asked for:
// N = 0, N = 1, strides above one on **every** input, and the gaps in C left untouched.
//
// The gaps are the point. The header's Maps line is `C[0] = sum((A[n] - B[n]) ** 2, 0 <= n < N)` - one scalar
// out, a window of N, and no inner count because there is no inner dimension. A port written from the
// signature alone, with two input strides, one output and no window width, would write one C per element, and
// no test of the input strides would catch it. So C is pre-filled with a known pattern over more elements than
// the call has, and **every element outside C[0] must come back exactly as it went in**.
//
// Every comparison is on the bit pattern, never `==`.

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

// One case: the same strided inputs to both, C pre-filled over more than N elements, and the whole of C
// compared - the element the call is for, and every gap after it.
static void run(const char *label, vDSP_Stride ia, vDSP_Stride ib, vDSP_Length n)
{
    float a[CAP], b[CAP], mine[CAP], theirs[CAP];
    for (vDSP_Length i = 0; i < CAP; i++) {
        // values that are distinct and not in ascending order, so a swapped stride shows
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
    // name the first difference, and whether it is the answer or a gap
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
        // N = 0: the release answers 0, and writes nothing past C[0]
        run("no elements", 1, 1, 0);
        // N = 1: a single window element, where a port that wrote one C per element would still pass
        run("one element", 1, 1, 1);
        // the ordinary case
        run("six elements, unit strides", 1, 1, 6);
        // strides above one on every input, independently, which is where a stride mistake shows
        run("strides 3 and 1", 3, 1, 6);
        run("strides 1 and 4", 1, 4, 6);
        run("strides 2 and 5", 2, 5, 6);
        run("strides 7 and 2", 7, 2, 4);
        // a long window, so the accumulation has room to differ from the host
        run("fourteen elements, stride 2", 2, 3, 14);
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
