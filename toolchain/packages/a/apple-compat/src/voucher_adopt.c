#include <stdio.h>
#include <stdlib.h>
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_voucher_adopt;

__attribute__((constructor))
static void revenant_resolve_voucher_adopt(void)
{
    revenant_system_function(&revenant_system_voucher_adopt, REVENANT_LIBDISPATCH, "voucher_adopt");
}

__attribute__((visibility("hidden")))
void *voucher_adopt(void *voucher)
{
    void *(*system)(void *) = revenant_system_function(&revenant_system_voucher_adopt, REVENANT_LIBDISPATCH, "voucher_adopt");
    if (system)
        return system(voucher);
    if (voucher) {
        fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: voucher_adopt was handed a voucher on a system without vouchers\n");
        abort();
    }
    return NULL;
}
