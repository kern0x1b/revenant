#include "dispatch_source_state.h"

__asm__(".linker_option \"-lobjc\"");

__attribute__((visibility("hidden")))
void revenant_dispatch_resume(dispatch_object_t object)
{
    revenant_source_mark_activated(object);
    dispatch_resume(object);
}
