#include <asl.h>
#include <errno.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

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

/*
 * The fallback renders the message the way os_log does in a release build, for processes that do not load the
 * Backports logging runtime. The format is parsed here and never handed to printf: every specifier is formatted
 * alone with its own flags, width and precision. %{public} values are printed, %{private} (and sensitive or mask)
 * values print as <private>, and strings and objects are private unless marked public. The arguments are read
 * from the va_list the Swift caller built, never past the count it passes.
 */

#pragma clang assume_nonnull begin

#define REVENANT_OS_LOG_MISSING "<decode: missing data>"
#define REVENANT_OS_LOG_PRIVATE "<private>"
#define REVENANT_OS_LOG_UNSUPPORTED "<unsupported>"

typedef struct {
    char bytes[1024];
    size_t length;
} revenant_os_log_text;

enum {
    REVENANT_OS_LOG_PRIVACY_DEFAULT,
    REVENANT_OS_LOG_PRIVACY_PUBLIC,
    REVENANT_OS_LOG_PRIVACY_PRIVATE,
};

typedef struct {
    char flags[8];
    int width;
    int precision;
    char length[3];
    int privacy;
} revenant_os_log_spec;

typedef struct {
    va_list *_Nonnull list;
    int remaining;
    int error;
} revenant_os_log_arguments;

static inline void revenant_os_log_reset(revenant_os_log_text *text) {
    text->length = 0;
    text->bytes[0] = 0;
}

static inline void revenant_os_log_append(revenant_os_log_text *text, const char *bytes, size_t length) {
    size_t room = sizeof text->bytes - 1 - text->length;
    if (length > room) {
        length = room;
    }
    memcpy(text->bytes + text->length, bytes, length);
    text->length += length;
    text->bytes[text->length] = 0;
}

static inline void revenant_os_log_escape(revenant_os_log_text *out, const char *bytes, size_t length) {
    for (size_t index = 0; index < length; index++) {
        unsigned char byte = (unsigned char)bytes[index];
        if (byte == '\t' || byte == '\n' || (byte >= 0x20 && byte != 0x7F)) {
            revenant_os_log_append(out, (const char *)&byte, 1);
        } else {
            char escape[3] = {'\\', '^', byte == 0x7F ? '?' : (char)(byte + '@')};
            revenant_os_log_append(out, escape, sizeof escape);
        }
    }
}

static inline void revenant_os_log_trim(revenant_os_log_text *text) {
    while (text->length && strchr(" \t\n\r", text->bytes[text->length - 1])) {
        text->bytes[--text->length] = 0;
    }
}

static inline int revenant_os_log_digit(int value, char digit) {
    int next = value * 10 + (digit - '0');
    return next > 128 ? 128 : next;
}

static inline int revenant_os_log_clamp(int value) {
    return value > 128 ? 128 : value < -128 ? -128 : value;
}

static inline int revenant_os_log_token_is(const char *name, size_t length, const char *word) {
    return strlen(word) == length && strncmp(name, word, length) == 0;
}

static inline void revenant_os_log_decorate(revenant_os_log_spec *spec, const char *begin, const char *end) {
    const char *token = begin;
    while (token < end) {
        const char *stop = token;
        while (stop < end && *stop != ',') {
            stop++;
        }
        const char *name = token;
        while (name < stop && *name == ' ') {
            name++;
        }
        size_t length = (size_t)(stop - name);
        while (length && name[length - 1] == ' ') {
            length--;
        }
        if (revenant_os_log_token_is(name, length, "public")) {
            spec->privacy = REVENANT_OS_LOG_PRIVACY_PUBLIC;
        } else if (revenant_os_log_token_is(name, length, "private") || revenant_os_log_token_is(name, length, "sensitive") ||
                   revenant_os_log_token_is(name, length, "mask.hash") || revenant_os_log_token_is(name, length, "mask.redact")) {
            spec->privacy = REVENANT_OS_LOG_PRIVACY_PRIVATE;
        }
        token = stop + 1;
    }
}

static inline int revenant_os_log_is_private(const revenant_os_log_spec *spec, int private_by_default) {
    return spec->privacy == REVENANT_OS_LOG_PRIVACY_PRIVATE ||
           (spec->privacy == REVENANT_OS_LOG_PRIVACY_DEFAULT && private_by_default);
}

