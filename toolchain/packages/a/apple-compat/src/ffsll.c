#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_ffsll;

__attribute__((constructor))
static void revenant_resolve_ffsll(void)
{
    revenant_system_function(&revenant_system_ffsll, REVENANT_LIBSYSTEM_PLATFORM, "ffsll");
}

__attribute__((visibility("default")))
int ffsll(long long mask)
{
    int (*system)(long long) = revenant_system_function(&revenant_system_ffsll, REVENANT_LIBSYSTEM_PLATFORM, "ffsll");
    if (system)
        return system(mask);
    unsigned long long bits = (unsigned long long)mask;
    return bits == 0 ? 0 : __builtin_ctzll(bits) + 1;
}
