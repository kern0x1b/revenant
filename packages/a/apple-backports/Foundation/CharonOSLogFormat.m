#import "CharonOSLog.h"
#include <errno.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <signal.h>
#include <sys/stat.h>
#include <time.h>
#include <wchar.h>

typedef struct {
    char *bytes;
    size_t length;
    size_t capacity;
} CharonText;

typedef struct {
    char flags[8];
    int width;
    int precision;
    char length[3];
    BOOL isBool, isBOOL, isErrno, isTime, isMode, isSignal, isUUID, isMask;
} CharonSpec;

/* The arguments of one call. The varargs path reads the caller's va_list. The buffer path reads what the
   compiler packed for an os_log macro: a summary byte, the item count, then per item a descriptor byte (the
   type in its high nibble, the privacy in its low one), a length byte and that many bytes. A string, an
   object and the bytes of %P are a pointer to their value, and the pointer is the item's data. */
typedef struct {
    va_list *arguments;
    const unsigned char *buffer;
    uint32_t size;
    uint32_t offset;
    unsigned remaining;
    int error;
} CharonArgs;

/* One item of the buffer: its type, its privacy nibble, and its data (length bytes). */
typedef struct {
    unsigned type;
    unsigned privacy;
    const unsigned char *data;
    uint32_t length;
} CharonItem;

static const CharonSpec charon_plain_spec = {.width = 0, .precision = -1};

static void text_append(CharonText *text, const char *bytes, size_t length)
{
    if (text->length + length + 1 > text->capacity) {
        text->capacity = (text->length + length + 1) * 2;
        text->bytes = realloc(text->bytes, text->capacity);
    }
    memcpy(text->bytes + text->length, bytes, length);
    text->length += length;
    text->bytes[text->length] = 0;
}

static void text_appendf(CharonText *text, const char *format, ...)
{
    char buffer[256];
    va_list arguments, again;
    va_start(arguments, format);
    va_copy(again, arguments);
    int written = vsnprintf(buffer, sizeof buffer, format, arguments);
    va_end(arguments);
    if (written > 0 && (size_t)written < sizeof buffer) {
        text_append(text, buffer, (size_t)written);
    } else if (written > 0) {
        char *large = malloc((size_t)written + 1);
        vsnprintf(large, (size_t)written + 1, format, again);
        text_append(text, large, (size_t)written);
        free(large);
    }
    va_end(again);
}

static BOOL has_flag(const CharonSpec *spec, char flag)
{
    return strchr(spec->flags, flag) != NULL;
}

static void text_padded(CharonText *text, const CharonSpec *spec, const char *bytes)
{
    size_t length = strlen(bytes);
    if (spec->precision > 0 && (size_t)spec->precision < length)
        length = (size_t)spec->precision;
    size_t padding = spec->width > 0 && (size_t)spec->width > length ? (size_t)spec->width - length : 0;
    char fill = has_flag(spec, '0') && !has_flag(spec, '-') ? '0' : ' ';
    for (size_t index = 0; !has_flag(spec, '-') && index < padding; index++)
        text_append(text, &fill, 1);
    text_append(text, bytes, length);
    for (size_t index = 0; has_flag(spec, '-') && index < padding; index++)
        text_append(text, " ", 1);
}

static BOOL next_item(CharonArgs *arguments, CharonItem *item)
{
    if (arguments->remaining == 0 || arguments->offset + 2 > arguments->size)
        return NO;
    uint32_t count = arguments->buffer[arguments->offset + 1];
    if (arguments->offset + 2 + count > arguments->size)
        return NO;
    item->type = arguments->buffer[arguments->offset] >> 4;
    item->privacy = arguments->buffer[arguments->offset] & 0x0F;
    item->data = arguments->buffer + arguments->offset + 2;
    item->length = count;
    arguments->offset += 2 + count;
    arguments->remaining--;
    return YES;
}

/* The item the next conversion would read, left in place. */
static BOOL peek_item(const CharonArgs *arguments, CharonItem *item)
{
    CharonArgs copy = *arguments;
    return next_item(&copy, item);
}

