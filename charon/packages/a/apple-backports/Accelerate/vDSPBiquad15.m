// The two coefficient setters of the single-section biquad that arrived in iOS 15.0:
// vDSP_biquad_SetCoefficientsDouble and vDSP_biquad_SetCoefficientsSingle. They are alone in this file
// because they are alone in their release: measured from the release's armv7 caches, 15.0 is the first held
// release that exports either, so an object file that carried one of them alongside a 16.0 biquad setter
// would hold two releases and the gate refuses that (modules/apple/backports.lua, check_releases).
//
// **The setup is the release's own object and is never read here, on either side.** vDSP.h declares
// `struct vDSP_biquad_SetupStruct` with no published layout, says the contents may change between releases
// and are to be touched only through the setup routines, and every measurement below is made by creating a
// setup with one side's own `vDSP_biquad_CreateSetup`, calling one side's own setter on it, and reading the
// result back through that same side's own `vDSP_biquad`. Nothing crosses, so nothing needs a layout both
// sides agree on. facts/Accelerate/vDSPPlacement.md recorded these two rows as blocked for want of a guest
// probe; that is not what is needed, and this file is the proof: both sides have their own create and their
// own filter.
//
// What the setters do, measured against the host with the setup never read:
//
//   - They replace the five coefficients of each section the window names, and nothing else. A setup of one
//     section, run once to produce a delay, then given a new b0, b1, b2, a1 and a2 and run again over the
//     same delay answers exactly what a setup made from those five coefficients answers over that delay,
//     and differs from both what the old coefficients answer and what a fresh delay answers (measured, both
//     precisions). So the caller's delay is the state and it is left alone.
//   - The window is `nsec` sections of five values each, at `start_sec`. Over a setup of three sections a
//     two-section window at start_sec 1 answers exactly what the same three coefficients with the window's
//     two blocks in place answers.
//
// What the header does not say, and what is therefore not reproduced:
//
//   - A window that leaves the setup. The host reads and writes outside its own object: on a setup of one
//     section a window at start_sec 1 answers coefficients the setup never had, a window of nsec 4 answers
//     values out of uninitialised memory, and over two sections a window at start_sec 1 with nsec 2 ends the
//     process with a trap and at start_sec 2 with a segfault (measured, one call per process). A port must
//     not write outside the caller's object, so a section the setup does not have is left alone - the same
//     answer the multiple-biquad setters of this package give for a cell outside the window, through
//     CharonBiquadCellOf.
//   - A NULL setup or a NULL array. The declaration's __nonnull makes both undefined; the multiple-biquad
//     setters of this package answer both without touching anything and that is what these do.

#import <Accelerate/Accelerate.h>

// The port's own single-section setup, from vDSPBiquad6.m: a count and five coefficients per section, and
// no state - the state is the caller's Delay, which is what makes the measurement above possible. The two
// structs are declared here rather than shared, because a function defined in a file that exports an API
// symbol of its own is left out of a band the release already has, and a struct is not a symbol but its
// definition still has to agree: the name and the layout are the release's own, since vDSP.h names them and
// a client's declarations must match.
struct vDSP_biquad_SetupStruct {
    vDSP_Length sections;
    double coeff[1];
};

// The window's five values for one section, at the section the window names. A section the setup does not
// have is left alone, and the offset is only formed for one it has, so no pointer is ever stepped past the
// caller's object.
static inline void charon_biquad15_set(void *setup, vDSP_Length section, const double *block)
{
    struct vDSP_biquad_SetupStruct *asSetup = (struct vDSP_biquad_SetupStruct *)setup;
    if (section >= asSetup->sections) {
        return;
    }
    double *into = asSetup->coeff + (size_t)section * 5;
    for (int k = 0; k < 5; k++) {
        into[k] = block[k];
    }
}

void vDSP_biquad_SetCoefficientsDouble(vDSP_biquad_Setup __setup, const double *__coeffs, vDSP_Length __start_sec,
                                       vDSP_Length __nsec)
{
    if (!__setup || !__coeffs) {
        return;
    }
    for (vDSP_Length at = 0; at < __nsec; at++) {
        charon_biquad15_set(__setup, __start_sec + at, __coeffs + (size_t)at * 5);
    }
}

void vDSP_biquad_SetCoefficientsSingle(vDSP_biquad_Setup __setup, const float *__coeffs, vDSP_Length __start_sec,
                                       vDSP_Length __nsec)
{
    if (!__setup || !__coeffs) {
        return;
    }
    for (vDSP_Length at = 0; at < __nsec; at++) {
        // The caller's values are floats and the setup's are doubles, as the declaration says: the five are
        // widened once, on the way in, which is the whole difference between this and the call above and is
        // measured by handing each of the two a float array of five and a double array of five.
        double block[5];
        for (int k = 0; k < 5; k++) {
            block[k] = (double)__coeffs[(size_t)at * 5 + k];
        }
        charon_biquad15_set(__setup, __start_sec + at, block);
    }
}
