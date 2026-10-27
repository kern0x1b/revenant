/*
 * The os_log renderer shared by the Backports logging runtime (frameworks/Backports/src/Foundation/
 * RevenantOSLogFormat.m) and the os overlay's fallback (RevenantOSOverlayShims.h), so that both print the same text.
 *
 * A message is rendered from a format and its arguments the way os_log renders it in a release build: %{public}
 * values are printed, %{private}, %{sensitive} and mask values print as <private>, and a string, a pointer or an
 * object is private unless it is marked %{public}. Numbers are public unless marked private. The format is parsed
 * here and never passed to printf: each specifier is formatted alone with its own flags, width and precision.
 *
 * Two argument sources are rendered: a va_list, with at most `count` arguments read from it, and the packed buffer the
 * compiler's os_log builtin emits. The buffer layout is the one the os_log ABI defines (swiftlang/swift
 * stdlib/private/OSLog/OSLogMessage.swift): a summary byte, an argument count byte, then per argument a header byte
 * (type in the high four bits, privacy flag in the low four, see OSLogPrivacy.swift), a size byte and the bytes.
 * Both sources decide privacy with revenant_os_log_is_private.
 */

#include <errno.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/vm_prot.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <wchar.h>

#pragma clang assume_nonnull begin

#if defined(__OBJC__)
#define REVENANT_OS_LOG_RENDER_BRIDGE __bridge
#else
#define REVENANT_OS_LOG_RENDER_BRIDGE
#endif

#define REVENANT_OS_LOG_PRIVATE_TEXT "<private>"
#define REVENANT_OS_LOG_MISSING_TEXT "<decode: missing data>"

typedef struct {
    char *_Nullable bytes;
    size_t length;
    size_t capacity;
} revenant_os_log_text;

/* The privacy flag of an argument: the low four bits of its header byte, as the os_log ABI encodes it (swiftlang/swift
   stdlib/private/OSLog/OSLogPrivacy.swift, argumentFlag: private 0x1, public 0x2, auto 0). */
enum {
    REVENANT_OS_LOG_PRIVACY_DEFAULT = 0,
    REVENANT_OS_LOG_PRIVACY_PUBLIC = 0x2,
    REVENANT_OS_LOG_PRIVACY_PRIVATE = 0x1,
};

typedef struct {
    char flags[8];
    int width;
    int precision;
    char length[3];
    int isBool, isBOOL, isErrno, isTime, isMode, isSignal, isUUID, isMask;
    int privacy;
} revenant_os_log_spec;

typedef struct {
    va_list *_Nullable arguments;
    int count;
    const unsigned char *_Nullable buffer;
    uint32_t size;
    uint32_t offset;
    unsigned remaining;
    int error;
} revenant_os_log_args;

typedef struct {
    unsigned type;
    unsigned privacy;
    const unsigned char *_Nullable data;
    uint32_t length;
} revenant_os_log_item;

static inline const revenant_os_log_spec *revenant_os_log_plain_spec(void) {
    static const revenant_os_log_spec plain = {{0}, 0, -1, {0}, 0, 0, 0, 0, 0, 0, 0, 0, REVENANT_OS_LOG_PRIVACY_DEFAULT};
    return &plain;
}

/* Width and precision are capped, and so is the whole message: a format from an app or a huge argument cannot make the
   padding or the buffer grow without bound. */
#define REVENANT_OS_LOG_MAX_LIMIT 128
#define REVENANT_OS_LOG_MAX_MESSAGE 8192

static inline int revenant_os_log_limit(int value) {
    return value > REVENANT_OS_LOG_MAX_LIMIT ? REVENANT_OS_LOG_MAX_LIMIT : value;
}

static inline int revenant_os_log_digit(int value, char digit) {
    return revenant_os_log_limit(value * 10 + (digit - '0'));
}

static inline void revenant_os_log_text_append(revenant_os_log_text *text, const char *bytes, size_t length) {
    if (length > REVENANT_OS_LOG_MAX_MESSAGE - text->length) {
        length = REVENANT_OS_LOG_MAX_MESSAGE - text->length;
    }
    if (text->length + length + 1 > text->capacity) {
        size_t capacity = (text->length + length + 1) * 2;
        char *grown = realloc(text->bytes, capacity);
        if (!grown) {
            return;
        }
        text->bytes = grown;
        text->capacity = capacity;
    }
    memcpy(text->bytes + text->length, bytes, length);
    text->length += length;
    text->bytes[text->length] = 0;
}

static inline void revenant_os_log_text_appendf(revenant_os_log_text *text, const char *format, ...) {
    char buffer[256];
    va_list arguments, again;
    va_start(arguments, format);
    va_copy(again, arguments);
    int written = vsnprintf(buffer, sizeof buffer, format, arguments);
    va_end(arguments);
    if (written > 0 && (size_t)written < sizeof buffer) {
        revenant_os_log_text_append(text, buffer, (size_t)written);
    } else if (written > 0) {
        char *large = malloc((size_t)written + 1);
        if (large) {
            vsnprintf(large, (size_t)written + 1, format, again);
            revenant_os_log_text_append(text, large, (size_t)written);
            free(large);
        }
    }
    va_end(again);
}

