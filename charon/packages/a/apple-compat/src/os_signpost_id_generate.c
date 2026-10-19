#include <os/signpost.h>
#include "system_function.h"

/* os_signpost_id_generate: the trace library of iOS 12 and later owns it, and a release without that library answers
   OS_SIGNPOST_ID_NULL, which is what the header documents this call returns when signposts are turned off - and they
   are, on a release with no signposts (os_signpost_enabled.c). An id of OS_SIGNPOST_ID_NULL is what the emit macros
   test for, so the interval and event that were given the id are skipped at that test, as the release's own
   behaviour is. */

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
