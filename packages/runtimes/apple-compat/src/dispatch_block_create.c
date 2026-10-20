#include "dispatch_block.h"

static _Atomic(uintptr_t) revenant_system_dispatch_block_create;

__attribute__((constructor))
static void revenant_resolve_dispatch_block_create(void)
{
    revenant_system_function(&revenant_system_dispatch_block_create, REVENANT_LIBDISPATCH, "dispatch_block_create");
}

__attribute__((visibility("hidden")))
dispatch_block_t revenant_dispatch_block_create(dispatch_block_flags_t flags, dispatch_block_t block) __asm("_dispatch_block_create");

dispatch_block_t revenant_dispatch_block_create(dispatch_block_flags_t flags, dispatch_block_t block)
{
    dispatch_block_t (*system)(dispatch_block_flags_t, dispatch_block_t) = revenant_system_function(&revenant_system_dispatch_block_create, REVENANT_LIBDISPATCH, "dispatch_block_create");
    if (system)
        return system(flags, block);
    if (flags & ~(unsigned long)REVENANT_BLOCK_API_MASK)
        return NULL;
    return revenant_block_create(flags, block);
}