static inline void revenant_os_log_pad(revenant_os_log_text *out, const revenant_os_log_spec *spec, const char *bytes, size_t length) {
    size_t shown = length;
    if (spec->precision >= 0 && (size_t)spec->precision < shown) {
        shown = (size_t)spec->precision;
    }
    size_t padding = (size_t)spec->width > shown ? (size_t)spec->width - shown : 0;
    int left = strchr(spec->flags, '-') != NULL;
    for (size_t index = 0; !left && index < padding; index++) {
        revenant_os_log_append(out, " ", 1);
    }
    revenant_os_log_append(out, bytes, shown);
    for (size_t index = 0; left && index < padding; index++) {
        revenant_os_log_append(out, " ", 1);
    }
}

static inline void revenant_os_log_format_spec(char *out, size_t size, const revenant_os_log_spec *spec, const char *length, char conversion) {
    char width[8] = "";
    char precision[8] = "";
    if (spec->width > 0) {
        snprintf(width, sizeof width, "%d", spec->width);
    }
    if (spec->precision >= 0) {
        snprintf(precision, sizeof precision, ".%d", spec->precision);
    }
    snprintf(out, size, "%%%s%s%s%s%c", spec->flags, width, precision, length, conversion);
}

static inline void revenant_os_log_append_formatted(revenant_os_log_text *out, const char *number, int written) {
    if (written > 0) {
        size_t length = (size_t)written < 1023 ? (size_t)written : 1023;
        revenant_os_log_append(out, number, length);
    }
}

static inline void revenant_os_log_put_signed(revenant_os_log_text *out, const revenant_os_log_spec *spec, char conversion, long long value) {
    char format[32];
    char number[1024];
    revenant_os_log_format_spec(format, sizeof format, spec, "ll", conversion);
    revenant_os_log_append_formatted(out, number, snprintf(number, sizeof number, format, value));
}

static inline void revenant_os_log_put_unsigned(revenant_os_log_text *out, const revenant_os_log_spec *spec, char conversion, unsigned long long value) {
    char format[32];
    char number[1024];
    revenant_os_log_format_spec(format, sizeof format, spec, "ll", conversion);
    revenant_os_log_append_formatted(out, number, snprintf(number, sizeof number, format, value));
}

static inline void revenant_os_log_put_double(revenant_os_log_text *out, const revenant_os_log_spec *spec, char conversion, double value) {
    char format[32];
    char number[1024];
    revenant_os_log_format_spec(format, sizeof format, spec, "", conversion);
    revenant_os_log_append_formatted(out, number, snprintf(number, sizeof number, format, value));
}

#if defined(__OBJC__)
#define REVENANT_OS_LOG_BRIDGE __bridge
#else
#define REVENANT_OS_LOG_BRIDGE
#endif

static inline const char *_Nullable revenant_os_log_description(const void *_Nullable object) {
    SEL description_selector = sel_registerName("description");
    Class cls = object_getClass((REVENANT_OS_LOG_BRIDGE id)object);
    if (!cls || !class_respondsToSelector(cls, description_selector)) {
        return NULL;
    }
    id description = ((id (*)(id, SEL))objc_msgSend)((REVENANT_OS_LOG_BRIDGE id)object, description_selector);
    if (!description) {
        return NULL;
    }
    SEL utf8_selector = sel_registerName("UTF8String");
    Class description_class = object_getClass(description);
    if (!description_class || !class_respondsToSelector(description_class, utf8_selector)) {
        return NULL;
    }
    return ((const char *(*)(id, SEL))objc_msgSend)(description, utf8_selector);
}

static inline void revenant_os_log_put_object(revenant_os_log_text *out, const revenant_os_log_spec *spec, const void *_Nullable object) {
    revenant_os_log_spec plain = *spec;
    plain.precision = -1;
    if (!object) {
        revenant_os_log_pad(out, &plain, "(null)", strlen("(null)"));
        return;
    }
    const char *description = revenant_os_log_description(object);
    if (description) {
        revenant_os_log_pad(out, &plain, description, strlen(description));
        return;
    }
    const char *name = class_getName(object_getClass((REVENANT_OS_LOG_BRIDGE id)object));
    char label[256];
    snprintf(label, sizeof label, "<%s>", name ? name : "object");
    revenant_os_log_pad(out, &plain, label, strlen(label));
}

static inline int revenant_os_log_take(revenant_os_log_arguments *arguments) {
    if (arguments->remaining <= 0) {
        return 0;
    }
    arguments->remaining--;
    return 1;
}

static inline void revenant_os_log_missing(revenant_os_log_text *out) {
    revenant_os_log_append(out, REVENANT_OS_LOG_MISSING, strlen(REVENANT_OS_LOG_MISSING));
}

static inline void revenant_os_log_private(revenant_os_log_text *out) {
    revenant_os_log_append(out, REVENANT_OS_LOG_PRIVATE, strlen(REVENANT_OS_LOG_PRIVATE));
}