static inline int revenant_os_log_has_flag(const revenant_os_log_spec *spec, char flag) {
    return strchr(spec->flags, flag) != NULL;
}

static inline void revenant_os_log_text_padded(revenant_os_log_text *text, const revenant_os_log_spec *spec, const char *bytes) {
    size_t length = strlen(bytes);
    if (spec->precision > 0 && (size_t)spec->precision < length) {
        length = (size_t)spec->precision;
    }
    size_t padding = spec->width > 0 && (size_t)spec->width > length ? (size_t)spec->width - length : 0;
    char fill = revenant_os_log_has_flag(spec, '0') && !revenant_os_log_has_flag(spec, '-') ? '0' : ' ';
    for (size_t index = 0; !revenant_os_log_has_flag(spec, '-') && index < padding; index++) {
        revenant_os_log_text_append(text, &fill, 1);
    }
    revenant_os_log_text_append(text, bytes, length);
    for (size_t index = 0; revenant_os_log_has_flag(spec, '-') && index < padding; index++) {
        revenant_os_log_text_append(text, " ", 1);
    }
}

static inline int revenant_os_log_next_item(revenant_os_log_args *arguments, revenant_os_log_item *item) {
    if (arguments->remaining == 0 || arguments->offset + 2 > arguments->size) {
        return 0;
    }
    uint32_t count = arguments->buffer[arguments->offset + 1];
    if (arguments->offset + 2 + count > arguments->size) {
        return 0;
    }
    item->type = arguments->buffer[arguments->offset] >> 4;
    item->privacy = arguments->buffer[arguments->offset] & 0x0F;
    item->data = arguments->buffer + arguments->offset + 2;
    item->length = count;
    arguments->offset += 2 + count;
    arguments->remaining--;
    return 1;
}

static inline int revenant_os_log_peek_item(const revenant_os_log_args *arguments, revenant_os_log_item *item) {
    revenant_os_log_args copy = *arguments;
    return revenant_os_log_next_item(&copy, item);
}

static inline unsigned long long revenant_os_log_read_little_endian(const unsigned char *_Nullable data, uint32_t length) {
    unsigned long long value = 0;
    for (uint32_t index = 0; data && index < length && index < sizeof value; index++) {
        value |= (unsigned long long)data[index] << (8 * index);
    }
    return value;
}

/* Takes one argument slot of a va_list; the buffer source has its own item count and always succeeds here. */
static inline int revenant_os_log_claim(revenant_os_log_args *arguments, int slots) {
    if (!arguments->arguments) {
        return 1;
    }
    if (arguments->count < slots) {
        return 0;
    }
    arguments->count -= slots;
    return 1;
}

static inline long long revenant_os_log_fetch_signed(revenant_os_log_args *arguments, const revenant_os_log_spec *spec) {
    if (!arguments->arguments) {
        revenant_os_log_item item;
        if (!revenant_os_log_next_item(arguments, &item)) {
            return 0;
        }
        if (item.type == 6) {
            return arguments->error;
        }
        unsigned long long raw = revenant_os_log_read_little_endian(item.data, item.length);
        if (item.length > 0 && item.length < sizeof raw && ((raw >> (8 * item.length - 1)) & 1)) {
            raw |= ~0ULL << (8 * item.length);
        }
        long long value = (long long)raw;
        if (!strcmp(spec->length, "hh")) {
            return (signed char)value;
        }
        if (!strcmp(spec->length, "h")) {
            return (short)value;
        }
        return value;
    }
    va_list *ap = arguments->arguments;
    if (!strcmp(spec->length, "hh")) {
        return (signed char)va_arg(*ap, int);
    }
    if (!strcmp(spec->length, "h")) {
        return (short)va_arg(*ap, int);
    }
    if (!strcmp(spec->length, "l")) {
        return va_arg(*ap, long);
    }
    if (!strcmp(spec->length, "z") || !strcmp(spec->length, "t")) {
        return va_arg(*ap, long);
    }
    if (!strcmp(spec->length, "ll") || !strcmp(spec->length, "q") || !strcmp(spec->length, "j")) {
        return va_arg(*ap, long long);
    }
    return va_arg(*ap, int);
}

