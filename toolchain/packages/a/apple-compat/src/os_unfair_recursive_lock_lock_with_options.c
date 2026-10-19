#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) revenant_system_recursive_lock;

__attribute__((constructor))
static void revenant_resolve_recursive_lock(void)
{
    revenant_system_function(&revenant_system_recursive_lock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_recursive_lock_lock_with_options");
}

__attribute__((visibility("default")))
void os_unfair_recursive_lock_lock_with_options(revenant_unfair_recursive_lock *lock, uint32_t options)
{
    void (*system)(revenant_unfair_recursive_lock *, uint32_t) =
        revenant_system_function(&revenant_system_recursive_lock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_recursive_lock_lock_with_options");
    if (system) {
        system(lock, options);
        return;
    }
    uint32_t self = revenant_unfair_self();
    if (revenant_unfair_trylock(&lock->lock, self))
        return;
    if ((atomic_load_explicit(&lock->lock.value, memory_order_relaxed) | REVENANT_UNFAIR_NO_WAITERS) == self) {
        lock->count++;
        return;
    }
    revenant_unfair_lock_slow(&lock->lock, self);
}
