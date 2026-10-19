#ifndef CHARON_UNFAIR_ASSERT_H
#define CHARON_UNFAIR_ASSERT_H

#include "unfair_lock.h"

static inline bool charon_unfair_holds(const charon_unfair_lock *lock)
{
    uint32_t current = atomic_load_explicit(&lock->value, memory_order_relaxed);
    return current != CHARON_UNFAIR_NO_OWNER && ((current ^ charon_unfair_self()) & ~(uint32_t)CHARON_UNFAIR_NO_WAITERS) == 0;
}

#endif
