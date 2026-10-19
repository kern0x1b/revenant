#include "system_function.h"

static _Atomic(uintptr_t) charon_system_voucher_copy;

__attribute__((constructor))
static void charon_resolve_voucher_copy(void)
{
    charon_system_function(&charon_system_voucher_copy, CHARON_LIBDISPATCH, "voucher_copy");
}

/* Vouchers arrived in iOS 8 (libdispatch-442). Before, no thread carries one, so the current voucher is none, as Swift's own
   VoucherShims.h answers where there are no vouchers. */
__attribute__((visibility("hidden")))
void *voucher_copy(void)
{
    void *(*system)(void) = charon_system_function(&charon_system_voucher_copy, CHARON_LIBDISPATCH, "voucher_copy");
    return system ? system() : NULL;
}
