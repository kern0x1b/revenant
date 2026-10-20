#import "RevenantOSLog.h"
#include <errno.h>

struct os_log_s _os_log_default;

__attribute__((constructor)) static void revenant_os_log_default(void)
{
    _os_log_default.isa = [RevenantOSLog class];
    _os_log_default.subsystem = "";
    _os_log_default.category = "";
}

void _os_log_internal(void *dso, os_log_t log, os_log_type_t type, const char *message, ...)
{
    int error = errno;
    if (!revenant_os_log_type_enabled(log, type))
        return;
    va_list arguments;
    va_start(arguments, message);
    revenant_os_log_send(log, type, message, arguments, error);
    va_end(arguments);
}

os_log_t _os_log_create(void *dso, const char *subsystem, const char *category)
{
    return revenant_os_log_named(subsystem, category);
}

bool os_log_is_enabled(os_log_t log)
{
    return true;
}

bool os_log_is_debug_enabled(os_log_t log)
{
    return revenant_os_log_type_enabled(log, OS_LOG_TYPE_DEBUG);
}
