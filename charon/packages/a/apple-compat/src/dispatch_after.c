#include "dispatch_block.h"

__attribute__((visibility("hidden")))
void charon_dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
    if (when == DISPATCH_TIME_FOREVER || !charon_block_unseen_barrier(block)) {
        dispatch_after(when, queue, block);
        return;
    }
    dispatch_after_f(when, charon_block_pusher(), charon_block_later(queue, block), charon_block_submit_barrier);
}
