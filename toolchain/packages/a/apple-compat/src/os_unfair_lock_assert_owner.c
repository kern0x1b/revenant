#include "system_function.h"
#include "unfair_assert.h"

static _Atomic(uintptr_t) revenant_system_assert;

__attribute__((constructor))
static void revenant_resolve_assert(void)
{
    revenant_system_function(&revenant_system_assert, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_lock_assert_owner");
}

__attribute__((visibility("hidden")))
void os_unfair_lock_assert_owner(const revenant_unfair_lock *lock)
{
    void (*system)(const revenant_unfair_lock *) = revenant_system_function(&revenant_system_assert, REVENANT_LIBSYSTEM_PLATFORM, "os_unfair_lock_assert_owner");
    if (system) {
        system(lock);
        return;
    }
    if (!revenant_unfair_holds(lock))
        revenant_unfair_crash("Assertion failed: Lock unexpectedly not owned by current thread", atomic_load_explicit(&lock->value, memory_order_relaxed));
}
