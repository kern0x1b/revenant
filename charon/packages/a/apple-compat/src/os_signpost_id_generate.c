#include <os/signpost.h>
#include "system_function.h"

#define CHARON_LIBSYSTEM_TRACE "/usr/lib/system/libsystem_trace.dylib"

static _Atomic(uintptr_t) charon_system_os_signpost_id_generate;

__attribute__((constructor))
static void charon_resolve_os_signpost_id_generate(void)
{
    charon_system_function(&charon_system_os_signpost_id_generate, CHARON_LIBSYSTEM_TRACE, "os_signpost_id_generate");
}

__attribute__((visibility("default")))
os_signpost_id_t os_signpost_id_generate(os_log_t log)
{
    os_signpost_id_t (*system)(os_log_t) =
        charon_system_function(&charon_system_os_signpost_id_generate, CHARON_LIBSYSTEM_TRACE, "os_signpost_id_generate");
    if (system)
        return system(log);
    return OS_SIGNPOST_ID_NULL;
}
