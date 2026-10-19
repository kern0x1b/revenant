#include <stdint.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_OSAtomicDecrement32;

__attribute__((constructor))
static void charon_resolve_OSAtomicDecrement32(void)
{
    charon_system_function(&charon_system_OSAtomicDecrement32, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicDecrement32");
}

__attribute__((visibility("default")))
int32_t OSAtomicDecrement32(volatile int32_t *theValue)
{
    int32_t (*system)(volatile int32_t *) = charon_system_function(&charon_system_OSAtomicDecrement32, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicDecrement32");
    if (system)
        return system(theValue);
    return __sync_sub_and_fetch(theValue, 1);
}
