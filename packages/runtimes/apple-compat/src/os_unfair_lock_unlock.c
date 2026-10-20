#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) revenant_system_unlock;

__attribute__((constructor))
static void revenant_resolve_unlock(void)
{
    revenant_system_function(&revenant_system_unlock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_lock_unlock");
}

__attribute__((visibility("default")))
void os_unfair_lock_unlock(revenant_unfair_lock *lock)
{
    void (*system)(revenant_unfair_lock *) = revenant_system_function(&revenant_system_unlock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_lock_unlock");
    if (system) {
        system(lock);
        return;
    }
    revenant_unfair_unlock(lock, revenant_unfair_self());
}
