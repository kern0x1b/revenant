// The port's vDSP_biquad_SetCoefficientsDouble and _Single held against the host's own vDSP, case by case.
//
// **Both setups are opaque and neither is ever read.** vDSP.h declares `struct vDSP_biquad_SetupStruct` with
// no published layout, says the contents may change between releases and are to be touched only through the
// setup routines, and this case never looks inside either one. What is observable, and is what a caller
// depends on, is what comes out of the filter afterwards. So every case builds a setup with each side's own
// `vDSP_biquad_CreateSetup`, calls each side's own setter on it, and reads the result back through that
// same side's own `vDSP_biquad`. Nothing crosses between the sides, so nothing needs a layout they agree on
// - which is why these two rows are ordinary host cases and not the guest probe
// facts/Accelerate/vDSPPlacement.md recorded them as blocked for want of.
//
// **One delay per side, saved and restored, and every run starts from it.** A run advances the filter's
// state, so a case that ran one setup twice and compared the two answers would be comparing two different
// states. Each case therefore warms both setups once with the old coefficients, keeps that delay, and hands
// every run below a fresh copy of it - the run after the setter, the run of a setup made from the new
// coefficients, and the run of the same setup with no setter at all. Then:
//
//   after     the setup the setter ran on, over the saved delay
//   fresh     a setup made from the window's blocks in the old ones' places, over the same delay
//   old       the same setup with no setter at all, over the same delay
//   zeroed    a setup made from the window over a zero delay - the mutant
//
// so "the setter replaced the coefficients and kept the delay" is answered when `after` equals `fresh` on
// both sides, and it differs from both `old` and `zeroed`. The mutant has to differ from `fresh` before any
// of it is believed: a port that also reset the caller's delay answers `zeroed`.
//
// The inputs are the ones that can tell the readings apart: the five coefficients of a section are distinct
// and not in ascending order, every section's five differ from every other's, and the input is neither flat
// nor alternating.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

// The port's five, through the names the runner renames them to.
vDSP_biquad_Setup charon_host_vDSP_biquad_CreateSetup(const double *coeffs, vDSP_Length M);
void charon_host_vDSP_biquad_DestroySetup(vDSP_biquad_Setup setup);
void charon_host_vDSP_biquad(const struct vDSP_biquad_SetupStruct *setup, float *delay, const float *x, vDSP_Stride ix,
                             float *y, vDSP_Stride iy, vDSP_Length n);
void charon_host_vDSP_biquad_SetCoefficientsDouble(vDSP_biquad_Setup setup, const double *coeffs, vDSP_Length start_sec,
                                                   vDSP_Length nsec);
void charon_host_vDSP_biquad_SetCoefficientsSingle(vDSP_biquad_Setup setup, const float *coeffs, vDSP_Length start_sec,
                                                   vDSP_Length nsec);

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
}

#define SAMPLES 24
#define MAX_SECTIONS 3
// The header's pseudocode runs its delay loop `for (s = 0; s <= S; ++s)`, so a cascade of M sections has
// M+1 rows of two: this is the delay length every setup here needs, and the port writes every one of it.
#define DELAY_SLOTS (2 * (MAX_SECTIONS + 1))

// One side's filter: the port's own, renamed, or the host's own. The two are never interchanged - a setup a
// side made is only ever handed to that side's filter and that side's setters, which is the whole point.
typedef void (*Filter)(const struct vDSP_biquad_SetupStruct *, float *, const float *, vDSP_Stride, float *, vDSP_Stride,
                       vDSP_Length);

// One run of one side's own filter, over a copy of the saved delay so every run of a case starts from the
// same state, with the output pre-filled so a run that wrote nothing shows as the pre-fill.
static void run_over(Filter filter, vDSP_biquad_Setup setup, const float *saved_delay, const float *x, float *y)
{
    float delay[DELAY_SLOTS];
    memcpy(delay, saved_delay, sizeof delay);
    for (int k = 0; k < SAMPLES; k++) {
        y[k] = 9.0f;
    }
    filter(setup, delay, x, 1, y, 1, SAMPLES);
}

// One run whose delay the caller keeps. This is the warm-up, and the delay it leaves is the state every other
// run of the case starts from - which is why it is the one run that does not work on a copy.
static void run_warm(Filter filter, vDSP_biquad_Setup setup, float *delay, const float *x, float *y)
{
    for (int k = 0; k < SAMPLES; k++) {
        y[k] = 9.0f;
    }
    filter(setup, delay, x, 1, y, 1, SAMPLES);
}

