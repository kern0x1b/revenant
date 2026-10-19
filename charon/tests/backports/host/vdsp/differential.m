// The port's vDSPFixed7.m and vDSPElementwise8.m held against the host's own vDSP, case by case.
//
// The port's two sources are compiled with every API name they define renamed, so this one can hold the
// port's answers and the host's side by side and compare them: the two 24-bit readers, the two scaling
// forms, the two clamps, the integer add, the two split-complex products in one precision and in the
// other, the two sums-and-differences, the four ramps, the two sliding window maxima, the scaled
// multiply-multiply-add, the two dot products and the distance.
//
// Every case gives both sides the same bytes and compares everything they wrote, so a function that
// writes less than the other - which is what a wrong stride or a wrong count does - is caught. The
// prototypes are the ones of the header of iOS 16.4, which is what the port's own translation units are
// compiled against; the types they use are the host's, so the two sides are called through one set of
// declarations.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

void charon_host_vDSP_vflt24(const vDSP_int24 *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N);
void charon_host_vDSP_vfltu24(const vDSP_uint24 *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N);
void charon_host_vDSP_vfltsm24(const vDSP_int24 *A, vDSP_Stride IA, const float *B, float *C, vDSP_Stride IC,
                               vDSP_Length N);
void charon_host_vDSP_vfltsmu24(const vDSP_uint24 *A, vDSP_Stride IA, const float *B, float *C, vDSP_Stride IC,
                                vDSP_Length N);
void charon_host_vDSP_vsmfix24(const float *A, vDSP_Stride IA, const float *B, vDSP_int24 *C, vDSP_Stride IC,
                               vDSP_Length N);
void charon_host_vDSP_vsmfixu24(const float *A, vDSP_Stride IA, const float *B, vDSP_uint24 *C, vDSP_Stride IC,
                                vDSP_Length N);
void charon_host_vDSP_vaddi(const int *A, vDSP_Stride IA, const int *B, vDSP_Stride IB, int *C, vDSP_Stride IC,
                            vDSP_Length N);
void charon_host_vDSP_zvma(const DSPSplitComplex *A, vDSP_Stride IA, const DSPSplitComplex *B, vDSP_Stride IB,
                           const DSPSplitComplex *C, vDSP_Stride IC, const DSPSplitComplex *D, vDSP_Stride ID,
                           vDSP_Length N);
void charon_host_vDSP_zvmmaa(const DSPSplitComplex *A, vDSP_Stride IA, const DSPSplitComplex *B, vDSP_Stride IB,
                             const DSPSplitComplex *C, vDSP_Stride IC, const DSPSplitComplex *D, vDSP_Stride ID,
                             const DSPSplitComplex *E, vDSP_Stride IE, const DSPSplitComplex *F, vDSP_Stride IF,
                             vDSP_Length N);
void charon_host_vDSP_vaddsub(const float *I0, vDSP_Stride I0S, const float *I1, vDSP_Stride I1S, float *O0,
                              vDSP_Stride O0S, float *O1, vDSP_Stride O1S, vDSP_Length N);
void charon_host_vDSP_vaddsubD(const double *I0, vDSP_Stride I0S, const double *I1, vDSP_Stride I1S, double *O0,
                               vDSP_Stride O0S, double *O1, vDSP_Stride O1S, vDSP_Length N);
void charon_host_vDSP_vrampmulD(const double *I, vDSP_Stride IS, double *Start, const double *Step, double *O,
                                vDSP_Stride OS, vDSP_Length N);
void charon_host_vDSP_vrampmul2D(const double *I0, const double *I1, vDSP_Stride IS, double *Start, const double *Step,
                                 double *O0, double *O1, vDSP_Stride OS, vDSP_Length N);
void charon_host_vDSP_vrampmuladdD(const double *I, vDSP_Stride IS, double *Start, const double *Step, double *O,
                                   vDSP_Stride OS, vDSP_Length N);
void charon_host_vDSP_vrampmuladd2D(const double *I0, const double *I1, vDSP_Stride IS, double *Start,
                                    const double *Step, double *O0, double *O1, vDSP_Stride OS, vDSP_Length N);
void charon_host_vDSP_vswmax(const float *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N,
                             vDSP_Length WindowLength);
void charon_host_vDSP_vswmaxD(const double *A, vDSP_Stride IA, double *C, vDSP_Stride IC, vDSP_Length N,
                              vDSP_Length WindowLength);
