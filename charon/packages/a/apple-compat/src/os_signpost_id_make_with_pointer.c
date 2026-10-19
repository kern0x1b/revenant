#include <os/signpost.h>
#include "system_function.h"

/* os_signpost_id_make_with_pointer: iOS 12 and later mangle the pointer in the trace library that owns the call; a
   release without it answers OS_SIGNPOST_ID_NULL, the value the header documents for a log whose signposts are off,
   and the value the emit macros test for. The pointer is still checked for NULL, so the answer is the header's own
   for a NULL pointer whichever release answers. */

#define CHARON_LIBSYSTEM_TRACE "/usr/lib/system/libsystem_trace.dylib"

static _Atomic(uintptr_t) charon_system_os_signpost_id_make_with_pointer;

__attribute__((constructor))
static void charon_resolve_os_signpost_id_make_with_pointer(void)
{
    charon_system_function(&charon_system_os_signpost_id_make_with_pointer, CHARON_LIBSYSTEM_TRACE, "os_signpost_id_make_with_pointer");
}

__attribute__((visibility("default")))
os_signpost_id_t os_signpost_id_make_with_pointer(os_log_t log, const void *ptr)
{
    os_signpost_id_t (*system)(os_log_t, const void *) =
        charon_system_function(&charon_system_os_signpost_id_make_with_pointer, CHARON_LIBSYSTEM_TRACE, "os_signpost_id_make_with_pointer");
    if (system)
        return system(log, ptr);
    if (log == OS_LOG_DISABLED)
        return OS_SIGNPOST_ID_INVALID;
    return OS_SIGNPOST_ID_NULL;
}
