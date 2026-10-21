#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) revenant_system_recursive_unlock;

__attribute__((constructor))
static void revenant_resolve_recursive_unlock(void)
{
    revenant_system_function(&revenant_system_recursive_unlock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_recursive_lock_unlock");
}

__attribute__((visibility("default")))
void os_unfair_recursive_lock_unlock(revenant_unfair_recursive_lock *lock)
{
    void (*system)(revenant_unfair_recursive_lock *) =
        revenant_system_function(&revenant_system_recursive_unlock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_recursive_lock_unlock");
    if (system) {
        system(lock);
        return;
    }
    uint32_t self = revenant_unfair_self();
    if (lock->count) {
        uint32_t owner = atomic_load_explicit(&lock->lock.value, memory_order_relaxed) | REVENANT_UNFAIR_NO_WAITERS;
        if (owner != self)
            revenant_unfair_crash("Unlock of an os_unfair_lock not owned by current thread", owner);
        lock->count--;
        return;
    }
    revenant_unfair_unlock(&lock->lock, self);
}