static unsigned long long read_little_endian(const unsigned char *data, uint32_t length)
{
    unsigned long long value = 0;
    for (uint32_t index = 0; index < length && index < sizeof value; index++)
        value |= (unsigned long long)data[index] << (8 * index);
    return value;
}

static long long fetch_signed(CharonArgs *arguments, const CharonSpec *spec)
{
    if (!arguments->arguments) {
        CharonItem item;
        if (!next_item(arguments, &item))
            return 0;
        /* Measured: a type 6 item is errno, and an integer conversion writes its value, whatever the item holds. */
        if (item.type == 6)
            return arguments->error;
        unsigned long long raw = read_little_endian(item.data, item.length);
        if (item.length > 0 && item.length < sizeof raw && ((raw >> (8 * item.length - 1)) & 1))
            raw |= ~0ULL << (8 * item.length);
        long long value = (long long)raw;
        if (!strcmp(spec->length, "hh"))
            return (signed char)value;
        if (!strcmp(spec->length, "h"))
            return (short)value;
        return value;
    }
    va_list *ap = arguments->arguments;
    if (!strcmp(spec->length, "hh"))
        return (signed char)va_arg(*ap, int);
    if (!strcmp(spec->length, "h"))
        return (short)va_arg(*ap, int);
    if (!strcmp(spec->length, "l"))
        return va_arg(*ap, long);
    if (!strcmp(spec->length, "z") || !strcmp(spec->length, "t"))
        return va_arg(*ap, long);
    if (!strcmp(spec->length, "ll") || !strcmp(spec->length, "q") || !strcmp(spec->length, "j"))
        return va_arg(*ap, long long);
    return va_arg(*ap, int);
}

static unsigned long long fetch_unsigned(CharonArgs *arguments, const CharonSpec *spec)
{
    if (!arguments->arguments) {
        CharonItem item;
        if (!next_item(arguments, &item))
            return 0;
        if (item.type == 6)
            return (unsigned int)arguments->error;
        unsigned long long value = read_little_endian(item.data, item.length);
        if (!strcmp(spec->length, "hh"))
            return (unsigned char)value;
        if (!strcmp(spec->length, "h"))
            return (unsigned short)value;
        return value;
    }
    va_list *ap = arguments->arguments;
    if (!strcmp(spec->length, "hh"))
        return (unsigned char)va_arg(*ap, int);
    if (!strcmp(spec->length, "h"))
        return (unsigned short)va_arg(*ap, int);
    if (!strcmp(spec->length, "l") || !strcmp(spec->length, "z") || !strcmp(spec->length, "t"))
        return va_arg(*ap, unsigned long);
    if (!strcmp(spec->length, "ll") || !strcmp(spec->length, "q") || !strcmp(spec->length, "j"))
        return va_arg(*ap, unsigned long long);
    return va_arg(*ap, unsigned int);
}

