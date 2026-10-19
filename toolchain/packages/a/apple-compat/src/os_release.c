#include <stdio.h>
#include <stdlib.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_os_release;

__attribute__((constructor))
static void charon_resolve_os_release(void)
{
    charon_system_function(&charon_system_os_release, CHARON_LIBDISPATCH, "os_release");
}

__attribute__((visibility("hidden")))
void os_release(void *object)
{
    void (*system)(void *) = charon_system_function(&charon_system_os_release, CHARON_LIBDISPATCH, "os_release");
    if (system)
        system(object);
    else if (object) {
        fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: os_release was handed an object on a system without vouchers\n");
        abort();
    }
}
