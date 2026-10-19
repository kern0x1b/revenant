#include <dispatch/dispatch.h>
#include "dispatch_source_state.h"
#include "system_function.h"

/* The Objective-C runtime is not part of libSystem; the image that pulls this shim in links it. */
__asm__(".linker_option \"-lobjc\"");

static _Atomic(uintptr_t) charon_system_activate;

__attribute__((constructor))
static void charon_resolve_activate(void)
{
    charon_system_function(&charon_system_activate, CHARON_LIBDISPATCH, "dispatch_activate");
}

/* Inactive objects arrived in iOS 10. Before, of what dispatch_activate is called on only a source starts inactive: created
   suspended, it waits for the one resume activation gives it. Queues start active, and activating an active object does nothing.
   The source remembers its activation on itself, in the one record dispatch_source_state.h holds and dispatch_resume writes
   too, so a second call does not resume it twice and a resume that already happened is not resumed again. */
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
    /* The one caller that has to know whether the resume is the first, so the look and the mark are
       held together; dispatch_resume only marks and does not read it back. */
    charon_source_lock_take();
    int first = !charon_source_activated(object);
    if (first)
        charon_source_mark_activated(object);
    charon_source_lock_give();
    if (first)
        dispatch_resume((dispatch_source_t)charon_object_pointer(object));
}
