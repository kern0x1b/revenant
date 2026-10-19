#include "system_function.h"

static _Atomic(uintptr_t) charon_system_flsll;

__attribute__((constructor))
static void charon_resolve_flsll(void)
{
    charon_system_function(&charon_system_flsll, CHARON_LIBSYSTEM_PLATFORM, "flsll");
}

__attribute__((visibility("default")))
int flsll(long long mask)
{
    int (*system)(long long) = charon_system_function(&charon_system_flsll, CHARON_LIBSYSTEM_PLATFORM, "flsll");
    if (system)
        return system(mask);
    unsigned long long bits = (unsigned long long)mask;
    return bits == 0 ? 0 : 64 - __builtin_clzll(bits);
}
