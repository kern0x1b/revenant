#include <stdint.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_OSAtomicDecrement32;

__attribute__((constructor))
static void charon_resolve_OSAtomicDecrement32(void)
{
    charon_system_function(&charon_system_OSAtomicDecrement32, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicDecrement32");
}

/* iOS 7.1.2 brought OSAtomicDecrement32 into libsystem_platform; the held releases before it (7.0.6 and below) have no such call. The system's own
   definition answers when there is one. Otherwise the subtract is one atomic read-modify-write of the word, which is a full
   memory barrier, and the answer is the value after the subtract, as the system's is. */
__attribute__((visibility("default")))
int32_t OSAtomicDecrement32(volatile int32_t *theValue)
{
    int32_t (*system)(volatile int32_t *) = charon_system_function(&charon_system_OSAtomicDecrement32, CHARON_LIBSYSTEM_PLATFORM, "OSAtomicDecrement32");
    if (system)
        return system(theValue);
    return __sync_sub_and_fetch(theValue, 1);
}
