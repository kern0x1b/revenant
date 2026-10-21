#include "dispatch_block.h"

__attribute__((visibility("hidden")))
void revenant_dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
    if (when == DISPATCH_TIME_FOREVER || !revenant_block_unseen_barrier(block)) {
        dispatch_after(when, queue, block);
        return;
    }
    dispatch_after_f(when, revenant_block_pusher(), revenant_block_later(queue, block), revenant_block_submit_barrier);
}