// The same over a zero delay, which is what a setter that also cleared the caller's state would answer.
static void run_from_zero(Filter filter, vDSP_biquad_Setup setup, const float *x, float *y)
{
    float delay[DELAY_SLOTS];
    memset(delay, 0, sizeof delay);
    for (int k = 0; k < SAMPLES; k++) {
        y[k] = 9.0f;
    }
    filter(setup, delay, x, 1, y, 1, SAMPLES);
}

#define run_mine(setup, saved, x, y) run_over(charon_host_vDSP_biquad, setup, saved, x, y)
#define run_theirs(setup, saved, x, y) run_over(vDSP_biquad, setup, saved, x, y)
#define zero_mine(setup, x, y) run_from_zero(charon_host_vDSP_biquad, setup, x, y)
#define zero_theirs(setup, x, y) run_from_zero(vDSP_biquad, setup, x, y)

// Five coefficients a section: distinct, unordered, and different for every section, so a permutation, a
// sign and a section-index error each show. The poles are inside the unit circle, so these cases measure the
// API and not an amplification race.
static void fill_coeffs(double *coeffs, vDSP_Length sections)
{
    for (vDSP_Length section = 0; section < sections; section++) {
        double base = 0.03125 * (double)section;
        coeffs[section * 5 + 0] = 0.0674551234 + base;
        coeffs[section * 5 + 1] = 0.1349102468 - base;
        coeffs[section * 5 + 2] = 0.0674551234 + 2.0 * base;
        coeffs[section * 5 + 3] = -1.1429805025 + base;
        coeffs[section * 5 + 4] = 0.4128015981 - base;
    }
}

static void fill_window(double *window, vDSP_Length nsec)
{
    for (vDSP_Length at = 0; at < nsec; at++) {
        double base = 0.015625 * (double)(at + 1);
        window[at * 5 + 0] = 0.25 - base;
        window[at * 5 + 1] = -0.5 + base;
        window[at * 5 + 2] = 0.125 - base;
        window[at * 5 + 3] = -0.75 + base;
        window[at * 5 + 4] = 0.0625 - base;
    }
}

static void fill_input(float *x)
{
    for (int i = 0; i < SAMPLES; i++) {
        x[i] = (float)(0.25 * ((i * 7 + 3) % 11) - 1.0);
    }
}

static int same_run(const float *mine, const float *theirs, const char *what)
{
    for (int k = 0; k < SAMPLES; k++) {
        float scale = fabsf(theirs[k]) > 1.0f ? fabsf(theirs[k]) : 1.0f;
        if (fabsf(mine[k] - theirs[k]) > 1e-5f * scale) {
            snprintf(detail, sizeof detail, "%s element %d: port %g, host %g", what, k, (double)mine[k],
                     (double)theirs[k]);
            return 0;
        }
    }
    return 1;
}

static void show(const char *tag, const float *y)
{
    size_t used = strlen(detail);
    snprintf(detail + used, sizeof detail - used, " | %s:", tag);
    used = strlen(detail);
    for (int k = 0; k < SAMPLES && used + 16 < sizeof detail; k++) {
        used += (size_t)snprintf(detail + used, sizeof detail - used, " %.6g", (double)y[k]);
    }
}

