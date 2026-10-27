#include <stdarg.h>
#include <stdint.h>

void *_Nonnull revenant_os_log_named(const char *_Nonnull subsystem, const char *_Nonnull category);
void revenant_os_log_send(void *_Nonnull log, uint8_t type, const char *_Nonnull format, va_list arguments, int error);
