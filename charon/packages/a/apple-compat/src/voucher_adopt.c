#include <stdio.h>
#include <stdlib.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_voucher_adopt;

__attribute__((constructor))
static void charon_resolve_voucher_adopt(void)
{
    charon_system_function(&charon_system_voucher_adopt, CHARON_LIBDISPATCH, "voucher_adopt");
}

__attribute__((visibility("hidden")))
void *voucher_adopt(void *voucher)
{
    void *(*system)(void *) = charon_system_function(&charon_system_voucher_adopt, CHARON_LIBDISPATCH, "voucher_adopt");
    if (system)
        return system(voucher);
    if (voucher) {
        fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: voucher_adopt was handed a voucher on a system without vouchers\n");
        abort();
    }
    return NULL;
}
