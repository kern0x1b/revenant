#include <stdint.h>
#include "revenant_atomic64.h"
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_OSAtomicIncrement64;

__attribute__((constructor))
static void revenant_resolve_OSAtomicIncrement64(void)
{
    revenant_system_function(&revenant_system_OSAtomicIncrement64, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicIncrement64");
}

__attribute__((visibility("default")))
int64_t OSAtomicIncrement64(volatile int64_t *theValue)
{
    int64_t (*system)(volatile int64_t *) = revenant_system_function(&revenant_system_OSAtomicIncrement64, REVENANT_LIBSYSTEM_PLATFORM, "OSAtomicIncrement64");
    if (system)
        return system(theValue);
    return revenant_atomic_add64(theValue, 1);
}
