#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) revenant_system_assert_queue_barrier;

__attribute__((constructor))
static void revenant_resolve_assert_queue_barrier(void)
{
    revenant_system_function(&revenant_system_assert_queue_barrier, REVENANT_LIBDISPATCH, "dispatch_assert_queue_barrier");
}

__attribute__((visibility("hidden")))
void revenant_assert_queue_barrier(dispatch_queue_t queue) __asm("_dispatch_assert_queue_barrier");

void revenant_assert_queue_barrier(dispatch_queue_t queue)
{
    void (*system)(dispatch_queue_t) = revenant_system_function(&revenant_system_assert_queue_barrier, REVENANT_LIBDISPATCH, "dispatch_assert_queue_barrier");
    if (system) {
        system(queue);
        return;
    }
    if (revenant_runs_on_queue(queue))
        return;
    fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: Block was expected to execute on queue [%s]\n",
            dispatch_queue_get_label(queue));
    abort();
}
