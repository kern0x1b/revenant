#pragma once

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct CharonBiquadCommon {
    vDSP_Length sections;
    vDSP_Length channels;
    int interpolates;
} CharonBiquadCommon;

typedef struct CharonBiquadCell {
    double coeff[5];
    double target[5];
    double rate;
    double threshold;
    double state[2];
    int active;
} CharonBiquadCell;

struct vDSP_biquadm_SetupStruct {
    CharonBiquadCommon common;
    CharonBiquadCell cell[1];
};

struct vDSP_biquadm_SetupStructD {
    CharonBiquadCommon common;
    CharonBiquadCell cell[1];
};

static inline CharonBiquadCell *CharonBiquadCells(void *setup)
{
    return (CharonBiquadCell *)((char *)setup + sizeof(CharonBiquadCommon));
}

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
                cell->coeff[k] = block[k];
                cell->target[k] = block[k];
            }
        }
    }
}

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
            for (int k = 0; k < 5; k++) {
                if (!interpolates || rate == 0.0 || threshold == 0.0 ||
                    fabs(cell->target[k] - cell->coeff[k]) <= threshold) {
                    cell->coeff[k] = cell->target[k];
                }
            }
        }
    }
}

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
        sample = 0.0;
    }
    if (interpolate) {
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
