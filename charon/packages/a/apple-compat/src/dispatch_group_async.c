#include "dispatch_block.h"

struct charon_group_barrier {
    dispatch_group_t group;
    dispatch_block_t block;
};

static void charon_group_barrier_invoke(void *context)
{
    struct charon_group_barrier *work = context;
    work->block();
    Block_release(work->block);
    dispatch_group_leave(work->group);
    dispatch_release(work->group);
    free(work);
}

/* dispatch_group_async reads a block's flags from iOS 8 and submits a barrier block as a barrier; before, the release's
   runs it as an ordinary one. The group is entered when the block is submitted and left once it has run, as libdispatch does. */
__attribute__((visibility("hidden")))
void charon_dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
    if (!charon_block_unseen_barrier(block)) {
        dispatch_group_async(group, queue, block);
        return;
    }
    struct charon_group_barrier *work = malloc(sizeof *work);
    if (!work)
        abort();
    dispatch_retain(group);
    work->group = group;
    work->block = Block_copy(block);
    dispatch_group_enter(group);
    dispatch_barrier_async_f(queue, work, charon_group_barrier_invoke);
}
