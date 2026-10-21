#include <os/signpost.h>
#include "system_function.h"

#define REVENANT_LIBSYSTEM_TRACE "/usr/lib/system/libsystem_trace.dylib"

static _Atomic(uintptr_t) revenant_system_os_signpost_id_make_with_pointer;

__attribute__((constructor))
static void revenant_resolve_os_signpost_id_make_with_pointer(void)
{
    revenant_system_function(&revenant_system_os_signpost_id_make_with_pointer, REVENANT_LIBSYSTEM_TRACE, "os_signpost_id_make_with_pointer");
}

__attribute__((visibility("default")))
os_signpost_id_t os_signpost_id_make_with_pointer(os_log_t log, const void *ptr)
{
    os_signpost_id_t (*system)(os_log_t, const void *) =
        revenant_system_function(&revenant_system_os_signpost_id_make_with_pointer, REVENANT_LIBSYSTEM_TRACE, "os_signpost_id_make_with_pointer");
    if (system)
        return system(log, ptr);
    if (log == OS_LOG_DISABLED)
        return OS_SIGNPOST_ID_INVALID;
    return OS_SIGNPOST_ID_NULL;
}