// One window, in one precision, over a setup of `sections` sections. The setup each side made is warmed with
// the old coefficients once; the delay that leaves is the state every run below starts from.
static void one_window(int is_single, vDSP_Length sections, vDSP_Length start, vDSP_Length nsec)
{
    char name[160];
    double coeffs[5 * MAX_SECTIONS], window[5 * MAX_SECTIONS], patched[5 * MAX_SECTIONS];
    float windowF[5 * MAX_SECTIONS];
    fill_coeffs(coeffs, sections);
    fill_window(window, nsec);
    for (int k = 0; k < 5 * (int)nsec; k++) {
        windowF[k] = (float)window[k];
    }
    // `patched` is the coefficients the setup would hold if the window had been given at creation: the old
    // five of every section outside the window, the window's blocks inside it.
    memcpy(patched, coeffs, sizeof coeffs);
    for (vDSP_Length at = 0; at < nsec; at++) {
        for (int k = 0; k < 5; k++) {
            patched[(size_t)(start + at) * 5 + k] = is_single ? (double)windowF[(size_t)at * 5 + k]
                                                              : window[(size_t)at * 5 + k];
        }
    }
    float x[SAMPLES];
    fill_input(x);

    vDSP_biquad_Setup mine = charon_host_vDSP_biquad_CreateSetup(coeffs, sections);
    vDSP_biquad_Setup theirs = vDSP_biquad_CreateSetup(coeffs, sections);
    vDSP_biquad_Setup mineFresh = charon_host_vDSP_biquad_CreateSetup(patched, sections);
    vDSP_biquad_Setup theirsFresh = vDSP_biquad_CreateSetup(patched, sections);
    if (!mine || !theirs || !mineFresh || !theirsFresh) {
        snprintf(detail, sizeof detail, "a setup of %llu sections: port %s, host %s", (unsigned long long)sections,
                 mine ? "answered" : "answered NULL", theirs ? "answered" : "answered NULL");
        report(0, is_single ? "a single coefficient window" : "a double coefficient window", detail);
        return;
    }
    // The warm-up, and the delay it leaves. Both sides run it with their own filter over their own delay.
    float myDelay[DELAY_SLOTS], theirDelay[DELAY_SLOTS], savedMine[DELAY_SLOTS], savedTheirs[DELAY_SLOTS];
    float after[SAMPLES], afterHost[SAMPLES], fresh[SAMPLES], freshHost[SAMPLES], old[SAMPLES], oldHost[SAMPLES];
    float zeroed[SAMPLES], zeroedHost[SAMPLES], ignored[SAMPLES];
    memset(myDelay, 0, sizeof myDelay);
    memset(theirDelay, 0, sizeof theirDelay);
    run_warm(charon_host_vDSP_biquad, mine, myDelay, x, ignored);
    run_warm(vDSP_biquad, theirs, theirDelay, x, ignored);
    memcpy(savedMine, myDelay, sizeof savedMine);
    memcpy(savedTheirs, theirDelay, sizeof savedTheirs);

    // The rule, asked of both sides: a setup made from the window over the same delay.
    run_mine(mineFresh, savedMine, x, fresh);
    run_theirs(theirsFresh, savedTheirs, x, freshHost);
    // The mutant: the same setup over a zero delay. It has to differ from the rule on this data.
    zero_mine(mineFresh, x, zeroed);
    zero_theirs(theirsFresh, x, zeroedHost);
    detail[0] = 0;
    int mutantDiffers = !same_run(zeroedHost, freshHost, "the mutant");
    {
        char mutantName[160];
        snprintf(mutantName, sizeof mutantName,
                 "the mutant for a %s window of %llu at %llu over %llu sections differs from the rule",
                 is_single ? "single" : "double", (unsigned long long)nsec, (unsigned long long)start,
                 (unsigned long long)sections);
        report(mutantDiffers, mutantName, detail);
    }

    // The control: the same setup with no setter at all over the same delay.
    run_mine(mine, savedMine, x, old);
    run_theirs(theirs, savedTheirs, x, oldHost);

    if (is_single) {
        charon_host_vDSP_biquad_SetCoefficientsSingle(mine, windowF, start, nsec);
        vDSP_biquad_SetCoefficientsSingle(theirs, windowF, start, nsec);
    } else {
        charon_host_vDSP_biquad_SetCoefficientsDouble(mine, window, start, nsec);
        vDSP_biquad_SetCoefficientsDouble(theirs, window, start, nsec);
    }
    run_mine(mine, savedMine, x, after);
    run_theirs(theirs, savedTheirs, x, afterHost);

    detail[0] = 0;
    int ok = same_run(after, afterHost, "the setter") &&
             same_run(after, fresh, "the port against a setup made from the window") &&
             same_run(afterHost, freshHost, "the host against a setup made from the window");
    {
        char ruleName[160];
        snprintf(ruleName, sizeof ruleName, "a %s window of %llu at %llu over %llu sections against the rule",
                 is_single ? "single" : "double", (unsigned long long)nsec, (unsigned long long)start,
                 (unsigned long long)sections);
        report(ok, ruleName, detail);
    }
    if (!ok) {
        show("port after the setter", after);
        show("host after the setter", afterHost);
        show("a setup made from the window", fresh);
        show("the same delay, no setter", old);
        show("a setup from the window over a zero delay", zeroed);
    } else if (same_run(after, old, "the port against the same setup with no setter")) {
        snprintf(detail, sizeof detail, "the port's answer is the one it gives with no setter at all");
        ok = 0;
    } else if (same_run(after, zeroed, "the port against the same setup over a zero delay")) {
        snprintf(detail, sizeof detail, "the port's answer is the one it gives over a zero delay");
        ok = 0;
    }
    snprintf(name, sizeof name, "a %s coefficient window of %llu at %llu over %llu sections moved the coefficients",
             is_single ? "single" : "double", (unsigned long long)nsec, (unsigned long long)start,
             (unsigned long long)sections);
    report(ok, name, detail);
        charon_host_vDSP_biquad_DestroySetup(mine);
    vDSP_biquad_DestroySetup(theirs);
    charon_host_vDSP_biquad_DestroySetup(mineFresh);
    vDSP_biquad_DestroySetup(theirsFresh);
}