static inline unsigned long long revenant_os_log_fetch_unsigned(revenant_os_log_args *arguments, const revenant_os_log_spec *spec) {
    if (!arguments->arguments) {
        revenant_os_log_item item;
        if (!revenant_os_log_next_item(arguments, &item)) {
            return 0;
        }
        if (item.type == 6) {
            return (unsigned int)arguments->error;
        }
        unsigned long long value = revenant_os_log_read_little_endian(item.data, item.length);
        if (!strcmp(spec->length, "hh")) {
            return (unsigned char)value;
        }
        if (!strcmp(spec->length, "h")) {
            return (unsigned short)value;
        }
        return value;
    }
    va_list *ap = arguments->arguments;
    if (!strcmp(spec->length, "hh")) {
        return (unsigned char)va_arg(*ap, int);
    }
    if (!strcmp(spec->length, "h")) {
        return (unsigned short)va_arg(*ap, int);
    }
    if (!strcmp(spec->length, "l") || !strcmp(spec->length, "z") || !strcmp(spec->length, "t")) {
        return va_arg(*ap, unsigned long);
    }
    if (!strcmp(spec->length, "ll") || !strcmp(spec->length, "q") || !strcmp(spec->length, "j")) {
        return va_arg(*ap, unsigned long long);
    }
    return va_arg(*ap, unsigned int);
}

static inline double revenant_os_log_take_double(revenant_os_log_args *arguments) {
    if (arguments->arguments) {
        return va_arg(*arguments->arguments, double);
    }
    revenant_os_log_item item;
    if (!revenant_os_log_next_item(arguments, &item)) {
        return 0;
    }
    if (item.length == sizeof(double)) {
        double value;
        memcpy(&value, item.data, sizeof value);
        return value;
    }
    if (item.length == sizeof(float)) {
        float value;
        memcpy(&value, item.data, sizeof value);
        return value;
    }
    return 0;
}

static inline const void *_Nullable revenant_os_log_take_pointer(revenant_os_log_args *arguments) {
    if (arguments->arguments) {
        return va_arg(*arguments->arguments, const void *);
    }
    revenant_os_log_item item;
    if (!revenant_os_log_next_item(arguments, &item)) {
        return NULL;
    }
    return (const void *)(uintptr_t)revenant_os_log_read_little_endian(item.data, item.length);
}

static inline void revenant_os_log_skip_item(revenant_os_log_args *arguments) {
    revenant_os_log_item item;
    if (!arguments->arguments) {
        revenant_os_log_next_item(arguments, &item);
    }
}

static inline void revenant_os_log_skip_hash_items(revenant_os_log_args *arguments) {
    revenant_os_log_item item;
    while (revenant_os_log_peek_item(arguments, &item) && item.type == 7) {
        revenant_os_log_next_item(arguments, &item);
    }
}

/* The text of an object's description, or NULL when it has none. The Objective-C runtime is used directly, so the header
   needs no Foundation import. */
static inline const char *_Nullable revenant_os_log_description_text(const void *_Nonnull object, SEL description_selector) {
    id description = ((id (*)(id, SEL))objc_msgSend)((REVENANT_OS_LOG_RENDER_BRIDGE id)object, description_selector);
    SEL utf8_selector = sel_registerName("UTF8String");
    Class description_class = description ? object_getClass(description) : NULL;
    if (description_class && class_respondsToSelector(description_class, utf8_selector)) {
        return ((const char *(*)(id, SEL))objc_msgSend)(description, utf8_selector);
    }
    return NULL;
}

/* The description of an object, or NULL when it has none or its description raises, as the renderer has always printed
   it as (null). An exception is caught where the compiler has Objective-C exceptions; C has none to catch. */
static inline const char *_Nullable revenant_os_log_description(const void *_Nonnull object) {
    Class cls = object_getClass((REVENANT_OS_LOG_RENDER_BRIDGE id)object);
    SEL description_selector = sel_registerName("description");
    if (!cls || !class_respondsToSelector(cls, description_selector)) {
        return NULL;
    }
#if defined(__OBJC__)
    @try {
        return revenant_os_log_description_text(object, description_selector);
    } @catch (id exception) {
        return NULL;
    }
#else
    return revenant_os_log_description_text(object, description_selector);
#endif
}

static inline int revenant_os_log_in_read_only_segment(const void *pointer) {
    uintptr_t address = (uintptr_t)pointer;
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        const struct mach_header *header = _dyld_get_image_header(index);
        uintptr_t slide = (uintptr_t)_dyld_get_image_vmaddr_slide(index);
        size_t headerSize = header->magic == MH_MAGIC_64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header);
        const struct load_command *command = (const struct load_command *)((const char *)header + headerSize);
        for (uint32_t commandIndex = 0; commandIndex < header->ncmds; commandIndex++) {
            uintptr_t start = 0, size = 0;
            vm_prot_t protection = 0;
            int isSegment = 0;
            if (command->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
                start = (uintptr_t)segment->vmaddr, size = (uintptr_t)segment->vmsize, protection = segment->initprot;
                isSegment = 1;
            } else if (command->cmd == LC_SEGMENT) {
                const struct segment_command *segment = (const struct segment_command *)command;
                start = segment->vmaddr, size = segment->vmsize, protection = segment->initprot;
                isSegment = 1;
            }
            if (isSegment && address - (start + slide) < size && !(protection & VM_PROT_WRITE)) {
                return 1;
            }
            command = (const struct load_command *)((const char *)command + command->cmdsize);
        }
    }
    return 0;
}