static double take_double(CharonArgs *arguments)
{
    if (arguments->arguments)
        return va_arg(*arguments->arguments, double);
    CharonItem item;
    if (!next_item(arguments, &item))
        return 0;
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

static const void *take_pointer(CharonArgs *arguments)
{
    if (arguments->arguments)
        return va_arg(*arguments->arguments, const void *);
    CharonItem item;
    if (!next_item(arguments, &item))
        return NULL;
    return (const void *)(uintptr_t)read_little_endian(item.data, item.length);
}

/* The item of a conversion that prints nothing from its argument, which the compiler still packs: %m. */
static void skip_item(CharonArgs *arguments)
{
    CharonItem item;
    if (!arguments->arguments)
        next_item(arguments, &item);
}

/* Measured on the host: a type 7 item (the hash of a masked value) is passed over by the conversion after it, and
   the value is the item after it. A buffer that holds only the hash leaves the conversion with no item. */
static void skip_hash_items(CharonArgs *arguments)
{
    CharonItem item;
    while (peek_item(arguments, &item) && item.type == 7)
        next_item(arguments, &item);
}

static NSString *description_of(id object);

/* Measured on the host: a string in a read-only segment of a loaded image (literal and const data) is written with no
   privacy word at nibble 0, and a string anywhere else (writable data, the heap, the stack) as private. */
static BOOL in_read_only_segment(const void *pointer)
{
    uintptr_t address = (uintptr_t)pointer;
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        const struct mach_header *header = _dyld_get_image_header(index);
        uintptr_t slide = (uintptr_t)_dyld_get_image_vmaddr_slide(index);
        size_t headerSize = header->magic == MH_MAGIC_64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header);
        const struct load_command *command = (const struct load_command *)((const char *)header + headerSize);
        for (uint32_t commandIndex = 0; commandIndex < header->ncmds; commandIndex++) {
            uintptr_t start = 0, size = 0;
            vm_prot_t protection = 0;
            BOOL isSegment = NO;
            if (command->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
                start = (uintptr_t)segment->vmaddr, size = (uintptr_t)segment->vmsize, protection = segment->initprot;
                isSegment = YES;
            } else if (command->cmd == LC_SEGMENT) {
                const struct segment_command *segment = (const struct segment_command *)command;
                start = segment->vmaddr, size = segment->vmsize, protection = segment->initprot;
                isSegment = YES;
            }
            if (isSegment && address - (start + slide) < size && !(protection & VM_PROT_WRITE))
                return YES;
            command = (const struct load_command *)((const char *)command + command->cmdsize);
        }
    }
    return NO;
}

/* Measured on the host, for the buffer path: an integer without a length modifier takes a scalar of up to four
   bytes or a type 6 item, %s takes a string, %@ a string or an object, and %.Np a byte run. Any other item is
   written as a mismatch and consumed. A type 5 item is a mismatch for %d, measured; a wide-string conversion reads
   it as before, and the other conversions are taken to mismatch as well, not measured. A type 7 item is passed over. */
static BOOL item_fits(const CharonSpec *spec, char conversion, const CharonItem *item)
{
    if (item->type == 7)
        return YES;
    if (item->type == 5)
        return conversion == 's' && spec->length[0] == 'l';
    switch (conversion) {
    case 'd': case 'i': case 'u': case 'o': case 'x': case 'X':
        if (spec->length[0])
            return YES;
        return item->type == 6 || (item->type == 0 && item->length <= 4);
    case 's':
        return spec->length[0] == 'l' || item->type == 2;
    case '@':
        return item->type == 2 || item->type == 4;
    case 'P':
        return item->type == 3;
    default:
        return YES;
    }
}

/* The size the host reports for a type 5 item of 8 bytes, a pointer to UTF-16LE units (measured on the host: the
   random pointed values, a sweep of each byte position of the first two units, and crafted texts). A first unit of
   0 gives 5 when the second unit is 1 to 16, and 1 otherwise. Otherwise the text is the units before a nul among the
   first two units, counted in UTF-8 bytes, and the size is that count plus one; a surrogate before that nul, or no
   nul among the two units, gives 1. A nul at the third unit or later is not seen. A NULL pointer gives 0, measured,
   and at nibble 0 it has no privacy word. Other lengths of the item are not measured. */
static unsigned long long wide_text_size(const void *pointer)
{
    const unsigned char *units = pointer;
    if (!units)
        return 0;
    unsigned first = units[0] | (units[1] << 8);
    unsigned second = units[2] | (units[3] << 8);
    if (first == 0)
        return second >= 1 && second <= 16 ? 5 : 1;
    unsigned long long size = 0;
    for (unsigned i = 0; i < 4; i += 2) {
        unsigned unit = units[i] | (units[i + 1] << 8);
        if (unit == 0)
            return size + 1;
        if (unit >= 0xD800 && unit <= 0xDFFF)
            return 1;
        size += unit < 0x80 ? 1 : unit < 0x800 ? 2 : 3;
    }
    return 1;
}

/* The mismatch marker: the conversion as the format writes it, the kind of the item the host names, the privacy
   words it prints, and the size it reports. Measured: a string's size is its length and a nul; a scalar's is its
   length byte; an object's is the length of its description and a nul; a count or byte run reports 0. Privacy
   nibble 3 reports "public private" and a size of 0, and the value is not read. A type 5 item is named by its type
   number, and its size is the wide_text_size of its pointer. */
