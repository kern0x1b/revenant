#include <stdint.h>
#include "charon_atomic64.h"
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_OSAtomicIncrement64;

__attribute__((constructor))
static void charon_resolve_OSAtomicIncrement64(void)
{
    charon_system_function(&charon_system_OSAtomicIncrement64, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicIncrement64");
}

/* iOS 7.1 brought OSAtomicIncrement64 into libsystem_platform; iOS 7.0.6 and the releases before it have no such call. The
   system's own definition answers when there is one. Otherwise the add is one 64-bit exclusive read-modify-write, and the
   answer is the value after the add, as the system's is. */
__attribute__((visibility("default")))
int64_t OSAtomicIncrement64(volatile int64_t *theValue)
{
    int64_t (*system)(volatile int64_t *) = charon_system_function(&charon_system_OSAtomicIncrement64, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicIncrement64");
    if (system)
        return system(theValue);
    return charon_atomic_add64(theValue, 1);
}
