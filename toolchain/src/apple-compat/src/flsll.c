#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_flsll;

__attribute__((constructor))
static void revenant_resolve_flsll(void)
{
    revenant_system_function(&revenant_system_flsll, REVENANT_LIBSYSTEM_PLATFORM, "flsll");
}

__attribute__((visibility("default")))
int flsll(long long mask)
{
    int (*system)(long long) = revenant_system_function(&revenant_system_flsll, REVENANT_LIBSYSTEM_PLATFORM, "flsll");
    if (system)
        return system(mask);
    unsigned long long bits = (unsigned long long)mask;
    return bits == 0 ? 0 : 64 - __builtin_clzll(bits);
}
