#ifndef REVENANT_METAL_GRID_H
#define REVENANT_METAL_GRID_H

#include <stddef.h>

static inline size_t RevenantMetalGroupCount(size_t grid, size_t threads)
{
    return grid / threads + (grid % threads != 0);
}

static inline size_t RevenantMetalGroupExtent(size_t grid, size_t threads, size_t group)
{
    size_t remaining = grid - group * threads;
    return remaining < threads ? remaining : threads;
}

#endif
