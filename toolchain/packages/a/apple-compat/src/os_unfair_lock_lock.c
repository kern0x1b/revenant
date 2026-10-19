#include "system_function.h"
#include "unfair_lock.h"

static _Atomic(uintptr_t) charon_system_lock;

__attribute__((constructor))
static void charon_resolve_lock(void)
{
    charon_system_function(&charon_system_lock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_lock_lock");
}

__attribute__((visibility("default")))
void os_unfair_lock_lock(charon_unfair_lock *lock)
{
    void (*system)(charon_unfair_lock *) = charon_system_function(&charon_system_lock, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_lock_lock");
    if (system) {
        system(lock);
        return;
    }
    charon_unfair_lock_lock(lock, charon_unfair_self());
}
