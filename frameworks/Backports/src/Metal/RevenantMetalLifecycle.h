#ifndef REVENANT_METAL_LIFECYCLE_H
#define REVENANT_METAL_LIFECYCLE_H

#include <stdbool.h>

typedef struct {
    unsigned depth;
    unsigned resumptions;
    bool suspended;
} RevenantMetalLifecycle;

static inline bool RevenantMetalLifecycleAcquire(RevenantMetalLifecycle *state)
{
    state->depth++;
    return !state->suspended;
}

static inline bool RevenantMetalLifecycleRelinquish(RevenantMetalLifecycle *state)
{
    if (state->depth == 0)
        return false;
    return --state->depth == 0;
}

static inline bool RevenantMetalLifecycleSuspend(RevenantMetalLifecycle *state)
{
    if (state->suspended)
        return false;
    state->suspended = true;
    return true;
}

static inline bool RevenantMetalLifecycleResume(RevenantMetalLifecycle *state)
{
    if (!state->suspended)
        return false;
    state->suspended = false;
    state->resumptions++;
    return true;
}

#endif