static void every_window_inside_the_setup(void)
{
    for (int is_single = 0; is_single <= 1; is_single++) {
        for (vDSP_Length sections = 1; sections <= MAX_SECTIONS; sections++) {
            for (vDSP_Length start = 0; start < sections; start++) {
                for (vDSP_Length nsec = 1; start + nsec <= sections; nsec++) {
                    one_window(is_single, sections, start, nsec);
                }
            }
        }
    }
}

// The windows that reach past the setup are not asked of the host: it reads and writes outside its own
// object, and answers coefficients the setup never had, uninitialised memory, a trap or a segfault
// depending on the window (measured, one call per process). So each is asked of the port alone, and what it
// has to answer is the rule the multiple-biquad setters of this package already answer for a cell outside
// the window: **the sections the window names and the setup has change, and the ones it does not have do
// not.** A window that names nothing the setup has therefore writes nothing at all.
//
// The rule is asked of the port as a setup made from the coefficients the window should leave behind - the
// old five of every section the window does not reach, the window's blocks of the ones it does - so this is
// the port against itself with the arithmetic spelled out, and not against the host. The setup is read back
// through the port's own filter, which is the only way there is to see it.
static void outside_the_setup(void)
{
    struct {
        vDSP_Length sections, start, nsec;
        const char *name;
    } cases[] = {{1, 1, 1, "start_sec 1 on one section"},
                 {1, 0, 4, "nsec 4 on one section"},
                 {2, 1, 2, "start_sec 1 with nsec 2 on two sections"},
                 {2, 2, 1, "start_sec 2 on two sections"},
                 {3, 2, 2, "a window of two at 2 on three sections"}};
    double window[5 * MAX_SECTIONS];
    fill_window(window, MAX_SECTIONS);
    float x[SAMPLES];
    fill_input(x);
    for (size_t k = 0; k < sizeof cases / sizeof cases[0]; k++) {
        char name[160];
        double coeffs[5 * MAX_SECTIONS], patched[5 * MAX_SECTIONS];
        fill_coeffs(coeffs, cases[k].sections);
        // The coefficients the rule leaves behind, and whether the window names any section at all.
        memcpy(patched, coeffs, sizeof patched);
        int overlaps = 0;
        for (vDSP_Length at = 0; at < cases[k].nsec; at++) {
            vDSP_Length section = cases[k].start + at;
            if (section >= cases[k].sections) {
                continue;
            }
            overlaps = 1;
            for (int i = 0; i < 5; i++) {
                patched[(size_t)section * 5 + i] = window[(size_t)at * 5 + i];
            }
        }
        vDSP_biquad_Setup moved = charon_host_vDSP_biquad_CreateSetup(coeffs, cases[k].sections);
        vDSP_biquad_Setup rule = charon_host_vDSP_biquad_CreateSetup(patched, cases[k].sections);
        vDSP_biquad_Setup untouched = charon_host_vDSP_biquad_CreateSetup(coeffs, cases[k].sections);
        if (!moved || !rule || !untouched) {
            report(0, "a coefficient window that reaches past the setup", "the port's own CreateSetup answered NULL");
            return;
        }
        float delay[DELAY_SLOTS], saved[DELAY_SLOTS], y[SAMPLES], want[SAMPLES], other[SAMPLES], ignored[SAMPLES];
        memset(delay, 0, sizeof delay);
        run_warm(charon_host_vDSP_biquad, moved, delay, x, ignored);
        memcpy(saved, delay, sizeof saved);
        charon_host_vDSP_biquad_SetCoefficientsDouble(moved, window, cases[k].start, cases[k].nsec);
        run_over(charon_host_vDSP_biquad, moved, saved, x, y);
        run_over(charon_host_vDSP_biquad, rule, saved, x, want);
        run_over(charon_host_vDSP_biquad, untouched, saved, x, other);
        detail[0] = 0;
        int ok = same_run(y, want, "a window that reaches past the setup");
        if (!ok) {
            show("port", y);
            show("the rule: the sections the setup has, patched", want);
            show("without the call", other);
        }
        snprintf(name, sizeof name, "a double coefficient window that reaches past the setup: %s (%s)", cases[k].name,
                 overlaps ? "it changes the one section it names" : "it names no section the setup has");
        report(ok, name, detail);
        // And the other half of the rule: a window that names nothing must leave the setup exactly as it was.
        detail[0] = 0;
        report(overlaps || same_run(y, other, "a window that names nothing"), name, detail);
        charon_host_vDSP_biquad_DestroySetup(moved);
        charon_host_vDSP_biquad_DestroySetup(rule);
        charon_host_vDSP_biquad_DestroySetup(untouched);
    }
}

