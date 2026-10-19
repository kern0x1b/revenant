#include "dispatch_block.h"

static _Atomic(uintptr_t) revenant_system_dispatch_block_testcancel;

__attribute__((constructor))
static void revenant_resolve_dispatch_block_testcancel(void)
{
    revenant_system_function(&revenant_system_dispatch_block_testcancel, REVENANT_LIBDISPATCH, "dispatch_block_testcancel");
}

__attribute__((visibility("hidden")))
intptr_t revenant_dispatch_block_testcancel(dispatch_block_t block) __asm("_dispatch_block_testcancel");

intptr_t revenant_dispatch_block_testcancel(dispatch_block_t block)
{
    intptr_t (*system)(dispatch_block_t) = revenant_system_function(&revenant_system_dispatch_block_testcancel, REVENANT_LIBDISPATCH, "dispatch_block_testcancel");
    if (system)
        return system(block);
    struct revenant_block_data *data = revenant_block_data(block);
    if (!data)
        revenant_block_crash("Invalid block object passed to dispatch_block_testcancel()", 0);
    return (data->atomic_flags & REVENANT_DBF_CANCELED) != 0;
}
