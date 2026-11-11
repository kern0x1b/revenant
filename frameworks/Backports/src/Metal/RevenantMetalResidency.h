#ifndef REVENANT_METAL_RESIDENCY_H
#define REVENANT_METAL_RESIDENCY_H

#include <stdbool.h>

typedef enum {
    RevenantMetalResidencyReadback,
    RevenantMetalResidencySurface,
    RevenantMetalResidencyImage,
    RevenantMetalResidencyLost
} RevenantMetalResidencyPlan;

static inline RevenantMetalResidencyPlan RevenantMetalResidencyPlanFor(bool surface, bool image, bool depth, unsigned channelBytes)
{
    if (surface)
        return RevenantMetalResidencySurface;
    if (image)
        return RevenantMetalResidencyImage;
    if (depth || channelBytes != 1)
        return RevenantMetalResidencyLost;
    return RevenantMetalResidencyReadback;
}

static inline bool RevenantMetalGenerationIsCurrent(unsigned long made, unsigned long current)
{
    return made == current;
}

#endif
