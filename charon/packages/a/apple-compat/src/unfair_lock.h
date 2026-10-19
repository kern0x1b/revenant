#ifndef CHARON_UNFAIR_LOCK_H
#define CHARON_UNFAIR_LOCK_H

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
    CHARON_UNFAIR_NO_OWNER = 0,
    CHARON_UNFAIR_NO_WAITERS = 1,
    CHARON_UL_COMPARE_AND_WAIT = 1,
    CHARON_ULF_WAKE_ALL = 0x100,
};

typedef struct {
    _Atomic(uint32_t) value;
} charon_unfair_lock;

typedef struct {
    charon_unfair_lock lock;
    uint32_t count;
} charon_unfair_recursive_lock;

static inline uint32_t charon_unfair_owner(uint32_t name)
{
    return name | CHARON_UNFAIR_NO_WAITERS;
}

static inline uint32_t charon_unfair_self(void)
{
    return charon_unfair_owner(pthread_mach_thread_np(pthread_self()));
}

__attribute__((noreturn, cold, unused))
static void charon_unfair_crash(const char *what, uint32_t value)
{
    fprintf(stderr, "BUG IN CLIENT OF LIBPLATFORM: %s (0x%x)\n", what, value);
    abort();
}

static inline bool charon_unfair_trylock(charon_unfair_lock *lock, uint32_t self)
{
    uint32_t unowned = CHARON_UNFAIR_NO_OWNER;
    return atomic_compare_exchange_strong_explicit(&lock->value, &unowned, self, memory_order_acquire, memory_order_relaxed);
}

static inline void charon_unfair_lock_slow(charon_unfair_lock *lock, uint32_t self)
{
    uint32_t waiters = 0;
    for (;;) {
        uint32_t current = atomic_load_explicit(&lock->value, memory_order_relaxed);
        if (current == CHARON_UNFAIR_NO_OWNER) {
            if (atomic_compare_exchange_weak_explicit(&lock->value, &current, self & ~waiters, memory_order_acquire,
                                                      memory_order_relaxed))
                return;
            continue;
        }
        if ((current | CHARON_UNFAIR_NO_WAITERS) == self)
            charon_unfair_crash("Trying to recursively lock an os_unfair_lock", self);
        uint32_t waited = current & ~(uint32_t)CHARON_UNFAIR_NO_WAITERS;
        if (waited != current && !atomic_compare_exchange_weak_explicit(&lock->value, &current, waited, memory_order_relaxed,
                                                                         memory_order_relaxed))
            continue;
        __ulock_wait(CHARON_UL_COMPARE_AND_WAIT, lock, waited, 0);
        waiters = CHARON_UNFAIR_NO_WAITERS;
    }
}

static inline void charon_unfair_lock_lock(charon_unfair_lock *lock, uint32_t self)
{
    if (!charon_unfair_trylock(lock, self))
        charon_unfair_lock_slow(lock, self);
}

static inline void charon_unfair_unlock(charon_unfair_lock *lock, uint32_t self)
{
    uint32_t current = atomic_exchange_explicit(&lock->value, CHARON_UNFAIR_NO_OWNER, memory_order_release);
    if (current == self)
        return;
    if ((current | CHARON_UNFAIR_NO_WAITERS) != self)
        charon_unfair_crash("Unlock of an os_unfair_lock not owned by current thread", current | CHARON_UNFAIR_NO_WAITERS);
    __ulock_wake(CHARON_UL_COMPARE_AND_WAIT | CHARON_ULF_WAKE_ALL, lock, 0);
}

#endif
