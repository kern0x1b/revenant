#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) charon_system_unlock;

__attribute__((constructor))
static void charon_resolve_unlock(void)
{
    charon_system_function(&charon_system_unlock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_lock_unlock");
}

__attribute__((visibility("default")))
void os_unfair_lock_unlock(charon_unfair_lock *lock)
{
    void (*system)(charon_unfair_lock *) = charon_system_function(&charon_system_unlock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_lock_unlock");
    if (system) {
        system(lock);
        return;
    }
    charon_unfair_unlock(lock, charon_unfair_self());
}
