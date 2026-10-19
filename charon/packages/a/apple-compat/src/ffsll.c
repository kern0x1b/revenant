#include "system_function.h"

static _Atomic(uintptr_t) charon_system_ffsll;

__attribute__((constructor))
static void charon_resolve_ffsll(void)
{
    charon_system_function(&charon_system_ffsll, CHARON_LIBSYSTEM_PLATFORM, "ffsll");
}

/* The index, counted from 1, of the least significant set bit of the mask, and 0 for a mask with no bit set. iOS 7.0.6 has
   ffsll in libsystem_platform, and the held releases before it (6.1.6 and below) have none, so the system's answers when it is there. */
__attribute__((visibility("default")))
int ffsll(long long mask)
{
    int (*system)(long long) = charon_system_function(&charon_system_ffsll, CHARON_LIBSYSTEM_PLATFORM, "ffsll");
    if (system)
        return system(mask);
    unsigned long long bits = (unsigned long long)mask;
    return bits == 0 ? 0 : __builtin_ctzll(bits) + 1;
}