static inline int revenant_os_log_item_fits(const revenant_os_log_spec *spec, char conversion, const revenant_os_log_item *item) {
    if (item->type == 7) {
        return 1;
    }
    if (item->type == 5) {
        return conversion == 's' && spec->length[0] == 'l';
    }
    switch (conversion) {
    case 'd': case 'i': case 'u': case 'o': case 'x': case 'X':
        if (spec->length[0]) {
            return 1;
        }
        return item->type == 6 || (item->type == 0 && item->length <= 4);
    case 's':
        return spec->length[0] == 'l' || item->type == 2;
    case '@':
        return item->type == 2 || item->type == 4;
    case 'P':
        return item->type == 3;
    default:
        return 1;
    }
}

static inline unsigned long long revenant_os_log_wide_text_size(const void *_Nullable pointer) {
    const unsigned char *units = pointer;
    if (!units) {
        return 0;
    }
    unsigned first = units[0] | (units[1] << 8);
    unsigned second = units[2] | (units[3] << 8);
    if (first == 0) {
        return second >= 1 && second <= 16 ? 5 : 1;
    }
    unsigned long long size = 0;
    for (unsigned i = 0; i < 4; i += 2) {
        unsigned unit = units[i] | (units[i + 1] << 8);
        if (unit == 0) {
            return size + 1;
        }
        if (unit >= 0xD800 && unit <= 0xDFFF) {
            return 1;
        }
        size += unit < 0x80 ? 1 : unit < 0x800 ? 2 : 3;
    }
    return 1;
}

static inline void revenant_os_log_append_mismatch(revenant_os_log_text *text, const char *label, size_t labelLength, const revenant_os_log_item *item) {
    const char *kind = "OBJECT";
    if (item->type == 0 || item->type == 6) {
        kind = "SCALAR";
    } else if (item->type == 1) {
        kind = "COUNT";
    } else if (item->type == 2) {
        kind = "STRING";
    } else if (item->type == 3) {
        kind = "DATA";
    } else if (item->type == 5) {
        kind = "5";
    }
    unsigned level = item->privacy & 3;
    const void *pointer = (const void *)(uintptr_t)revenant_os_log_read_little_endian(item->data, item->length);
    const char *privacy = "";
    if (item->type == 1) {
        privacy = "public";
    } else if (level == 1) {
        privacy = "private";
    } else if (level == 2) {
        privacy = "public";
    } else if (level == 3) {
        privacy = "public private";
    } else if ((item->type == 2 || item->type == 5) && !(item->privacy & 4) && pointer && !revenant_os_log_in_read_only_segment(pointer)) {
        privacy = "private";
    }
    unsigned long long size = 0;
    if (level == 3) {
        size = 0;
    } else if (item->type == 2) {
        const char *string = pointer;
        size = string ? strlen(string) + 1 : 0;
    } else if (item->type == 5) {
        size = revenant_os_log_wide_text_size(pointer);
    } else if (item->type == 0 || item->type == 6) {
        size = item->length;
    } else if (item->type == 4) {
        const char *description = pointer ? revenant_os_log_description(pointer) : NULL;
        size = description ? strlen(description) + 1 : 0;
    }
    revenant_os_log_text_append(text, "<decode: mismatch for [", strlen("<decode: mismatch for ["));
    revenant_os_log_text_append(text, label, labelLength);
    revenant_os_log_text_appendf(text, "] got [%s%s%s sz:%llu]>", kind, *privacy ? " " : "", privacy, size);
}

static inline void revenant_os_log_spec_string(const revenant_os_log_spec *spec, char conversion, char *out, size_t size, const char *length) {
    size_t used = (size_t)snprintf(out, size, "%%%s", spec->flags);
    if (spec->width > 0) {
        used += (size_t)snprintf(out + used, size - used, "%d", spec->width);
    }
    if (spec->precision >= 0) {
        used += (size_t)snprintf(out + used, size - used, ".%d", spec->precision);
    }
    snprintf(out + used, size - used, "%s%c", length, conversion);
}

static inline void revenant_os_log_append_mode(revenant_os_log_text *text, unsigned mode) {
    char string[11] = "----------";
    switch (mode & S_IFMT) {
    case S_IFDIR: string[0] = 'd'; break;
    case S_IFLNK: string[0] = 'l'; break;
    case S_IFCHR: string[0] = 'c'; break;
    case S_IFBLK: string[0] = 'b'; break;
    case S_IFSOCK: string[0] = 's'; break;
    case S_IFIFO: string[0] = 'p'; break;
    default: break;
    }
    static const unsigned bits[9] = {S_IRUSR, S_IWUSR, S_IXUSR, S_IRGRP, S_IWGRP, S_IXGRP, S_IROTH, S_IWOTH, S_IXOTH};
    static const char letters[9] = {'r', 'w', 'x', 'r', 'w', 'x', 'r', 'w', 'x'};
    for (int index = 0; index < 9; index++) {
        if (mode & bits[index]) {
            string[index + 1] = letters[index];
        }
    }
    if (mode & S_ISUID) {
        string[3] = string[3] == 'x' ? 's' : 'S';
    }
    if (mode & S_ISGID) {
        string[6] = string[6] == 'x' ? 's' : 'S';
    }
    if (mode & S_ISVTX) {
        string[9] = string[9] == 'x' ? 't' : 'T';
    }
    revenant_os_log_text_append(text, string, 10);
}

