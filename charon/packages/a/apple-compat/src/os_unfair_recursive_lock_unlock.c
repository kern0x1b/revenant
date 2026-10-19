#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) charon_system_recursive_unlock;

__attribute__((constructor))
static void charon_resolve_recursive_unlock(void)
{
    charon_system_function(&charon_system_recursive_unlock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_recursive_lock_unlock");
}

__attribute__((visibility("default")))
void os_unfair_recursive_lock_unlock(charon_unfair_recursive_lock *lock)
{
    void (*system)(charon_unfair_recursive_lock *) =
        charon_system_function(&charon_system_recursive_unlock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_recursive_lock_unlock");
    if (system) {
        system(lock);
        return;
    }
    uint32_t self = charon_unfair_self();
    if (lock->count) {
        uint32_t owner = atomic_load_explicit(&lock->lock.value, memory_order_relaxed) | CHARON_UNFAIR_NO_WAITERS;
        if (owner != self)
            charon_unfair_crash("Unlock of an os_unfair_lock not owned by current thread", owner);
        lock->count--;
        return;
    }
    charon_unfair_unlock(&lock->lock, self);
}
