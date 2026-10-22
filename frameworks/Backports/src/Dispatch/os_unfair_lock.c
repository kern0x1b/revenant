#include <os/lock.h>
#include <pthread.h>
#include <sched.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#define BACKPORT_EXPORT __attribute__((visibility("default")))

static inline uint32_t owner_of_caller(void)
{
    return (uint32_t)pthread_mach_thread_np(pthread_self());
}

BACKPORT_EXPORT void os_unfair_lock_lock(os_unfair_lock_t lock)
{
    uint32_t me = owner_of_caller();
    for (;;) {
        if (__sync_bool_compare_and_swap(&lock->_os_unfair_lock_opaque, 0, me))
            return;
        if (lock->_os_unfair_lock_opaque == me)
            abort();
        sched_yield();
    }
}

BACKPORT_EXPORT bool os_unfair_lock_trylock(os_unfair_lock_t lock)
{
    return __sync_bool_compare_and_swap(&lock->_os_unfair_lock_opaque, 0, owner_of_caller());
}

BACKPORT_EXPORT void os_unfair_lock_unlock(os_unfair_lock_t lock)
{
    if (lock->_os_unfair_lock_opaque != owner_of_caller())
        abort();
    __sync_lock_release(&lock->_os_unfair_lock_opaque);
}

BACKPORT_EXPORT void os_unfair_lock_assert_owner(const os_unfair_lock *lock)
{
    if (lock->_os_unfair_lock_opaque != owner_of_caller())
        abort();
}

BACKPORT_EXPORT void os_unfair_lock_assert_not_owner(const os_unfair_lock *lock)
{
    if (lock->_os_unfair_lock_opaque == owner_of_caller())
        abort();
}
