#include "../revenant_impl.h"
#import "RevenantOSLog.h"
#include <errno.h>

struct os_log_s BACKPORT_IMPL(_os_log_default);

__attribute__((constructor)) static void revenant_os_log_default(void)
{
    BACKPORT_IMPL(_os_log_default).isa = [RevenantOSLog class];
    BACKPORT_IMPL(_os_log_default).subsystem = "";
    BACKPORT_IMPL(_os_log_default).category = "";
}

void BACKPORT_IMPL(_os_log_internal)(void *dso, os_log_t log, os_log_type_t type, const char *message, ...)
{
    int error = errno;
    if (!revenant_os_log_type_enabled(log, type))
        return;
    va_list arguments;
    va_start(arguments, message);
    revenant_os_log_send(log, type, message, arguments, error);
    va_end(arguments);
}

os_log_t BACKPORT_IMPL(_os_log_create)(void *dso, const char *subsystem, const char *category)
{
    return revenant_os_log_named(subsystem, category);
}

bool BACKPORT_IMPL(os_log_is_enabled)(os_log_t log)
{
    return true;
}

bool BACKPORT_IMPL(os_log_is_debug_enabled)(os_log_t log)
{
    return revenant_os_log_type_enabled(log, OS_LOG_TYPE_DEBUG);
}
