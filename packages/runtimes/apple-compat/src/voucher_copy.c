#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_voucher_copy;

__attribute__((constructor))
static void revenant_resolve_voucher_copy(void)
{
    revenant_system_function(&revenant_system_voucher_copy, REVENANT_LIBDISPATCH, "voucher_copy");
}

__attribute__((visibility("hidden")))
void *voucher_copy(void)
{
    void *(*system)(void) = revenant_system_function(&revenant_system_voucher_copy, REVENANT_LIBDISPATCH, "voucher_copy");
    return system ? system() : NULL;
}
