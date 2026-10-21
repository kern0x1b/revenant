#include <os/signpost.h>
#include "system_function.h"

#define REVENANT_LIBSYSTEM_TRACE "/usr/lib/system/libsystem_trace.dylib"

static _Atomic(uintptr_t) revenant_system_os_signpost_enabled;

__attribute__((constructor))
static void revenant_resolve_os_signpost_enabled(void)
{
    revenant_system_function(&revenant_system_os_signpost_enabled, REVENANT_LIBSYSTEM_TRACE, "os_signpost_enabled");
}

__attribute__((visibility("default")))
bool os_signpost_enabled(os_log_t log)
{
    bool (*system)(os_log_t) = revenant_system_function(&revenant_system_os_signpost_enabled, REVENANT_LIBSYSTEM_TRACE, "os_signpost_enabled");
    if (system)
        return system(log);
    return false;
}
