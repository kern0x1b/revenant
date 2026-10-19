#include <os/signpost.h>
#include "system_function.h"

/* Signposts arrived with iOS 12, in the trace library that owns them. A release below that has no such library: the
   lookup asks it by path and only if it is already loaded, finds nothing, and the call answers the way the header
   documents for signposts that are turned off. Nothing is lost by that, because the header's own guard asks
   os_signpost_enabled before it marshals an argument for _os_signpost_emit_with_name_impl - with false here, every
   os_signpost_interval_begin, os_signpost_interval_end and os_signpost_event_emit is skipped at the test, which is
   what a release whose unified logging has no signposts does with them. */

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
