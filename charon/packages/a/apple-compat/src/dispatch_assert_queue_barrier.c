#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) charon_system_assert_queue_barrier;

__attribute__((constructor))
static void charon_resolve_assert_queue_barrier(void)
{
    charon_system_function(&charon_system_assert_queue_barrier, CHARON_LIBDISPATCH, "dispatch_assert_queue_barrier");
}

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
