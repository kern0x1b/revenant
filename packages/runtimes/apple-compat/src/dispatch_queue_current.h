#ifndef REVENANT_DISPATCH_QUEUE_CURRENT_H
#define REVENANT_DISPATCH_QUEUE_CURRENT_H

#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static void revenant_unmarked(void *unused)
{
    (void)unused;
}

static inline int revenant_global_priority(dispatch_queue_t queue, long *priority)
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

static inline int revenant_runs_on_queue(dispatch_queue_t queue)
{
    if (queue == dispatch_get_main_queue())
        return pthread_main_np() != 0;
    if (revenant_global_priority(queue, NULL)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return dispatch_get_current_queue() == queue;
#pragma clang diagnostic pop
    }
    void *key = (void *)((uintptr_t)queue | 1);
    if (dispatch_queue_get_specific(queue, key) != key)
        dispatch_queue_set_specific(queue, key, key, revenant_unmarked);
    return dispatch_get_specific(key) == key;
}

#endif
