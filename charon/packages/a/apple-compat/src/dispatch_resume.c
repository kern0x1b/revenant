#include "dispatch_source_state.h"

/* What a source's activation record is written with, so this object calls the Objective-C runtime; the
   runtime is not part of libSystem, and the image that pulls this shim in links it. */
__asm__(".linker_option \"-lobjc\"");

/* Records that a dispatch object has been activated, which below iOS 10 is what dispatch_resume does
   to a source: a source is made suspended and this is the one resume that starts it, and
   libdispatch-703 reads the event handler's DISPATCH_BLOCK_BARRIER once, in
   _dispatch_source_finalize_activation, which that resume reaches. So a handler set after it is not a
   barrier handler on iOS 10 and later, and a barrier source's event handler must not be one here
   either - which is what dispatch_source_set_event_handler asks this record.

   Nothing else changes: the release's dispatch_resume is called exactly as before, with every
   object, and this only writes a record on the ones that are dispatch objects of iOS 6 and later. */

__attribute__((visibility("hidden")))
void charon_dispatch_resume(dispatch_object_t object)
{
    charon_source_mark_activated(object);
    dispatch_resume(object);
}
