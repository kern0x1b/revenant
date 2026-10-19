#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern volatile int charon_tracing;
extern volatile long charon_fail_at, charon_seen, charon_failed_calls;

#ifdef CHARON_PORT
extern vDSP_DFT_Interleaved_Setup charon_host_vDSP_DFT_Interleaved_CreateSetup(vDSP_DFT_Interleaved_Setup, vDSP_Length, vDSP_DFT_Direction, vDSP_DFT_RealtoComplex);
extern vDSP_DFT_Interleaved_SetupD charon_host_vDSP_DFT_Interleaved_CreateSetupD(vDSP_DFT_Interleaved_SetupD, vDSP_Length, vDSP_DFT_Direction, vDSP_DFT_RealtoComplex);
extern void charon_host_vDSP_DFT_Interleaved_DestroySetup(vDSP_DFT_Interleaved_Setup);
extern void charon_host_vDSP_DFT_Interleaved_DestroySetupD(vDSP_DFT_Interleaved_SetupD);
#define DESTROY(dbl, s) ((dbl) ? charon_host_vDSP_DFT_Interleaved_DestroySetupD((vDSP_DFT_Interleaved_SetupD)(s)) : charon_host_vDSP_DFT_Interleaved_DestroySetup((vDSP_DFT_Interleaved_Setup)(s)))
#define CREATE(dbl, n, dir, form) ((dbl) ? (void *)charon_host_vDSP_DFT_Interleaved_CreateSetupD(NULL, (n), (dir), (form)) \
                                         : (void *)charon_host_vDSP_DFT_Interleaved_CreateSetup(NULL, (n), (dir), (form)))
static const char *who = "port";
#else
#define DESTROY(dbl, s) ((dbl) ? vDSP_DFT_Interleaved_DestroySetupD((vDSP_DFT_Interleaved_SetupD)(s)) : vDSP_DFT_Interleaved_DestroySetup((vDSP_DFT_Interleaved_Setup)(s)))
#define CREATE(dbl, n, dir, form) ((dbl) ? (void *)vDSP_DFT_Interleaved_CreateSetupD(NULL, (n), (dir), (form)) \
                                         : (void *)vDSP_DFT_Interleaved_CreateSetup(NULL, (n), (dir), (form)))
static const char *who = "host";
#endif

static int failures = 0;

static void *createWith(int dbl, vDSP_Length n, vDSP_DFT_Direction dir, vDSP_DFT_RealtoComplex form, long k, long *calls, long *hit)
{
    charon_fail_at = k;
    charon_seen = 0;
    charon_failed_calls = 0;
    charon_tracing = 1;
    void *s = CREATE(dbl, n, dir, form);
    charon_tracing = 0;
    if (calls) { *calls = charon_seen; }
    if (hit) { *hit = charon_failed_calls; }
    return s;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    const vDSP_Length lengths[] = {8, 128, 1024};
    for (size_t li = 0; li < sizeof(lengths) / sizeof(lengths[0]); li++)
    for (int dbl = 0; dbl < 2; dbl++)
    for (int r = 0; r < 2; r++)
    for (int f = 0; f < 2; f++) {
        vDSP_Length n = lengths[li];
        vDSP_DFT_RealtoComplex form = r ? vDSP_DFT_Interleaved_RealtoComplex : vDSP_DFT_Interleaved_ComplextoComplex;
        vDSP_DFT_Direction dir = f ? vDSP_DFT_FORWARD : vDSP_DFT_INVERSE;
        long calls = 0, hit = 0;
        void *s = createWith(dbl, n, dir, form, -1, &calls, &hit);
        if (s) { DESTROY(dbl, s); }
        if (!s) { printf("%s N=%lu %s %s %s: unfailed setup NULL\n", who, (unsigned long)n, dbl ? "D" : "S", r ? "R2C" : "C2C", f ? "fwd" : "inv"); failures++; continue; }
        for (long k = 1; k <= calls; k++) {
            long h = 0;
            void *t = createWith(dbl, n, dir, form, k, NULL, &h);
            printf("%s N=%lu %s %s %s fail_at=%ld: %s hit=%ld\n", who, (unsigned long)n, dbl ? "D" : "S", r ? "R2C" : "C2C",
                   f ? "fwd" : "inv", k, t ? "setup" : "NULL", h);
            if (t && h > 0 && who[0] == 'p') { failures++; }
        }
    }
    printf("%s: checks=%s failures=%d\n", who, who[0] == 'p' ? "port-null-on-hit" : "table", failures);
    return failures == 0 ? 0 : 1;
}
