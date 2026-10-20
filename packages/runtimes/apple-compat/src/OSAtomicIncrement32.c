#include <stdint.h>
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_OSAtomicIncrement32;

__attribute__((constructor))
static void revenant_resolve_OSAtomicIncrement32(void)
{
    revenant_system_function(&revenant_system_OSAtomicIncrement32, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicIncrement32");
}

__attribute__((visibility("default")))
int32_t OSAtomicIncrement32(volatile int32_t *theValue)
{
    int32_t (*system)(volatile int32_t *) = revenant_system_function(&revenant_system_OSAtomicIncrement32, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicIncrement32");
    if (system)
        return system(theValue);
    return __sync_add_and_fetch(theValue, 1);
}
