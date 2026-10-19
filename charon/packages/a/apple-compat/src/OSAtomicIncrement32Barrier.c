#include <stdint.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_OSAtomicIncrement32Barrier;

__attribute__((constructor))
static void charon_resolve_OSAtomicIncrement32Barrier(void)
{
    charon_system_function(&charon_system_OSAtomicIncrement32Barrier, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicIncrement32Barrier");
}

/* The barrier variant of OSAtomicIncrement32, which iOS 7.1.2 brought with it. The read-modify-write below is already a full
   barrier, so the answer is the same as the variant without one: the value after the add. */
__attribute__((visibility("default")))
int32_t OSAtomicIncrement32Barrier(volatile int32_t *theValue)
{
    int32_t (*system)(volatile int32_t *) = charon_system_function(&charon_system_OSAtomicIncrement32Barrier, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicIncrement32Barrier");
    if (system)
        return system(theValue);
    return __sync_add_and_fetch(theValue, 1);
}
