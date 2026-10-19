#include <dispatch/dispatch.h>
#include "dispatch_source_state.h"
#include "system_function.h"

__asm__(".linker_option \"-lobjc\"");

static _Atomic(uintptr_t) charon_system_activate;

__attribute__((constructor))
static void charon_resolve_activate(void)
{
    charon_system_function(&charon_system_activate, CHARON_LIBDISPATCH, "dispatch_activate");
}

__attribute__((visibility("hidden")))
void charon_dispatch_activate(dispatch_object_t object) __asm("_dispatch_activate");

void charon_dispatch_activate(dispatch_object_t object)
{
    void (*system)(dispatch_object_t) = charon_system_function(&charon_system_activate, CHARON_LIBDISPATCH, "dispatch_activate");
    if (system) {
        system(object);
        return;
    }
    if (!charon_dispatch_is_object(object))
        return;
    charon_source_lock_take();
    int first = !charon_source_activated(object);
    if (first)
        charon_source_mark_activated(object);
    charon_source_lock_give();
    if (first)
        dispatch_resume((dispatch_source_t)charon_object_pointer(object));
}