static inline void revenant_os_log_append_integer(revenant_os_log_text *text, const revenant_os_log_spec *spec, char conversion, revenant_os_log_args *arguments) {
    int isSigned = conversion == 'd' || conversion == 'i';
    long long signedValue = isSigned ? revenant_os_log_fetch_signed(arguments, spec) : 0;
    unsigned long long unsignedValue = isSigned ? 0 : revenant_os_log_fetch_unsigned(arguments, spec);
    if (spec->isBool || spec->isBOOL) {
        int truth = isSigned ? signedValue != 0 : unsignedValue != 0;
        revenant_os_log_spec plain = *spec;
        plain.precision = -1;
        plain.flags[0] = 0;
        revenant_os_log_text_padded(text, &plain, spec->isBool ? (truth ? "true" : "false") : (truth ? "YES" : "NO"));
        return;
    }
    if (spec->isErrno) {
        int code = (int)(isSigned ? signedValue : unsignedValue);
        revenant_os_log_text_appendf(text, "[%d: %s]", code, code == 0 ? "Success" : strerror(code));
        return;
    }
    if (spec->isTime) {
        time_t seconds = (time_t)(isSigned ? signedValue : unsignedValue);
        struct tm local;
        char formatted[64];
        if (localtime_r(&seconds, &local) && strftime(formatted, sizeof formatted, "%Y-%m-%d %H:%M:%S%z", &local)) {
            revenant_os_log_text_append(text, formatted, strlen(formatted));
        }
        return;
    }
    if (spec->isMode) {
        revenant_os_log_append_mode(text, (unsigned)(isSigned ? signedValue : unsignedValue));
        return;
    }
    if (spec->isSignal) {
        int code = (int)(isSigned ? signedValue : unsignedValue);
        if (code > 0 && code < NSIG) {
            revenant_os_log_text_appendf(text, "[sig%s: %s]", sys_signame[code], sys_siglist[code]);
        } else {
            revenant_os_log_text_appendf(text, "[%d: Unknown signal]", code);
        }
        return;
    }
    char format[32];
    revenant_os_log_spec_string(spec, conversion, format, sizeof format, "ll");
    if (isSigned) {
        revenant_os_log_text_appendf(text, format, signedValue);
    } else {
        revenant_os_log_text_appendf(text, format, unsignedValue);
    }
}

static inline void revenant_os_log_append_bytes(revenant_os_log_text *text, const revenant_os_log_spec *spec, const unsigned char *bytes, int length) {
    if (spec->isUUID && length == 16) {
        revenant_os_log_text_appendf(text, "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4],
                                     bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);
        return;
    }
    revenant_os_log_text_append(text, "'", 1);
    for (int index = 0; index < length; index++) {
        revenant_os_log_text_appendf(text, index ? " %02X" : "%02X", bytes[index]);
    }
    revenant_os_log_text_append(text, "'", 1);
}

static inline void revenant_os_log_parse_decorators(const char *_Nonnull *_Nonnull cursor, revenant_os_log_spec *spec) {
    const char *close = strchr(*cursor, '}');
    if (!close) {
        return;
    }
    const char *token = *cursor + 1;
    while (token <= close) {
        while (token < close && *token == ' ') {
            token++;
        }
        const char *end = token;
        while (end < close && *end != ',') {
            end++;
        }
        size_t length = (size_t)(end - token);
        if (length == 4 && !strncmp(token, "bool", 4)) {
            spec->isBool = 1;
        } else if (length == 4 && !strncmp(token, "BOOL", 4)) {
            spec->isBOOL = 1;
        } else if (length == 5 && !strncmp(token, "errno", 5)) {
            spec->isErrno = 1;
        } else if (length == 12 && !strncmp(token, "darwin.errno", 12)) {
            spec->isErrno = 1;
        } else if (length == 6 && !strncmp(token, "time_t", 6)) {
            spec->isTime = 1;
        } else if (length == 11 && !strncmp(token, "darwin.mode", 11)) {
            spec->isMode = 1;
        } else if (length == 13 && !strncmp(token, "darwin.signal", 13)) {
            spec->isSignal = 1;
        } else if (length == 6 && !strncmp(token, "uuid_t", 6)) {
            spec->isUUID = 1;
        } else if (length == 6 && !strncmp(token, "public", 6)) {
            spec->privacy = REVENANT_OS_LOG_PRIVACY_PUBLIC;
        } else if ((length == 7 && !strncmp(token, "private", 7)) || (length == 9 && !strncmp(token, "sensitive", 9)) ||
                   (length == 11 && !strncmp(token, "mask.redact", 11))) {
            spec->privacy = REVENANT_OS_LOG_PRIVACY_PRIVATE;
        } else if (length == 9 && !strncmp(token, "mask.hash", 9)) {
            spec->isMask = 1;
            spec->privacy = REVENANT_OS_LOG_PRIVACY_PRIVATE;
        }
        token = end + 1;
    }
    *cursor = close + 1;
}

