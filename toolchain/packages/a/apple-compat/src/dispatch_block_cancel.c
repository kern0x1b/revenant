#include "dispatch_block.h"

static _Atomic(uintptr_t) charon_system_dispatch_block_cancel;

__attribute__((constructor))
static void charon_resolve_dispatch_block_cancel(void)
{
    charon_system_function(&charon_system_dispatch_block_cancel, CHARON_LIBDISPATCH, "dispatch_block_cancel");
}

__attribute__((visibility("hidden")))
void charon_dispatch_block_cancel(dispatch_block_t block) __asm("_dispatch_block_cancel");

void charon_dispatch_block_cancel(dispatch_block_t block)
{
    void (*system)(dispatch_block_t) = charon_system_function(&charon_system_dispatch_block_cancel, CHARON_LIBDISPATCH, "dispatch_block_cancel");
    if (system) {
        system(block);
        return;
    }
    struct charon_block_data *data = charon_block_data(block);
    if (!data)
        charon_block_crash("Invalid block object passed to dispatch_block_cancel()", 0);
    charon_block_or(&data->atomic_flags, CHARON_DBF_CANCELED);
}
