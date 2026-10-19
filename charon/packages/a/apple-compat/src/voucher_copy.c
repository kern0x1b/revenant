#include "system_function.h"

static _Atomic(uintptr_t) charon_system_voucher_copy;

__attribute__((constructor))
static void charon_resolve_voucher_copy(void)
{
    charon_system_function(&charon_system_voucher_copy, CHARON_LIBDISPATCH, "voucher_copy");
}

__attribute__((visibility("hidden")))
void *voucher_copy(void)
{
    void *(*system)(void) = charon_system_function(&charon_system_voucher_copy, CHARON_LIBDISPATCH, "voucher_copy");
    return system ? system() : NULL;
}
