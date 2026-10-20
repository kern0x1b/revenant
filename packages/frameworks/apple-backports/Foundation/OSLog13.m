#import "RevenantOSLog.h"
#include <errno.h>

void _os_log_debug_impl(void *dso, os_log_t log, os_log_type_t type, const char *format, uint8_t *buffer, uint32_t size)
{
    int error = errno;
    revenant_os_log_buffer(log, type, format, buffer, size, error);
}
