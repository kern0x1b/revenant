#ifndef REVENANT_UNFAIR_ASSERT_H
#define REVENANT_UNFAIR_ASSERT_H

#include "unfair_lock.h"

static inline bool revenant_unfair_holds(const revenant_unfair_lock *lock)
{
    uint32_t current = atomic_load_explicit(&lock->value, memory_order_relaxed);
    return current != REVENANT_UNFAIR_NO_OWNER && ((current ^ revenant_unfair_self()) & ~(uint32_t)REVENANT_UNFAIR_NO_WAITERS) == 0;
}

#endif
