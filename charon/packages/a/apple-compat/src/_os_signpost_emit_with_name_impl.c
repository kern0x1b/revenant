#include <os/signpost.h>
#include "system_function.h"

/* _os_signpost_emit_with_name_impl is the function every os_signpost_* macro in signpost.h expands to: the three of
   them - interval begin, interval end and event emit - are macros over os_signpost_emit_with_type, which is a macro
   over this call, guarded first by os_signpost_enabled (false on a release with no signposts, so nothing reaches
   here) and then by the marshalling the OS_LOG_CALL_WITH_FORMAT_NAME does. It is defined because the macro names it
   and compares it against NULL, and a caller that names it directly reaches a real one: the system's, where the
   release has it, and here a no-op, which is what a release whose logging has no signpost to write one to does with
   a signpost. */

#define CHARON_LIBSYSTEM_TRACE "/usr/lib/system/libsystem_trace.dylib"

static _Atomic(uintptr_t) charon_system_os_signpost_emit_with_name_impl;

__attribute__((constructor))
static void charon_resolve_os_signpost_emit_with_name_impl(void)
{
    charon_system_function(&charon_system_os_signpost_emit_with_name_impl, CHARON_LIBSYSTEM_TRACE, "_os_signpost_emit_with_name_impl");
}

__attribute__((visibility("default")))
void _os_signpost_emit_with_name_impl(void *dso, os_log_t log, os_signpost_type_t type, os_signpost_id_t spid, const char *name,
                                      const char *format, uint8_t *buf, uint32_t size)
{
    void (*system)(void *, os_log_t, os_signpost_type_t, os_signpost_id_t, const char *, const char *, uint8_t *, uint32_t) =
        charon_system_function(&charon_system_os_signpost_emit_with_name_impl, CHARON_LIBSYSTEM_TRACE, "_os_signpost_emit_with_name_impl");
    if (system) {
        system(dso, log, type, spid, name, format, buf, size);
    }
}
