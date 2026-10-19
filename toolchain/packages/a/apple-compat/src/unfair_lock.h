#ifndef REVENANT_UNFAIR_LOCK_H
#define REVENANT_UNFAIR_LOCK_H

#include <mach/mach.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int __ulock_wait(uint32_t operation, void *address, uint64_t value, uint32_t timeout);
int __ulock_wake(uint32_t operation, void *address, uint64_t value);

enum {
    REVENANT_UNFAIR_NO_OWNER = 0,
    REVENANT_UNFAIR_NO_WAITERS = 1,
    REVENANT_UL_COMPARE_AND_WAIT = 1,
    REVENANT_ULF_WAKE_ALL = 0x100,
};

typedef struct {
    _Atomic(uint32_t) value;
} revenant_unfair_lock;

typedef struct {
    revenant_unfair_lock lock;
    uint32_t count;
} revenant_unfair_recursive_lock;

static inline uint32_t revenant_unfair_owner(uint32_t name)
{
    return name | REVENANT_UNFAIR_NO_WAITERS;
}

static inline uint32_t revenant_unfair_self(void)
{
    return revenant_unfair_owner(pthread_mach_thread_np(pthread_self()));
}

__attribute__((noreturn, cold, unused))
static void revenant_unfair_crash(const char *what, uint32_t value)
{
    fprintf(stderr, "BUG IN CLIENT OF LIBPLATFORM: %s (0x%x)\n", what, value);
    abort();
}

static inline bool revenant_unfair_trylock(revenant_unfair_lock *lock, uint32_t self)
{
    uint32_t unowned = REVENANT_UNFAIR_NO_OWNER;
    return atomic_compare_exchange_strong_explicit(&lock->value, &unowned, self, memory_order_acquire, memory_order_relaxed);
}

static inline void revenant_unfair_lock_slow(revenant_unfair_lock *lock, uint32_t self)
{
    uint32_t waiters = 0;
    for (;;) {
        uint32_t current = atomic_load_explicit(&lock->value, memory_order_relaxed);
        if (current == REVENANT_UNFAIR_NO_OWNER) {
            if (atomic_compare_exchange_weak_explicit(&lock->value, &current, self & ~waiters, memory_order_acquire,
                                                      memory_order_relaxed))
                return;
            continue;
        }
        if ((current | REVENANT_UNFAIR_NO_WAITERS) == self)
            revenant_unfair_crash("Trying to recursively lock an os_unfair_lock", self);
        uint32_t waited = current & ~(uint32_t)REVENANT_UNFAIR_NO_WAITERS;
        if (waited != current && !atomic_compare_exchange_weak_explicit(&lock->value, &current, waited, memory_order_relaxed,
                                                                         memory_order_relaxed))
            continue;
        __ulock_wait(REVENANT_UL_COMPARE_AND_WAIT, lock, waited, 0);
        waiters = REVENANT_UNFAIR_NO_WAITERS;
    }
}

static inline void revenant_unfair_lock_lock(revenant_unfair_lock *lock, uint32_t self)
{
    if (!revenant_unfair_trylock(lock, self))
        revenant_unfair_lock_slow(lock, self);
}

static inline void revenant_unfair_unlock(revenant_unfair_lock *lock, uint32_t self)
{
    uint32_t current = atomic_exchange_explicit(&lock->value, REVENANT_UNFAIR_NO_OWNER, memory_order_release);
    if (current == self)
        return;
    if ((current | REVENANT_UNFAIR_NO_WAITERS) != self)
        revenant_unfair_crash("Unlock of an os_unfair_lock not owned by current thread", current | REVENANT_UNFAIR_NO_WAITERS);
    __ulock_wake(REVENANT_UL_COMPARE_AND_WAIT | REVENANT_ULF_WAKE_ALL, lock, 0);
}

#endif
