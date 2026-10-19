// The setup objects of vDSP's multiple-biquad filter, and the accessors the five files that carry its
// twenty entry points read and write them through.
//
// vDSP.h declares `struct vDSP_biquadm_SetupStruct` and `struct vDSP_biquadm_SetupStructD` and publishes
// no layout for either, saying only that the contents "may change from release to release" and that a
// caller should manipulate the values through the setup and setter routines. So the layout is the port's to
// define, and these two definitions are it: a caller only ever passes the pointer around.
//
// The delay is two doubles per section and channel, which is the state of one biquad section in transposed
// direct form II - the form whose two state values carry the input and the output history of the last two
// samples, and which is what the release's own answer is (measured: a section with b0 = 1 and a1 = 0.5
// answers 1, -0.5, 0.25, -0.125, ... to an impulse, which is that recursion and only that one).
//
// The name carries a Charon prefix on purpose, as CharonLinearAlgebra.h's does: the gate does not weigh a
// symbol of the port's own against a release or ask the registry about it (modules/apple/backports.lua,
// internal_symbol). The two structs themselves are the release's own names, because vDSP.h names them and
// a client's declarations must match.

#pragma once

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

// What the two setups have in common, and what each of them spells with its own struct. The scalar type's
// own behaviour lives here rather than in a cell, because a setup of no sections or no channels has no cell
// at all and the setters still have to read it.
typedef struct CharonBiquadCommon {
    vDSP_Length sections;   // M
    vDSP_Length channels;   // N
    int interpolates;       // 1 for a float setup, whose coefficients approach their targets, 0 for a double one
} CharonBiquadCommon;

// One section of one channel: its five coefficients, the target the SetTargets calls aim at with the two
// numbers that describe how to approach it, whether the section is active, and its two state values.
typedef struct CharonBiquadCell {
    double coeff[5];    // b0, b1, b2, a1, a2 - the order vDSP.h's own pseudocode uses
    double target[5];
    double rate;        // interp_rate of the SetTargets call that named this section
    double threshold;   // its interp_threshold
    double state[2];    // the transposed direct form II state, s1 and s2
    int active;         // SetActiveFilters, 1 until a call says otherwise
} CharonBiquadCell;

struct vDSP_biquadm_SetupStruct {
    CharonBiquadCommon common;
    CharonBiquadCell cell[1];   // M * N of them, indexed section-major and channel-minor
};

struct vDSP_biquadm_SetupStructD {
    CharonBiquadCommon common;
    CharonBiquadCell cell[1];
};

// The cells, which sit after the two counts in both of the structs above - and which are named through
// this rather than by adding one to a CharonBiquadCell pointer, because that would step over a whole cell
// and land inside the counts.
static inline CharonBiquadCell *CharonBiquadCells(void *setup)
{
    return (CharonBiquadCell *)((char *)setup + sizeof(CharonBiquadCommon));
}

// The cell for one section and channel, or NULL when that section or channel is not one the setup has. The
// header forbids a window that leaves the setup and the host answers one anyway - the cells inside the window
// change, everything else is left alone and nothing crashes (measured) - so every setter asks through here
// and writes nothing for a NULL, which is the same answer without writing past the block.
static inline CharonBiquadCell *CharonBiquadCellOf(void *setup, vDSP_Length section, vDSP_Length channel)
{
    CharonBiquadCommon *common = (CharonBiquadCommon *)setup;
    if (section >= common->sections || channel >= common->channels) {
        return NULL;
    }
    return &CharonBiquadCells(setup)[section * common->channels + channel];
}

static inline vDSP_Length CharonBiquadSections(const void *setup)
{
    return ((const CharonBiquadCommon *)setup)->sections;
}

static inline vDSP_Length CharonBiquadChannels(const void *setup)
{
    return ((const CharonBiquadCommon *)setup)->channels;
}