void charon_host_vDSP_vsmsmaD(const double *A, vDSP_Stride IA, const double *B, const double *C, vDSP_Stride IC,
                              const double *D, double *E, vDSP_Stride IE, vDSP_Length N);
void charon_host_vDSP_dotpr2D(const double *A0, vDSP_Stride IA0, const double *A1, vDSP_Stride IA1, const double *B,
                              vDSP_Stride IB, double *C0, double *C1, vDSP_Length N);
void charon_host_vDSP_distancesqD(const double *A, vDSP_Stride IA, const double *B, vDSP_Stride IB, double *C,
                                  vDSP_Length N);
void charon_host_vDSP_zvmaD(const DSPDoubleSplitComplex *A, vDSP_Stride IA, const DSPDoubleSplitComplex *B,
                            vDSP_Stride IB, const DSPDoubleSplitComplex *C, vDSP_Stride IC,
                            const DSPDoubleSplitComplex *D, vDSP_Stride ID, vDSP_Length N);
void charon_host_vDSP_zvmmaaD(const DSPDoubleSplitComplex *A, vDSP_Stride IA, const DSPDoubleSplitComplex *B,
                              vDSP_Stride IB, const DSPDoubleSplitComplex *C, vDSP_Stride IC,
                              const DSPDoubleSplitComplex *D, vDSP_Stride ID, const DSPDoubleSplitComplex *E,
                              vDSP_Stride IE, const DSPDoubleSplitComplex *F, vDSP_Stride IF, vDSP_Length N);

static int checks;
static int failures;
static char detail[512];

static void report(int passed, const char *name, const char *why)
{
    checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: %s\n", name, why);
    }
    fflush(stdout);
}

static vDSP_int24 charon_int24(int value)
{
    vDSP_int24 out;
    out.bytes[0] = (unsigned char)(value & 0xff);
    out.bytes[1] = (unsigned char)((value >> 8) & 0xff);
    out.bytes[2] = (unsigned char)((value >> 16) & 0xff);
    return out;
}

static vDSP_uint24 charon_uint24(unsigned value)
{
    vDSP_uint24 out;
    out.bytes[0] = (unsigned char)(value & 0xff);
    out.bytes[1] = (unsigned char)((value >> 8) & 0xff);
    out.bytes[2] = (unsigned char)((value >> 16) & 0xff);
    return out;
}

static int charon_read_int24(const vDSP_int24 *value, int at)
{
    int raw = value[at].bytes[0] | (value[at].bytes[1] << 8) | (value[at].bytes[2] << 16);
    return (raw & 0x800000) ? raw | ~0xffffff : raw;
}

static unsigned charon_read_uint24(const vDSP_uint24 *value, int at)
{
    return (unsigned)(value[at].bytes[0] | (value[at].bytes[1] << 8) | (value[at].bytes[2] << 16));
}

// The two sides write into their own buffers, which start as the same bytes, and every element of both
// is compared - so an element neither wrote, or only one of them wrote, is a difference.
static void same_floats(const char *name, const float *mine, const float *theirs, int count)
{
    for (int at = 0; at < count; at++) {
        if (memcmp(&mine[at], &theirs[at], sizeof(float)) != 0 &&
            !(isnan(mine[at]) && isnan(theirs[at]))) {
            snprintf(detail, sizeof detail, "element %d is %.9g, the host says %.9g", at, mine[at], theirs[at]);
            report(0, name, detail);
            return;
        }
    }
    report(1, name, "");
}

static void same_doubles(const char *name, const double *mine, const double *theirs, int count)
{
    for (int at = 0; at < count; at++) {
        double difference = fabs(mine[at] - theirs[at]);
        double scale = fabs(theirs[at]) > 1.0 ? fabs(theirs[at]) : 1.0;
        if (isnan(mine[at]) && isnan(theirs[at])) {
            continue;
        }
        if (difference > 1e-12 * scale) {
            snprintf(detail, sizeof detail, "element %d is %.17g, the host says %.17g", at, mine[at], theirs[at]);
            report(0, name, detail);
            return;
        }
    }
    report(1, name, "");
}

