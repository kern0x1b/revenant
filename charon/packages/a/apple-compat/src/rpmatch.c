#include "system_function.h"

static _Atomic(uintptr_t) charon_system_rpmatch;

__attribute__((constructor))
static void charon_resolve_rpmatch(void)
{
    charon_system_function(&charon_system_rpmatch, CHARON_LIBSYSTEM, "rpmatch");
}

__attribute__((visibility("default")))
int rpmatch(const char *response)
{
    int (*system)(const char *) = charon_system_function(&charon_system_rpmatch, CHARON_LIBSYSTEM, "rpmatch");
    if (system && response != NULL)
        return system(response);
    if (response == NULL)
        return -1;
    switch (response[0]) {
    case 'y':
    case 'Y':
        return 1;
    case 'n':
    case 'N':
        return 0;
    default:
        return -1;
    }
}
