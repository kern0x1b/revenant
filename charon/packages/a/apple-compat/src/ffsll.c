#include "system_function.h"

static _Atomic(uintptr_t) charon_system_ffsll;

__attribute__((constructor))
static void charon_resolve_ffsll(void)
{
    charon_system_function(&charon_system_ffsll, CHARON_LIBSYSTEM_PLATFORM, "ffsll");
}

__attribute__((visibility("default")))
int ffsll(long long mask)
{
    int (*system)(long long) = charon_system_function(&charon_system_ffsll, CHARON_LIBSYSTEM_PLATFORM, "ffsll");
    if (system)
        return system(mask);
    unsigned long long bits = (unsigned long long)mask;
    return bits == 0 ? 0 : __builtin_ctzll(bits) + 1;
}
