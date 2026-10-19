#include <stdint.h>
#include "revenant_atomic64.h"
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_OSAtomicDecrement64;

__attribute__((constructor))
static void revenant_resolve_OSAtomicDecrement64(void)
{
    revenant_system_function(&revenant_system_OSAtomicDecrement64, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicDecrement64");
}

__attribute__((visibility("default")))
int64_t OSAtomicDecrement64(volatile int64_t *theValue)
{
    int64_t (*system)(volatile int64_t *) = revenant_system_function(&revenant_system_OSAtomicDecrement64, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicDecrement64");
    if (system)
        return system(theValue);
    return revenant_atomic_add64(theValue, -1);
}
