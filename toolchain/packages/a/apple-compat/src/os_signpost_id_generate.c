#include <os/signpost.h>
#include "system_function.h"

#define REVENANT_LIBSYSTEM_TRACE "/usr/lib/system/libsystem_trace.dylib"

static _Atomic(uintptr_t) revenant_system_os_signpost_id_generate;

__attribute__((constructor))
static void revenant_resolve_os_signpost_id_generate(void)
{
    revenant_system_function(&revenant_system_os_signpost_id_generate, REVENANT_LIBSYSTEM_TRACE, "os_signpost_id_generate");
}

__attribute__((visibility("default")))
os_signpost_id_t os_signpost_id_generate(os_log_t log)
{
    os_signpost_id_t (*system)(os_log_t) =
        revenant_system_function(&revenant_system_os_signpost_id_generate, REVENANT_LIBSYSTEM_TRACE, "os_signpost_id_generate");
    if (system)
        return system(log);
    return OS_SIGNPOST_ID_NULL;
}
