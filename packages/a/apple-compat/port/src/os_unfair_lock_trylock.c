#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) revenant_system_trylock;

__attribute__((constructor))
static void revenant_resolve_trylock(void)
{
    revenant_system_function(&revenant_system_trylock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_lock_trylock");
}

__attribute__((visibility("default")))
bool os_unfair_lock_trylock(revenant_unfair_lock *lock)
{
    bool (*system)(revenant_unfair_lock *) = revenant_system_function(&revenant_system_trylock, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_lock_trylock");
    if (system)
        return system(lock);
    return revenant_unfair_trylock(lock, revenant_unfair_self());
}
