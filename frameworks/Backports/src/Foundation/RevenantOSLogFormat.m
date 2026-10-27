#import "RevenantOSLog.h"
#include <limits.h>
#include "../../../../toolchain/src/swift-runtime/overlay/os/RevenantOSLogRender.h"

/* The renderer lives in RevenantOSLogRender.h, shared with the os overlay's fallback, so both print the same text. */

char *revenant_os_log_format(const char *format, va_list arguments, int error)
{
    return revenant_os_log_render_arguments(format, arguments, INT_MAX, error);
}

char *revenant_os_log_format_buffer(const char *format, const uint8_t *buffer, uint32_t size, int error)
{
    return revenant_os_log_render_buffer(format, buffer, size, error);
}
