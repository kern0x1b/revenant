#import "RevenantOSLog.h"
#include <errno.h>

#undef os_log_create

void _os_log_impl(void *dso, os_log_t log, os_log_type_t type, const char *format, uint8_t *buffer, uint32_t size)
{
    int error = errno;
    revenant_os_log_buffer(log, type, format, buffer, size, error);
}

os_log_t os_log_create(const char *subsystem, const char *category)
{
    return revenant_os_log_named(subsystem, category);
}

bool os_log_type_enabled(os_log_t log, os_log_type_t type)
{
    return revenant_os_log_type_enabled(log, type);
}
