#include <os/signpost.h>
#include "system_function.h"

#define CHARON_LIBSYSTEM_TRACE "/usr/lib/system/libsystem_trace.dylib"

static _Atomic(uintptr_t) charon_system_os_signpost_enabled;

__attribute__((constructor))
static void charon_resolve_os_signpost_enabled(void)
{
    charon_system_function(&charon_system_os_signpost_enabled, CHARON_LIBSYSTEM_TRACE, "os_signpost_enabled");
}

__attribute__((visibility("default")))
bool os_signpost_enabled(os_log_t log)
{
    bool (*system)(os_log_t) = charon_system_function(&charon_system_os_signpost_enabled, CHARON_LIBSYSTEM_TRACE, "os_signpost_enabled");
    if (system)
        return system(log);
    return false;
}
