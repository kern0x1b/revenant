#ifndef CHARON_DISPATCH_BLOCK_H
#define CHARON_DISPATCH_BLOCK_H

#include <Block.h>
#include <dispatch/dispatch.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "system_function.h"

/* dispatch_block_t objects with private data, as libdispatch of iOS 8 makes them (queue.c and block.cpp in libdispatch-1271 and
   later): the block that dispatch_block_create answers runs the block it was given at most once, and a dispatch group, entered
   when the block is made and left when the block has run or been cancelled, is what dispatch_block_wait and
   dispatch_block_notify wait on. Its invoke is what libdispatch calls the direct invoke, so a queue of this release that runs
   it as any other block gets the whole behaviour.
   What iOS 8 does around the invoke has no counterpart here and is left out: the QOS class and the voucher a block is created
   with (the release has neither, so the flags that name them change nothing), the boost of the queue or the thread a wait
   blocks on. DISPATCH_BLOCK_BARRIER, which the release's libdispatch cannot read, is read by apple-compat's
   dispatch_async and the other calls that submit a block (charon_block_unseen_barrier below). The first call that sees a
   block finds the private data by the magic word after the block's header, so a block one image made is understood by
   another image's copy of these calls. libdispatch's own blocks carry the same magic word over a different layout (a
   priority and a voucher come before the block), so where the release has these calls each one is handed to the system and
   reads nothing itself. */

enum {
    CHARON_BLOCK_MAGIC = 0xD159B10C,
    CHARON_BLOCK_API_MASK = 0xff,
    CHARON_BLOCK_BARRIER = 1u,
    CHARON_DBF_CANCELED = 1u,
    CHARON_DBF_WAITING = 2u,
    CHARON_DBF_WAITED = 4u,
    CHARON_DBF_PERFORM = 8u,
    CHARON_BLOCK_HAS_COPY_DISPOSE = 1 << 25,
    CHARON_BLOCK_NEEDS_FREE = 1 << 24,
    CHARON_QOS_MIN_RELATIVE_PRIORITY = -15,
};

struct charon_block_descriptor {
    unsigned long reserved;
    unsigned long size;
    void (*copy)(void *, const void *);
    void (*dispose)(const void *);
};

struct charon_block_data {
    unsigned long magic;
    unsigned int flags;
    unsigned int volatile atomic_flags;
    int volatile performed;
    dispatch_block_t block;
    dispatch_group_t group;
};

struct charon_block_layout {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *);
    struct charon_block_descriptor *descriptor;
};

struct charon_block {
    struct charon_block_layout layout;
    struct charon_block_data data;
};

extern void *_NSConcreteMallocBlock[];

__attribute__((noreturn, cold, unused))
static void charon_block_crash(const char *what, unsigned long value)
{
    fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: %s (0x%lx)\n", what, value);
    abort();
}

/* The private data of a block, or NULL for one that has none. The size the block's descriptor gives is read first, so that no
   byte is read past a block too small to have any. */
static inline struct charon_block_data *charon_block_data(dispatch_block_t block)
{
    struct charon_block_layout *layout = (struct charon_block_layout *)(void *)block;
    if (!layout || !layout->descriptor || layout->descriptor->size < sizeof(struct charon_block))
        return NULL;
    struct charon_block_data *data = &((struct charon_block *)layout)->data;
    if (data->magic != CHARON_BLOCK_MAGIC)
        return NULL;
    return data;
}

static inline unsigned int charon_block_or(unsigned int volatile *word, unsigned int bits)
{
    return __atomic_fetch_or(word, bits, __ATOMIC_RELAXED);
}

static inline void charon_block_invoke_direct(struct charon_block_data *data)
{
    unsigned int atomic_flags = data->atomic_flags;
    if (atomic_flags & CHARON_DBF_WAITED)
        charon_block_crash("A block object may not be both run more than once and waited for", atomic_flags);
    if (!(atomic_flags & CHARON_DBF_CANCELED))
        data->block();
    if ((atomic_flags & CHARON_DBF_PERFORM) == 0) {
        if (__atomic_add_fetch(&data->performed, 1, __ATOMIC_RELAXED) == 1)
            dispatch_group_leave(data->group);
    }
}

