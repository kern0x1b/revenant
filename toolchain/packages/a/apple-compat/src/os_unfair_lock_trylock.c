#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) charon_system_trylock;

__attribute__((constructor))
static void charon_resolve_trylock(void)
{
    charon_system_function(&charon_system_trylock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_lock_trylock");
}

__attribute__((visibility("default")))
bool os_unfair_lock_trylock(charon_unfair_lock *lock)
{
    bool (*system)(charon_unfair_lock *) = charon_system_function(&charon_system_trylock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_lock_trylock");
    if (system)
        return system(lock);
    return charon_unfair_trylock(lock, charon_unfair_self());
}
