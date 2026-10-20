#pragma once

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct RevenantBiquadCommon {
    vDSP_Length sections;
    vDSP_Length channels;
    int interpolates;
} RevenantBiquadCommon;

typedef struct RevenantBiquadCell {
    double coeff[5];
    double target[5];
    double rate;
    double threshold;
    double state[2];
    int active;
} RevenantBiquadCell;

struct vDSP_biquadm_SetupStruct {
    RevenantBiquadCommon common;
    RevenantBiquadCell cell[1];
};

struct vDSP_biquadm_SetupStructD {
    RevenantBiquadCommon common;
    RevenantBiquadCell cell[1];
};

static inline RevenantBiquadCell *RevenantBiquadCells(void *setup)
{
    return (RevenantBiquadCell *)((char *)setup + sizeof(RevenantBiquadCommon));
}

static inline RevenantBiquadCell *RevenantBiquadCellOf(void *setup, vDSP_Length section, vDSP_Length channel)
{
    RevenantBiquadCommon *common = (RevenantBiquadCommon *)setup;
    if (section >= common->sections || channel >= common->channels) {
        return NULL;
    }
    return &RevenantBiquadCells(setup)[section * common->channels + channel];
}

static inline vDSP_Length RevenantBiquadSections(const void *setup)
{
    return ((const RevenantBiquadCommon *)setup)->sections;
}

static inline vDSP_Length RevenantBiquadChannels(const void *setup)
{
    return ((const RevenantBiquadCommon *)setup)->channels;
}

static inline void *RevenantBiquadCreate(const double *coefficients, vDSP_Length sections, vDSP_Length channels,
                                       int interpolates)
{
    vDSP_Length count = sections * channels;
    struct vDSP_biquadm_SetupStruct *setup;
    if (!coefficients || (sections != 0 && channels != 0 && count > (vDSP_Length)-1 / channels)) {
        return NULL;
    }
    setup = (struct vDSP_biquadm_SetupStruct *)calloc(1, sizeof(RevenantBiquadCommon) +
                                                             (size_t)count * sizeof(RevenantBiquadCell));
    if (!setup) {
        return NULL;
    }
    setup->common.sections = sections;
    setup->common.channels = channels;
    for (vDSP_Length at = 0; at < count; at++) {
        RevenantBiquadCell *cell = &RevenantBiquadCells(setup)[at];
        for (int k = 0; k < 5; k++) {
            cell->coeff[k] = coefficients[at * 5 + k];
            cell->target[k] = cell->coeff[k];
        }
        cell->active = 1;
    }
    ((RevenantBiquadCommon *)setup)->interpolates = interpolates;
    return setup;
}

static inline void RevenantBiquadDestroy(void *setup)
{
    free(setup);
}

static inline void RevenantBiquadResetState(void *setup)
{
    vDSP_Length count = RevenantBiquadSections(setup) * RevenantBiquadChannels(setup);
    for (vDSP_Length at = 0; at < count; at++) {
        RevenantBiquadCell *cell = &RevenantBiquadCells(setup)[at];
        cell->state[0] = 0.0;
        cell->state[1] = 0.0;
    }
}

static inline void RevenantBiquadCopyState(void *destination, const void *source)
{
    vDSP_Length from = RevenantBiquadSections(source) * RevenantBiquadChannels(source);
    vDSP_Length to = RevenantBiquadSections(destination) * RevenantBiquadChannels(destination);
    vDSP_Length count = from < to ? from : to;
    for (vDSP_Length at = 0; at < count; at++) {
        RevenantBiquadCell *into = &RevenantBiquadCells(destination)[at];
        const RevenantBiquadCell *from_cell = &RevenantBiquadCells((void *)source)[at];
        into->state[0] = from_cell->state[0];
        into->state[1] = from_cell->state[1];
    }
}

static inline void RevenantBiquadSetActive(void *setup, const bool *states)
{
    vDSP_Length sections = RevenantBiquadSections(setup);
    vDSP_Length channels = RevenantBiquadChannels(setup);
    for (vDSP_Length section = 0; section < sections; section++) {
        int active = states[section] ? 1 : 0;
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            RevenantBiquadCell *cell = RevenantBiquadCellOf(setup, section, channel);
            if (cell) {
                cell->active = active;
            }
        }
    }
}

#define REVENANT_BIQUAD_WINDOW(values, section, channel, sections) (values) + ((section) * (channels) + (channel)) * 5

static inline void RevenantBiquadSetCoefficients(void *setup, const double *values, vDSP_Length start_section,
                                               vDSP_Length start_channel, vDSP_Length sections,
                                               vDSP_Length channels)
{
    for (vDSP_Length section = 0; section < sections; section++) {
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            RevenantBiquadCell *cell = RevenantBiquadCellOf(setup, start_section + section, start_channel + channel);
            const double *block = REVENANT_BIQUAD_WINDOW(values, section, channel, sections);
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

static inline void RevenantBiquadSetCoefficientsFloat(void *setup, const float *values, vDSP_Length start_section,
                                                    vDSP_Length start_channel, vDSP_Length sections,
                                                    vDSP_Length channels)
{
    for (vDSP_Length section = 0; section < sections; section++) {
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            RevenantBiquadCell *cell = RevenantBiquadCellOf(setup, start_section + section, start_channel + channel);
            const float *block = REVENANT_BIQUAD_WINDOW(values, section, channel, sections);
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

static inline void RevenantBiquadSetTargets(void *setup, const double *values, double rate, double threshold,
                                          vDSP_Length start_section, vDSP_Length start_channel, vDSP_Length sections,
                                          vDSP_Length channels)
{
    int interpolates = ((RevenantBiquadCommon *)setup)->interpolates;
    for (vDSP_Length section = 0; section < sections; section++) {
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            RevenantBiquadCell *cell = RevenantBiquadCellOf(setup, start_section + section, start_channel + channel);
            const double *block = REVENANT_BIQUAD_WINDOW(values, section, channel, sections);
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

static inline void RevenantBiquadSetTargetsFloat(void *setup, const float *values, double rate, double threshold,
                                               vDSP_Length start_section, vDSP_Length start_channel,
                                               vDSP_Length sections, vDSP_Length channels)
{
    int interpolates = ((RevenantBiquadCommon *)setup)->interpolates;
    for (vDSP_Length section = 0; section < sections; section++) {
        for (vDSP_Length channel = 0; channel < channels; channel++) {
            RevenantBiquadCell *cell = RevenantBiquadCellOf(setup, start_section + section, start_channel + channel);
            const float *block = REVENANT_BIQUAD_WINDOW(values, section, channel, sections);
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

static inline double RevenantBiquadStep(RevenantBiquadCell *cells, vDSP_Length channels, vDSP_Length section_count,
                                      double sample, int interpolate, int pass_through)
{
    int active = 0;
    for (vDSP_Length section = 0; section < section_count; section++) {
        RevenantBiquadCell *cell = &cells[section * channels];
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
            RevenantBiquadCell *cell = &cells[at * channels];
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
