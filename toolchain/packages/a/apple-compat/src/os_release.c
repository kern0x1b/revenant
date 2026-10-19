#include <stdio.h>
#include <stdlib.h>
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_os_release;

__attribute__((constructor))
static void revenant_resolve_os_release(void)
{
    revenant_system_function(&revenant_system_os_release, REVENANT_LIBDISPATCH, "os_release");
}

__attribute__((visibility("hidden")))
void os_release(void *object)
{
    void (*system)(void *) = revenant_system_function(&revenant_system_os_release, REVENANT_LIBDISPATCH, "os_release");
    if (system)
        system(object);
    else if (object) {
        fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: os_release was handed an object on a system without vouchers\n");
        abort();
    }
}
