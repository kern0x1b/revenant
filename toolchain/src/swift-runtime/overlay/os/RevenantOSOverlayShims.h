#include <asl.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>

#include "RevenantOSLogRender.h"

void *_Nullable revenant_os_log_named(const char *_Nonnull subsystem, const char *_Nonnull category) __attribute__((weak_import));
signed char revenant_os_log_type_enabled(void *_Nullable log, uint8_t type) __attribute__((weak_import));
void revenant_os_log_send(void *_Nullable log, uint8_t type, const char *_Nonnull format, va_list arguments, int error) __attribute__((weak_import));

static inline int revenant_os_log_linked(void) {
    return revenant_os_log_named != NULL && revenant_os_log_type_enabled != NULL && revenant_os_log_send != NULL;
}

static inline int revenant_os_log_errno(void) {
    return errno;
}

static inline int revenant_os_log_recorded(uint8_t type) {
    return type != 0x01 && type != 0x02;
}

static inline int revenant_os_log_asl_level(uint8_t type) {
    switch (type) {
    case 0x10:
        return ASL_LEVEL_ERR;
    case 0x11:
        return ASL_LEVEL_CRIT;
    default:
        return ASL_LEVEL_NOTICE;
    }
}

static inline void revenant_os_log_fallback(uint8_t type, const char *_Nonnull format, va_list arguments, int count, int error) {
    if (!revenant_os_log_recorded(type)) {
        return;
    }
    char *text = revenant_os_log_render_arguments(format, arguments, count, error);
    if (text) {
        asl_log(NULL, NULL, revenant_os_log_asl_level(type), "%s", text);
        free(text);
    }
}
