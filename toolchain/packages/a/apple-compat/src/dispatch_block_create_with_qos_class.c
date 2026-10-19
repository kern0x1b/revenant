#include "dispatch_block.h"

static inline int revenant_qos_valid(unsigned int qos_class, int relative_priority)
{
    switch (qos_class) {
    case 0x00: case 0x05: case 0x09: case 0x11: case 0x15: case 0x19: case 0x21:
        break;
    default:
        return 0;
    }
    return REVENANT_QOS_MIN_RELATIVE_PRIORITY <= relative_priority && relative_priority <= 0;
}

static _Atomic(uintptr_t) revenant_system_dispatch_block_create_with_qos_class;

__attribute__((constructor))
static void revenant_resolve_dispatch_block_create_with_qos_class(void)
{
    revenant_system_function(&revenant_system_dispatch_block_create_with_qos_class, REVENANT_LIBDISPATCH, "dispatch_block_create_with_qos_class");
}

__attribute__((visibility("hidden")))
dispatch_block_t revenant_dispatch_block_create_with_qos_class(dispatch_block_flags_t flags, dispatch_qos_class_t qos_class, int relative_priority, dispatch_block_t block) __asm("_dispatch_block_create_with_qos_class");

dispatch_block_t revenant_dispatch_block_create_with_qos_class(dispatch_block_flags_t flags, dispatch_qos_class_t qos_class, int relative_priority, dispatch_block_t block)
{
    dispatch_block_t (*system)(dispatch_block_flags_t, dispatch_qos_class_t, int, dispatch_block_t) = revenant_system_function(&revenant_system_dispatch_block_create_with_qos_class, REVENANT_LIBDISPATCH, "dispatch_block_create_with_qos_class");
    if (system)
        return system(flags, qos_class, relative_priority, block);
    if ((flags & ~(unsigned long)REVENANT_BLOCK_API_MASK) || !revenant_qos_valid(qos_class, relative_priority))
        return NULL;
    return revenant_block_create(flags, block);
}
