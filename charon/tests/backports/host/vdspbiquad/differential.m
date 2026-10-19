// The port's biquad and DFT objects held against the host's own vDSP, case by case: the same inputs
// through each, comparing every element either of them wrote.
//
// The port's sources are compiled with every API name they define renamed, so this translation unit can
// hold the port's objects and the host's side by side. The names come from the port's registry, not from a
// list kept here, so a name added to either file is renamed too.
//
// Every case is one the measurement in facts/Accelerate/vDSPBiquad.md and facts/Accelerate/vDSPDFT.md rests
// on, and the inputs are the ones that can tell the readings apart: the coefficients are distinct values so
// their order shows, the channels differ so the layout shows, the targets are far from the coefficients so
// the interpolation shows, and a second call follows every first one so the delay shows.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// The port's twenty-four entry points, through the names this file renames them to.
vDSP_biquadm_Setup charon_host_vDSP_biquadm_CreateSetup(const double *coeffs, vDSP_Length M, vDSP_Length N);
void charon_host_vDSP_biquadm_DestroySetup(vDSP_biquadm_Setup setup);
void charon_host_vDSP_biquadm_ResetState(vDSP_biquadm_Setup setup);
void charon_host_vDSP_biquadm_CopyState(vDSP_biquadm_Setup dest, const struct vDSP_biquadm_SetupStruct *src);
void charon_host_vDSP_biquadm(vDSP_biquadm_Setup setup, const float *__nonnull *__nonnull X, vDSP_Stride IX,
                             float *__nonnull *__nonnull Y, vDSP_Stride IY, vDSP_Length N);
vDSP_biquadm_SetupD charon_host_vDSP_biquadm_CreateSetupD(const double *coeffs, vDSP_Length M, vDSP_Length N);
void charon_host_vDSP_biquadm_DestroySetupD(vDSP_biquadm_SetupD setup);
void charon_host_vDSP_biquadm_ResetStateD(vDSP_biquadm_SetupD setup);
void charon_host_vDSP_biquadm_CopyStateD(vDSP_biquadm_SetupD dest, const struct vDSP_biquadm_SetupStructD *src);
void charon_host_vDSP_biquadmD(vDSP_biquadm_SetupD setup, const double *__nonnull *__nonnull X, vDSP_Stride IX,
                              double *__nonnull *__nonnull Y, vDSP_Stride IY, vDSP_Length N);
void charon_host_vDSP_biquadm_SetActiveFilters(vDSP_biquadm_Setup setup, const bool *filter_states);
void charon_host_vDSP_biquadm_SetCoefficientsSingle(vDSP_biquadm_Setup setup, const float *coeffs, vDSP_Length start_sec,
                                                   vDSP_Length start_chn, vDSP_Length nsec, vDSP_Length nchn);
void charon_host_vDSP_biquadm_SetCoefficientsDouble(vDSP_biquadm_Setup setup, const double *coeffs,
                                                    vDSP_Length start_sec, vDSP_Length start_chn, vDSP_Length nsec,
                                                    vDSP_Length nchn);
void charon_host_vDSP_biquadm_SetTargetsSingle(vDSP_biquadm_Setup setup, const float *targets, float interp_rate,
                                              float interp_threshold, vDSP_Length start_sec, vDSP_Length start_chn,
                                              vDSP_Length nsec, vDSP_Length nchn);
void charon_host_vDSP_biquadm_SetTargetsDouble(vDSP_biquadm_Setup setup, const double *targets, float interp_rate,
                                              float interp_threshold, vDSP_Length start_sec, vDSP_Length start_chn,
                                              vDSP_Length nsec, vDSP_Length nchn);
void charon_host_vDSP_biquadm_SetActiveFiltersD(vDSP_biquadm_SetupD setup, const bool *filter_states);
void charon_host_vDSP_biquadm_SetCoefficientsSingleD(vDSP_biquadm_SetupD setup, const float *coeffs,
                                                    vDSP_Length start_sec, vDSP_Length start_chn, vDSP_Length nsec,
                                                    vDSP_Length nchn);
void charon_host_vDSP_biquadm_SetCoefficientsDoubleD(vDSP_biquadm_SetupD setup, const double *coeffs,
                                                     vDSP_Length start_sec, vDSP_Length start_chn, vDSP_Length nsec,
                                                     vDSP_Length nchn);
void charon_host_vDSP_biquadm_SetTargetsSingleD(vDSP_biquadm_SetupD setup, const float *targets, double interp_rate,
                                               double interp_threshold, vDSP_Length start_sec, vDSP_Length start_chn,
                                               vDSP_Length nsec, vDSP_Length nchn);
void charon_host_vDSP_biquadm_SetTargetsDoubleD(vDSP_biquadm_SetupD setup, const double *targets, double interp_rate,
                                                double interp_threshold, vDSP_Length start_sec,
                                                vDSP_Length start_chn, vDSP_Length nsec, vDSP_Length nchn);
vDSP_DFT_SetupD charon_host_vDSP_DFT_zop_CreateSetupD(vDSP_DFT_SetupD previous, vDSP_Length length,
                                                     vDSP_DFT_Direction direction);
vDSP_DFT_SetupD charon_host_vDSP_DFT_zrop_CreateSetupD(vDSP_DFT_SetupD previous, vDSP_Length length,
                                                      vDSP_DFT_Direction direction);
void charon_host_vDSP_DFT_ExecuteD(const struct vDSP_DFT_SetupStructD *setup, const double *Ir, const double *Ii,
                                   double *Or, double *Oi);
void charon_host_vDSP_DFT_DestroySetupD(vDSP_DFT_SetupD setup);

static int checks;
static int failures;
static char detail[512];

// The tolerance is the tightest the measured worst difference supports, and the measurement is in the facts.
// Tracked over every check in this file the worst relative difference between the port and the host is
// **1.49012e-08**, and all of the checks pass at 1e-6, 1e-7, 3e-8 and 2e-8; the worst one is a *float* biquad
// output, whose own precision is 1.2e-7, so the float half of this file is the part that needs a tolerance at
// all. The DFT half agrees to about 1e-15 and is compared at the same number, which its own arithmetic
// (facts/Accelerate/vDSPDFT.md).
static const double kBiquadTolerance = 2e-8;

static int agrees(double mine, double theirs)
{
    double scale = fabs(theirs) > 1.0 ? fabs(theirs) : 1.0;
    return fabs(mine - theirs) <= kBiquadTolerance * scale;
}

static void report(int passed, const char *name, const char *why)
{
    checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: %s\n", name, why ? why : detail);
    }
    fflush(stdout);
}

// One run of the filter, on both sides at once: the same coefficients into a setup of each, the same
// inputs, and every element of every output compared. The inputs and the outputs are filled with a value
// neither side writes, so an element only one of them wrote is a difference.
#define SLOTS 16
static const float kFill = -987654.0f;

