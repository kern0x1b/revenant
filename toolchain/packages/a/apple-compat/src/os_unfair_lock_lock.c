#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) revenant_system_lock;

__attribute__((constructor))
static void revenant_resolve_lock(void)
{
    revenant_system_function(&revenant_system_lock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_lock_lock");
}

__attribute__((visibility("default")))
void os_unfair_lock_lock(revenant_unfair_lock *lock)
{
    void (*system)(revenant_unfair_lock *) = revenant_system_function(&revenant_system_lock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_lock_lock");
    if (system) {
        system(lock);
        return;
    }
    revenant_unfair_lock_lock(lock, revenant_unfair_self());
}