static void append_mismatch(CharonText *text, const char *label, size_t labelLength, const CharonItem *item)
{
    const char *kind = "OBJECT";
    if (item->type == 0 || item->type == 6)
        kind = "SCALAR";
    else if (item->type == 1)
        kind = "COUNT";
    else if (item->type == 2)
        kind = "STRING";
    else if (item->type == 3)
        kind = "DATA";
    else if (item->type == 5)
        kind = "5";
    unsigned level = item->privacy & 3;
    const void *pointer = (const void *)(uintptr_t)read_little_endian(item->data, item->length);
    const char *privacy = "";
    if (item->type == 1)
        privacy = "public";
    else if (level == 1)
        privacy = "private";
    else if (level == 2)
        privacy = "public";
    else if (level == 3)
        privacy = "public private";
    /* Measured: a NULL string at nibble 0 has no word either, as a read-only one does. */
    else if ((item->type == 2 || item->type == 5) && !(item->privacy & 4) && pointer && !in_read_only_segment(pointer))
        privacy = "private";
    unsigned long long size = 0;
    if (level == 3) {
        size = 0;
    } else if (item->type == 2) {
        const char *string = pointer;
        size = string ? strlen(string) + 1 : 0;
    } else if (item->type == 5) {
        size = wide_text_size(pointer);
    } else if (item->type == 0 || item->type == 6) {
        size = item->length;
    } else if (item->type == 4) {
        NSString *description = description_of((__bridge id)pointer);
        size = description ? strlen(description.UTF8String) + 1 : 0;
    }
    text_append(text, "<decode: mismatch for [", strlen("<decode: mismatch for ["));
    text_append(text, label, labelLength);
    text_appendf(text, "] got [%s%s%s sz:%llu]>", kind, *privacy ? " " : "", privacy, size);
}

static void spec_string(const CharonSpec *spec, char conversion, char *out, size_t size, const char *length)
{
    size_t used = (size_t)snprintf(out, size, "%%%s", spec->flags);
    if (spec->width > 0)
        used += (size_t)snprintf(out + used, size - used, "%d", spec->width);
    if (spec->precision >= 0)
        used += (size_t)snprintf(out + used, size - used, ".%d", spec->precision);
    snprintf(out + used, size - used, "%s%c", length, conversion);
}

static void append_mode(CharonText *text, unsigned mode)
{
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
    for (int index = 0; index < 9; index++)
        if (mode & bits[index])
            string[index + 1] = letters[index];
    if (mode & S_ISUID)
        string[3] = string[3] == 'x' ? 's' : 'S';
    if (mode & S_ISGID)
        string[6] = string[6] == 'x' ? 's' : 'S';
    if (mode & S_ISVTX)
        string[9] = string[9] == 'x' ? 't' : 'T';
    text_append(text, string, 10);
}

static void append_integer(CharonText *text, const CharonSpec *spec, char conversion, CharonArgs *arguments, int error)
{
    BOOL isSigned = conversion == 'd' || conversion == 'i';
    long long signedValue = isSigned ? fetch_signed(arguments, spec) : 0;
    unsigned long long unsignedValue = isSigned ? 0 : fetch_unsigned(arguments, spec);
    if (spec->isBool || spec->isBOOL) {
        BOOL truth = isSigned ? signedValue != 0 : unsignedValue != 0;
        text_padded(text, &(CharonSpec){.width = spec->width, .precision = -1},
                    spec->isBool ? (truth ? "true" : "false") : (truth ? "YES" : "NO"));
        return;
    }
    if (spec->isErrno) {
        int code = (int)(isSigned ? signedValue : unsignedValue);
        text_appendf(text, "[%d: %s]", code, code == 0 ? "Success" : strerror(code));
        return;
    }
    if (spec->isTime) {
        time_t seconds = (time_t)(isSigned ? signedValue : unsignedValue);
        struct tm local;
        char formatted[64];
        if (localtime_r(&seconds, &local) && strftime(formatted, sizeof formatted, "%Y-%m-%d %H:%M:%S%z", &local))
            text_append(text, formatted, strlen(formatted));
        return;
    }
    if (spec->isMode) {
        append_mode(text, (unsigned)(isSigned ? signedValue : unsignedValue));
        return;
    }
    if (spec->isSignal) {
        int code = (int)(isSigned ? signedValue : unsignedValue);
        if (code > 0 && code < NSIG)
            text_appendf(text, "[sig%s: %s]", sys_signame[code], sys_siglist[code]);
        else
            text_appendf(text, "[%d: Unknown signal]", code);
        return;
    }
    char format[32];
    spec_string(spec, conversion, format, sizeof format, "ll");
    if (isSigned)
        text_appendf(text, format, signedValue);
    else
        text_appendf(text, format, unsignedValue);
    (void)error;
}

