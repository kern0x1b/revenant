#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) charon_system_recursive_lock;

__attribute__((constructor))
static void charon_resolve_recursive_lock(void)
{
    charon_system_function(&charon_system_recursive_lock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_recursive_lock_lock_with_options");
}

/* The options of libplatform (data synchronization, adaptive spin) tune the kernel's wait, which is not there; a lock taken
   with any of them is taken the same way. */
__attribute__((visibility("default")))
void os_unfair_recursive_lock_lock_with_options(charon_unfair_recursive_lock *lock, uint32_t options)
{
    void (*system)(charon_unfair_recursive_lock *, uint32_t) =
        charon_system_function(&charon_system_recursive_lock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_recursive_lock_lock_with_options");
    if (system) {
        system(lock, options);
        return;
    }
    uint32_t self = charon_unfair_self();
    if (charon_unfair_trylock(&lock->lock, self))
        return;
    if ((atomic_load_explicit(&lock->lock.value, memory_order_relaxed) | CHARON_UNFAIR_NO_WAITERS) == self) {
        lock->count++;
        return;
    }
    charon_unfair_lock_slow(&lock->lock, self);
}
