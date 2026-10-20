#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) revenant_system_assert_queue_not;

__attribute__((constructor))
static void revenant_resolve_assert_queue_not(void)
{
    revenant_system_function(&revenant_system_assert_queue_not, REVENANT_LIBDISPATCH, "dispatch_assert_queue_not$V2");
}

__attribute__((visibility("hidden")))
void revenant_assert_queue_not(dispatch_queue_t queue) __asm("_dispatch_assert_queue_not$V2");

void revenant_assert_queue_not(dispatch_queue_t queue)
{
    void (*system)(dispatch_queue_t) = revenant_system_function(&revenant_system_assert_queue_not, REVENANT_LIBDISPATCH, "dispatch_assert_queue_not$V2");
    if (system) {
        system(queue);
        return;
    }
    if (!revenant_runs_on_queue(queue))
        return;
    fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: Block was expected to not execute on queue [%s]\n",
            dispatch_queue_get_label(queue));
    abort();
}
