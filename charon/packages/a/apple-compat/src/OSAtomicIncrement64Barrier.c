#include <stdint.h>
#include "charon_atomic64.h"
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_OSAtomicIncrement64Barrier;

__attribute__((constructor))
static void charon_resolve_OSAtomicIncrement64Barrier(void)
{
    charon_system_function(&charon_system_OSAtomicIncrement64Barrier, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicIncrement64Barrier");
}

/* The barrier variant of OSAtomicIncrement64, which iOS 7.1 brought with it. The exclusive loop is bracketed by dmb, so the
   answer and the barrier are those of the variant without one: the value after the add. */
__attribute__((visibility("default")))
int64_t OSAtomicIncrement64Barrier(volatile int64_t *theValue)
{
    int64_t (*system)(volatile int64_t *) = charon_system_function(&charon_system_OSAtomicIncrement64Barrier, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicIncrement64Barrier");
    if (system)
        return system(theValue);
    return charon_atomic_add64(theValue, 1);
}
