#ifndef CHARON_UNFAIR_LOCK_H
#define CHARON_UNFAIR_LOCK_H

#include <mach/mach.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

/* os_unfair_lock as libplatform keeps it (lock.c in libplatform-126 and later): the lock word holds the owner's Mach thread
   port name with its low bit set, and a waiter clears that bit so the owner's unlock knows to wake someone. libplatform takes
   the name as it is, because XNU hands out odd names: the low byte is the entry's generation, which counts 3, 7, 11 and so on
   (400 threads on this machine, all odd). Setting the bit is therefore the same value on a device, and it also holds where a
   name is even, which is what iLEmu gives a thread it starts (0x10c00, 0x11e00, spaced by 0x100, generation zero): there the
   waiter's cleared bit would otherwise be the owner's own value and the unlock would wake nobody. Two live threads whose names
   differ only in that bit would look like one owner, which XNU's odd names and iLEmu's zero generations both rule out.
   The kernel's unfair ulock of iOS 10 is not there to wait on, so a waiter parks in __ulock_wait until the unlock wakes it. Waiters and wakes meet
   in __ulock_wait's table, so every image in a process must reach this one copy: a lock two images take (a Mutex inlined
   into both) would otherwise park in one table and be woken in another. The locks are therefore not linked into each image
   but built into libc++abi, which exports them once for the process. */

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
        /* __ulock_wait cannot say whether others still wait, so the next owner assumes they do and wakes on unlock. */
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
