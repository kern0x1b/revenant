#pragma once
#include <errno.h>
#include <poll.h>
#include <stddef.h>
#include <string.h>
#include <unistd.h>

#define RC_VERSION "1"
#define RC_LINE_MOST 65536
#define RC_FIELDS_MOST 8
#define RC_ID_MOST 64
#define RC_ALLOWED_MOST 120000

enum { RC_LINE = 1, RC_END = 0, RC_LONG = -1, RC_WAIT = -2, RC_BROKEN = -3 };

struct rc_reader {
    int fd;
    size_t have;
    size_t taken;
    size_t dropped;
    int dropping;
    char bytes[RC_LINE_MOST];
};

struct rc_field {
    const char *bytes;
    size_t length;
};

static inline int rc_hex(int c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

static inline size_t rc_escape(const char *from, size_t length, char *to, size_t room, int ascii)
{
    static const char digits[] = "0123456789ABCDEF";
    size_t out = 0;
    for (size_t i = 0; i < length; i++) {
        unsigned char c = (unsigned char)from[i];
        if (c < 0x20 || c == 0x7f || c == '%' || (ascii && c >= 0x80)) {
            if (out + 3 > room)
                return (size_t)-1;
            to[out++] = '%';
            to[out++] = digits[c >> 4];
            to[out++] = digits[c & 15];
        } else {
            if (out + 1 > room)
                return (size_t)-1;
            to[out++] = (char)c;
        }
    }
    return out;
}

static inline size_t rc_unescape(char *field, size_t length)
{
    size_t out = 0;
    for (size_t i = 0; i < length; i++) {
        if (field[i] != '%') {
            field[out++] = field[i];
            continue;
        }
        if (i + 2 >= length || rc_hex(field[i + 1]) < 0 || rc_hex(field[i + 2]) < 0)
            return (size_t)-1;
        field[out++] = (char)(rc_hex(field[i + 1]) << 4 | rc_hex(field[i + 2]));
        i += 2;
    }
    return out;
}

static inline int rc_split(char *line, size_t length, char **fields, size_t *lengths)
{
    int count = 0;
    size_t start = 0;
    for (size_t i = 0; i <= length; i++) {
        if (i < length && line[i] != '\t')
            continue;
        if (count == RC_FIELDS_MOST)
            return RC_FIELDS_MOST + 1;
        fields[count] = line + start;
        lengths[count++] = i - start;
        start = i + 1;
    }
    return count;
}

static inline int rc_id_ok(const char *id, size_t length)
{
    if (length < 1 || length > RC_ID_MOST)
        return 0;
    for (size_t i = 0; i < length; i++) {
        char c = id[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '.' || c == '_' || c == '-'))
            return 0;
    }
    return 1;
}

static inline int rc_utf8_ok(const char *text, size_t length)
{
    const unsigned char *bytes = (const unsigned char *)text;
    size_t i = 0;
    while (i < length) {
        unsigned char c = bytes[i];
        size_t more;
        unsigned long point;
        if (c < 0x80) {
            i++;
            continue;
        }
        if (c >= 0xc2 && c <= 0xdf) {
            more = 1;
            point = c & 0x1f;
        } else if (c >= 0xe0 && c <= 0xef) {
            more = 2;
            point = c & 0x0f;
        } else if (c >= 0xf0 && c <= 0xf4) {
            more = 3;
            point = c & 0x07;
        } else {
            return 0;
        }
        if (i + more >= length)
            return 0;
        for (size_t k = 1; k <= more; k++) {
            if ((bytes[i + k] & 0xc0) != 0x80)
                return 0;
            point = point << 6 | (bytes[i + k] & 0x3f);
        }
        if ((more == 2 && point < 0x800) || (more == 3 && point < 0x10000) || point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff))
            return 0;
        i += more + 1;
    }
    return 1;
}

static inline long rc_number(const char *text, size_t length, long most)
{
    if (length < 1 || length > 9)
        return -1;
    long value = 0;
    for (size_t i = 0; i < length; i++) {
        if (text[i] < '0' || text[i] > '9')
            return -1;
        value = value * 10 + (text[i] - '0');
    }
    return value >= 1 && value <= most ? value : -1;
}

static inline size_t rc_build(char *to, size_t room, const struct rc_field *fields, int count, int ascii)
{
    size_t out = 0;
    for (int i = 0; i < count; i++) {
        if (i) {
            if (out + 1 > room)
                return (size_t)-1;
            to[out++] = '\t';
        }
        size_t wrote = rc_escape(fields[i].bytes, fields[i].length, to + out, room - out, ascii);
        if (wrote == (size_t)-1)
            return (size_t)-1;
        out += wrote;
    }
    if (out + 1 > room)
        return (size_t)-1;
    to[out++] = '\n';
    return out;
}

static inline int rc_write_all(int fd, const char *bytes, size_t length)
{
    while (length) {
        ssize_t wrote = write(fd, bytes, length);
        if (wrote < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        bytes += wrote;
        length -= (size_t)wrote;
    }
    return 0;
}

static inline int rc_read_line(struct rc_reader *reader, int wait_ms, char **line, size_t *length)
{
    if (reader->taken) {
        memmove(reader->bytes, reader->bytes + reader->taken, reader->have - reader->taken);
        reader->have -= reader->taken;
        reader->taken = 0;
    }
    size_t scanned = 0;
    for (;;) {
        char *end = memchr(reader->bytes + scanned, '\n', reader->have - scanned);
        if (end) {
            size_t size = (size_t)(end - reader->bytes);
            reader->taken = size + 1;
            if (reader->dropping) {
                *length = reader->dropped + size + 1;
                reader->dropping = 0;
                reader->dropped = 0;
                return RC_LONG;
            }
            *end = '\0';
            *line = reader->bytes;
            *length = size;
            return RC_LINE;
        }
        if (reader->dropping || reader->have == sizeof reader->bytes) {
            reader->dropping = 1;
            reader->dropped += reader->have;
            reader->have = 0;
        }
        scanned = reader->have;
        if (wait_ms >= 0) {
            struct pollfd waited = {reader->fd, POLLIN, 0};
            int ready = poll(&waited, 1, wait_ms);
            if (ready < 0 && errno == EINTR)
                continue;
            if (ready == 0)
                return RC_WAIT;
        }
        ssize_t got = read(reader->fd, reader->bytes + reader->have, sizeof reader->bytes - reader->have);
        if (got < 0) {
            if (errno == EINTR)
                continue;
            return RC_BROKEN;
        }
        if (got == 0) {
            *length = reader->dropped + reader->have;
            return RC_END;
        }
        reader->have += (size_t)got;
    }
}
