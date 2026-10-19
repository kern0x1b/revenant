#import "CharonOSLog.h"
#include <errno.h>

// OS_LOG_DISABLED is the address of this object in a program built for 11.0 or later. Its class is the port's
// own, and its subsystem is the marker the core reads: a log made of it writes nothing and answers NO to every
// type, which is what the release's object does for every message.
struct os_log_s _os_log_disabled;

__attribute__((constructor)) static void charon_os_log_disabled(void)
{
    _os_log_disabled.isa = [CharonOSLog class];
    _os_log_disabled.subsystem = charon_os_log_disabled_marker;
    _os_log_disabled.category = "";
}

void _os_log_error_impl(void *dso, os_log_t log, os_log_type_t type, const char *format, uint8_t *buffer, uint32_t size)
{
    int error = errno;
    charon_os_log_buffer(log, type, format, buffer, size, error);
}

void _os_log_fault_impl(void *dso, os_log_t log, os_log_type_t type, const char *format, uint8_t *buffer, uint32_t size)
{
    int error = errno;
    charon_os_log_buffer(log, type, format, buffer, size, error);
}
