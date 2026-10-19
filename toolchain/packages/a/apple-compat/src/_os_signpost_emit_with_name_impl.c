#include <os/signpost.h>
#include "system_function.h"

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
