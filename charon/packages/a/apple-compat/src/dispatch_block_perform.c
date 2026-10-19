#include "dispatch_block.h"

static _Atomic(uintptr_t) charon_system_dispatch_block_perform;

__attribute__((constructor))
static void charon_resolve_dispatch_block_perform(void)
{
    charon_system_function(&charon_system_dispatch_block_perform, CHARON_LIBDISPATCH, "dispatch_block_perform");
}

__attribute__((visibility("hidden")))
void charon_dispatch_block_perform(dispatch_block_flags_t flags, dispatch_block_t block) __asm("_dispatch_block_perform");

void charon_dispatch_block_perform(dispatch_block_flags_t flags, dispatch_block_t block)
{
    void (*system)(dispatch_block_flags_t, dispatch_block_t) = charon_system_function(&charon_system_dispatch_block_perform, CHARON_LIBDISPATCH, "dispatch_block_perform");
    if (system) {
        system(flags, block);
        return;
    }
    if (flags & ~(unsigned long)CHARON_BLOCK_API_MASK)
        charon_block_crash("Invalid flags passed to dispatch_block_perform()", flags);
    struct charon_block_data data;
    memset(&data, 0, sizeof(data));
    data.magic = CHARON_BLOCK_MAGIC;
    data.flags = flags;
    data.atomic_flags = CHARON_DBF_PERFORM;
    data.block = block;
    charon_block_invoke_direct(&data);
}