// How a setup is made: a block of M * N cells, zeroed, every section active, every delay zero (which is
// what the header says a new setup's delay values are), and the interpolation flag of the scalar type.
//
// No sections and no channels are not refusals: the host answers a setup for both, and what it then does
// is what a cascade of no sections and a call over no channels do - the first passes the input through
// unchanged (measured: a call of four samples answers 1, 2, 3, 4 with M = 0) and the second writes nothing
// at all (measured: with N = 0 the output is left as it was, 9, 9, 9, 9). Only no coefficients at all and a
// count that would overflow are refused, and the first of those the host cannot be asked about at all: it
// reads through the array and stops the process.
static inline void *CharonBiquadCreate(const double *coefficients, vDSP_Length sections, vDSP_Length channels,
                                       int interpolates)
{
    vDSP_Length count = sections * channels;
    struct vDSP_biquadm_SetupStruct *setup;
    if (!coefficients || (sections != 0 && channels != 0 && count > (vDSP_Length)-1 / channels)) {
        return NULL;
    }
    setup = (struct vDSP_biquadm_SetupStruct *)calloc(1, sizeof(CharonBiquadCommon) +
                                                             (size_t)count * sizeof(CharonBiquadCell));
    if (!setup) {
        return NULL;
    }
    setup->common.sections = sections;
    setup->common.channels = channels;
    for (vDSP_Length at = 0; at < count; at++) {
        CharonBiquadCell *cell = &CharonBiquadCells(setup)[at];
        for (int k = 0; k < 5; k++) {
            cell->coeff[k] = coefficients[at * 5 + k];
            cell->target[k] = cell->coeff[k];
        }
        cell->active = 1;
    }
    ((CharonBiquadCommon *)setup)->interpolates = interpolates;
    return setup;
}

static inline void CharonBiquadDestroy(void *setup)
{
    free(setup);
}

static inline void CharonBiquadResetState(void *setup)
{
    vDSP_Length count = CharonBiquadSections(setup) * CharonBiquadChannels(setup);
    for (vDSP_Length at = 0; at < count; at++) {
        CharonBiquadCell *cell = &CharonBiquadCells(setup)[at];
        cell->state[0] = 0.0;
        cell->state[1] = 0.0;
    }
}

// CopyState moves the delay and nothing else - the coefficients, the targets and the active flags stay
// where they are (measured: a 1x1 and a 2x1 setup of the same coefficients answer differently, and after
// the copy the destination answers as the source's shape does). A source with fewer cells than the
// destination copies the ones it has and leaves the rest alone, which is what the host does with a pair the
// header does not allow (it says the two must have the same shape, and the host does not crash).
static inline void CharonBiquadCopyState(void *destination, const void *source)
{
    vDSP_Length from = CharonBiquadSections(source) * CharonBiquadChannels(source);
    vDSP_Length to = CharonBiquadSections(destination) * CharonBiquadChannels(destination);
    vDSP_Length count = from < to ? from : to;
    for (vDSP_Length at = 0; at < count; at++) {
        CharonBiquadCell *into = &CharonBiquadCells(destination)[at];
        const CharonBiquadCell *from_cell = &CharonBiquadCells((void *)source)[at];
        into->state[0] = from_cell->state[0];
        into->state[1] = from_cell->state[1];
    }
}

// SetActiveFilters takes one bool per section, not per section and channel (measured: two sections of one
// channel answer differently when the second is false, and the array of two is what it read), and an
// inactive section is skipped whole: its input passes through and its delay is left as it was.
static inline void CharonBiquadSetActive(void *setup, const bool *states)
{
    vDSP_Length sections = CharonBiquadSections(setup);
    vDSP_Length channels = CharonBiquadChannels(setup);
    for (vDSP_Length section = 0; section < sections; section++) {
        int active = states[section] ? 1 : 0;
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            CharonBiquadCell *cell = CharonBiquadCellOf(setup, section, channel);
            if (cell) {
                cell->active = active;
            }
        }
    }
}

// SetCoefficients, in either precision, over a window of sections and channels. The window is the
// caller's own block, packed nsec by nchn - the five values of its (section, channel) begin at
// (section * nchn + channel) * 5 - and the window is placed in the setup at (start_sec, start_chn). The
// two are different layouts and the host uses the first of them here: measured, a window of one section and
// one channel at (0, 1) of a two-channel setup takes the first five values of a five-value array, and the
// cell it changes is channel 1's.
#define CHARON_BIQUAD_WINDOW(values, section, channel, sections) (values) + ((section) * (channels) + (channel)) * 5

static inline void CharonBiquadSetCoefficients(void *setup, const double *values, vDSP_Length start_section,
                                               vDSP_Length start_channel, vDSP_Length sections,
                                               vDSP_Length channels)
{
    for (vDSP_Length section = 0; section < sections; section++) {
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            CharonBiquadCell *cell = CharonBiquadCellOf(setup, start_section + section, start_channel + channel);
            const double *block = CHARON_BIQUAD_WINDOW(values, section, channel, sections);
            if (!cell) {
                continue;
            }
            for (int k = 0; k < 5; k++) {
                // The target moves with the coefficient: a target is only elsewhere once a SetTargets says
                // so, and a single-precision setup walks its coefficients toward their targets at every
                // sample, so a coefficient whose target stayed behind would be walked back to it.
                cell->coeff[k] = block[k];
                cell->target[k] = block[k];
            }
        }
    }
}

