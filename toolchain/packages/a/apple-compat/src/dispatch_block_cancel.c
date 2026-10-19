#include "dispatch_block.h"

static _Atomic(uintptr_t) revenant_system_dispatch_block_cancel;

__attribute__((constructor))
static void revenant_resolve_dispatch_block_cancel(void)
{
    revenant_system_function(&revenant_system_dispatch_block_cancel, REVENANT_LIBDISPATCH, "dispatch_block_cancel");
}

__attribute__((visibility("hidden")))
void revenant_dispatch_block_cancel(dispatch_block_t block) __asm("_dispatch_block_cancel");

void revenant_dispatch_block_cancel(dispatch_block_t block)
{
    void (*system)(dispatch_block_t) = revenant_system_function(&revenant_system_dispatch_block_cancel, REVENANT_LIBDISPATCH, "dispatch_block_cancel");
    if (system) {
        system(block);
        return;
    }
    struct revenant_block_data *data = revenant_block_data(block);
    if (!data)
        revenant_block_crash("Invalid block object passed to dispatch_block_cancel()", 0);
    revenant_block_or(&data->atomic_flags, REVENANT_DBF_CANCELED);
}