static void filter_case(const char *name, const double *coefficients, vDSP_Length sections, vDSP_Length channels,
                        vDSP_Length length, vDSP_Stride istride, vDSP_Stride ostride, int calls, int double_typed)
{
    float mine_f[2][SLOTS * SLOTS], theirs_f[2][SLOTS * SLOTS];
    double mine_d[2][SLOTS * SLOTS], theirs_d[2][SLOTS * SLOTS];
    vDSP_Length slots = length * (ostride > 0 ? ostride : 1) + 1;
    vDSP_Length channel;
    for (channel = 0; channel < 2; channel++) {
        for (vDSP_Length at = 0; at < SLOTS * SLOTS; at++) {
            mine_f[channel][at] = theirs_f[channel][at] = kFill;
            mine_d[channel][at] = theirs_d[channel][at] = kFill;
        }
    }
    if (double_typed) {
        vDSP_biquadm_SetupD port_setup = charon_host_vDSP_biquadm_CreateSetupD(coefficients, sections, channels);
        vDSP_biquadm_SetupD host_setup = vDSP_biquadm_CreateSetupD(coefficients, sections, channels);
        double input[2][SLOTS * SLOTS];
        const double *x[2];
        double *port_y[2], *host_y[2];
        for (channel = 0; channel < channels; channel++) {
            for (vDSP_Length at = 0; at < length * (istride > 0 ? istride : 1); at++) {
                input[channel][at] = (double)((channel * 7 + at * 3) % 11) / 4.0 - 1.0;
            }
        }
        x[0] = input[0];
        x[1] = input[1];
        port_y[0] = mine_d[0];
        port_y[1] = mine_d[1];
        host_y[0] = theirs_d[0];
        host_y[1] = theirs_d[1];
        for (int call = 0; call < calls; call++) {
            charon_host_vDSP_biquadmD(port_setup, x, istride, port_y, ostride, length);
            vDSP_biquadmD(host_setup, x, istride, host_y, ostride, length);
        }
        // each side frees its own setup with its own destroy, which is the one thing a pair of libraries
        // sharing a symbol table will not do for you
        vDSP_biquadm_DestroySetupD(host_setup);
        charon_host_vDSP_biquadm_DestroySetupD(port_setup);
        for (channel = 0; channel < channels; channel++) {
            for (vDSP_Length at = 0; at < slots && at < SLOTS * SLOTS; at++) {
                if (!agrees(mine_d[channel][at], theirs_d[channel][at])) {
                    snprintf(detail, sizeof detail, "channel %lu element %lu is %.10g, the host says %.10g",
                             (unsigned long)channel, (unsigned long)at, mine_d[channel][at], theirs_d[channel][at]);
                    report(0, name, detail);
                    return;
                }
            }
        }
        report(1, name, "");
        return;
    }
    {
        vDSP_biquadm_Setup port_setup = charon_host_vDSP_biquadm_CreateSetup(coefficients, sections, channels);
        vDSP_biquadm_Setup host_setup = vDSP_biquadm_CreateSetup(coefficients, sections, channels);
        float input[2][SLOTS * SLOTS];
        const float *x[2];
        float *port_y[2], *host_y[2];
        for (channel = 0; channel < channels; channel++) {
            for (vDSP_Length at = 0; at < length * (istride > 0 ? istride : 1); at++) {
                input[channel][at] = (float)(((channel * 7 + at * 3) % 11) / 4.0 - 1.0);
            }
        }
        x[0] = input[0];
        x[1] = input[1];
        port_y[0] = mine_f[0];
        port_y[1] = mine_f[1];
        host_y[0] = theirs_f[0];
        host_y[1] = theirs_f[1];
        for (int call = 0; call < calls; call++) {
            charon_host_vDSP_biquadm(port_setup, x, istride, port_y, ostride, length);
            vDSP_biquadm(host_setup, x, istride, host_y, ostride, length);
        }
        vDSP_biquadm_DestroySetup(host_setup);
        charon_host_vDSP_biquadm_DestroySetup(port_setup);
        for (channel = 0; channel < channels; channel++) {
            for (vDSP_Length at = 0; at < slots && at < SLOTS * SLOTS; at++) {
                if (!agrees(mine_f[channel][at], theirs_f[channel][at])) {
                    snprintf(detail, sizeof detail, "channel %lu element %lu is %.10g, the host says %.10g",
                             (unsigned long)channel, (unsigned long)at, mine_f[channel][at], theirs_f[channel][at]);
                    report(0, name, detail);
                    return;
                }
            }
        }
        report(1, name, "");
    }
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        // 1. the coefficient order and the sign convention, one section, and a cascade of two.
        {
            double order[5] = {0.1, 0.2, 0.3, 0.4, 0.5};
            filter_case("vDSP_biquadm of one section, five distinct coefficients", order, 1, 1, 8, 1, 1, 1, 0);
            double sign[5] = {1, 0, 0, 0.5, 0};
            filter_case("vDSP_biquadm with a positive a1", sign, 1, 1, 8, 1, 1, 1, 0);
            double negative[5] = {1, 0, 0, -0.5, 0};
            filter_case("vDSP_biquadm with a negative a1", negative, 1, 1, 8, 1, 1, 1, 0);
            double cascade[10] = {1, 0, 0, 0.5, 0, 2, 0, 0, 0.25, 0};
            filter_case("vDSP_biquadm of two sections in a cascade", cascade, 2, 1, 8, 1, 1, 1, 0);
        }
        // 2. the layout of the caller's coefficients: section-major, channel-minor.
        {
            double two_channels[10] = {1, 0, 0, 0.5, 0, 2, 0, 0, 0.25, 0};
            filter_case("vDSP_biquadm, one section and two channels", two_channels, 1, 2, 8, 1, 1, 1, 0);
            double two_by_two[20] = {1, 0, 0, 0.5, 0,  2, 0, 0, 0.25, 0,
                                     3, 0, 0, 0.125, 0, 4, 0, 0, 0.0625, 0};
            filter_case("vDSP_biquadm, two sections and two channels", two_by_two, 2, 2, 8, 1, 1, 1, 0);
            filter_case("vDSP_biquadmD, two sections and two channels", two_by_two, 2, 2, 8, 1, 1, 1, 1);
        }
        // 3. the delay: a second call with the same input answers something else, and only on the channel
        //    the impulse was on.
        {
            double iir[5] = {1, 0, 0, 0.5, 0};
            filter_case("vDSP_biquadm twice, the delay live", iir, 1, 1, 8, 1, 1, 2, 0);
            filter_case("vDSP_biquadm four times, the delay live", iir, 1, 1, 8, 1, 1, 4, 0);
            filter_case("vDSP_biquadmD twice, the delay live", iir, 1, 1, 8, 1, 1, 2, 1);
            filter_case("vDSP_biquadm, two channels twice, the delay live", iir, 1, 2, 8, 1, 1, 2, 0);
        }
        // 4. the strides and the length.
        {
            double one[5] = {1, 0.5, 0.25, 0.125, 0.0625};
            filter_case("vDSP_biquadm with a stride of two in and out", one, 1, 1, 6, 2, 2, 1, 0);
            filter_case("vDSP_biquadm with a stride of two in only", one, 1, 1, 6, 2, 1, 1, 0);
            filter_case("vDSP_biquadmD with a stride of two in and out", one, 1, 1, 6, 2, 2, 1, 1);
            filter_case("vDSP_biquadm of no samples at all", one, 1, 1, 0, 1, 1, 1, 0);
            filter_case("vDSP_biquadm of one sample", one, 1, 1, 1, 1, 1, 3, 0);
        }
        // 5. ResetState and CopyState, on both precisions.
        {
            // The state pair, on a setup a side of its own: a second setup is made to copy the first one's
            // delay into, because a copy into itself would be a copy of nothing.
            double iir[5] = {1, 0, 0, 0.5, 0};
            vDSP_biquadm_Setup port_one = charon_host_vDSP_biquadm_CreateSetup(iir, 1, 1);
            vDSP_biquadm_Setup port_two = charon_host_vDSP_biquadm_CreateSetup(iir, 1, 1);
            vDSP_biquadm_Setup host_one = vDSP_biquadm_CreateSetup(iir, 1, 1);
            vDSP_biquadm_Setup host_two = vDSP_biquadm_CreateSetup(iir, 1, 1);
            float mine[SLOTS], theirs[SLOTS], input[SLOTS] = {0};
            const float *x[1] = {input};
            float *my_y[1] = {mine}, *their_y[1] = {theirs};
            input[0] = 1.0f;
            // one call into each of the four, so all four delays hold something
            charon_host_vDSP_biquadm(port_one, x, 1, my_y, 1, 6);
            charon_host_vDSP_biquadm(port_two, x, 1, my_y, 1, 6);
            vDSP_biquadm(host_one, x, 1, their_y, 1, 6);
            vDSP_biquadm(host_two, x, 1, their_y, 1, 6);
            charon_host_vDSP_biquadm_ResetState(port_one);
            vDSP_biquadm_ResetState(host_one);
            memset(mine, 0, sizeof mine);
            memset(theirs, 0, sizeof theirs);
            charon_host_vDSP_biquadm(port_one, x, 1, my_y, 1, 6);
            vDSP_biquadm(host_one, x, 1, their_y, 1, 6);
            {
                int agreed = 1;
                for (int at = 0; at < 6; at++) {
                    if (!agrees(mine[at], theirs[at])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "after ResetState the port says %g %g %g, the host %g %g %g", mine[0],
                         mine[1], mine[2], theirs[0], theirs[1], theirs[2]);
                report(agreed, "vDSP_biquadm after vDSP_biquadm_ResetState", agreed ? "" : detail);
            }
            // and now the copy: the second setup of each side takes the first one's delay, and both then
            // answer with no input at all, which is the delay talking
            charon_host_vDSP_biquadm_CopyState(port_two, (const struct vDSP_biquadm_SetupStruct *)port_one);
            vDSP_biquadm_CopyState(host_two, (const struct vDSP_biquadm_SetupStruct *)host_one);
            memset(mine, 0, sizeof mine);
            memset(theirs, 0, sizeof theirs);
            memset(input, 0, sizeof input);
            charon_host_vDSP_biquadm(port_two, x, 1, my_y, 1, 6);
            vDSP_biquadm(host_two, x, 1, their_y, 1, 6);
            {
                int agreed = 1;
                for (int at = 0; at < 6; at++) {
                    if (!agrees(mine[at], theirs[at])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "the copied delay answers %g %g on the port and %g %g on the host",
                         mine[0], mine[1], theirs[0], theirs[1]);
                report(agreed, "vDSP_biquadm after vDSP_biquadm_CopyState", agreed ? "" : detail);
            }
            charon_host_vDSP_biquadm_DestroySetup(port_one);
            charon_host_vDSP_biquadm_DestroySetup(port_two);
            vDSP_biquadm_DestroySetup(host_one);
            vDSP_biquadm_DestroySetup(host_two);
        }
        {
            // the same two calls in double
            double iir[5] = {1, 0, 0, 0.5, 0};
            vDSP_biquadm_SetupD port_one = charon_host_vDSP_biquadm_CreateSetupD(iir, 1, 1);
            vDSP_biquadm_SetupD port_two = charon_host_vDSP_biquadm_CreateSetupD(iir, 1, 1);
            vDSP_biquadm_SetupD host_one = vDSP_biquadm_CreateSetupD(iir, 1, 1);
            vDSP_biquadm_SetupD host_two = vDSP_biquadm_CreateSetupD(iir, 1, 1);
            double mine[SLOTS], theirs[SLOTS], input[SLOTS] = {0};
            const double *x[1] = {input};
            double *my_y[1] = {mine}, *their_y[1] = {theirs};
            input[0] = 1.0;
            charon_host_vDSP_biquadmD(port_one, x, 1, my_y, 1, 6);
            charon_host_vDSP_biquadmD(port_two, x, 1, my_y, 1, 6);
            vDSP_biquadmD(host_one, x, 1, their_y, 1, 6);
            vDSP_biquadmD(host_two, x, 1, their_y, 1, 6);
            charon_host_vDSP_biquadm_ResetStateD(port_one);
            vDSP_biquadm_ResetStateD(host_one);
            memset(mine, 0, sizeof mine);
            memset(theirs, 0, sizeof theirs);
            charon_host_vDSP_biquadmD(port_one, x, 1, my_y, 1, 6);
            vDSP_biquadmD(host_one, x, 1, their_y, 1, 6);
            {
                int agreed = 1;
                for (int at = 0; at < 6; at++) {
                    if (!agrees(mine[at], theirs[at])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "after ResetStateD the port says %g %g %g, the host %g %g %g", mine[0],
                         mine[1], mine[2], theirs[0], theirs[1], theirs[2]);
                report(agreed, "vDSP_biquadmD after vDSP_biquadm_ResetStateD", agreed ? "" : detail);
            }
            charon_host_vDSP_biquadm_CopyStateD(port_two, (const struct vDSP_biquadm_SetupStructD *)port_one);
            vDSP_biquadm_CopyStateD(host_two, (const struct vDSP_biquadm_SetupStructD *)host_one);
            memset(mine, 0, sizeof mine);
            memset(theirs, 0, sizeof theirs);
            memset(input, 0, sizeof input);
            charon_host_vDSP_biquadmD(port_two, x, 1, my_y, 1, 6);
            vDSP_biquadmD(host_two, x, 1, their_y, 1, 6);
            {
                int agreed = 1;
                for (int at = 0; at < 6; at++) {
                    if (!agrees(mine[at], theirs[at])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "the copied delay answers %g %g on the port and %g %g on the host",
                         mine[0], mine[1], theirs[0], theirs[1]);
                report(agreed, "vDSP_biquadmD after vDSP_biquadm_CopyStateD", agreed ? "" : detail);
            }
            charon_host_vDSP_biquadm_DestroySetupD(port_one);
            charon_host_vDSP_biquadm_DestroySetupD(port_two);
            vDSP_biquadm_DestroySetupD(host_one);
            vDSP_biquadm_DestroySetupD(host_two);
        }
        // 5b. The cascade of a SetTargets walk, which is the case a single-section check cannot see: the
        // first section's distance reaches the threshold a sample before the second's, and the release
        // holds it until the second lands too. These are the review's eleven cases, unchanged - a rate of
        // 0.25, 0.5 and 0.75, a threshold of 0.1 to 0.5, and two targets that never land on a round
        // number - and each is asked of both sides and compared element by element.
        {
            static const struct {
                double a0, t0, a1, t1;
                float rate, threshold;
                const char *what;
            } cases[] = {
                {2, 4, 5, 10, 0.5f, 0.1f, "a cascade at a rate of 0.5 and a threshold of 0.1"},
                {2, 4, 5, 10, 0.5f, 0.2f, "a cascade at a rate of 0.5 and a threshold of 0.2"},
                {2, 4, 5, 10, 0.5f, 0.24f, "a cascade just under the threshold"},
                {2, 4, 5, 10, 0.5f, 0.25f, "a cascade at the threshold itself"},
                {2, 4, 5, 10, 0.5f, 0.26f, "a cascade just over the threshold"},
                {2, 4, 5, 10, 0.5f, 0.3f, "a cascade at a rate of 0.5 and a threshold of 0.3"},
                {2, 4, 5, 10, 0.5f, 0.5f, "a cascade at a threshold above every distance"},
                {2, 4.5, 5, 10, 0.5f, 0.25f, "a cascade whose targets never land on a round number"},
                {2, 4, 5, 11, 0.5f, 0.25f, "a cascade with one target that never lands on one"},
                {2, 4, 5, 10, 0.25f, 0.25f, "a cascade at a rate of 0.25"},
                {2, 4, 5, 10, 0.75f, 0.25f, "a cascade at a rate of 0.75, where neither section lands in eight samples"},
            };
            for (unsigned at = 0; at < sizeof cases / sizeof *cases; at++) {
                double coeffs[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
                float targets[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
                coeffs[0] = cases[at].a0;
                coeffs[5] = cases[at].a1;
                targets[0] = (float)cases[at].t0;
                targets[5] = (float)cases[at].t1;
                vDSP_biquadm_Setup mine = charon_host_vDSP_biquadm_CreateSetup(coeffs, 2, 1);
                vDSP_biquadm_Setup theirs = vDSP_biquadm_CreateSetup(coeffs, 2, 1);
                charon_host_vDSP_biquadm_SetTargetsSingle(mine, targets, cases[at].rate, cases[at].threshold, 0, 0, 2, 1);
                vDSP_biquadm_SetTargetsSingle(theirs, targets, cases[at].rate, cases[at].threshold, 0, 0, 2, 1);
                float mine_out[8] = {0}, their_out[8] = {0}, in[8];
                for (int sample = 0; sample < 8; sample++) {
                    in[sample] = 1.0f;
                }
                const float *x[1] = {in};
                float *my_y[1] = {mine_out}, *their_y[1] = {their_out};
                charon_host_vDSP_biquadm(mine, x, 1, my_y, 1, 8);
                vDSP_biquadm(theirs, x, 1, their_y, 1, 8);
                int agreed = 1;
                for (int sample = 0; sample < 8; sample++) {
                    if (fabs((double)mine_out[sample] - (double)their_out[sample]) > kBiquadTolerance) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "the port answers %g %g %g %g %g %g and the host %g %g %g %g %g %g",
                         (double)mine_out[0], (double)mine_out[1], (double)mine_out[2], (double)mine_out[3],
                         (double)mine_out[4], (double)mine_out[5], (double)their_out[0], (double)their_out[1],
                         (double)their_out[2], (double)their_out[3], (double)their_out[4], (double)their_out[5]);
                report(agreed, cases[at].what, agreed ? "" : detail);
                charon_host_vDSP_biquadm_DestroySetup(mine);
                vDSP_biquadm_DestroySetup(theirs);
            }
        }
        // 6. the refused setup calls. The host cannot be asked about a NULL coefficient array: it reads
        //    through it and stops the process (measured - a NULL reaches a memmove inside the host's own
        //    CreateSetup), so those three are the port's answers alone and the facts file says so. The
        //    shapes with no sections and no channels it can be asked about, and those two agree.
        {
            double iir[5] = {1, 0, 0, 0.5, 0};
            report(charon_host_vDSP_biquadm_CreateSetup(NULL, 1, 1) == NULL,
                   "vDSP_biquadm_CreateSetup of no coefficients answers NULL, which the host cannot be asked about",
                   "");
            report(charon_host_vDSP_biquadm_CreateSetupD(NULL, 1, 1) == NULL,
                   "vDSP_biquadm_CreateSetupD of no coefficients answers NULL, which the host cannot be asked about",
                   "");
            // No sections and no channels are not refusals on either side, and what a call over such a setup
            // does is the answer worth comparing: the input through unchanged, and nothing written at all.
            {
                vDSP_biquadm_Setup port = charon_host_vDSP_biquadm_CreateSetup(iir, 0, 1);
                vDSP_biquadm_Setup host = vDSP_biquadm_CreateSetup(iir, 0, 1);
                float in[4] = {1, 2, 3, 4}, mine[4] = {0, 0, 0, 0}, theirs[4] = {0, 0, 0, 0};
                const float *x[1] = {in};
                float *my_y[1] = {mine}, *their_y[1] = {theirs};
                int agreed = port != NULL && host != NULL;
                charon_host_vDSP_biquadm(port, x, 1, my_y, 1, 4);
                vDSP_biquadm(host, x, 1, their_y, 1, 4);
                for (int at = 0; at < 4; at++) {
                    if (!agrees(mine[at], theirs[at])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "with no sections the port answers %g %g %g %g and the host %g %g %g %g",
                         mine[0], mine[1], mine[2], mine[3], theirs[0], theirs[1], theirs[2], theirs[3]);
                report(agreed, "vDSP_biquadm over a setup of no sections passes the input through", agreed ? "" : detail);
                charon_host_vDSP_biquadm_DestroySetup(port);
                vDSP_biquadm_DestroySetup(host);
            }
            {
                vDSP_biquadm_Setup port = charon_host_vDSP_biquadm_CreateSetup(iir, 1, 0);
                vDSP_biquadm_Setup host = vDSP_biquadm_CreateSetup(iir, 1, 0);
                float in[4] = {1, 2, 3, 4}, mine[4] = {9, 9, 9, 9}, theirs[4] = {9, 9, 9, 9};
                const float *x[1] = {in};
                float *my_y[1] = {mine}, *their_y[1] = {theirs};
                int agreed = port != NULL && host != NULL;
                charon_host_vDSP_biquadm(port, x, 1, my_y, 1, 4);
                vDSP_biquadm(host, x, 1, their_y, 1, 4);
                for (int at = 0; at < 4; at++) {
                    if (mine[at] != 9.0f || theirs[at] != 9.0f) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "with no channels the port leaves %g %g and the host %g %g", mine[0],
                         mine[1], theirs[0], theirs[1]);
                report(agreed, "vDSP_biquadm over a setup of no channels writes nothing", agreed ? "" : detail);
                charon_host_vDSP_biquadm_DestroySetup(port);
                vDSP_biquadm_DestroySetup(host);
            }
            // DestroySetup of nothing: the port takes it and does nothing, and the host cannot be asked
            // because the header does not declare that argument nullable and the host reads through it
            // (measured: a NULL reaches the first load inside the host's own vDSP_biquadm_DestroySetup and
            // stops the process). So this is a difference in care, and it is recorded as one.
            charon_host_vDSP_biquadm_DestroySetup(NULL);
            charon_host_vDSP_biquadm_DestroySetupD(NULL);
            report(1, "vDSP_biquadm_DestroySetup of NULL does nothing, which the host cannot be asked about", "");
            // and a setup of a real shape is destroyed without a crash on either side
            {
                vDSP_biquadm_Setup port = charon_host_vDSP_biquadm_CreateSetup(iir, 1, 1);
                vDSP_biquadm_Setup host = vDSP_biquadm_CreateSetup(iir, 1, 1);
                charon_host_vDSP_biquadm_DestroySetup(port);
                vDSP_biquadm_DestroySetup(host);
                report(port != NULL && host != NULL, "a setup of one section and one channel is made and freed by both",
                       "");
            }
        }
        // 7. SetActiveFilters, SetCoefficients and SetTargets, each through a filter case so the answer the
        //    port gives is compared element by element and not only in a setup's own fields.
        {
            double two[10] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0};
            vDSP_biquadm_Setup one = charon_host_vDSP_biquadm_CreateSetup(two, 2, 1);
            vDSP_biquadm_Setup two_setup = vDSP_biquadm_CreateSetup(two, 2, 1);
            bool states[2] = {true, false};
            charon_host_vDSP_biquadm_SetActiveFilters(one, states);
            vDSP_biquadm_SetActiveFilters(two_setup, states);
            {
                float mine[SLOTS], theirs[SLOTS], input[SLOTS];
                const float *x[1] = {input};
                float *my_y[1] = {mine}, *their_y[1] = {theirs};
                int agreed = 1;
                for (int at = 0; at < 8; at++) {
                    input[at] = 1.0f;
                }
                memset(mine, 0, sizeof mine);
                memset(theirs, 0, sizeof theirs);
                charon_host_vDSP_biquadm(one, x, 1, my_y, 1, 8);
                vDSP_biquadm(two_setup, x, 1, their_y, 1, 8);
                for (int at = 0; at < 8; at++) {
                    if (!agrees(mine[at], theirs[at])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "with the second section inactive the port says %g, the host %g",
                         mine[1], theirs[1]);
                report(agreed, "vDSP_biquadm with the second section inactive", agreed ? "" : detail);
                // and active again, with whatever delay the inactive run left
                states[1] = true;
                charon_host_vDSP_biquadm_SetActiveFilters(one, states);
                vDSP_biquadm_SetActiveFilters(two_setup, states);
                memset(mine, 0, sizeof mine);
                memset(theirs, 0, sizeof theirs);
                charon_host_vDSP_biquadm(one, x, 1, my_y, 1, 8);
                vDSP_biquadm(two_setup, x, 1, their_y, 1, 8);
                agreed = 1;
                for (int at = 0; at < 8; at++) {
                    if (!agrees(mine[at], theirs[at])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "with it active again the port says %g, the host %g", mine[1],
                         theirs[1]);
                report(agreed, "vDSP_biquadm with the second section active again", agreed ? "" : detail);
            }
            // SetCoefficients over a window: one section, two channels, and the (0, 1, 1, 1) window.
            {
                double channels[10] = {1, 0, 0, 0.5, 0, 2, 0, 0, 0.25, 0};
                vDSP_biquadm_Setup a = charon_host_vDSP_biquadm_CreateSetup(channels, 1, 2);
                vDSP_biquadm_Setup b = vDSP_biquadm_CreateSetup(channels, 1, 2);
                float as_single[5] = {5.0f, 0, 0, 0.125f, 0};
                double as_double[5] = {7.0, 0, 0, 0.0625, 0};
                float mine[2][SLOTS], theirs[2][SLOTS], input[2][SLOTS];
                const float *x[2] = {input[0], input[1]};
                float *my_y[2] = {mine[0], mine[1]};
                float *their_y[2] = {theirs[0], theirs[1]};
                int agreed = 1;
                charon_host_vDSP_biquadm_SetCoefficientsSingle(a, as_single, 0, 1, 1, 1);
                vDSP_biquadm_SetCoefficientsSingle(b, as_single, 0, 1, 1, 1);
                charon_host_vDSP_biquadm_SetCoefficientsDouble(a, as_double, 0, 0, 1, 1);
                vDSP_biquadm_SetCoefficientsDouble(b, as_double, 0, 0, 1, 1);
                for (int channel = 0; channel < 2; channel++) {
                    for (int at = 0; at < 6; at++) {
                        input[channel][at] = 1.0f;
                        mine[channel][at] = theirs[channel][at] = 0.0f;
                    }
                }
                charon_host_vDSP_biquadm(a, x, 1, my_y, 1, 6);
                vDSP_biquadm(b, x, 1, their_y, 1, 6);
                for (int channel = 0; channel < 2; channel++) {
                    for (int at = 0; at < 6; at++) {
                        if (!agrees(mine[channel][at], theirs[channel][at])) {
                            agreed = 0;
                            snprintf(detail, sizeof detail, "channel %d element %d is %.10g, the host says %.10g",
                                     channel, at, mine[channel][at], theirs[channel][at]);
                        }
                    }
                }
                if (agreed) {
                    snprintf(detail, sizeof detail, "channel 0 answers %g and channel 1 %g on both sides", mine[0][0],
                             mine[1][0]);
                }
                report(agreed, "vDSP_biquadm_SetCoefficientsSingle and Double over a channel window",
                       agreed ? "" : detail);
                charon_host_vDSP_biquadm_DestroySetup(a);
                vDSP_biquadm_DestroySetup(b);

        // A window that names channels the setup does not have. The header forbids it; the release answers
        // it anyway, and what it answers is that the cells the window does cover change and the rest of the
        // setup is left alone (the review measured a two-section four-channel setup with a (2, 2) window at
        // (1, 2): the host answers 0 for the channels the window names and does not crash, where the port
        // answered 2 4 6 8 and 3 6 9 12 having written into cells 10 and 11 of an eight-cell block).
        // CharonBiquadCellOf answers NULL for a channel the setup has not and the setters write nothing for
        // one, which is the same answer without writing past the block.
        //
        // **The host cannot be asked about this shape**: with a two-by-two setup and a (1, 4) window at
        // (0, 2) it answers the setter and then stops the process inside the next vDSP_biquadm, so the case
        // below asserts the port's own answer - the one the review's measurement gives - rather than
        // comparing against a host that cannot be asked. It has teeth without AddressSanitizer, which the
        // armv7 bands do not have, because the window is placed so that an unclamped index lands on a cell the
        // setup *does* have: a channel past the setup's own count at a section that exists indexes the next
        // section's first cells, and those two are read back through the channels that own them. With the guard
        // the second section keeps what CreateSetup gave it and the answers are 70 and 160; without it the
        // second section takes the window's last two blocks and the answers are 63 and 80.
        {
            double coeffs[5 * 2 * 2];
            double values[5 * 1 * 4];
            memset(coeffs, 0, sizeof coeffs);
            // section 0 over channels 0 and 1 is a gain of 1 and 2, section 1 over the same channels 10 and 20,
            // so a channel's answer is the product of its two b0s and every cell is distinct
            coeffs[0] = 1.0;
            coeffs[5] = 2.0;
            coeffs[10] = 10.0;
            coeffs[15] = 20.0;
            for (int at = 0; at < 5 * 1 * 4; at++) {
                values[at] = 7.0 + (double)at;    // four distinct blocks, of which the last two name no channel
            }
            vDSP_biquadm_Setup setup = charon_host_vDSP_biquadm_CreateSetup(coeffs, 2, 2);
            charon_host_vDSP_biquadm_SetCoefficientsDouble(setup, values, 0, 1, 1, 4);
            {
                // A setup of two channels is called with two pointers, one per channel, which is the shape
                // every case here uses.
                float in[2] = {1.0f, 1.0f};
                float out[2] = {0.0f, 0.0f};
                const float *x[2] = {&in[0], &in[1]};
                float *y[2] = {&out[0], &out[1]};
                charon_host_vDSP_biquadm(setup, x, 1, y, 1, 1);
                int agreed = fabs((double)out[0] - 10.0) <= kBiquadTolerance &&
                             fabs((double)out[1] - 140.0) <= kBiquadTolerance;
                snprintf(detail, sizeof detail,
                         "channel 0 answers %.10g and channel 1 %.10g, where the window's first block (7) reaches the "
                         "one cell it covers and the three after it reach none, so the two cells of the second "
                         "section stay at 10 and 20", (double)out[0], (double)out[1]);
                report(agreed, "vDSP_biquadm_SetCoefficients over a window past the setup's own channels: the covered "
                               "cells change and the rest are left alone",
                       agreed ? "" : detail);
            }
            charon_host_vDSP_biquadm_DestroySetup(setup);
        }
            }
            // SetTargets on a float setup: the interpolation, with the parameters the facts name.
            {
                static const struct {
                    double rate;
                    double threshold;
                    const char *what;
                } cases[] = {
                    {0.5, 0.25, "a rate of 0.5 and a threshold of 0.25"},
                    {0.1, 0.25, "a rate of 0.1 and a threshold of 0.25"},
                    {0.9, 0.25, "a rate of 0.9 and a threshold of 0.25"},
                    {0.5, 0.0, "a rate of 0.5 and a threshold of 0"},
                    {0.5, 100.0, "a rate of 0.5 and a threshold above the distance"},
                };
                for (unsigned at = 0; at < sizeof cases / sizeof *cases; at++) {
                    vDSP_biquadm_Setup a = charon_host_vDSP_biquadm_CreateSetup(two, 1, 1);
                    vDSP_biquadm_Setup b = vDSP_biquadm_CreateSetup(two, 1, 1);
                    float targets[5] = {9.0f, 0, 0, 0, 0};
                    float mine[SLOTS], theirs[SLOTS], input[SLOTS];
                    const float *x[1] = {input};
                    float *my_y[1] = {mine}, *their_y[1] = {theirs};
                    char label[128];
                    int agreed = 1;
                    charon_host_vDSP_biquadm_SetTargetsSingle(a, targets, (float)cases[at].rate,
                                                               (float)cases[at].threshold, 0, 0, 1, 1);
                    vDSP_biquadm_SetTargetsSingle(b, targets, (float)cases[at].rate, (float)cases[at].threshold, 0, 0,
                                                  1, 1);
                    for (int sample = 0; sample < 8; sample++) {
                        input[sample] = 1.0f;
                        mine[sample] = theirs[sample] = 0.0f;
                    }
                    charon_host_vDSP_biquadm(a, x, 1, my_y, 1, 8);
                    vDSP_biquadm(b, x, 1, their_y, 1, 8);
                    for (int sample = 0; sample < 8; sample++) {
                        if (!agrees(mine[sample], theirs[sample])) {
                            agreed = 0;
                        }
                    }
                    snprintf(detail, sizeof detail,
                             "the samples answer %g %g %g %g %g %g on the port and %g %g %g %g %g %g on the host",
                             mine[0], mine[1], mine[2], mine[3], mine[4], mine[5], theirs[0], theirs[1], theirs[2],
                             theirs[3], theirs[4], theirs[5]);
                    snprintf(label, sizeof label, "vDSP_biquadm after vDSP_biquadm_SetTargetsSingle with %s",
                             cases[at].what);
                    report(agreed, label, agreed ? "" : detail);
                    charon_host_vDSP_biquadm_DestroySetup(a);
                    vDSP_biquadm_DestroySetup(b);
                }
            }
            charon_host_vDSP_biquadm_DestroySetup(one);
            vDSP_biquadm_DestroySetup(two_setup);
        }
        // 8. the same three setters on a double setup, where the targets are in place at once.
        {
            double one_section[5] = {1, 0, 0, 0, 0};
            static const struct {
                double rate;
                double threshold;
                const char *what;
            } cases[] = {
                {0.5, 0.25, "a rate of 0.5 and a threshold of 0.25"},
                {0.1, 0.25, "a rate of 0.1 and a threshold of 0.25"},
                {0.5, 100.0, "a rate of 0.5 and a threshold above the distance"},
            };
            for (unsigned at = 0; at < sizeof cases / sizeof *cases; at++) {
                vDSP_biquadm_SetupD a = charon_host_vDSP_biquadm_CreateSetupD(one_section, 1, 1);
                vDSP_biquadm_SetupD b = vDSP_biquadm_CreateSetupD(one_section, 1, 1);
                double as_double[5] = {9.0, 0, 0, 0, 0};
                float as_single[5] = {11.0f, 0, 0, 0, 0};
                double mine[SLOTS], theirs[SLOTS], input[SLOTS];
                const double *x[1] = {input};
                double *my_y[1] = {mine}, *their_y[1] = {theirs};
                char label[128];
                int agreed = 1;
                charon_host_vDSP_biquadm_SetTargetsDoubleD(a, as_double, cases[at].rate, cases[at].threshold, 0, 0, 1, 1);
                vDSP_biquadm_SetTargetsDoubleD(b, as_double, cases[at].rate, cases[at].threshold, 0, 0, 1, 1);
                charon_host_vDSP_biquadm_SetTargetsSingleD(a, as_single, cases[at].rate, cases[at].threshold, 0, 0, 1, 1);
                vDSP_biquadm_SetTargetsSingleD(b, as_single, cases[at].rate, cases[at].threshold, 0, 0, 1, 1);
                for (int sample = 0; sample < 8; sample++) {
                    input[sample] = 1.0;
                    mine[sample] = theirs[sample] = 0.0;
                }
                charon_host_vDSP_biquadmD(a, x, 1, my_y, 1, 8);
                vDSP_biquadmD(b, x, 1, their_y, 1, 8);
                for (int sample = 0; sample < 8; sample++) {
                    if (!agrees(mine[sample], theirs[sample])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail,
                         "the samples answer %g %g %g %g %g %g on the port and %g %g %g %g %g %g on the host",
                         mine[0], mine[1], mine[2], mine[3], mine[4], mine[5], theirs[0], theirs[1], theirs[2],
                         theirs[3], theirs[4], theirs[5]);
                snprintf(label, sizeof label,
                         "vDSP_biquadmD after the two 16.0 target setters with %s - the last one wins",
                         cases[at].what);
                report(agreed, label, agreed ? "" : detail);
                charon_host_vDSP_biquadm_DestroySetupD(a);
                vDSP_biquadm_DestroySetupD(b);
            }
            // SetCoefficients and SetActiveFilters on a double setup
            {
                vDSP_biquadm_SetupD a = charon_host_vDSP_biquadm_CreateSetupD(one_section, 1, 1);
                vDSP_biquadm_SetupD b = vDSP_biquadm_CreateSetupD(one_section, 1, 1);
                float as_single[5] = {3.0f, 0, 0, 0.25f, 0};
                double as_double[5] = {4.0, 0, 0, 0.125, 0};
                bool states[1] = {false};
                double mine[SLOTS], theirs[SLOTS], input[SLOTS];
                const double *x[1] = {input};
                double *my_y[1] = {mine}, *their_y[1] = {theirs};
                int agreed = 1;
                charon_host_vDSP_biquadm_SetCoefficientsSingleD(a, as_single, 0, 0, 1, 1);
                vDSP_biquadm_SetCoefficientsSingleD(b, as_single, 0, 0, 1, 1);
                charon_host_vDSP_biquadm_SetCoefficientsDoubleD(a, as_double, 0, 0, 1, 1);
                vDSP_biquadm_SetCoefficientsDoubleD(b, as_double, 0, 0, 1, 1);
                charon_host_vDSP_biquadm_SetActiveFiltersD(a, states);
                vDSP_biquadm_SetActiveFiltersD(b, states);
                for (int sample = 0; sample < 8; sample++) {
                    input[sample] = 1.0;
                    mine[sample] = theirs[sample] = 0.0;
                }
                charon_host_vDSP_biquadmD(a, x, 1, my_y, 1, 8);
                vDSP_biquadmD(b, x, 1, their_y, 1, 8);
                for (int sample = 0; sample < 8; sample++) {
                    if (!agrees(mine[sample], theirs[sample])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "the port says %g and the host %g", mine[0], theirs[0]);
                report(agreed, "vDSP_biquadmD after the 16.0 coefficient setters and an inactive section",
                       agreed ? "" : detail);
                charon_host_vDSP_biquadm_DestroySetupD(a);
                vDSP_biquadm_DestroySetupD(b);
            }
        }
        // 9. the DFT: which lengths have a setup, and what each transform answers.
        {
            vDSP_Length lengths[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 15, 16, 24, 40, 48, 120, 192, 200, 256};
            for (unsigned at = 0; at < sizeof lengths / sizeof *lengths; at++) {
                vDSP_DFT_SetupD port_zop = charon_host_vDSP_DFT_zop_CreateSetupD(NULL, lengths[at], vDSP_DFT_FORWARD);
                vDSP_DFT_SetupD host_zop = vDSP_DFT_zop_CreateSetupD(NULL, lengths[at], vDSP_DFT_FORWARD);
                vDSP_DFT_SetupD port_zrop = charon_host_vDSP_DFT_zrop_CreateSetupD(NULL, lengths[at], vDSP_DFT_FORWARD);
                vDSP_DFT_SetupD host_zrop = vDSP_DFT_zrop_CreateSetupD(NULL, lengths[at], vDSP_DFT_FORWARD);
                char label[96];
                snprintf(label, sizeof label, "a setup of length %lu for both kinds of transform",
                         (unsigned long)lengths[at]);
                snprintf(detail, sizeof detail, "the port has %s/%s and the host %s/%s", port_zop ? "zop" : "NULL",
                         port_zrop ? "zrop" : "NULL", host_zop ? "zop" : "NULL", host_zrop ? "zrop" : "NULL");
                report((port_zop != NULL) == (host_zop != NULL) && (port_zrop != NULL) == (host_zrop != NULL), label,
                       detail);
                if (port_zop) {
                    charon_host_vDSP_DFT_DestroySetupD(port_zop);
                }
                if (host_zop) {
                    vDSP_DFT_DestroySetupD(host_zop);
                }
                if (port_zrop) {
                    charon_host_vDSP_DFT_DestroySetupD(port_zrop);
                }
                if (host_zrop) {
                    vDSP_DFT_DestroySetupD(host_zrop);
                }
            }
            vDSP_DFT_DestroySetupD(NULL);
            report(1, "vDSP_DFT_DestroySetupD of NULL does nothing", "");
        }
        {
            // Complex to complex, forward and inverse, over inputs whose transforms are known.
            static const vDSP_Length lengths[] = {2, 4, 8, 12, 16};
            for (unsigned which = 0; which < sizeof lengths / sizeof *lengths; which++) {
                for (int inverse = 0; inverse < 2; inverse++) {
                    vDSP_DFT_SetupD port_setup =
                        charon_host_vDSP_DFT_zop_CreateSetupD(NULL, lengths[which],
                                                              inverse ? vDSP_DFT_INVERSE : vDSP_DFT_FORWARD);
                    vDSP_DFT_SetupD host_setup =
                        vDSP_DFT_zop_CreateSetupD(NULL, lengths[which], inverse ? vDSP_DFT_INVERSE : vDSP_DFT_FORWARD);
                    double mine_ir[64], mine_ii[64], mine_or[64], mine_oi[64];
                    double their_ir[64], their_ii[64], their_or[64], their_oi[64];
                    char label[128];
                    int agreed = 1;
                    for (vDSP_Length at = 0; at < lengths[which]; at++) {
                        mine_ir[at] = their_ir[at] = sin((double)at * 1.7) * 3.0;
                        mine_ii[at] = their_ii[at] = cos((double)at * 0.9) * 2.0;
                        mine_or[at] = mine_oi[at] = their_or[at] = their_oi[at] = 0.0;
                    }
                    if (port_setup && host_setup) {
                    charon_host_vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)port_setup, mine_ir, mine_ii,
                                                 mine_or, mine_oi);
                    vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)host_setup, their_ir, their_ii, their_or,
                                      their_oi);
                    for (vDSP_Length at = 0; at < lengths[which]; at++) {
                        if (!agrees(mine_or[at], their_or[at]) || !agrees(mine_oi[at], their_oi[at])) {
                            agreed = 0;
                        }
                    }
                    snprintf(detail, sizeof detail, "bin %lu is (%g, %g) on the port and (%g, %g) on the host",
                             0UL, mine_or[0], mine_oi[0], their_or[0], their_oi[0]);
                    snprintf(label, sizeof label, "vDSP_DFT_ExecuteD, complex to complex, length %lu, %s",
                             (unsigned long)lengths[which], inverse ? "inverse" : "forward");
                    report(agreed, label, agreed ? "" : detail);
                    }
                    vDSP_DFT_DestroySetupD(host_setup);
                    charon_host_vDSP_DFT_DestroySetupD(port_setup);
                }
            }
        }
        {
            // Real to complex, forward: the input is the even and the odd samples, the output the packing.
            static const vDSP_Length lengths[] = {2, 4, 8, 16};
            for (unsigned which = 0; which < sizeof lengths / sizeof *lengths; which++) {
                vDSP_DFT_SetupD port_setup =
                    charon_host_vDSP_DFT_zrop_CreateSetupD(NULL, lengths[which], vDSP_DFT_FORWARD);
                vDSP_DFT_SetupD host_setup = vDSP_DFT_zrop_CreateSetupD(NULL, lengths[which], vDSP_DFT_FORWARD);
                vDSP_Length half = lengths[which] / 2;
                double mine_ir[32], mine_ii[32], mine_or[32], mine_oi[32];
                double their_ir[32], their_ii[32], their_or[32], their_oi[32];
                char label[128];
                int agreed = 1;
                for (vDSP_Length at = 0; at < half; at++) {
                    mine_ir[at] = their_ir[at] = cos((double)at * 0.6) * 4.0;
                    mine_ii[at] = their_ii[at] = sin((double)at * 1.1) * 1.5;
                    mine_or[at] = mine_oi[at] = their_or[at] = their_oi[at] = 0.0;
                }
                charon_host_vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)port_setup, mine_ir, mine_ii, mine_or,
                                             mine_oi);
                vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)host_setup, their_ir, their_ii, their_or, their_oi);
                for (vDSP_Length at = 0; at < half; at++) {
                    if (!agrees(mine_or[at], their_or[at]) || !agrees(mine_oi[at], their_oi[at])) {
                        agreed = 0;
                    }
                }
                snprintf(detail, sizeof detail, "the packed answer starts (%g, %g) (%g, %g) on the port and "
                                                "(%g, %g) (%g, %g) on the host",
                         mine_or[0], mine_oi[0], half > 1 ? mine_or[1] : 0.0, half > 1 ? mine_oi[1] : 0.0, their_or[0],
                         their_oi[0], half > 1 ? their_or[1] : 0.0, half > 1 ? their_oi[1] : 0.0);
                snprintf(label, sizeof label, "vDSP_DFT_ExecuteD, real to complex, length %lu, forward",
                         (unsigned long)lengths[which]);
                report(agreed, label, agreed ? "" : detail);
                vDSP_DFT_DestroySetupD(host_setup);
                charon_host_vDSP_DFT_DestroySetupD(port_setup);
            }
            // and the inverse, where the packing is the input and the even and the odd samples the
            // output. The input is a packed spectrum that came out of the forward transform, which is the
            // case a caller has, and the round trip is what the header's two layouts between them say: a
            // forward that is twice the transform times an unnormalised inverse is 2N times the signal
            // (measured at the host: a real signal of N = 8 comes back as 16 times itself).
            for (unsigned which = 0; which < sizeof lengths / sizeof *lengths; which++) {
                vDSP_Length length = lengths[which], half = length / 2;
                vDSP_DFT_SetupD port_forward = charon_host_vDSP_DFT_zrop_CreateSetupD(NULL, length, vDSP_DFT_FORWARD);
                vDSP_DFT_SetupD host_forward = vDSP_DFT_zrop_CreateSetupD(NULL, length, vDSP_DFT_FORWARD);
                vDSP_DFT_SetupD port_inverse = charon_host_vDSP_DFT_zrop_CreateSetupD(NULL, length, vDSP_DFT_INVERSE);
                vDSP_DFT_SetupD host_inverse = vDSP_DFT_zrop_CreateSetupD(NULL, length, vDSP_DFT_INVERSE);
                double port_even[32], port_odd[32], port_or[32], port_oi[32], port_back[32], port_backodd[32];
                double host_even[32], host_odd[32], host_or[32], host_oi[32], host_back[32], host_backodd[32];
                char label[128];
                int agreed = 1;
                for (vDSP_Length at = 0; at < half; at++) {
                    port_even[at] = host_even[at] = cos(0.7 * (double)at);
                    port_odd[at] = host_odd[at] = sin(1.3 * (double)at);
                    port_back[at] = port_backodd[at] = host_back[at] = host_backodd[at] = 0.0;
                }
                if (port_forward && host_forward && port_inverse && host_inverse) {
                    charon_host_vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)port_forward, port_even,
                                                 port_odd, port_or, port_oi);
                    vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)host_forward, host_even, host_odd, host_or,
                                      host_oi);
                    for (vDSP_Length at = 0; at < half; at++) {
                        if (!agrees(port_or[at], host_or[at]) || !agrees(port_oi[at], host_oi[at])) {
                            agreed = 0;
                            snprintf(detail, sizeof detail,
                                     "the forward's packed bin %lu is (%g, %g) on the port and (%g, %g) on the host",
                                     (unsigned long)at, port_or[at], port_oi[at], host_or[at], host_oi[at]);
                        }
                    }
                    charon_host_vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)port_inverse, port_or, port_oi,
                                                 port_back, port_backodd);
                    vDSP_DFT_ExecuteD((const struct vDSP_DFT_SetupStructD *)host_inverse, host_or, host_oi, host_back,
                                      host_backodd);
                    for (vDSP_Length at = 0; at < half; at++) {
                        if (!agrees(port_back[at], host_back[at])) {
                            agreed = 0;
                            snprintf(detail, sizeof detail,
                                     "the round trip's even sample %lu is %g on the port and %g on the host",
                                     (unsigned long)at, port_back[at], host_back[at]);
                        }
                        if (!agrees(port_backodd[at], host_backodd[at])) {
                            agreed = 0;
                            snprintf(detail, sizeof detail,
                                     "the round trip's odd sample %lu is %g on the port and %g on the host",
                                     (unsigned long)at, port_backodd[at], host_backodd[at]);
                        }
                    }
                }
                snprintf(label, sizeof label,
                         "vDSP_DFT_ExecuteD, real to complex forward and back, length %lu", (unsigned long)length);
                report(agreed, label, agreed ? "" : detail);
                vDSP_DFT_DestroySetupD(host_forward);
                charon_host_vDSP_DFT_DestroySetupD(port_forward);
                vDSP_DFT_DestroySetupD(host_inverse);
                charon_host_vDSP_DFT_DestroySetupD(port_inverse);
            }
        }
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
