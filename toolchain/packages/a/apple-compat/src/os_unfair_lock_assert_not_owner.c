#include "system_function.h"
#include "unfair_assert.h"

static _Atomic(uintptr_t) charon_system_assert;

__attribute__((constructor))
static void charon_resolve_assert(void)
{
    charon_system_function(&charon_system_assert, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_lock_assert_not_owner");
}

__attribute__((visibility("hidden")))
void os_unfair_lock_assert_not_owner(const charon_unfair_lock *lock)
{
    void (*system)(const charon_unfair_lock *) = charon_system_function(&charon_system_assert, CHARON_LIBSYSTEM_PLATFORM, "os_unfair_lock_assert_not_owner");
    if (system) {
        system(lock);
        return;
    }
    if (charon_unfair_holds(lock))
        charon_unfair_crash("Assertion failed: Lock unexpectedly owned by current thread", atomic_load_explicit(&lock->value, memory_order_relaxed));
}