static inline void revenant_os_log_unsupported(revenant_os_log_text *out) {
    revenant_os_log_append(out, REVENANT_OS_LOG_UNSUPPORTED, strlen(REVENANT_OS_LOG_UNSUPPORTED));
}

static inline long long revenant_os_log_fetch_signed(va_list *_Nonnull list, const char *length) {
    if (!strcmp(length, "hh")) {
        return (signed char)va_arg(*list, int);
    }
    if (!strcmp(length, "h")) {
        return (short)va_arg(*list, int);
    }
    if (!strcmp(length, "l") || !strcmp(length, "z") || !strcmp(length, "t")) {
        return va_arg(*list, long);
    }
    if (!strcmp(length, "ll") || !strcmp(length, "q") || !strcmp(length, "j")) {
        return va_arg(*list, long long);
    }
    return va_arg(*list, int);
}

static inline unsigned long long revenant_os_log_fetch_unsigned(va_list *_Nonnull list, const char *length) {
    if (!strcmp(length, "hh")) {
        return (unsigned char)va_arg(*list, int);
    }
    if (!strcmp(length, "h")) {
        return (unsigned short)va_arg(*list, int);
    }
    if (!strcmp(length, "l") || !strcmp(length, "z") || !strcmp(length, "t")) {
        return va_arg(*list, unsigned long);
    }
    if (!strcmp(length, "ll") || !strcmp(length, "q") || !strcmp(length, "j")) {
        return va_arg(*list, unsigned long long);
    }
    return va_arg(*list, unsigned int);
}

static inline void revenant_os_log_convert(revenant_os_log_text *out, const revenant_os_log_spec *spec, char conversion,
                                           revenant_os_log_arguments *arguments) {
    switch (conversion) {
    case 'd':
    case 'i': {
        if (!revenant_os_log_take(arguments)) {
            revenant_os_log_missing(out);
            break;
        }
        long long number = revenant_os_log_fetch_signed(arguments->list, spec->length);
        if (revenant_os_log_is_private(spec, 0)) {
            revenant_os_log_private(out);
        } else {
            revenant_os_log_put_signed(out, spec, 'd', number);
        }
        break;
    }
    case 'u':
    case 'o':
    case 'x':
    case 'X': {
        if (!revenant_os_log_take(arguments)) {
            revenant_os_log_missing(out);
            break;
        }
        unsigned long long number = revenant_os_log_fetch_unsigned(arguments->list, spec->length);
        if (revenant_os_log_is_private(spec, 0)) {
            revenant_os_log_private(out);
        } else {
            revenant_os_log_put_unsigned(out, spec, conversion, number);
        }
        break;
    }
    case 'c': {
        if (!revenant_os_log_take(arguments)) {
            revenant_os_log_missing(out);
            break;
        }
        char byte = (char)va_arg(*arguments->list, int);
        if (revenant_os_log_is_private(spec, 0)) {
            revenant_os_log_private(out);
        } else {
            revenant_os_log_pad(out, spec, &byte, 1);
        }
        break;
    }
    case 'e':
    case 'E':
    case 'f':
    case 'F':
    case 'g':
    case 'G':
    case 'a':
    case 'A': {
        if (!revenant_os_log_take(arguments)) {
            revenant_os_log_missing(out);
            break;
        }
        double number = va_arg(*arguments->list, double);
        if (revenant_os_log_is_private(spec, 0)) {
            revenant_os_log_private(out);
        } else {
            revenant_os_log_put_double(out, spec, conversion, number);
        }
        break;
    }
    case 'p': {
        if (!revenant_os_log_take(arguments)) {
            revenant_os_log_missing(out);
            break;
        }
        const void *pointer = va_arg(*arguments->list, const void *);
        if (revenant_os_log_is_private(spec, 0)) {
            revenant_os_log_private(out);
        } else {
            char text[32];
            snprintf(text, sizeof text, "%p", pointer);
            revenant_os_log_pad(out, spec, text, strlen(text));
        }
        break;
    }
    case 's': {
        if (!revenant_os_log_take(arguments)) {
            revenant_os_log_missing(out);
            break;
        }
        const char *string = va_arg(*arguments->list, const char *);
        if (spec->length[0] == 'l') {
            revenant_os_log_unsupported(out);
        } else if (revenant_os_log_is_private(spec, 1)) {
            revenant_os_log_private(out);
        } else if (!string) {
            revenant_os_log_pad(out, spec, "(null)", strlen("(null)"));
        } else {
            revenant_os_log_pad(out, spec, string, strlen(string));
        }
        break;
    }
    case '@': {
        if (!revenant_os_log_take(arguments)) {
            revenant_os_log_missing(out);
            break;
        }
        const void *object = va_arg(*arguments->list, const void *);
        if (revenant_os_log_is_private(spec, 1)) {
            revenant_os_log_private(out);
        } else {
            revenant_os_log_put_object(out, spec, object);
        }
        break;
    }
    case 'C':
    case 'S':
    case 'P': {
        if (!revenant_os_log_take(arguments)) {
            revenant_os_log_missing(out);
            break;
        }
        if (conversion == 'C') {
            va_arg(*arguments->list, int);
        } else {
            va_arg(*arguments->list, const void *);
        }
        revenant_os_log_unsupported(out);
        break;
    }
    case 'm':
        revenant_os_log_append(out, strerror(arguments->error), strlen(strerror(arguments->error)));
        break;
    default:
        revenant_os_log_append(out, &conversion, 1);
        break;
    }
}