/* The argument type a va_list conversion stands for, so that both sources decide privacy the same way. */
static inline unsigned revenant_os_log_va_type(char conversion) {
    switch (conversion) {
    case 's':
    case 'S':
        return 2;
    case '@':
        return 4;
    case 'P':
        return 3;
    default:
        return 0;
    }
}

/* Whether an argument is private. The header flag decides when it is set. Without one (auto) the renderer treats
   strings, objects and data as private and numbers and pointers as public; the os_log ABI leaves auto to the system
   (swiftlang/swift stdlib/private/OSLog/OSLogPrivacy.swift), so this default is the renderer's own. */
static inline int revenant_os_log_is_private(unsigned flag, unsigned type, char conversion) {
    if (flag & REVENANT_OS_LOG_PRIVACY_PRIVATE) {
        return 1;
    }
    if (flag & REVENANT_OS_LOG_PRIVACY_PUBLIC) {
        return 0;
    }
    switch (type) {
    case 2:
    case 4:
    case 5:
        return 1;
    case 3:
        return conversion == 'P';
    default:
        return 0;
    }
}

/* Reads and discards the va_list argument of a private conversion, so the next specifier reads the next argument. */
static inline void revenant_os_log_discard(revenant_os_log_args *arguments, const revenant_os_log_spec *spec, char conversion) {
    switch (conversion) {
    case 'e': case 'E': case 'f': case 'F': case 'g': case 'G': case 'a': case 'A':
        revenant_os_log_take_double(arguments);
        break;
    case 'd': case 'i':
        revenant_os_log_fetch_signed(arguments, spec);
        break;
    case 'c':
        revenant_os_log_fetch_signed(arguments, revenant_os_log_plain_spec());
        break;
    case 'C':
        revenant_os_log_fetch_unsigned(arguments, revenant_os_log_plain_spec());
        break;
    case 'u': case 'o': case 'x': case 'X':
        revenant_os_log_fetch_unsigned(arguments, spec);
        break;
    default:
        revenant_os_log_take_pointer(arguments);
        break;
    }
}

static inline void revenant_os_log_escape_into(revenant_os_log_text *out, const unsigned char *bytes, size_t length) {
    size_t index = 0;
    while (index < length) {
        unsigned char byte = bytes[index];
        size_t sequence = 0;
        if (byte < 0x80) {
            sequence = 1;
        } else if (byte >= 0xC2 && byte <= 0xDF) {
            sequence = 2;
        } else if (byte >= 0xE0 && byte <= 0xEF) {
            sequence = 3;
        } else if (byte >= 0xF0 && byte <= 0xF4) {
            sequence = 4;
        }
        int valid = sequence > 0 && index + sequence <= length;
        for (size_t follow = 1; valid && follow < sequence; follow++) {
            valid = (bytes[index + follow] & 0xC0) == 0x80;
        }
        if (valid && sequence == 1) {
            if ((byte >= 0x20 && byte < 0x7F) || byte == '\t' || byte == '\n') {
                revenant_os_log_text_append(out, (const char *)&byte, 1);
            } else {
                char escape[4] = {'\\', '^', byte == 0x7F ? '?' : (char)(byte + '@'), 0};
                revenant_os_log_text_append(out, escape, 3);
            }
            index++;
        } else if (valid) {
            revenant_os_log_text_append(out, (const char *)bytes + index, sequence);
            index += sequence;
        } else {
            unsigned char low = byte & 0x7F;
            char escape[6] = {'\\', 'M', 0, 0, 0, 0};
            if (low >= 0x20 && low < 0x7F) {
                escape[2] = '-';
                escape[3] = (char)low;
            } else {
                escape[2] = '^';
                escape[3] = low == 0x7F ? '?' : (char)(low + '@');
            }
            revenant_os_log_text_append(out, escape, 4);
            index++;
        }
    }
}

