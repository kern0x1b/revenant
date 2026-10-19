#include "dispatch_block.h"

static _Atomic(uintptr_t) charon_system_dispatch_block_create;

__attribute__((constructor))
static void charon_resolve_dispatch_block_create(void)
{
    charon_system_function(&charon_system_dispatch_block_create, CHARON_LIBDISPATCH, "dispatch_block_create");
}

__attribute__((visibility("hidden")))
dispatch_block_t charon_dispatch_block_create(dispatch_block_flags_t flags, dispatch_block_t block) __asm("_dispatch_block_create");

dispatch_block_t charon_dispatch_block_create(dispatch_block_flags_t flags, dispatch_block_t block)
{
    dispatch_block_t (*system)(dispatch_block_flags_t, dispatch_block_t) = charon_system_function(&charon_system_dispatch_block_create, CHARON_LIBDISPATCH, "dispatch_block_create");
    if (system)
        return system(flags, block);
    if (flags & ~(unsigned long)CHARON_BLOCK_API_MASK)
        return NULL;
    return charon_block_create(flags, block);
}
