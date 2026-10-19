#include "dispatch_block.h"

struct revenant_group_barrier {
    dispatch_group_t group;
    dispatch_block_t block;
};

static void revenant_group_barrier_invoke(void *context)
{
    struct revenant_group_barrier *work = context;
    work->block();
    Block_release(work->block);
    dispatch_group_leave(work->group);
    dispatch_release(work->group);
    free(work);
}

__attribute__((visibility("hidden")))
void revenant_dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
    if (!revenant_block_unseen_barrier(block)) {
        dispatch_group_async(group, queue, block);
        return;
    }
    struct revenant_group_barrier *work = malloc(sizeof *work);
    if (!work)
        abort();
    dispatch_retain(group);
    work->group = group;
    work->block = Block_copy(block);
    dispatch_group_enter(group);
    dispatch_barrier_async_f(queue, work, revenant_group_barrier_invoke);
}
