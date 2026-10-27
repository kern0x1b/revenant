#include <asl.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>

void *_Nullable revenant_os_log_named(const char *_Nonnull subsystem, const char *_Nonnull category) __attribute__((weak_import));
signed char revenant_os_log_type_enabled(void *_Nullable log, uint8_t type) __attribute__((weak_import));
void revenant_os_log_send(void *_Nullable log, uint8_t type, const char *_Nonnull format, va_list arguments, int error) __attribute__((weak_import));

static inline int revenant_os_log_linked(void) {
    return revenant_os_log_named != NULL && revenant_os_log_type_enabled != NULL && revenant_os_log_send != NULL;
}

static inline int revenant_os_log_errno(void) {
    return errno;
}

static inline int revenant_os_log_asl_level(uint8_t type) {
    switch (type) {
    case 0x01:
        return ASL_LEVEL_INFO;
    case 0x02:
        return ASL_LEVEL_DEBUG;
    case 0x10:
        return ASL_LEVEL_ERR;
    case 0x11:
        return ASL_LEVEL_CRIT;
    default:
        return ASL_LEVEL_NOTICE;
    }
}

static inline void revenant_os_log_format(char *_Nonnull text, size_t size, const char *_Nonnull format, va_list arguments) {
    vsnprintf(text, size, format, arguments);
}

static inline void revenant_os_log_fallback(uint8_t type, const char *_Nonnull format, va_list arguments) {
    char text[1024];
    revenant_os_log_format(text, sizeof(text), format, arguments);
    asl_log(NULL, NULL, revenant_os_log_asl_level(type), "%s", text);
}
