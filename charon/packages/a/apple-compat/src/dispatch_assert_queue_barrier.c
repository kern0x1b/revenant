#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) charon_system_assert_queue_barrier;

__attribute__((constructor))
static void charon_resolve_assert_queue_barrier(void)
{
    charon_system_function(&charon_system_assert_queue_barrier, CHARON_LIBDISPATCH, "dispatch_assert_queue_barrier");
}

/* The release cannot tell a barrier block of a concurrent queue from any other block that runs on it, so this asks what
   dispatch_assert_queue asks: that the code runs on the queue. It is as strict as iOS 10 on a serial queue, where every block
   is alone, and lets a plain block of a concurrent queue pass, which iOS 10 does not. */

__attribute__((visibility("hidden")))
void charon_assert_queue_barrier(dispatch_queue_t queue) __asm("_dispatch_assert_queue_barrier");

void charon_assert_queue_barrier(dispatch_queue_t queue)
{
    void (*system)(dispatch_queue_t) = charon_system_function(&charon_system_assert_queue_barrier, CHARON_LIBDISPATCH, "dispatch_assert_queue_barrier");
    if (system) {
        system(queue);
        return;
    }
    if (charon_runs_on_queue(queue))
        return;
    fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: Block was expected to execute on queue [%s]\n",
            dispatch_queue_get_label(queue));
    abort();
}
