#include <stdint.h>
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_OSAtomicDecrement32Barrier;

__attribute__((constructor))
static void revenant_resolve_OSAtomicDecrement32Barrier(void)
{
    revenant_system_function(&revenant_system_OSAtomicDecrement32Barrier, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicDecrement32Barrier");
}

__attribute__((visibility("default")))
int32_t OSAtomicDecrement32Barrier(volatile int32_t *theValue)
{
    int32_t (*system)(volatile int32_t *) = revenant_system_function(&revenant_system_OSAtomicDecrement32Barrier, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicDecrement32Barrier");
    if (system)
        return system(theValue);
    return __sync_sub_and_fetch(theValue, 1);
}
