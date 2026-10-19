// A command-line test of the twenty-two elementwise vDSP entry points of Accelerate on the device: every
// one of them called, and every answer compared with the one the host's own vDSP gives, which
// host/vdsp measures in the same order these cases run in.
//
// The values below are the host's, copied from tests/backports/host/vdsp; the operations that are exact in
// the scalar type they use are compared exactly, and only the two sums over a vector — the ramp, the dot
// products and the distance — are compared to a tolerance, because two summations of the same terms in a
// different order differ in the last place a double has.
//
// It needs the package built with accelerate = true.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Whether a name in this process comes from the backports' own library and not from the release.
static BOOL fromBackports(const char *name)
{
    void *symbol = dlsym(RTLD_DEFAULT, name);
    Dl_info info;
    if (!symbol || dladdr(symbol, &info) == 0 || !info.dli_fname)
        return NO;
    return [[NSString stringWithUTF8String:info.dli_fname].lastPathComponent
        isEqualToString:@"libAccelerateBackports.dylib"];
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

// What each side wrote, and whether it is what the host wrote: a fill value no case is expected to write
// makes an element neither side touched a difference.
static const float kFill = -987654.0f;
static const double kFillD = -987654.0;
static const int kFillI = -987654;

static BOOL sameFloats(const float *mine, const float *theirs, int count)
{
    for (int at = 0; at < count; at++)
        if (mine[at] != theirs[at])
            return NO;
    return YES;
}

static BOOL sameDoubles(const double *mine, const double *theirs, int count)
{
    for (int at = 0; at < count; at++) {
        double difference = fabs(mine[at] - theirs[at]);
        double scale = fabs(theirs[at]) > 1.0 ? fabs(theirs[at]) : 1.0;
        if (!(difference <= 1e-12 * scale))
            return NO;
    }
    return YES;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));

        CHECK(fromBackports("vDSP_vflt24"), "vDSP_vflt24 comes from the backports");
        CHECK(fromBackports("vDSP_zvma"), "vDSP_zvma comes from the backports");
        CHECK(fromBackports("vDSP_vswmax"), "vDSP_vswmax comes from the backports");
        CHECK(fromBackports("vDSP_dotpr2D"), "vDSP_dotpr2D comes from the backports");

        // the 24-bit readers
        {
            const int signed_values[6] = {0, 1, -1, 8388607, -8388608, -12345};
            const unsigned unsigned_values[6] = {0, 1, 8388607, 8388608, 16777215, 12345};
            vDSP_int24 signed24[6];
            vDSP_uint24 unsigned24[6];
            for (int at = 0; at < 6; at++) {
                signed24[at] = charon_int24(signed_values[at]);
                unsigned24[at] = charon_uint24(unsigned_values[at]);
            }
            float out[8];
            for (int at = 0; at < 8; at++)
                out[at] = kFill;
            vDSP_vflt24(signed24, 1, out, 1, 6);
            CHECK(out[0] == 0.0f && out[1] == 1.0f && out[2] == -1.0f && out[3] == 8388607.0f && out[4] == -8388608.0f &&
                      out[5] == -12345.0f,
                  "vDSP_vflt24 of 0, 1, -1, 8388607, -8388608 and -12345");
            for (int at = 0; at < 8; at++)
                out[at] = kFill;
            vDSP_vfltu24(unsigned24, 1, out, 1, 6);
            CHECK(out[0] == 0.0f && out[3] == 8388607.0f && out[4] == 8388608.0f && out[5] == 16777215.0f,
                  "vDSP_vfltu24 of the same six, unsigned");
            // the scale is a scalar at B[0] and is applied as it stands
            const float scales[4] = {1.0f, 2.0f, -1.0f, 0.0f};
            for (int which = 0; which < 4; which++) {
                float scale[4] = {scales[which], 0.0f, 0.0f, 0.0f};
                for (int at = 0; at < 8; at++)
                    out[at] = kFill;
                vDSP_vfltsm24(signed24, 1, scale, out, 1, 6);
                BOOL right = YES;
                for (int at = 0; at < 6; at++)
                    right = right && out[at] == scales[which] * (float)signed_values[at];
                CHECK(right, "vDSP_vfltsm24 is B[0] times the conversion, with no clamp");
                for (int at = 0; at < 8; at++)
                    out[at] = kFill;
                vDSP_vfltsmu24(unsigned24, 1, scale, out, 1, 6);
                right = YES;
                for (int at = 0; at < 6; at++)
                    right = right && out[at] == scales[which] * (float)unsigned_values[at];
                CHECK(right, "vDSP_vfltsmu24 likewise, and a negative scale is not clamped");
            }
            // the two clamps
            const float inputs[6] = {1.0f, -1.0f, 0.5f, -0.5f, 2.0f / 3.0f, 100.0f};
            const float big[4] = {8388608.0f, 0.0f, 0.0f, 0.0f};
            vDSP_int24 out24[8];
            memset(out24, 0x5a, sizeof out24);
            vDSP_vsmfix24(inputs, 1, big, out24, 1, 6);
            const int want[6] = {8388607, -8388608, 4194304, -4194304, 5592405, 8388607};
            BOOL right = YES;
            for (int at = 0; at < 6; at++)
                right = right && charon_read_int24(out24, at) == want[at];
            CHECK(right, "vDSP_vsmfix24 truncates toward zero and clamps to [-8388608, 8388607]");
            vDSP_uint24 outu24[8];
            memset(outu24, 0x5a, sizeof outu24);
            vDSP_vsmfixu24(inputs, 1, big, outu24, 1, 6);
            const unsigned wantu[6] = {8388608, 0, 4194304, 0, 5592405, 16777215};
            right = YES;
            for (int at = 0; at < 6; at++)
                right = right && charon_read_uint24(outu24, at) == wantu[at];
            CHECK(right, "vDSP_vsmfixu24 clamps to [0, 16777215], and a negative result becomes 0");
        }

        // the integer add
        {
            const int a[6] = {1, -2, 3, -4, 5, -6}, b[6] = {10, 20, -30, 40, -50, 60}, want[6] = {11, 18, -27, 36, -45, 54};
            int out[8];
            for (int at = 0; at < 8; at++)
                out[at] = kFillI;
            vDSP_vaddi(a, 1, b, 1, out, 1, 6);
            BOOL right = YES;
            for (int at = 0; at < 6; at++)
                right = right && out[at] == want[at];
            CHECK(right, "vDSP_vaddi over six values");
            for (int at = 0; at < 8; at++)
                out[at] = kFillI;
            vDSP_vaddi(a, 2, b, 1, out, 1, 3);
            CHECK(out[0] == 11 && out[1] == 23 && out[2] == -25, "vDSP_vaddi with a stride of two on the first");
        }

        // the split-complex products: the accumulator is the last operand
        {
            float ar[4] = {1, 2, 3, 4}, ai[4] = {5, 6, 7, 8};
            float br[4] = {2, 0, -1, 3}, bi[4] = {0, 1, 1, 0};
            float cr[4] = {1, 1, 0, -1}, ci[4] = {1, -1, 1, 1};
            float dr[4], di[4];
            DSPSplitComplex A = {ar, ai}, B = {br, bi}, C = {cr, ci}, D = {dr, di};
            vDSP_zvma(&A, 1, &B, 1, &C, 1, &D, 1, 4);
            CHECK(dr[0] == 3.0f && di[0] == 11.0f && dr[1] == -5.0f && di[1] == 1.0f,
                  "vDSP_zvma is A * B + C, in that order");
            float er[3] = {1, 2, 3}, ei[3] = {4, 5, 6};
            float fr[3] = {1, 0, 1}, fi[3] = {0, 1, 1};
            float gr[3] = {2, 3, 4}, gi[3] = {5, 6, 7};
            float hr[3] = {1, 1, 1}, hi[3] = {1, 1, 1};
            float ir[3] = {10, 20, 30}, ii[3] = {40, 50, 60};
            float jr[3], ji[3];
            DSPSplitComplex E = {er, ei}, F = {fr, fi}, G = {gr, gi}, H = {hr, hi}, I = {ir, ii}, J = {jr, ji};
            vDSP_zvmmaa(&E, 1, &F, 1, &G, 1, &H, 1, &I, 1, &J, 1, 3);
            CHECK(jr[0] == 8.0f && ji[0] == 51.0f && jr[1] == 12.0f && ji[1] == 61.0f,
                  "vDSP_zvmmaa is A * B + C * D + E, in that order");
            // the same two in double, from the same body
            double dar[4] = {1, 2, 3, 4}, dai[4] = {5, 6, 7, 8};
            double dbr[4] = {2, 0, -1, 3}, dbi[4] = {0, 1, 1, 0};
            double dcr[4] = {1, 1, 0, -1}, dci[4] = {1, -1, 1, 1};
            double ddr[4], ddi[4];
            DSPDoubleSplitComplex DA = {dar, dai}, DB = {dbr, dbi}, DC = {dcr, dci}, DD = {ddr, ddi};
            vDSP_zvmaD(&DA, 1, &DB, 1, &DC, 1, &DD, 1, 4);
            CHECK(ddr[0] == 3.0 && ddi[0] == 11.0, "vDSP_zvmaD answers the same as vDSP_zvma");
        }

        // the two sums and differences: the second output is I1 - I0
        {
            const float a[6] = {1, 2, 3, 4, 5, 6}, b[6] = {0.5f, -0.5f, 1.0f, -1.0f, 2.0f, -2.0f};
            float o0[8], o1[8];
            for (int at = 0; at < 8; at++) {
                o0[at] = o1[at] = kFill;
            }
            vDSP_vaddsub(a, 1, b, 1, o0, 1, o1, 1, 6);
            const float want0[6] = {1.5f, 1.5f, 4.0f, 3.0f, 7.0f, 4.0f};
            const float want1[6] = {-0.5f, -2.5f, -2.0f, -5.0f, -3.0f, -8.0f};
            CHECK(sameFloats(o0, want0, 6), "vDSP_vaddsub's first output is I0 + I1");
            CHECK(sameFloats(o1, want1, 6), "vDSP_vaddsub's second output is I1 - I0, not I0 - I1");
            const double ad[4] = {1, 2, 3, 4}, bd[4] = {0.25, -0.25, 0.5, -0.5};
            double d0[4], d1[4];
            vDSP_vaddsubD(ad, 1, bd, 1, d0, 1, d1, 1, 4);
            const double wantd0[4] = {1.25, 1.75, 3.5, 3.5}, wantd1[4] = {-0.75, -2.25, -2.5, -4.5};
            CHECK(sameDoubles(d0, wantd0, 4), "vDSP_vaddsubD's sum");
            CHECK(sameDoubles(d1, wantd1, 4), "vDSP_vaddsubD's difference is the second operand first, too");
        }

        // the ramps, and the start each leaves behind
        {
            const double a[5] = {1, 2, 3, 4, 5}, step = 2.0;
            const double want[5] = {1, 6, 15, 28, 45};
            double out[5], start = 1.0;
            vDSP_vrampmulD(a, 1, &start, &step, out, 1, 5);
            CHECK(sameDoubles(out, want, 5), "vDSP_vrampmulD is I[n] * (start + n * step)");
            CHECK(start == 11.0, "and it leaves the start at start + N * step, not at the last value it used");
            double first[5], second[5];
            start = 1.0;
            vDSP_vrampmul2D(a, a, 1, &start, &step, first, second, 1, 5);
            const double want2[5] = {10, 15, 24, 37, 54};
            CHECK(sameDoubles(first, want2, 5) && sameDoubles(second, want2, 5), "vDSP_vrampmul2D walks one ramp across two inputs");
            for (int at = 0; at < 5; at++)
                out[at] = want[at];
            start = 1.0;
            vDSP_vrampmuladdD(a, 1, &start, &step, out, 1, 5);
            const double wantadd[5] = {2, 12, 30, 56, 90};
            CHECK(sameDoubles(out, wantadd, 5), "vDSP_vrampmuladdD accumulates into what the caller left");
            for (int at = 0; at < 5; at++) {
                first[at] = a[at];
                second[at] = 2.0 * a[at];
            }
            start = 1.0;
            vDSP_vrampmuladd2D(a, a, 1, &start, &step, first, second, 1, 5);
            CHECK(sameDoubles(first, wantadd, 5) && sameDoubles(second, wantadd, 5),
                  "vDSP_vrampmuladd2D accumulates into both");
        }

        // the sliding window maximum, over the N + WindowLength - 1 elements the header requires
        {
            const float a[9] = {3, 1, 4, 1, 5, 9, 2, 8, 6};
            float out[9];
            for (int at = 0; at < 9; at++)
                out[at] = kFill;
            vDSP_vswmax(a, 1, out, 1, 7, 3);
            const float want[7] = {4, 4, 5, 9, 9, 9, 9};
            CHECK(sameFloats(out, want, 7),
                  "vDSP_vswmax is the greatest of the elements beginning at n, and a window of 1 is the input itself");
            for (int at = 0; at < 9; at++)
                out[at] = kFill;
            vDSP_vswmax(a, 1, out, 1, 9, 1);
            CHECK(sameFloats(out, a, 9), "vDSP_vswmax with a window of 1 answers the input");
            const double ad[9] = {3, 1, 4, 1, 5, 9, 2, 8, 6};
            double dout[9];
            for (int at = 0; at < 9; at++)
                dout[at] = kFillD;
            vDSP_vswmaxD(ad, 1, dout, 1, 7, 3);
            const double wantd[7] = {4, 4, 5, 9, 9, 9, 9};
            CHECK(sameDoubles(dout, wantd, 7), "vDSP_vswmaxD answers the same as vDSP_vswmax");
        }

        // the scaled multiply-multiply-add, the two dot products and the distance
        {
            // B and D are both scalars, and this case has to be able to tell that from reading them as
            // vectors: with a constant D either reading gives the same answer, so B and D are both
            // non-uniform here and the expected answer is the one both scalars give.
            const double a[4] = {1, 2, 3, 4}, b[4] = {2.0, 7.0, 7.0, 7.0}, c[4] = {10, 20, 30, 40},
                         d[4] = {0.5, 99, 99, 99};
            const double want[4] = {7, 14, 21, 28};
            double out[8];
            for (int at = 0; at < 8; at++)
                out[at] = kFillD;
            vDSP_vsmsmaD(a, 1, b, c, 1, d, out, 1, 4);
            CHECK(sameDoubles(out, want, 4),
                  "vDSP_vsmsmaD is A * B[0] + C * D[0], with B and D each a scalar at its own [0]");
            const double a0[4] = {1, 2, 3, 4}, a1[4] = {1, 0, 0, 1}, bb[4] = {5, 6, 7, 8};
            double c0 = 0.0, c1 = 0.0;
            vDSP_dotpr2D(a0, 1, a1, 1, bb, 1, &c0, &c1, 4);
            CHECK(c0 == 70.0 && c1 == 13.0, "vDSP_dotpr2D is two dot products over one vector");
            const double da[3] = {1, 2, 3}, db[3] = {4, 6, 3};
            double distance = 0.0;
            vDSP_distancesqD(da, 1, db, 1, &distance, 3);
            CHECK(distance == 25.0, "vDSP_distancesqD is the sum of the squares of the differences");
        }

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures == 0 ? 0 : 1;
    }
}
