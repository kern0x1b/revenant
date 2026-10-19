#include <stdint.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_OSAtomicIncrement32;

__attribute__((constructor))
static void charon_resolve_OSAtomicIncrement32(void)
{
    charon_system_function(&charon_system_OSAtomicIncrement32, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicIncrement32");
}

/* iOS 7.1.2 brought OSAtomicIncrement32 into libsystem_platform; the held releases before it (7.0.6 and below) have no such call. The system's own
   definition answers when there is one. Otherwise the add is one atomic read-modify-write of the word, which is a full memory
   barrier, and the answer is the value after the add, as the system's is. */
__attribute__((visibility("default")))
int32_t OSAtomicIncrement32(volatile int32_t *theValue)
{
    int32_t (*system)(volatile int32_t *) = charon_system_function(&charon_system_OSAtomicIncrement32, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicIncrement32");
    if (system)
        return system(theValue);
    return __sync_add_and_fetch(theValue, 1);
}