// The two precisions of SetCoefficients, which differ only in the element type the caller's array holds:
// the window is the caller's own layout, so the block the cell (section, channel) takes is the one its index
// names, and a float array is read one value at a time and widened.
static inline void CharonBiquadSetCoefficientsFloat(void *setup, const float *values, vDSP_Length start_section,
                                                    vDSP_Length start_channel, vDSP_Length sections,
                                                    vDSP_Length channels)
{
    for (vDSP_Length section = 0; section < sections; section++) {
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            CharonBiquadCell *cell = CharonBiquadCellOf(setup, start_section + section, start_channel + channel);
            const float *block = CHARON_BIQUAD_WINDOW(values, section, channel, sections);
            if (!cell) {
                continue;
            }
            for (int k = 0; k < 5; k++) {
                cell->coeff[k] = block[k];
                cell->target[k] = block[k];
            }
        }
    }
}

// SetTargets, in either precision, over the same window: the target and the two numbers that describe how
// to reach it.
//
// How a coefficient is brought to its target is what the two setups do differently, and both were measured
// with a pure gain and a constant input, where the output at each sample is the coefficient that sample was
// filtered with:
//
//   - A float setup has the target in place before the first sample when interp_rate is 0 or the distance
//     from the coefficient to the target is at most interp_threshold, and otherwise approaches it at every
//     sample: the sample is filtered with the coefficient as it stands, and the coefficient then moves by
//     (target - coefficient) * (1 - interp_rate), or lands exactly on the target when what is left is at
//     most the threshold. Measured with b0 going from 1 to 9 and a threshold of 0.25, a rate of 0.5 has
//     the samples of one call answer 1, 5, 7, 8, 8.5, 9, 9, 9, a rate of 0.1 answers 1, 8.2, 9, a rate of
//     0.9 answers 1, 1.8, 2.52, 3.168, and a rate of 0 or a threshold of 100 puts 9 in front of them all.
//   - A double setup has the target in place before the first sample whatever the rate and the threshold
//     are: the same four parameter sets answer 9, 9, 9, 9 from the first sample, where the float setup of
//     the first two answers 1, 5, 7 and 1, 8.2, 9. So for a double setup the two rate arguments are stored
//     and change nothing, which is what `interpolates` records and what the registry entries for
//     vDSP_biquadm_SetTargetsSingleD and vDSP_biquadm_SetTargetsDoubleD say (facts/Accelerate/vDSPBiquad.md).
//
// A section on its own is this rule with nothing after it, which is the walk the single-section cases
// measure; a cascade is what the reverse pass above is for, and without it a two-section setup whose
// sections go 2 -> 4 and 5 -> 10 answers 37.5 and 38.75 where the release answers 35.1562 and 37.5391
// (facts/Accelerate/vDSPBiquad.md has the eleven cases the rule is fitted over).
static inline void CharonBiquadSetTargets(void *setup, const double *values, double rate, double threshold,
                                          vDSP_Length start_section, vDSP_Length start_channel, vDSP_Length sections,
                                          vDSP_Length channels)
{
    int interpolates = ((CharonBiquadCommon *)setup)->interpolates;
    for (vDSP_Length section = 0; section < sections; section++) {
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            CharonBiquadCell *cell = CharonBiquadCellOf(setup, start_section + section, start_channel + channel);
            const double *block = CHARON_BIQUAD_WINDOW(values, section, channel, sections);
            if (!cell) {
                continue;
            }
            for (int k = 0; k < 5; k++) {
                cell->target[k] = block[k];
            }
            cell->rate = rate;
            cell->threshold = threshold;
            // The target is in place before the first sample when the setup does not interpolate at all, or
            // when the caller has asked for none of it: a rate of zero, a threshold of zero, or a threshold
            // at or above the distance (measured: with a b0 going from 1 to 9, a rate of 0.5 and thresholds
            // of 0 and of 100 both answer 9 in front of every sample, where a threshold of 0.25 walks there
            // one sample at a time).
            for (int k = 0; k < 5; k++) {
                if (!interpolates || rate == 0.0 || threshold == 0.0 ||
                    fabs(cell->target[k] - cell->coeff[k]) <= threshold) {
                    cell->coeff[k] = cell->target[k];
                }
            }
        }
    }
}