static void append_bytes(CharonText *text, const CharonSpec *spec, const unsigned char *bytes, int length)
{
    if (spec->isUUID && length == 16) {
        text_appendf(text, "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4],
                     bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);
        return;
    }
    text_append(text, "'", 1);
    for (int index = 0; index < length; index++)
        text_appendf(text, index ? " %02X" : "%02X", bytes[index]);
    text_append(text, "'", 1);
}

static NSString *description_of(id object)
{
    @try {
        return [object description];
    } @catch (NSException *exception) {
        return nil;
    }
}

static void parse_decorators(const char **cursor, CharonSpec *spec)
{
    const char *close = strchr(*cursor, '}');
    if (!close)
        return;
    const char *token = *cursor + 1;
    while (token <= close) {
        while (token < close && *token == ' ')
            token++;
        const char *end = token;
        while (end < close && *end != ',')
            end++;
        size_t length = (size_t)(end - token);
        if (length == 4 && !strncmp(token, "bool", 4))
            spec->isBool = YES;
        else if (length == 4 && !strncmp(token, "BOOL", 4))
            spec->isBOOL = YES;
        else if (length == 5 && !strncmp(token, "errno", 5))
            spec->isErrno = YES;
        else if (length == 12 && !strncmp(token, "darwin.errno", 12))
            spec->isErrno = YES;
        else if (length == 6 && !strncmp(token, "time_t", 6))
            spec->isTime = YES;
        else if (length == 11 && !strncmp(token, "darwin.mode", 11))
            spec->isMode = YES;
        else if (length == 13 && !strncmp(token, "darwin.signal", 13))
            spec->isSignal = YES;
        else if (length == 6 && !strncmp(token, "uuid_t", 6))
            spec->isUUID = YES;
        else if (length == 9 && !strncmp(token, "mask.hash", 9))
            spec->isMask = YES;
        token = end + 1;
    }
    *cursor = close + 1;
}

static void escape_into(CharonText *out, const unsigned char *bytes, size_t length)
{
    size_t index = 0;
    while (index < length) {
        unsigned char byte = bytes[index];
        size_t sequence = 0;
        if (byte < 0x80)
            sequence = 1;
        else if (byte >= 0xC2 && byte <= 0xDF)
            sequence = 2;
        else if (byte >= 0xE0 && byte <= 0xEF)
            sequence = 3;
        else if (byte >= 0xF0 && byte <= 0xF4)
            sequence = 4;
        BOOL valid = sequence > 0 && index + sequence <= length;
        for (size_t follow = 1; valid && follow < sequence; follow++)
            valid = (bytes[index + follow] & 0xC0) == 0x80;
        if (valid && sequence == 1) {
            if ((byte >= 0x20 && byte < 0x7F) || byte == '\t' || byte == '\n') {
                text_append(out, (const char *)&byte, 1);
            } else {
                char escape[4] = {'\\', '^', byte == 0x7F ? '?' : (char)(byte + '@'), 0};
                text_append(out, escape, 3);
            }
            index++;
        } else if (valid) {
            text_append(out, (const char *)bytes + index, sequence);
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
            text_append(out, escape, 4);
            index++;
        }
    }
}

