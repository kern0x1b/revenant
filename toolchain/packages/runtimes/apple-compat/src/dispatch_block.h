#ifndef REVENANT_DISPATCH_BLOCK_H
#define REVENANT_DISPATCH_BLOCK_H

#include <Block.h>
#include <dispatch/dispatch.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "system_function.h"

enum {
    REVENANT_BLOCK_MAGIC = 0xD159B10C,
    REVENANT_BLOCK_API_MASK = 0xff,
    REVENANT_BLOCK_BARRIER = 1u,
    REVENANT_DBF_CANCELED = 1u,
    REVENANT_DBF_WAITING = 2u,
    REVENANT_DBF_WAITED = 4u,
    REVENANT_DBF_PERFORM = 8u,
    REVENANT_BLOCK_HAS_COPY_DISPOSE = 1 << 25,
    REVENANT_BLOCK_NEEDS_FREE = 1 << 24,
    REVENANT_QOS_MIN_RELATIVE_PRIORITY = -15,
};

struct revenant_block_descriptor {
    unsigned long reserved;
    unsigned long size;
    void (*copy)(void *, const void *);
    void (*dispose)(const void *);
};

struct revenant_block_data {
    unsigned long magic;
    unsigned int flags;
    unsigned int volatile atomic_flags;
    int volatile performed;
    dispatch_block_t block;
    dispatch_group_t group;
};

struct revenant_block_layout {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *);
    struct revenant_block_descriptor *descriptor;
};

struct revenant_block {
    struct revenant_block_layout layout;
    struct revenant_block_data data;
};

extern void *_NSConcreteMallocBlock[];

__attribute__((noreturn, cold, unused))
static void revenant_block_crash(const char *what, unsigned long value)
{
    fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: %s (0x%lx)\n", what, value);
    abort();
}

static inline struct revenant_block_data *revenant_block_data(dispatch_block_t block)
{
    struct revenant_block_layout *layout = (struct revenant_block_layout *)(void *)block;
    if (!layout || !layout->descriptor || layout->descriptor->size < sizeof(struct revenant_block))
        return NULL;
    struct revenant_block_data *data = &((struct revenant_block *)layout)->data;
    if (data->magic != REVENANT_BLOCK_MAGIC)
        return NULL;
    return data;
}

static inline unsigned int revenant_block_or(unsigned int volatile *word, unsigned int bits)
{
    return __atomic_fetch_or(word, bits, __ATOMIC_RELAXED);
}

static inline void revenant_block_invoke_direct(struct revenant_block_data *data)
{
    unsigned int atomic_flags = data->atomic_flags;
    if (atomic_flags & REVENANT_DBF_WAITED)
        revenant_block_crash("A block object may not be both run more than once and waited for", atomic_flags);
    if (!(atomic_flags & REVENANT_DBF_CANCELED))
        data->block();
    if ((atomic_flags & REVENANT_DBF_PERFORM) == 0) {
        if (__atomic_add_fetch(&data->performed, 1, __ATOMIC_RELAXED) == 1)
            dispatch_group_leave(data->group);
    }
}

static void revenant_block_invoke(void *block)
{
    revenant_block_invoke_direct(&((struct revenant_block *)block)->data);
}

static void revenant_block_copy(void *to, const void *from)
{
}

static void revenant_block_dispose(const void *block)
{
    struct revenant_block_data *data = &((struct revenant_block *)block)->data;
    if (data->group) {
        if (!data->performed)
            dispatch_group_leave(data->group);
        dispatch_release(data->group);
    }
    if (data->block)
        Block_release(data->block);
}

static struct revenant_block_descriptor revenant_block_descriptor = {
    0, sizeof(struct revenant_block), revenant_block_copy, revenant_block_dispose
};

static inline dispatch_block_t revenant_block_create(unsigned int flags, dispatch_block_t block)
{
    struct revenant_block *made = calloc(1, sizeof(struct revenant_block));
    if (!made)
        abort();
    made->layout.isa = _NSConcreteMallocBlock;
    made->layout.flags = REVENANT_BLOCK_NEEDS_FREE | REVENANT_BLOCK_HAS_COPY_DISPOSE | 2;
    made->layout.invoke = revenant_block_invoke;
    made->layout.descriptor = &revenant_block_descriptor;
    made->data.magic = REVENANT_BLOCK_MAGIC;
    made->data.flags = flags;
    made->data.block = Block_copy(block);
    made->data.group = dispatch_group_create();
    dispatch_group_enter(made->data.group);
    return (dispatch_block_t)(void *)made;
}

static inline int revenant_block_is_barrier(dispatch_block_t block)
{
    struct revenant_block_data *data = revenant_block_data(block);
    return data && (data->flags & REVENANT_BLOCK_BARRIER);
}

static inline int revenant_system_has_block_create(void)
{
    static _Atomic(uintptr_t) system_create;
    return revenant_system_function(&system_create, REVENANT_LIBDISPATCH, "dispatch_block_create") != NULL;
}

static inline int revenant_block_unseen_barrier(dispatch_block_t block)
{
    return !revenant_system_has_block_create() && revenant_block_is_barrier(block);
}

struct revenant_block_later {
    dispatch_queue_t queue;
    dispatch_block_t block;
};

static void revenant_block_submit_barrier(void *context)
{
    struct revenant_block_later *later = context;
    dispatch_barrier_async(later->queue, later->block);
    Block_release(later->block);
    dispatch_release(later->queue);
    free(later);
}

static inline struct revenant_block_later *revenant_block_later(dispatch_queue_t queue, dispatch_block_t block)
{
    struct revenant_block_later *later = malloc(sizeof *later);
    if (!later)
        abort();
    dispatch_retain(queue);
    later->queue = queue;
    later->block = Block_copy(block);
    return later;
}

static inline dispatch_queue_t revenant_block_pusher(void)
{
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
}

static inline void revenant_block_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
    if (revenant_block_is_barrier(block))
        dispatch_group_notify_f(group, revenant_block_pusher(), revenant_block_later(queue, block), revenant_block_submit_barrier);
    else
        dispatch_group_notify(group, queue, block);
}

#endif
