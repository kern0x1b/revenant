#include <stdint.h>
#include "revenant_atomic64.h"
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_OSAtomicDecrement64Barrier;

__attribute__((constructor))
static void revenant_resolve_OSAtomicDecrement64Barrier(void)
{
    revenant_system_function(&revenant_system_OSAtomicDecrement64Barrier, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicDecrement64Barrier");
}

__attribute__((visibility("default")))
int64_t OSAtomicDecrement64Barrier(volatile int64_t *theValue)
{
    int64_t (*system)(volatile int64_t *) = revenant_system_function(&revenant_system_OSAtomicDecrement64Barrier, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicDecrement64Barrier");
    if (system)
        return system(theValue);
    return revenant_atomic_add64(theValue, -1);
}