static void same_int24(const char *name, const vDSP_int24 *mine, const vDSP_int24 *theirs, int count)
{
    for (int at = 0; at < count; at++) {
        if (charon_read_int24(mine, at) != charon_read_int24(theirs, at)) {
            snprintf(detail, sizeof detail, "element %d is %d, the host says %d", at, charon_read_int24(mine, at),
                     charon_read_int24(theirs, at));
            report(0, name, detail);
            return;
        }
    }
    report(1, name, "");
}

static void same_uint24(const char *name, const vDSP_uint24 *mine, const vDSP_uint24 *theirs, int count)
{
    for (int at = 0; at < count; at++) {
        if (charon_read_uint24(mine, at) != charon_read_uint24(theirs, at)) {
            snprintf(detail, sizeof detail, "element %d is %u, the host says %u", at, charon_read_uint24(mine, at),
                     charon_read_uint24(theirs, at));
            report(0, name, detail);
            return;
        }
    }
    report(1, name, "");
}

static void same_ints(const char *name, const int *mine, const int *theirs, int count)
{
    for (int at = 0; at < count; at++) {
        if (mine[at] != theirs[at]) {
            snprintf(detail, sizeof detail, "element %d is %d, the host says %d", at, mine[at], theirs[at]);
            report(0, name, detail);
            return;
        }
    }
    report(1, name, "");
}

// The six values the 24-bit cases use, and the buffer each case writes into: eight elements, so a case
// with a stride of two can be seen to write where it should and nowhere else. Every byte of both
// buffers starts as a value neither side is expected to write.
// Six elements at an output stride of two occupy twelve slots; both sides write all twelve, so both
// buffers are that long and all twelve are compared. A buffer of eight would have both of them writing
// past the end, which is the caller's mistake and not a difference between the two.
#define BUFFER_SLOTS 8
#define STRIDED_SLOTS 12
static const float kFill = -987654.0f;
static const double kFillD = -987654.0;
static const int kFillI = -987654;

