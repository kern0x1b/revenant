#include "system_function.h"

static _Atomic(uintptr_t) charon_system_rpmatch;

__attribute__((constructor))
static void charon_resolve_rpmatch(void)
{
    charon_system_function(&charon_system_rpmatch, CHARON_LIBSYSTEM, "rpmatch");
}

/* 1 for a response that begins with y or Y, 0 for one that begins with n or N, and -1 for anything else, the answers of the
   C locale's affirmative and negative expressions. A NULL response is -1: the host segfaults on it (measured), and an API must
   not crash its caller, so this is the one place the shim answers differently from the host. iOS 13.4 is the first held arm64
   cache that exports it, and the SDK names iOS 13.0; the system's answers when it is there. */
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