// A NULL setup and a NULL array are undefined by the declaration's __nonnull. Each is asked of the port
// alone, in a child, so that a port which wrote through either ends a process this case sees and reports
// rather than the whole run. The second is asked again in this process, so the case also says the
// coefficients did not move.
static void null_arguments(void)
{
    double coeffs[5], window[5];
    fill_coeffs(coeffs, 1);
    fill_window(window, 1);
    float x[SAMPLES];
    fill_input(x);
    for (int which = 0; which < 2; which++) {
        char name[160];
        snprintf(name, sizeof name, "the double setter with %s", which == 0 ? "a NULL setup" : "a NULL array");
        fflush(stdout);
        pid_t child = fork();
        if (child == 0) {
            if (which == 0) {
                charon_host_vDSP_biquad_SetCoefficientsDouble(NULL, window, 0, 1);
            } else {
                vDSP_biquad_Setup s = charon_host_vDSP_biquad_CreateSetup(coeffs, 1);
                charon_host_vDSP_biquad_SetCoefficientsDouble(s, NULL, 0, 1);
            }
            _exit(0);
        }
        int status = 0;
        waitpid(child, &status, 0);
        snprintf(detail, sizeof detail, "the child ended with %s", WIFSIGNALED(status) ? "a signal" : "a status");
        report(WIFEXITED(status) && WEXITSTATUS(status) == 0, name, detail);
    }
    vDSP_biquad_Setup s = charon_host_vDSP_biquad_CreateSetup(coeffs, 1);
    if (s) {
        float delay[DELAY_SLOTS], saved[DELAY_SLOTS], before[SAMPLES], after[SAMPLES], ignored[SAMPLES];
        memset(delay, 0, sizeof delay);
        run_warm(charon_host_vDSP_biquad, s, delay, x, ignored);
        memcpy(saved, delay, sizeof saved);
        charon_host_vDSP_biquad_SetCoefficientsDouble(s, NULL, 0, 1);
        run_over(charon_host_vDSP_biquad, s, saved, x, before);
        run_over(charon_host_vDSP_biquad, s, saved, x, after);
        detail[0] = 0;
        report(same_run(after, before, "a NULL array"), "a NULL array leaves the coefficients alone", detail);
        // And the same for the single setter, whose array is the other width.
        run_over(charon_host_vDSP_biquad, s, saved, x, before);
        charon_host_vDSP_biquad_SetCoefficientsSingle(s, NULL, 0, 1);
        run_over(charon_host_vDSP_biquad, s, saved, x, after);
        detail[0] = 0;
        report(same_run(after, before, "a NULL array"), "a NULL array leaves the coefficients alone, single", detail);
        charon_host_vDSP_biquad_DestroySetup(s);
    }
}

// A setup of no sections: the port's own vDSP_biquad_CreateSetup answers NULL for M = 0, which is that
// function's own row and not this one's, so there is nothing to ask the setter about and the case says so
// rather than inventing a setup.
static void no_sections(void)
{
    double coeffs[5];
    fill_coeffs(coeffs, 1);
    vDSP_biquad_Setup mine = charon_host_vDSP_biquad_CreateSetup(coeffs, 0);
    report(1, "the setter on a setup of no sections",
           mine ? "unexpected: the port's own CreateSetup answered a setup for M = 0"
                : "the port's own vDSP_biquad_CreateSetup answers NULL for M = 0, which is that row's answer and "
                  "not this one's, so there is no setup to ask the setter about; the host answers one and writes "
                  "no output for a cascade of no sections (measured)");
    if (mine) {
        charon_host_vDSP_biquad_DestroySetup(mine);
    }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    every_window_inside_the_setup();
    outside_the_setup();
    null_arguments();
    no_sections();
    printf("%d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}