// The single-precision SetTargets, whose targets are floats in the caller's own layout. Whether the target
// is in place at once is the cell's own flag and not this function's business, exactly as in the double one
// above: a single-precision setup approaches its targets and a double-precision one has them at once.
static inline void CharonBiquadSetTargetsFloat(void *setup, const float *values, double rate, double threshold,
                                               vDSP_Length start_section, vDSP_Length start_channel,
                                               vDSP_Length sections, vDSP_Length channels)
{
    int interpolates = ((CharonBiquadCommon *)setup)->interpolates;
    for (vDSP_Length section = 0; section < sections; section++) {
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            CharonBiquadCell *cell = CharonBiquadCellOf(setup, start_section + section, start_channel + channel);
            const float *block = CHARON_BIQUAD_WINDOW(values, section, channel, sections);
            if (!cell) {
                continue;
            }
            for (int k = 0; k < 5; k++) {
                cell->target[k] = block[k];
            }
            cell->rate = rate;
            cell->threshold = threshold;
            for (int k = 0; k < 5; k++) {
                if (!interpolates || rate == 0.0 || threshold == 0.0 ||
                    fabs(cell->target[k] - cell->coeff[k]) <= threshold) {
                    cell->coeff[k] = cell->target[k];
                }
            }
        }
    }
}

// One sample through the whole cascade, for one channel: each active section is the transposed direct form
// II recursion - out = b0 * x + s1, s1 = b1 * x - a1 * out + s2, s2 = b2 * x - a2 * out - and an inactive
// section is skipped without touching its delay. pass_through is the scalar type's answer for a cascade
// with no active section at all, and interpolate says whether the coefficients move toward their targets
// between the samples, which is a single-precision setup's own behaviour.
static inline double CharonBiquadStep(CharonBiquadCell *cells, vDSP_Length channels, vDSP_Length section_count,
                                      double sample, int interpolate, int pass_through)
{
    int active = 0;
    for (vDSP_Length section = 0; section < section_count; section++) {
        CharonBiquadCell *cell = &cells[section * channels];
        double out;
        if (!cell->active) {
            continue;
        }
        active = 1;
        out = cell->coeff[0] * sample + cell->state[0];
        cell->state[0] = cell->coeff[1] * sample - cell->coeff[3] * out + cell->state[1];
        cell->state[1] = cell->coeff[2] * sample - cell->coeff[4] * out;
        sample = out;
    }
    if (!active && !pass_through) {
        // No section of the cascade is active, and a double setup answers zero where a single-precision
        // one answers the input (measured: with every section of a two-section setup inactive and the input
        // 1, 2, 3, 4, vDSP_biquadm answers 1, 2, 3, 4 and vDSP_biquadmD answers 0, 0, 0, 0).
        sample = 0.0;
    }
    if (interpolate) {
        // The snap travels backwards through the cascade. A section's coefficient lands on its target when
        // what is left of the distance is at most interp_threshold **and every section after it has landed
        // too**, which is what makes a cascade walk differently from a section on its own: the last section
        // snaps as soon as its own distance is within the threshold, and one before it waits for that.
        //
        // Measured, and it is what fits all eleven of the review's cases (a rate of 0.25, 0.5 and 0.75, a
        // threshold of 0.1 to 0.5, and two targets that never land on a round number). For instance with two
        // sections going 2 -> 4 and 5 -> 10 at a rate of 0.5 and a threshold of 0.25, the host answers
        // 10, 22.5, 30.625, 35.1562, 37.5391, 40, 40, 40: the first section's own distance reaches the
        // threshold at the third sample but it waits, because the second section's does not, and the two land
        // together at the fifth. A section on its own is this rule with nothing after it, which is the walk
        // 2, 3, 3.5, 4 the one-section case measures (facts/Accelerate/vDSPBiquad.md).
        int later_all_snapped = 1;
        for (vDSP_Length at = section_count; at-- > 0;) {
            CharonBiquadCell *cell = &cells[at * channels];
            int snapped = 1;
            if (!cell->active) {
                continue;
            }
            for (int k = 0; k < 5; k++) {
                cell->coeff[k] += (cell->target[k] - cell->coeff[k]) * (1.0 - cell->rate);
                if (fabs(cell->target[k] - cell->coeff[k]) > cell->threshold) {
                    snapped = 0;
                }
            }
            if (snapped && later_all_snapped) {
                for (int k = 0; k < 5; k++) {
                    cell->coeff[k] = cell->target[k];
                }
            } else {
                later_all_snapped = 0;
            }
        }
    }
    return sample;
}