static inline void revenant_os_log_render_into(revenant_os_log_text *out, const char *format, revenant_os_log_arguments *arguments) {
    const char *cursor = format;
    while (*cursor) {
        if (*cursor != '%') {
            const char *next = strchr(cursor, '%');
            size_t run = next ? (size_t)(next - cursor) : strlen(cursor);
            revenant_os_log_append(out, cursor, run);
            cursor += run;
            continue;
        }
        cursor++;
        if (!*cursor) {
            break;
        }
        if (*cursor == '%') {
            revenant_os_log_append(out, "%", 1);
            cursor++;
            continue;
        }
        revenant_os_log_spec spec = {{0}, 0, -1, {0}, REVENANT_OS_LOG_PRIVACY_DEFAULT};
        if (*cursor == '{') {
            const char *close = strchr(cursor, '}');
            if (!close) {
                break;
            }
            revenant_os_log_decorate(&spec, cursor + 1, close);
            cursor = close + 1;
        }
        int missing = 0;
        size_t flags = 0;
        while (*cursor && strchr("-+ #0", *cursor) && flags < sizeof spec.flags - 1) {
            spec.flags[flags++] = *cursor++;
        }
        if (*cursor == '*') {
            cursor++;
            if (revenant_os_log_take(arguments)) {
                int width = va_arg(*arguments->list, int);
                if (width < 0 && flags < sizeof spec.flags - 1) {
                    spec.flags[flags++] = '-';
                }
                spec.width = width < 0 ? -revenant_os_log_clamp(width) : revenant_os_log_clamp(width);
            } else {
                missing = 1;
            }
        } else {
            while (*cursor >= '0' && *cursor <= '9') {
                spec.width = revenant_os_log_digit(spec.width, *cursor++);
            }
        }
        if (*cursor == '.') {
            cursor++;
            spec.precision = 0;
            if (*cursor == '*') {
                cursor++;
                if (revenant_os_log_take(arguments)) {
                    int precision = va_arg(*arguments->list, int);
                    spec.precision = precision < 0 ? -1 : revenant_os_log_clamp(precision);
                } else {
                    missing = 1;
                }
            } else {
                while (*cursor >= '0' && *cursor <= '9') {
                    spec.precision = revenant_os_log_digit(spec.precision, *cursor++);
                }
            }
        }
        if (*cursor == 'h' || *cursor == 'l') {
            spec.length[0] = *cursor++;
            if (*cursor == spec.length[0]) {
                spec.length[1] = *cursor++;
            }
        } else if (*cursor && strchr("Lqjzt", *cursor)) {
            spec.length[0] = *cursor++;
        }
        char conversion = *cursor;
        if (!conversion) {
            break;
        }
        cursor++;
        if (missing) {
            revenant_os_log_missing(out);
            continue;
        }
        revenant_os_log_convert(out, &spec, conversion, arguments);
    }
}

static inline void revenant_os_log_render(revenant_os_log_text *out, const char *format, va_list arguments, int count, int error) {
    va_list list;
    va_copy(list, arguments);
    revenant_os_log_arguments args = {&list, count, error};
    revenant_os_log_text raw;
    revenant_os_log_reset(&raw);
    revenant_os_log_render_into(&raw, format, &args);
    va_end(list);
    revenant_os_log_trim(&raw);
    revenant_os_log_reset(out);
    revenant_os_log_escape(out, raw.bytes, raw.length);
}

static inline void revenant_os_log_fallback(uint8_t type, const char *_Nonnull format, va_list arguments, int count, int error) {
    if (!revenant_os_log_recorded(type)) {
        return;
    }
    revenant_os_log_text text;
    revenant_os_log_render(&text, format, arguments, count, error);
    asl_log(NULL, NULL, revenant_os_log_asl_level(type), "%s", text.bytes);
}

#pragma clang assume_nonnull end
