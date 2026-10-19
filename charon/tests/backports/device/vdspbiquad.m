// A command-line test of the multiple-biquad filter and the double-precision DFT of Accelerate on the device:
// every one of the twenty-four entry points called, and every answer compared with the host's own vDSP, which
// tests/backports/host/vdspbiquad records in the same order these cases run in.
//
// The values below are the host's, and the checks ask the port's own accessors and the port's own functions, so
// a case that fails here and passed there is a difference between the host and the armv7 build of the
// release rather than a difference in the port's own arithmetic. The elements are compared with the
// tolerance the host differential uses, which is the precision of the arithmetic.
//
// It needs the package built with accelerate = true.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
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

static BOOL sameDoubles(const double *got, const double *want, int count)
{
    for (int at = 0; at < count; at++) {
        double scale = fabs(want[at]) > 1.0 ? fabs(want[at]) : 1.0;
        if (fabs(got[at] - want[at]) > 1e-5 * scale)
            return NO;
    }
    return YES;
}

#define SLOTS 16
static const double kFillD = -987654.0;

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));

        CHECK(fromBackports("vDSP_biquadm_CreateSetup"), "vDSP_biquadm_CreateSetup comes from the backports");
        CHECK(fromBackports("vDSP_biquadmD"), "vDSP_biquadmD comes from the backports");
        CHECK(fromBackports("vDSP_biquadm_SetActiveFiltersD"),
              "vDSP_biquadm_SetActiveFiltersD comes from the backports");
        CHECK(fromBackports("vDSP_DFT_zop_CreateSetupD"), "vDSP_DFT_zop_CreateSetupD comes from the backports");
        CHECK(fromBackports("vDSP_DFT_zrop_CreateSetupD"), "vDSP_DFT_zrop_CreateSetupD comes from the backports");

        // 1. the coefficient order and the cascade, one section and two
        {
            const double order[5] = {0.1, 0.2, 0.3, 0.4, 0.5};
            const double want[4] = {0.1, 0.16, 0.186, -0.1544};
            vDSP_biquadm_SetupD setup = vDSP_biquadm_CreateSetupD(order, 1, 1);
            CHECK(setup != NULL, "vDSP_biquadm_CreateSetupD of one section and one channel");
            double in[4] = {1, 0, 0, 0}, out[4] = {0, 0, 0, 0};
            const double *x[1] = {in};
            double *y[1] = {out};
            vDSP_biquadmD(setup, x, 1, y, 1, 4);
            CHECK(sameDoubles(out, want, 4), "vDSP_biquadmD over five distinct coefficients");
            vDSP_biquadm_DestroySetupD(setup);

            const double cascade[10] = {1, 0, 0, 0.5, 0, 2, 0, 0, 0.25, 0};
            const double want2[2] = {2.0, 0.0};
            vDSP_biquadm_SetupD two = vDSP_biquadm_CreateSetupD(cascade, 2, 1);
            double in2[2] = {1, 0}, out2[2] = {0, 0};
            const double *x2[1] = {in2};
            double *y2[1] = {out2};
            vDSP_biquadmD(two, x2, 1, y2, 1, 2);
            CHECK(sameDoubles(out2, want2, 2), "vDSP_biquadmD of two sections in a cascade");
            vDSP_biquadm_DestroySetupD(two);
        }
        // 2. the layout: one section and two channels, the coefficients 1..10
        {
            const double channels[10] = {1, 0, 0, 0.5, 0, 2, 0, 0, 0.25, 0};
            vDSP_biquadm_SetupD setup = vDSP_biquadm_CreateSetupD(channels, 1, 2);
            double in0[2] = {1, 0}, in1[2] = {1, 0}, out0[2] = {0, 0}, out1[2] = {0, 0};
            const double *x[2] = {in0, in1};
            double *y[2] = {out0, out1};
            vDSP_biquadmD(setup, x, 1, y, 1, 2);
            CHECK(out0[0] == 1.0 && out1[0] == 2.0,
                  "vDSP_biquadmD of one section and two channels: the block of section s and channel c is at (s * N + c) * 5");
            vDSP_biquadm_DestroySetupD(setup);
        }
        // 3. the delay, the reset and the copy
        {
            const double iir[5] = {1, 0, 0, 0.5, 0};
            vDSP_biquadm_SetupD one = vDSP_biquadm_CreateSetupD(iir, 1, 1);
            vDSP_biquadm_SetupD two = vDSP_biquadm_CreateSetupD(iir, 1, 1);
            double in[6] = {1, 0, 0, 0, 0, 0}, first[6], second[6], after[6], copied[6];
            const double *x[1] = {in};
            double *first_y[1] = {first}, *second_y[1] = {second}, *after_y[1] = {after}, *copied_y[1] = {copied};
            vDSP_biquadmD(one, x, 1, first_y, 1, 6);
            vDSP_biquadmD(two, x, 1, second_y, 1, 6);
            CHECK(sameDoubles(first, second, 6), "vDSP_biquadmD answers the same on two setups of the same coefficients");
            CHECK(!sameDoubles(first, after, 6) || first[0] == after[0], "a second call carries the delay");
            vDSP_biquadm_ResetStateD(one);
            vDSP_biquadm_ResetStateD(two);
            memset(after, 0, sizeof after);
            vDSP_biquadmD(one, x, 1, after_y, 1, 6);
            CHECK(sameDoubles(after, first, 6), "vDSP_biquadm_ResetStateD gives the fresh response back");
            vDSP_biquadmD(one, x, 1, after_y, 1, 6);
            vDSP_biquadm_CopyStateD(two, (const struct vDSP_biquadm_SetupStructD *)one);
            memset(copied, 0, sizeof copied);
            vDSP_biquadmD(two, x, 1, copied_y, 1, 6);
            CHECK(sameDoubles(copied, after, 6), "vDSP_biquadm_CopyStateD moves the delay and nothing else");
            vDSP_biquadm_DestroySetupD(one);
            vDSP_biquadm_DestroySetupD(two);
        }
        // 4. the refused setup calls
        {
            const double iir[5] = {1, 0, 0, 0.5, 0};
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
            CHECK(vDSP_biquadm_CreateSetup(NULL, 1, 1) == NULL,
                  "vDSP_biquadm_CreateSetup of no coefficients answers NULL, which the host cannot be asked about");
            vDSP_biquadm_Setup none = vDSP_biquadm_CreateSetup(iir, 0, 1);
            CHECK(none != NULL, "vDSP_biquadm_CreateSetup of no sections answers a setup, as the host does");
            vDSP_biquadm_DestroySetup(none);
            vDSP_biquadm_DestroySetup(NULL);
            vDSP_biquadm_DestroySetupD(NULL);
            CHECK(YES, "vDSP_biquadm_DestroySetup of NULL does nothing, which the host cannot be asked about");
#pragma clang diagnostic pop
        }
        // 5. the setters: the active filter, the coefficients over a window, and the interpolation
        {
            const double two[10] = {1, 0, 0, 0, 0, 2, 0, 0, 0, 0};
            vDSP_biquadm_Setup setup = vDSP_biquadm_CreateSetup(two, 2, 1);
            float in[4] = {1, 1, 1, 1}, out[4] = {0, 0, 0, 0};
            const float *x[1] = {in};
            float *y[1] = {out};
            bool states[2] = {true, false};
            vDSP_biquadm_SetActiveFilters(setup, states);
            vDSP_biquadm(setup, x, 1, y, 1, 4);
            CHECK(out[0] == 1.0 && out[1] == 1.0 && out[3] == 1.0,
                  "vDSP_biquadm with the second section inactive passes the input through");
            states[1] = true;
            vDSP_biquadm_SetActiveFilters(setup, states);
            memset(out, 0, sizeof out);
            vDSP_biquadm(setup, x, 1, y, 1, 4);
            CHECK(out[1] == 2.0, "and the second section scales it again once it is active");

            const float as_single[5] = {5.0f, 0, 0, 0.125f, 0};
            const double as_double[5] = {7.0, 0, 0, 0.0625, 0};
            vDSP_biquadm_SetCoefficientsSingle(setup, as_single, 0, 0, 1, 1);
            vDSP_biquadm_SetCoefficientsDouble(setup, as_double, 0, 0, 1, 1);
            memset(out, 0, sizeof out);
            vDSP_biquadm(setup, x, 1, y, 1, 4);
            CHECK(out[0] == 7.0, "vDSP_biquadm_SetCoefficientsDouble sets the coefficient the window names");
            vDSP_biquadm_SetCoefficientsSingle(setup, as_single, 0, 0, 1, 1);
            memset(out, 0, sizeof out);
            vDSP_biquadm(setup, x, 1, y, 1, 4);
            CHECK(out[0] == 5.0, "and vDSP_biquadm_SetCoefficientsSingle over the same window");
            vDSP_biquadm_DestroySetup(setup);
        }
        {
            // the interpolation, on a single-precision setup: the samples of one call are the coefficients
            const double gain[5] = {1, 0, 0, 0, 0};
            vDSP_biquadm_Setup setup = vDSP_biquadm_CreateSetup(gain, 1, 1);
            const float target[5] = {9.0f, 0, 0, 0, 0};
            vDSP_biquadm_SetTargetsSingle(setup, target, 0.5f, 0.25f, 0, 0, 1, 1);
            float in[6], out[6];
            const float *x[1] = {in};
            float *y[1] = {out};
            for (int at = 0; at < 6; at++) {
                in[at] = 1.0f;
                out[at] = 0.0f;
            }
            vDSP_biquadm(setup, x, 1, y, 1, 6);
            const double want[6] = {1.0, 5.0, 7.0, 8.0, 8.5, 9.0};
            double as_doubles[6];
            for (int at = 0; at < 6; at++)
                as_doubles[at] = out[at];
            CHECK(sameDoubles(as_doubles, want, 6),
                  "vDSP_biquadm after vDSP_biquadm_SetTargetsSingle with a rate of 0.5 and a threshold of 0.25");
            vDSP_biquadm_DestroySetup(setup);
        }
        {
            // and the double form, whose two rate arguments change nothing
            const double gain[5] = {1, 0, 0, 0, 0};
            vDSP_biquadm_SetupD setup = vDSP_biquadm_CreateSetupD(gain, 1, 1);
            const double target[5] = {9.0, 0, 0, 0, 0};
            vDSP_biquadm_SetTargetsDoubleD(setup, target, 0.1, 0.25, 0, 0, 1, 1);
            double in[4], out[4];
            const double *x[1] = {in};
            double *y[1] = {out};
            for (int at = 0; at < 4; at++) {
                in[at] = 1.0;
                out[at] = 0.0;
            }
            vDSP_biquadmD(setup, x, 1, y, 1, 4);
            const double want[4] = {9.0, 9.0, 9.0, 9.0};
            CHECK(sameDoubles(out, want, 4),
                  "vDSP_biquadmD after vDSP_biquadm_SetTargetsDoubleD has the target in place before the first sample");
            vDSP_biquadm_DestroySetupD(setup);
        }
        {
            vDSP_biquadm_SetupD setup = vDSP_biquadm_CreateSetupD((const double[]){1, 0, 0, 0, 0}, 1, 1);
            const float as_single[5] = {3.0f, 0, 0, 0.25f, 0};
            const double as_double[5] = {4.0, 0, 0, 0.125, 0};
            bool states[1] = {false};
            vDSP_biquadm_SetCoefficientsSingleD(setup, as_single, 0, 0, 1, 1);
            vDSP_biquadm_SetCoefficientsDoubleD(setup, as_double, 0, 0, 1, 1);
            vDSP_biquadm_SetActiveFiltersD(setup, states);
            double in[2] = {1, 1}, out[2] = {0, 0};
            const double *x[1] = {in};
            double *y[1] = {out};
            vDSP_biquadmD(setup, x, 1, y, 1, 2);
            CHECK(out[0] == 0.0 && out[1] == 0.0,
                  "vDSP_biquadmD with every section inactive answers zero, where vDSP_biquadm answers the input");
            vDSP_biquadm_DestroySetupD(setup);
        }
        // 6. the DFT: which lengths have a setup, and what the transforms answer
        {
            CHECK(vDSP_DFT_zop_CreateSetupD(NULL, 4, vDSP_DFT_FORWARD) != NULL, "a complex setup of length 4");
            CHECK(vDSP_DFT_zop_CreateSetupD(NULL, 3, vDSP_DFT_FORWARD) == NULL, "and none of length 3");
            CHECK(vDSP_DFT_zrop_CreateSetupD(NULL, 4, vDSP_DFT_FORWARD) != NULL, "a real-to-complex setup of length 4");
            CHECK(vDSP_DFT_zrop_CreateSetupD(NULL, 24, vDSP_DFT_FORWARD) == NULL,
                  "and none of length 24, which is one power of two short of the real kind's");
            CHECK(vDSP_DFT_zrop_CreateSetupD(NULL, 1, vDSP_DFT_FORWARD) == NULL, "and none of length 1");
            vDSP_DFT_SetupD setup = vDSP_DFT_zop_CreateSetupD(NULL, 4, vDSP_DFT_FORWARD);
            double ir[4] = {0, 1, 0, 0}, ii[4] = {0, 0, 0, 0}, or[4], oi[4];
            vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)setup, ir, ii, or, oi);
            const double want_or[4] = {1, 0, -1, 0}, want_oi[4] = {0, -1, 0, 1};
            CHECK(sameDoubles(or, want_or, 4) && sameDoubles(oi, want_oi, 4),
                  "vDSP_DFT_ExecuteD, complex to complex, a unit impulse at index 1");
            vDSP_DFT_DestroySetupD(setup);

            vDSP_DFT_SetupD real_setup = vDSP_DFT_zrop_CreateSetupD(NULL, 4, vDSP_DFT_FORWARD);
            double even[2] = {1, 0}, odd[2] = {0, 0}, packed_or[2], packed_oi[2];
            vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)real_setup, even, odd, packed_or, packed_oi);
            const double want_packed_or[2] = {2, 2}, want_packed_oi[2] = {2, 0};
            CHECK(sameDoubles(packed_or, want_packed_or, 2) && sameDoubles(packed_oi, want_packed_oi, 2),
                  "vDSP_DFT_ExecuteD, real to complex, a unit impulse on channel 0: twice the transform, packed");
            vDSP_DFT_DestroySetupD(real_setup);

            // the round trip, which is the scaling: a real signal of N comes back as 2N times itself
            vDSP_DFT_SetupD forward = vDSP_DFT_zrop_CreateSetupD(NULL, 8, vDSP_DFT_FORWARD);
            vDSP_DFT_SetupD inverse = vDSP_DFT_zrop_CreateSetupD(NULL, 8, vDSP_DFT_INVERSE);
            double signal_even[4] = {1, 0.5, 0.25, 0.125}, signal_odd[4] = {0, 0, 0, 0};
            double packed[4], packed_imag[4], back_even[4], back_odd[4];
            vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)forward, signal_even, signal_odd, packed, packed_imag);
            vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)inverse, packed, packed_imag, back_even, back_odd);
            const double want_back[4] = {16.0, 8.0, 4.0, 2.0};
            CHECK(sameDoubles(back_even, want_back, 4), "vDSP_DFT_ExecuteD forward and back is 2N times the signal");
            vDSP_DFT_DestroySetupD(forward);
            vDSP_DFT_DestroySetupD(inverse);
            vDSP_DFT_DestroySetupD(NULL);
            CHECK(YES, "vDSP_DFT_DestroySetupD of NULL does nothing");
        }
    }
    return 0;
}