static void charon_block_invoke(void *block)
{
    charon_block_invoke_direct(&((struct charon_block *)block)->data);
}

static void charon_block_copy(void *to, const void *from)
{
}

static void charon_block_dispose(const void *block)
{
    struct charon_block_data *data = &((struct charon_block *)block)->data;
    if (data->group) {
        if (!data->performed)
            dispatch_group_leave(data->group);
        dispatch_release(data->group);
    }
    if (data->block)
        Block_release(data->block);
}

static struct charon_block_descriptor charon_block_descriptor = {
    0, sizeof(struct charon_block), charon_block_copy, charon_block_dispose
};

static inline dispatch_block_t charon_block_create(unsigned int flags, dispatch_block_t block)
{
    struct charon_block *made = calloc(1, sizeof(struct charon_block));
    if (!made)
        abort();
    made->layout.isa = _NSConcreteMallocBlock;
    made->layout.flags = CHARON_BLOCK_NEEDS_FREE | CHARON_BLOCK_HAS_COPY_DISPOSE | 2;
    made->layout.invoke = charon_block_invoke;
    made->layout.descriptor = &charon_block_descriptor;
    made->data.magic = CHARON_BLOCK_MAGIC;
    made->data.flags = flags;
    made->data.block = Block_copy(block);
    made->data.group = dispatch_group_create();
    dispatch_group_enter(made->data.group);
    return (dispatch_block_t)(void *)made;
}

/* Whether the release leaves a block's DISPATCH_BLOCK_BARRIER unread: every release before iOS 8, the one that brought
   dispatch_block_create, whose libdispatch reads no block's flags. There every block with private data is one these calls
   made, and apple-compat's dispatch_async, _sync and _group_async submit a barrier block with the release's barrier call,
   as libdispatch-442 (iOS 8) does; its dispatch_after, dispatch_group_notify and dispatch_source_set_event_handler do as
   libdispatch-703 (iOS 10) does. Where the release has dispatch_block_create the calls are the system's, which read its
   own blocks. */
static inline int charon_block_is_barrier(dispatch_block_t block)
{
    struct charon_block_data *data = charon_block_data(block);
    return data && (data->flags & CHARON_BLOCK_BARRIER);
}

/* Whether the system has dispatch_block_create: the one lookup every shim that submits a block asks, made by the first of
   them that runs. */
static inline int charon_system_has_block_create(void)
{
    static _Atomic(uintptr_t) system_create;
    return charon_system_function(&system_create, CHARON_LIBDISPATCH, "dispatch_block_create") != NULL;
}

static inline int charon_block_unseen_barrier(dispatch_block_t block)
{
    return !charon_system_has_block_create() && charon_block_is_barrier(block);
}

/* A barrier submitted when a timer fires or a group empties. libdispatch-703 pushes the block to its queue as a barrier at
   that moment; the release's dispatch_after and dispatch_group_notify run what they are given on the queue as an ordinary
   block, so they are given this instead, on a global queue, and it does the push. */
struct charon_block_later {
    dispatch_queue_t queue;
    dispatch_block_t block;
};

static void charon_block_submit_barrier(void *context)
{
    struct charon_block_later *later = context;
    dispatch_barrier_async(later->queue, later->block);
    Block_release(later->block);
    dispatch_release(later->queue);
    free(later);
}

static inline struct charon_block_later *charon_block_later(dispatch_queue_t queue, dispatch_block_t block)
{
    struct charon_block_later *later = malloc(sizeof *later);
    if (!later)
        abort();
    dispatch_retain(queue);
    later->queue = queue;
    later->block = Block_copy(block);
    return later;
}

static inline dispatch_queue_t charon_block_pusher(void)
{
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
}

/* dispatch_group_notify on a release that reads no block's flags. */
static inline void charon_block_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
    if (charon_block_is_barrier(block))
        dispatch_group_notify_f(group, charon_block_pusher(), charon_block_later(queue, block), charon_block_submit_barrier);
    else
        dispatch_group_notify(group, queue, block);
}

#endif