static char *format_arguments(const char *format, CharonArgs *ap, int error)
{
    CharonText text = {NULL, 0, 0};
    text_append(&text, "", 0);
    const char *cursor = format;
    while (*cursor) {
        if (*cursor != '%') {
            const char *next = strchr(cursor, '%');
            size_t run = next ? (size_t)(next - cursor) : strlen(cursor);
            text_append(&text, cursor, run);
            cursor += run;
            continue;
        }
        const char *specStart = cursor++;
        if (!*cursor)
            break;
        if (*cursor == '%') {
            text_append(&text, "%", 1);
            cursor++;
            continue;
        }
        CharonSpec spec = {.width = 0, .precision = -1};
        BOOL literal_precision = NO;
        if (*cursor == '{') {
            parse_decorators(&cursor, &spec);
            /* A masked value is packed as the hash of the value, ahead of the value and of any count item. */
            if (spec.isMask)
                skip_item(ap);
        }
        size_t flagCount = 0;
        while (*cursor && strchr("-+ #0'", *cursor) && flagCount < sizeof spec.flags - 1)
            spec.flags[flagCount++] = *cursor++;
        if (*cursor == '*') {
            int width = (int)fetch_signed(ap, &charon_plain_spec);
            if (width < 0 && flagCount < sizeof spec.flags - 1) {
                spec.flags[flagCount++] = '-';
                width = -width;
            }
            spec.width = width;
            cursor++;
        } else {
            while (*cursor >= '0' && *cursor <= '9')
                spec.width = spec.width * 10 + (*cursor++ - '0');
        }
        if (*cursor == '.') {
            cursor++;
            spec.precision = 0;
            if (*cursor == '*') {
                spec.precision = (int)fetch_signed(ap, &charon_plain_spec);
                cursor++;
            } else {
                literal_precision = YES;
                while (*cursor >= '0' && *cursor <= '9')
                    spec.precision = spec.precision * 10 + (*cursor++ - '0');
            }
        }
        if (*cursor == 'h' || *cursor == 'l') {
            spec.length[0] = *cursor++;
            if (*cursor == spec.length[0])
                spec.length[1] = *cursor++;
        } else if (*cursor && strchr("Lqjzt", *cursor)) {
            spec.length[0] = *cursor++;
        }
        char conversion = *cursor;
        if (!conversion)
            break;
        cursor++;
        size_t labelLength = (size_t)(cursor - specStart);
        /* Measured: %P without a precision writes its own marker in place of the value, and the rest of the format
           is not written after it, whatever the buffer holds. */
        if (!ap->arguments && conversion == 'P' && spec.precision < 0) {
            text_append(&text, "<decode: can't compose [", strlen("<decode: can't compose ["));
            text_append(&text, specStart, labelLength);
            text_append(&text, "]>", strlen("]>"));
            break;
        }
        if (!ap->arguments)
            skip_hash_items(ap);
        /* Measured on the host, with a buffer that holds no item: each value conversion writes
           <decode: missing data> in place of its value, and the text after it goes on. */
        CharonItem pending;
        if (!ap->arguments && strchr("diouxXcsSeEfFgGaAp@mC", conversion) && !peek_item(ap, &pending)) {
            text_append(&text, "<decode: missing data>", strlen("<decode: missing data>"));
            continue;
        }
        /* Measured: a literal precision on a string or a byte run is packed as a count item of its own, ahead
           of the value. An integer's or a float's precision is not packed at all. */
        if (literal_precision && (conversion == 's' || conversion == 'S' || conversion == 'P'))
            skip_item(ap);
        /* Measured on the host: a zero-length scalar is an item with no value. An integer conversion takes it, and writes
           <decode: missing data> in place of its value; the next conversion takes the item after it. */
        if (!ap->arguments && strchr("diouxX", conversion)) {
            CharonItem item;
            if (peek_item(ap, &item) && item.type == 0 && item.length == 0) {
                next_item(ap, &item);
                text_append(&text, "<decode: missing data>", strlen("<decode: missing data>"));
                continue;
            }
        }
        /* An item of another kind than the conversion takes is consumed and written as a mismatch. */
        if (!ap->arguments) {
            CharonItem item;
            if (peek_item(ap, &item) && !item_fits(&spec, conversion, &item)) {
                next_item(ap, &item);
                append_mismatch(&text, specStart, labelLength, &item);
                continue;
            }
        }
        switch (conversion) {
        case 'd': case 'i': case 'u': case 'o': case 'x': case 'X':
            append_integer(&text, &spec, conversion, ap, error);
            break;
        case 'c': {
            if (spec.isBool || spec.isBOOL) {
                append_integer(&text, &spec, 'd', ap, error);
                break;
            }
            char string[2] = {(char)fetch_signed(ap, &charon_plain_spec), 0};
            spec.precision = -1;
            if (string[0])
                text_padded(&text, &spec, string);
            break;
        }
        case 'C': {
            char string[16];
            wint_t value = (wint_t)fetch_unsigned(ap, &charon_plain_spec);
            snprintf(string, sizeof string, "%lc", value);
            text_append(&text, string, strlen(string));
            break;
        }
        case 'e': case 'E': case 'f': case 'F': case 'g': case 'G': case 'a': case 'A': {
            double value = take_double(ap);
            char spec_format[32];
            spec_string(&spec, conversion, spec_format, sizeof spec_format, "");
            text_appendf(&text, spec_format, value);
            break;
        }
        case 'p': {
            const void *value = take_pointer(ap);
            char spec_format[32];
            spec_string(&spec, conversion, spec_format, sizeof spec_format, "");
            text_appendf(&text, spec_format, value);
            break;
        }
        case 's': case 'S': {
            if (conversion == 'S' || !strcmp(spec.length, "l")) {
                const wchar_t *wide = take_pointer(ap);
                char spec_format[32];
                spec_string(&spec, 's', spec_format, sizeof spec_format, "l");
                if (wide)
                    text_appendf(&text, spec_format, wide);
                else
                    text_padded(&text, &spec, "(null)");
                break;
            }
            const char *string = take_pointer(ap);
            text_padded(&text, &spec, string ?: "(null)");
            break;
        }
        case '@': {
            /* Measured: a string item under %@ is written as the string, not read as an object. */
            CharonItem next;
            if (!ap->arguments && peek_item(ap, &next) && next.type == 2) {
                next_item(ap, &next);
                const char *string = (const char *)(uintptr_t)read_little_endian(next.data, next.length);
                spec.precision = -1;
                text_padded(&text, &spec, string ?: "(null)");
                break;
            }
            id object = (__bridge id)take_pointer(ap);
            NSString *description = object ? description_of(object) : nil;
            spec.precision = -1;
            text_padded(&text, &spec, description ? description.UTF8String : "(null)");
            break;
        }
        case 'P': {
            const unsigned char *bytes = take_pointer(ap);
            append_bytes(&text, &spec, bytes, spec.precision > 0 ? spec.precision : 0);
            break;
        }
        case 'm':
            skip_item(ap);
            text_append(&text, strerror(error), strlen(strerror(error)));
            break;
        default:
            text_append(&text, &conversion, 1);
            break;
        }
    }
    while (text.length && strchr(" \t\n\r", text.bytes[text.length - 1]))
        text.bytes[--text.length] = 0;
    CharonText escaped = {NULL, 0, 0};
    text_append(&escaped, "", 0);
    escape_into(&escaped, (const unsigned char *)text.bytes, text.length);
    free(text.bytes);
    return escaped.bytes;
}

char *charon_os_log_format(const char *format, va_list arguments, int error)
{
    va_list list;
    va_copy(list, arguments);
    CharonArgs args = {.arguments = &list};
    char *text = format_arguments(format, &args, error);
    va_end(list);
    return text;
}

char *charon_os_log_format_buffer(const char *format, const uint8_t *buffer, uint32_t size, int error)
{
    CharonArgs args = {.buffer = buffer, .size = size, .error = error};
    if (buffer && size >= 2) {
        args.remaining = buffer[1];
        args.offset = 2;
    }
    return format_arguments(format, &args, error);
}
