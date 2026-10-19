#ifndef CHARON_DISPATCH_QUEUE_CURRENT_H
#define CHARON_DISPATCH_QUEUE_CURRENT_H

#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static void charon_unmarked(void *unused)
{
    (void)unused;
}

/* The class of service a global queue of a priority has in iOS 8 (DISPATCH_QUEUE_PRIORITY_* in queue.h). */
static inline int charon_global_priority(dispatch_queue_t queue, long *priority)
{
    static const long priorities[] = {DISPATCH_QUEUE_PRIORITY_HIGH, DISPATCH_QUEUE_PRIORITY_DEFAULT, DISPATCH_QUEUE_PRIORITY_LOW,
                                      DISPATCH_QUEUE_PRIORITY_BACKGROUND};
    for (unsigned index = 0; index < sizeof priorities / sizeof priorities[0]; index++) {
        if (queue == dispatch_get_global_queue(priorities[index], 0) || queue == dispatch_get_global_queue(priorities[index], 0x2)) {
            if (priority)
                *priority = priorities[index];
            return 1;
        }
    }
    return 0;
}

/* Whether the code that runs is running on the queue: the queue itself, or a queue that targets it, which dispatch_get_specific
   answers by walking the target chain (iOS 5). The queue is marked under a key only it uses, its address with the low bit set,
   which no object's address is. Global queues take no specifics, so for them only the queue running the block itself counts,
   not a queue that targets them. The main thread holds the main queue, in a block or not, as libdispatch binds it there. */
static inline int charon_runs_on_queue(dispatch_queue_t queue)
{
    if (queue == dispatch_get_main_queue())
        return pthread_main_np() != 0;
    if (charon_global_priority(queue, NULL)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return dispatch_get_current_queue() == queue;
#pragma clang diagnostic pop
    }
    void *key = (void *)((uintptr_t)queue | 1);
    if (dispatch_queue_get_specific(queue, key) != key)
        dispatch_queue_set_specific(queue, key, key, charon_unmarked);
    return dispatch_get_specific(key) == key;
}

#endif
