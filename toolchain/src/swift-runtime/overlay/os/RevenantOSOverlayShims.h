#include <errno.h>
#include <stdarg.h>
#include <stdint.h>

void *_Nonnull revenant_os_log_named(const char *_Nonnull subsystem, const char *_Nonnull category);
signed char revenant_os_log_type_enabled(void *_Nonnull log, uint8_t type);
void revenant_os_log_send(void *_Nonnull log, uint8_t type, const char *_Nonnull format, va_list arguments, int error);
static inline int revenant_os_log_errno(void) {
    return errno;
}