int main(void)
{
    const int signed_values[6] = {0, 1, -1, 8388607, -8388608, -12345};
    const unsigned unsigned_values[6] = {0, 1, 8388607, 8388608, 16777215, 12345};
    vDSP_int24 signed24[6];
    vDSP_uint24 unsigned24[6];
    for (int at = 0; at < 6; at++) {
        signed24[at] = charon_int24(signed_values[at]);
        unsigned24[at] = charon_uint24(unsigned_values[at]);
    }

    // the two plain conversions, and a stride of two on each side
    {
        float mine[BUFFER_SLOTS], theirs[BUFFER_SLOTS];
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            mine[at] = theirs[at] = kFill;
        }
        charon_host_vDSP_vflt24(signed24, 1, mine, 1, 6);
        vDSP_vflt24(signed24, 1, theirs, 1, 6);
        same_floats("vDSP_vflt24 over six values", mine, theirs, BUFFER_SLOTS);
        float wide_mine[STRIDED_SLOTS], wide_theirs[STRIDED_SLOTS];
        for (int at = 0; at < STRIDED_SLOTS; at++) {
            wide_mine[at] = wide_theirs[at] = kFill;
        }
        charon_host_vDSP_vflt24(signed24, 1, wide_mine, 2, 6);
        vDSP_vflt24(signed24, 1, wide_theirs, 2, 6);
        same_floats("vDSP_vflt24 with a stride of two on the output", wide_mine, wide_theirs, STRIDED_SLOTS);
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            mine[at] = theirs[at] = kFill;
        }
        vDSP_int24 doubled[12];
        for (int at = 0; at < 12; at++) {
            doubled[at] = signed24[at % 6];
        }
        charon_host_vDSP_vflt24(doubled, 2, mine, 1, 3);
        vDSP_vflt24(doubled, 2, theirs, 1, 3);
        same_floats("vDSP_vflt24 with a stride of two on the input", mine, theirs, 3);
    }
    {
        float mine[BUFFER_SLOTS], theirs[BUFFER_SLOTS];
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            mine[at] = theirs[at] = kFill;
        }
        charon_host_vDSP_vfltu24(unsigned24, 1, mine, 1, 6);
        vDSP_vfltu24(unsigned24, 1, theirs, 1, 6);
        same_floats("vDSP_vfltu24 over six values", mine, theirs, BUFFER_SLOTS);
    }

    // the scaling forms, at a scale of 1, 2, -1 and 0
    for (int which = 0; which < 4; which++) {
        const float scales[4] = {1.0f, 2.0f, -1.0f, 0.0f};
        float scale_array[4] = {scales[which], 0.0f, 0.0f, 0.0f};
        float mine[BUFFER_SLOTS], theirs[BUFFER_SLOTS];
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            mine[at] = theirs[at] = kFill;
        }
        charon_host_vDSP_vfltsm24(signed24, 1, scale_array, mine, 1, 6);
        vDSP_vfltsm24(signed24, 1, scale_array, theirs, 1, 6);
        snprintf(detail, sizeof detail, "at a scale of %g", scales[which]);
        {
            char label[80];
            snprintf(label, sizeof label, "vDSP_vfltsm24 %s", detail);
            same_floats(label, mine, theirs, BUFFER_SLOTS);
        }
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            mine[at] = theirs[at] = kFill;
        }
        charon_host_vDSP_vfltsmu24(unsigned24, 1, scale_array, mine, 1, 6);
        vDSP_vfltsmu24(unsigned24, 1, scale_array, theirs, 1, 6);
        {
            char label[80];
            snprintf(label, sizeof label, "vDSP_vfltsmu24 %s", detail);
            same_floats(label, mine, theirs, BUFFER_SLOTS);
        }
    }

    // the two clamps, at a scale that overflows both ranges and one that does not
    {
        const float inputs[6] = {1.0f, -1.0f, 0.5f, -0.5f, 2.0f / 3.0f, 100.0f};
        const float scales[4] = {8388608.0f, -8388608.0f, 1.0f, 0.5f};
        for (int which = 0; which < 4; which++) {
            float scale_array[4] = {scales[which], 0.0f, 0.0f, 0.0f};
            vDSP_int24 mine[BUFFER_SLOTS], theirs[BUFFER_SLOTS];
            memset(mine, 0x5a, sizeof mine);
            memset(theirs, 0x5a, sizeof theirs);
            charon_host_vDSP_vsmfix24(inputs, 1, scale_array, mine, 1, 6);
            vDSP_vsmfix24(inputs, 1, scale_array, theirs, 1, 6);
            {
                char label[80];
                snprintf(label, sizeof label, "vDSP_vsmfix24 at a scale of %g", scales[which]);
                same_int24(label, mine, theirs, 6);
            }
            vDSP_uint24 umine[BUFFER_SLOTS], utheirs[BUFFER_SLOTS];
            memset(umine, 0x5a, sizeof umine);
            memset(utheirs, 0x5a, sizeof utheirs);
            charon_host_vDSP_vsmfixu24(inputs, 1, scale_array, umine, 1, 6);
            vDSP_vsmfixu24(inputs, 1, scale_array, utheirs, 1, 6);
            {
                char label[80];
                snprintf(label, sizeof label, "vDSP_vsmfixu24 at a scale of %g", scales[which]);
                same_uint24(label, umine, utheirs, 6);
            }
        }
        // negative inputs at a scale of one, which is where the unsigned clamp shows
        {
            const float negative[6] = {-1.0f, -0.5f, -2.0f, 0.0f, 0.25f, -1e9f};
            float one[4] = {1.0f, 0.0f, 0.0f, 0.0f};
            vDSP_int24 mine[BUFFER_SLOTS], theirs[BUFFER_SLOTS];
            memset(mine, 0x5a, sizeof mine);
            memset(theirs, 0x5a, sizeof theirs);
            charon_host_vDSP_vsmfix24(negative, 1, one, mine, 1, 6);
            vDSP_vsmfix24(negative, 1, one, theirs, 1, 6);
            same_int24("vDSP_vsmfix24 of negative values at a scale of one", mine, theirs, 6);
            vDSP_uint24 umine[BUFFER_SLOTS], utheirs[BUFFER_SLOTS];
            memset(umine, 0x5a, sizeof umine);
            memset(utheirs, 0x5a, sizeof utheirs);
            charon_host_vDSP_vsmfixu24(negative, 1, one, umine, 1, 6);
            vDSP_vsmfixu24(negative, 1, one, utheirs, 1, 6);
            same_uint24("vDSP_vsmfixu24 of negative values at a scale of one", umine, utheirs, 6);
        }
    }

    // the integer add, with a stride on each of the three
    {
        const int a[6] = {1, -2, 3, -4, 5, -6}, b[6] = {10, 20, -30, 40, -50, 60};
        int mine[BUFFER_SLOTS], theirs[BUFFER_SLOTS];
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            mine[at] = theirs[at] = kFillI;
        }
        charon_host_vDSP_vaddi(a, 1, b, 1, mine, 1, 6);
        vDSP_vaddi(a, 1, b, 1, theirs, 1, 6);
        same_ints("vDSP_vaddi over six values", mine, theirs, BUFFER_SLOTS);
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            mine[at] = theirs[at] = kFillI;
        }
        charon_host_vDSP_vaddi(a, 2, b, 1, mine, 1, 3);
        vDSP_vaddi(a, 2, b, 1, theirs, 1, 3);
        same_ints("vDSP_vaddi with a stride of two on the first", mine, theirs, 3);
        int wide_mine[STRIDED_SLOTS], wide_theirs[STRIDED_SLOTS];
        for (int at = 0; at < STRIDED_SLOTS; at++) {
            wide_mine[at] = wide_theirs[at] = kFillI;
        }
        charon_host_vDSP_vaddi(a, 1, b, 1, wide_mine, 2, 6);
        vDSP_vaddi(a, 1, b, 1, wide_theirs, 2, 6);
        same_ints("vDSP_vaddi with a stride of two on the output", wide_mine, wide_theirs, STRIDED_SLOTS);
    }

    // the split-complex products, in one precision and in the other
    {
        float ar[4] = {1, 2, 3, 4}, ai[4] = {5, 6, 7, 8};
        float br[4] = {2, 0, -1, 3}, bi[4] = {0, 1, 1, 0};
        float cr[4] = {1, 1, 0, -1}, ci[4] = {1, -1, 1, 1};
        DSPSplitComplex A = {ar, ai}, B = {br, bi}, C = {cr, ci};
        float mdr[4], mdi[4], tdr[4], tdi[4];
        DSPSplitComplex mine = {mdr, mdi}, theirs = {tdr, tdi};
        charon_host_vDSP_zvma(&A, 1, &B, 1, &C, 1, &mine, 1, 4);
        vDSP_zvma(&A, 1, &B, 1, &C, 1, &theirs, 1, 4);
        same_floats("vDSP_zvma, the real part", mdr, tdr, 4);
        same_floats("vDSP_zvma, the imaginary part", mdi, tdi, 4);
        {
            float mdr2[4], mdi2[4], tdr2[4], tdi2[4];
            DSPSplitComplex mine2 = {mdr2, mdi2}, theirs2 = {tdr2, tdi2};
            charon_host_vDSP_zvma(&A, 2, &B, 1, &C, 2, &mine2, 1, 2);
            vDSP_zvma(&A, 2, &B, 1, &C, 2, &theirs2, 1, 2);
            same_floats("vDSP_zvma with a stride of two on the inputs", mdr2, tdr2, 2);
            same_floats("vDSP_zvma with a stride of two on the inputs, the imaginary part", mdi2, tdi2, 2);
        }
        {
            float fr[3] = {1, 2, 3}, fi[3] = {4, 5, 6};
            float gr[3] = {1, 0, 1}, gi[3] = {0, 1, 1};
            float hr[3] = {2, 3, 4}, hi[3] = {5, 6, 7};
            float ir[3] = {1, 1, 1}, ii[3] = {1, 1, 1};
            float jr[3] = {10, 20, 30}, ji[3] = {40, 50, 60};
            DSPSplitComplex F = {fr, fi}, G = {gr, gi}, H = {hr, hi}, I = {ir, ii}, J = {jr, ji};
            float mfr[3], mfi[3], tfr[3], tfi[3];
            DSPSplitComplex mine3 = {mfr, mfi}, theirs3 = {tfr, tfi};
            charon_host_vDSP_zvmmaa(&F, 1, &G, 1, &H, 1, &I, 1, &J, 1, &mine3, 1, 3);
            vDSP_zvmmaa(&F, 1, &G, 1, &H, 1, &I, 1, &J, 1, &theirs3, 1, 3);
            same_floats("vDSP_zvmmaa, the real part", mfr, tfr, 3);
            same_floats("vDSP_zvmmaa, the imaginary part", mfi, tfi, 3);
        }
    }
    {
        double ar[4] = {1, 2, 3, 4}, ai[4] = {5, 6, 7, 8};
        double br[4] = {2, 0, -1, 3}, bi[4] = {0, 1, 1, 0};
        double cr[4] = {1, 1, 0, -1}, ci[4] = {1, -1, 1, 1};
        DSPDoubleSplitComplex A = {ar, ai}, B = {br, bi}, C = {cr, ci};
        double mdr[4], mdi[4], tdr[4], tdi[4];
        DSPDoubleSplitComplex mine = {mdr, mdi}, theirs = {tdr, tdi};
        charon_host_vDSP_zvmaD(&A, 1, &B, 1, &C, 1, &mine, 1, 4);
        vDSP_zvmaD(&A, 1, &B, 1, &C, 1, &theirs, 1, 4);
        same_doubles("vDSP_zvmaD, the real part", mdr, tdr, 4);
        same_doubles("vDSP_zvmaD, the imaginary part", mdi, tdi, 4);
        {
            double fr[3] = {1, 2, 3}, fi[3] = {4, 5, 6};
            double gr[3] = {1, 0, 1}, gi[3] = {0, 1, 1};
            double hr[3] = {2, 3, 4}, hi[3] = {5, 6, 7};
            double ir[3] = {1, 1, 1}, ii[3] = {1, 1, 1};
            double jr[3] = {10, 20, 30}, ji[3] = {40, 50, 60};
            DSPDoubleSplitComplex F = {fr, fi}, G = {gr, gi}, H = {hr, hi}, I = {ir, ii}, J = {jr, ji};
            double mfr[3], mfi[3], tfr[3], tfi[3];
            DSPDoubleSplitComplex mine3 = {mfr, mfi}, theirs3 = {tfr, tfi};
            charon_host_vDSP_zvmmaaD(&F, 1, &G, 1, &H, 1, &I, 1, &J, 1, &mine3, 1, 3);
            vDSP_zvmmaaD(&F, 1, &G, 1, &H, 1, &I, 1, &J, 1, &theirs3, 1, 3);
            same_doubles("vDSP_zvmmaaD, the real part", mfr, tfr, 3);
            same_doubles("vDSP_zvmmaaD, the imaginary part", mfi, tfi, 3);
        }
    }

    // the two sums and differences
    {
        const float a[6] = {1, 2, 3, 4, 5, 6}, b[6] = {0.5f, -0.5f, 1.0f, -1.0f, 2.0f, -2.0f};
        float m0[BUFFER_SLOTS], m1[BUFFER_SLOTS], t0[BUFFER_SLOTS], t1[BUFFER_SLOTS];
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            m0[at] = m1[at] = t0[at] = t1[at] = kFill;
        }
        charon_host_vDSP_vaddsub(a, 1, b, 1, m0, 1, m1, 1, 6);
        vDSP_vaddsub(a, 1, b, 1, t0, 1, t1, 1, 6);
        same_floats("vDSP_vaddsub, the sum", m0, t0, BUFFER_SLOTS);
        same_floats("vDSP_vaddsub, the difference", m1, t1, BUFFER_SLOTS);
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            m0[at] = m1[at] = t0[at] = t1[at] = kFill;
        }
        charon_host_vDSP_vaddsub(a, 2, b, 2, m0, 2, m1, 2, 3);
        vDSP_vaddsub(a, 2, b, 2, t0, 2, t1, 2, 3);
        same_floats("vDSP_vaddsub with a stride of two, the sum", m0, t0, 3);
        same_floats("vDSP_vaddsub with a stride of two, the difference", m1, t1, 3);
    }
    {
        const double a[4] = {1, 2, 3, 4}, b[4] = {0.25, -0.25, 0.5, -0.5};
        double m0[BUFFER_SLOTS], m1[BUFFER_SLOTS], t0[BUFFER_SLOTS], t1[BUFFER_SLOTS];
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            m0[at] = m1[at] = t0[at] = t1[at] = kFillD;
        }
        charon_host_vDSP_vaddsubD(a, 1, b, 1, m0, 1, m1, 1, 4);
        vDSP_vaddsubD(a, 1, b, 1, t0, 1, t1, 1, 4);
        same_doubles("vDSP_vaddsubD, the sum", m0, t0, BUFFER_SLOTS);
        same_doubles("vDSP_vaddsubD, the difference", m1, t1, BUFFER_SLOTS);
    }

    // the four ramps, each of which leaves the start where the ramp ended
    {
        const double a[5] = {1, 2, 3, 4, 5}, step = 2.0;
        double m[BUFFER_SLOTS], t[BUFFER_SLOTS];
        double m0[BUFFER_SLOTS], m1[BUFFER_SLOTS], t0[BUFFER_SLOTS], t1[BUFFER_SLOTS];
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            m[at] = t[at] = kFillD;
        }
        double my_start = 1.0, their_start = 1.0;
        charon_host_vDSP_vrampmulD(a, 1, &my_start, &step, m, 1, 5);
        vDSP_vrampmulD(a, 1, &their_start, &step, t, 1, 5);
        same_doubles("vDSP_vrampmulD over five values", m, t, BUFFER_SLOTS);
        if (my_start == their_start) {
            report(1, "vDSP_vrampmulD leaves the start at the end of the ramp", "");
        } else {
            snprintf(detail, sizeof detail, "the port leaves %g, the host leaves %g", my_start, their_start);
            report(0, "vDSP_vrampmulD leaves the start at the end of the ramp", detail);
        }
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            m[at] = t[at] = kFillD;
        }
        my_start = their_start = 1.0;
        charon_host_vDSP_vrampmul2D(a, a, 1, &my_start, &step, m0, m1, 1, 5);
        vDSP_vrampmul2D(a, a, 1, &their_start, &step, t0, t1, 1, 5);
        same_doubles("vDSP_vrampmul2D, the first output", m0, t0, 5);
        same_doubles("vDSP_vrampmul2D, the second output", m1, t1, 5);
        // the add forms accumulate into what the caller left, so both start from the same non-zero
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            m[at] = t[at] = kFillD;
        }
        for (int at = 0; at < 5; at++) {
            m[at] = t[at] = a[at] * (1.0 + 2.0 * at);
        }
        my_start = their_start = 1.0;
        charon_host_vDSP_vrampmuladdD(a, 1, &my_start, &step, m, 1, 5);
        vDSP_vrampmuladdD(a, 1, &their_start, &step, t, 1, 5);
        same_doubles("vDSP_vrampmuladdD into what was already there", m, t, BUFFER_SLOTS);
        for (int at = 0; at < 5; at++) {
            m0[at] = t0[at] = a[at];
            m1[at] = t1[at] = 2.0 * a[at];
        }
        my_start = their_start = 1.0;
        charon_host_vDSP_vrampmuladd2D(a, a, 1, &my_start, &step, m0, m1, 1, 5);
        vDSP_vrampmuladd2D(a, a, 1, &their_start, &step, t0, t1, 1, 5);
        same_doubles("vDSP_vrampmuladd2D, the first output", m0, t0, 5);
        same_doubles("vDSP_vrampmuladd2D, the second output", m1, t1, 5);
    }

    // the two sliding window maxima, with the N + WindowLength - 1 elements the header requires
    {
        const float a[9] = {3, 1, 4, 1, 5, 9, 2, 8, 6};
        const double ad[9] = {3, 1, 4, 1, 5, 9, 2, 8, 6};
        const vDSP_Length windows[3] = {1, 3, 4};
        for (int which = 0; which < 3; which++) {
            vDSP_Length count = 9 - windows[which] + 1;
            float mine[9], theirs[9];
            for (int at = 0; at < 9; at++) {
                mine[at] = theirs[at] = kFill;
            }
            charon_host_vDSP_vswmax(a, 1, mine, 1, count, windows[which]);
            vDSP_vswmax(a, 1, theirs, 1, count, windows[which]);
            char label[80];
            snprintf(label, sizeof label, "vDSP_vswmax with a window of %ld, N = %ld", (long)windows[which],
                     (long)count);
            same_floats(label, mine, theirs, 9);
            double m9[9], t9[9];
            for (int at = 0; at < 9; at++) {
                m9[at] = t9[at] = kFillD;
            }
            charon_host_vDSP_vswmaxD(ad, 1, m9, 1, count, windows[which]);
            vDSP_vswmaxD(ad, 1, t9, 1, count, windows[which]);
            snprintf(label, sizeof label, "vDSP_vswmaxD with a window of %ld, N = %ld", (long)windows[which],
                     (long)count);
            same_doubles(label, m9, t9, 9);
        }
        // a stride on the input and on the output
        {
            const float wide[18] = {3, -1, 1, -1, 4, -1, 1, -1, 5, -1, 9, -1, 2, -1, 8, -1, 6, -1};
            float mine[9], theirs[9];
            for (int at = 0; at < 9; at++) {
                mine[at] = theirs[at] = kFill;
            }
            charon_host_vDSP_vswmax(wide, 2, mine, 1, 4, 3);
            vDSP_vswmax(wide, 2, theirs, 1, 4, 3);
            same_floats("vDSP_vswmax with a stride of two on the input", mine, theirs, 9);
        }
    }

    // The scaled multiply-multiply-add, the two dot products and the distance.
    //
    // B and D are both scalars, and a differential can only see that with an input that tells the two
    // readings apart: with a constant D, D[0] and D[n] are the same number and any reading of D passes.
    // So B and D are both non-uniform here, and a second case passes the one element each that the header
    // tells a caller to pass - which is the case a vector reading also gets wrong, and gets wrong by
    // reading past the end of the caller's own buffer.
    {
        const double a[4] = {1, 2, 3, 4}, c[4] = {10, 20, 30, 40};
        const double d[4] = {0.5, 99, 99, 99};
        const double b[4] = {2.0, 7.0, 7.0, 7.0};
        double me[BUFFER_SLOTS], te[BUFFER_SLOTS];
        for (int at = 0; at < BUFFER_SLOTS; at++) {
            me[at] = te[at] = kFillD;
        }
        charon_host_vDSP_vsmsmaD(a, 1, b, c, 1, d, me, 1, 4);
        vDSP_vsmsmaD(a, 1, b, c, 1, d, te, 1, 4);
        same_doubles("vDSP_vsmsmaD with a D that is not constant", me, te, BUFFER_SLOTS);
        {
            // The one element B and D the header asks for, each in a buffer with a guard element on
            // each side. Reading D[1..3] as a vector then takes whatever the guard holds, which is
            // visible in the compared output rather than in the guard itself - a read does not change
            // what it reads - and the guard elements are checked after the call for the other half of
            // it, which is that neither side writes to an operand it was given.
            double lone_b[4], lone_d[4];
            for (int at = 0; at < 4; at++) {
                lone_b[at] = lone_d[at] = kFillD;
            }
            lone_b[1] = 2.0;
            lone_d[1] = 0.5;
            for (int at = 0; at < BUFFER_SLOTS; at++) {
                me[at] = te[at] = kFillD;
            }
            charon_host_vDSP_vsmsmaD(a, 1, lone_b + 1, c, 1, lone_d + 1, me, 1, 4);
            vDSP_vsmsmaD(a, 1, lone_b + 1, c, 1, lone_d + 1, te, 1, 4);
            same_doubles("vDSP_vsmsmaD with the one element B and D the header asks for", me, te, BUFFER_SLOTS);
            int guards_agree = lone_b[0] == kFillD && lone_b[2] == kFillD && lone_d[0] == kFillD && lone_d[2] == kFillD;
            snprintf(detail, sizeof detail, "the guard elements are %g %g %g %g, the fill is %g", lone_b[0], lone_b[2],
                     lone_d[0], lone_d[2], kFillD);
            report(guards_agree, "vDSP_vsmsmaD writes to neither B nor D, and the guards are still the fill",
                   detail);
        }
        {
            const double a0[4] = {1, 2, 3, 4}, a1[4] = {1, 0, 0, 1}, bb[4] = {5, 6, 7, 8};
            double my0 = 0.0, my1 = 0.0, their0 = 0.0, their1 = 0.0;
            charon_host_vDSP_dotpr2D(a0, 1, a1, 1, bb, 1, &my0, &my1, 4);
            vDSP_dotpr2D(a0, 1, a1, 1, bb, 1, &their0, &their1, 4);
            same_doubles("vDSP_dotpr2D, the first product", &my0, &their0, 1);
            same_doubles("vDSP_dotpr2D, the second product", &my1, &their1, 1);
        }
        {
            const double aa[3] = {1, 2, 3}, bb[3] = {4, 6, 3};
            double mine = 0.0, theirs = 0.0;
            charon_host_vDSP_distancesqD(aa, 1, bb, 1, &mine, 3);
            vDSP_distancesqD(aa, 1, bb, 1, &theirs, 3);
            same_doubles("vDSP_distancesqD of [1,2,3] and [4,6,3]", &mine, &theirs, 1);
        }
    }

    printf("%d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
