#include <dispatch/dispatch.h>
#include "dispatch_source_state.h"
#include "system_function.h"

__asm__(".linker_option \"-lobjc\"");

static _Atomic(uintptr_t) revenant_system_activate;

__attribute__((constructor))
static void revenant_resolve_activate(void)
{
    revenant_system_function(&revenant_system_activate, REVENANT_LIBDISPATCH, "dispatch_activate");
}

__attribute__((visibility("hidden")))
void revenant_dispatch_activate(dispatch_object_t object) __asm("_dispatch_activate");

void revenant_dispatch_activate(dispatch_object_t object)
{
    void (*system)(dispatch_object_t) = revenant_system_function(&revenant_system_activate, REVENANT_LIBDISPATCH, "dispatch_activate");
    if (system) {
        system(object);
        return;
    }
    if (!revenant_dispatch_is_object(object))
        return;
    revenant_source_lock_take();
    int first = !revenant_source_activated(object);
    if (first)
        revenant_source_mark_activated(object);
    revenant_source_lock_give();
    if (first)
        dispatch_resume((dispatch_source_t)revenant_object_pointer(object));
}
