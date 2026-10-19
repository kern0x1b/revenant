#include "dispatch_block.h"

static _Atomic(uintptr_t) charon_system_dispatch_block_testcancel;

__attribute__((constructor))
static void charon_resolve_dispatch_block_testcancel(void)
{
    charon_system_function(&charon_system_dispatch_block_testcancel, CHARON_LIBDISPATCH, "dispatch_block_testcancel");
}

__attribute__((visibility("hidden")))
intptr_t charon_dispatch_block_testcancel(dispatch_block_t block) __asm("_dispatch_block_testcancel");

intptr_t charon_dispatch_block_testcancel(dispatch_block_t block)
{
    intptr_t (*system)(dispatch_block_t) = charon_system_function(&charon_system_dispatch_block_testcancel, CHARON_LIBDISPATCH, "dispatch_block_testcancel");
    if (system)
        return system(block);
    struct charon_block_data *data = charon_block_data(block);
    if (!data)
        charon_block_crash("Invalid block object passed to dispatch_block_testcancel()", 0);
    return (data->atomic_flags & CHARON_DBF_CANCELED) != 0;
}