static inline char *_Nullable revenant_os_log_format_arguments(const char *format, revenant_os_log_args *ap, int error) {
    revenant_os_log_text text = {NULL, 0, 0};
    revenant_os_log_text_append(&text, "", 0);
    const char *cursor = format;
    while (*cursor) {
        if (*cursor != '%') {
            const char *next = strchr(cursor, '%');
            size_t run = next ? (size_t)(next - cursor) : strlen(cursor);
            revenant_os_log_text_append(&text, cursor, run);
            cursor += run;
            continue;
        }
        const char *specStart = cursor++;
        if (!*cursor) {
            break;
        }
        if (*cursor == '%') {
            revenant_os_log_text_append(&text, "%", 1);
            cursor++;
            continue;
        }
        revenant_os_log_spec spec = {{0}, 0, -1, {0}, 0, 0, 0, 0, 0, 0, 0, 0, REVENANT_OS_LOG_PRIVACY_DEFAULT};
        int literal_precision = 0;
        int missing = 0;
        if (*cursor == '{') {
            revenant_os_log_parse_decorators(&cursor, &spec);
            if (spec.isMask) {
                revenant_os_log_skip_item(ap);
            }
        }
        size_t flagCount = 0;
        while (*cursor && strchr("-+ #0'", *cursor) && flagCount < sizeof spec.flags - 1) {
            spec.flags[flagCount++] = *cursor++;
        }
        if (*cursor == '*') {
            cursor++;
            if (!revenant_os_log_claim(ap, 1)) {
                missing = 1;
            } else {
                int width = (int)revenant_os_log_fetch_signed(ap, revenant_os_log_plain_spec());
                if (width < 0 && flagCount < sizeof spec.flags - 1) {
                    spec.flags[flagCount++] = '-';
                }
                int magnitude = width < -REVENANT_OS_LOG_MAX_LIMIT ? REVENANT_OS_LOG_MAX_LIMIT : width < 0 ? -width : width;
                spec.width = revenant_os_log_limit(magnitude);
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
                if (!revenant_os_log_claim(ap, 1)) {
                    missing = 1;
                } else {
                    int precision = (int)revenant_os_log_fetch_signed(ap, revenant_os_log_plain_spec());
                    spec.precision = precision < 0 ? -1 : revenant_os_log_limit(precision);
                }
            } else {
                literal_precision = 1;
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
        size_t labelLength = (size_t)(cursor - specStart);
        if (missing) {
            revenant_os_log_text_append(&text, REVENANT_OS_LOG_MISSING_TEXT, strlen(REVENANT_OS_LOG_MISSING_TEXT));
            continue;
        }
        if (!ap->arguments && conversion == 'P' && spec.precision < 0) {
            revenant_os_log_text_append(&text, "<decode: can't compose [", strlen("<decode: can't compose ["));
            revenant_os_log_text_append(&text, specStart, labelLength);
            revenant_os_log_text_append(&text, "]>", strlen("]>"));
            break;
        }
        if (!ap->arguments) {
            revenant_os_log_skip_hash_items(ap);
        }
        revenant_os_log_item pending;
        if (!ap->arguments && strchr("diouxXcsSeEfFgGaAp@mC", conversion) && !revenant_os_log_peek_item(ap, &pending)) {
            revenant_os_log_text_append(&text, REVENANT_OS_LOG_MISSING_TEXT, strlen(REVENANT_OS_LOG_MISSING_TEXT));
            continue;
        }
        if (literal_precision && (conversion == 's' || conversion == 'S' || conversion == 'P')) {
            revenant_os_log_skip_item(ap);
        }
        if (!ap->arguments && strchr("diouxX", conversion)) {
            revenant_os_log_item item;
            if (revenant_os_log_peek_item(ap, &item) && item.type == 0 && item.length == 0) {
                revenant_os_log_next_item(ap, &item);
                revenant_os_log_text_append(&text, REVENANT_OS_LOG_MISSING_TEXT, strlen(REVENANT_OS_LOG_MISSING_TEXT));
                continue;
            }
        }
        if (!ap->arguments) {
            revenant_os_log_item item;
            if (revenant_os_log_peek_item(ap, &item) && !revenant_os_log_item_fits(&spec, conversion, &item)) {
                revenant_os_log_next_item(ap, &item);
                revenant_os_log_append_mismatch(&text, specStart, labelLength, &item);
                continue;
            }
        }
        /* A buffer argument is private when its header flag says so, or by the default for its type. */
        if (!ap->arguments && strchr("diouxXcsSeEfFgGaApP@C", conversion)) {
            revenant_os_log_item item;
            if (revenant_os_log_peek_item(ap, &item) && revenant_os_log_is_private(item.privacy, item.type, conversion)) {
                revenant_os_log_next_item(ap, &item);
                revenant_os_log_text_append(&text, REVENANT_OS_LOG_PRIVATE_TEXT, strlen(REVENANT_OS_LOG_PRIVATE_TEXT));
                continue;
            }
        }
        /* A va_list conversion consumes one argument; without one left the message says so. */
        if (ap->arguments && strchr("diouxXcsSeEfFgGaApP@C", conversion)) {
            if (!revenant_os_log_claim(ap, 1)) {
                revenant_os_log_text_append(&text, REVENANT_OS_LOG_MISSING_TEXT, strlen(REVENANT_OS_LOG_MISSING_TEXT));
                continue;
            }
            if (revenant_os_log_is_private(spec.privacy, revenant_os_log_va_type(conversion), conversion)) {
                revenant_os_log_discard(ap, &spec, conversion);
                revenant_os_log_text_append(&text, REVENANT_OS_LOG_PRIVATE_TEXT, strlen(REVENANT_OS_LOG_PRIVATE_TEXT));
                continue;
            }
        }
        switch (conversion) {
        case 'd': case 'i': case 'u': case 'o': case 'x': case 'X':
            revenant_os_log_append_integer(&text, &spec, conversion, ap);
            break;
        case 'c': {
            if (spec.isBool || spec.isBOOL) {
                revenant_os_log_append_integer(&text, &spec, 'd', ap);
                break;
            }
            char string[2] = {(char)revenant_os_log_fetch_signed(ap, revenant_os_log_plain_spec()), 0};
            spec.precision = -1;
            if (string[0]) {
                revenant_os_log_text_padded(&text, &spec, string);
            }
            break;
        }
        case 'C': {
            char string[16];
            wint_t value = (wint_t)revenant_os_log_fetch_unsigned(ap, revenant_os_log_plain_spec());
            snprintf(string, sizeof string, "%lc", value);
            revenant_os_log_text_append(&text, string, strlen(string));
            break;
        }
        case 'e': case 'E': case 'f': case 'F': case 'g': case 'G': case 'a': case 'A': {
            double value = revenant_os_log_take_double(ap);
            char spec_format[32];
            revenant_os_log_spec_string(&spec, conversion, spec_format, sizeof spec_format, "");
            revenant_os_log_text_appendf(&text, spec_format, value);
            break;
        }
        case 'p': {
            const void *value = revenant_os_log_take_pointer(ap);
            char spec_format[32];
            revenant_os_log_spec_string(&spec, conversion, spec_format, sizeof spec_format, "");
            revenant_os_log_text_appendf(&text, spec_format, value);
            break;
        }
        case 's': case 'S': {
            if (conversion == 'S' || !strcmp(spec.length, "l")) {
                const wchar_t *wide = revenant_os_log_take_pointer(ap);
                char spec_format[32];
                revenant_os_log_spec_string(&spec, 's', spec_format, sizeof spec_format, "l");
                if (wide) {
                    revenant_os_log_text_appendf(&text, spec_format, wide);
                } else {
                    revenant_os_log_text_padded(&text, &spec, "(null)");
                }
                break;
            }
            const char *string = revenant_os_log_take_pointer(ap);
            revenant_os_log_text_padded(&text, &spec, string ? string : "(null)");
            break;
        }
        case '@': {
            revenant_os_log_item next;
            if (!ap->arguments && revenant_os_log_peek_item(ap, &next) && next.type == 2) {
                revenant_os_log_next_item(ap, &next);
                const char *string = (const char *)(uintptr_t)revenant_os_log_read_little_endian(next.data, next.length);
                spec.precision = -1;
                revenant_os_log_text_padded(&text, &spec, string ? string : "(null)");
                break;
            }
            const void *object = revenant_os_log_take_pointer(ap);
            const char *description = object ? revenant_os_log_description(object) : NULL;
            spec.precision = -1;
            revenant_os_log_text_padded(&text, &spec, description ? description : "(null)");
            break;
        }
        case 'P': {
            const unsigned char *bytes = revenant_os_log_take_pointer(ap);
            revenant_os_log_append_bytes(&text, &spec, bytes, spec.precision > 0 ? spec.precision : 0);
            break;
        }
        case 'm':
            revenant_os_log_skip_item(ap);
            revenant_os_log_text_append(&text, strerror(error), strlen(strerror(error)));
            break;
        default:
            revenant_os_log_text_append(&text, &conversion, 1);
            break;
        }
    }
    while (text.length && strchr(" \t\n\r", text.bytes[text.length - 1])) {
        text.bytes[--text.length] = 0;
    }
    revenant_os_log_text escaped = {NULL, 0, 0};
    revenant_os_log_text_append(&escaped, "", 0);
    revenant_os_log_escape_into(&escaped, (const unsigned char *)text.bytes, text.length);
    free(text.bytes);
    return escaped.bytes;
}

/* Renders a va_list of `count` arguments. The caller keeps its va_list: the rendering reads a copy. */
static inline char *_Nullable revenant_os_log_render_arguments(const char *format, va_list arguments, int count, int error) {
    va_list list;
    va_copy(list, arguments);
    revenant_os_log_args args = {&list, count, NULL, 0, 0, 0, error};
    char *text = revenant_os_log_format_arguments(format, &args, error);
    va_end(list);
    return text;
}

/* Renders the packed buffer the compiler's os_log builtin emits for `format`. */
static inline char *_Nullable revenant_os_log_render_buffer(const char *format, const uint8_t *buffer, uint32_t size, int error) {
    revenant_os_log_args args = {NULL, 0, buffer, size, 0, 0, error};
    if (buffer && size >= 2) {
        args.remaining = buffer[1];
        args.offset = 2;
    }
    return revenant_os_log_format_arguments(format, &args, error);
}

#pragma clang assume_nonnull end
