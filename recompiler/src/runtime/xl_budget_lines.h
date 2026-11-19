#pragma once

#include <stddef.h>

struct xl_stacks_count {
    unsigned live;
    unsigned long mapped, deepest, deepest_of, ever;
};

struct xl_budget_count {
    int unread;
    unsigned long arena, arena_size;
    unsigned words, slots;
    unsigned long aliases, aliases_size;
};

static inline size_t xl_line_text(char *line, size_t at, size_t size, const char *text)
{
    while (*text && at + 1 < size)
        line[at++] = *text++;
    if (at < size)
        line[at] = 0;
    return at;
}

static inline size_t xl_line_number(char *line, size_t at, size_t size, unsigned long value)
{
    char digits[3 * sizeof value];
    size_t count = 0;
    do {
        digits[count++] = (char)('0' + value % 10);
        value /= 10;
    } while (value);
    while (count && at + 1 < size)
        line[at++] = digits[--count];
    if (at < size)
        line[at] = 0;
    return at;
}

static inline size_t xl_stacks_line(char *line, size_t size, int read, const struct xl_stacks_count *count)
{
    size_t at = xl_line_text(line, 0, size, "xlate: guest stacks: ");
    if (read) {
        at = xl_line_number(line, at, size, count->live);
        at = xl_line_text(line, at, size, " live, ");
        at = xl_line_number(line, at, size, count->mapped >> 10);
        at = xl_line_text(line, at, size, " KiB mapped; the deepest live one has used ");
        at = xl_line_number(line, at, size, count->deepest >> 10);
        at = xl_line_text(line, at, size, " KiB of ");
        at = xl_line_number(line, at, size, count->deepest_of >> 10);
        at = xl_line_text(line, at, size, " KiB, the deepest ever ");
    } else {
        at = xl_line_text(line, at, size, "not read (the lock of the list of threads is held), the deepest ever ");
    }
    at = xl_line_number(line, at, size, count->ever >> 10);
    return xl_line_text(line, at, size, " KiB\n");
}

static inline size_t xl_budget_line(char *line, size_t size, const struct xl_budget_count *count)
{
    size_t at = xl_line_text(line, 0, size, "xlate: budget: metadata arena ");
    if (count->unread) {
        at = xl_line_text(line, at, size, "of ");
        at = xl_line_number(line, at, size, count->arena_size >> 10);
        at = xl_line_text(line, at, size, " KiB not read (mincore: errno ");
        if (count->unread < 0)
            at = xl_line_text(line, at, size, "-");
        at = xl_line_number(line, at, size, count->unread < 0 ? 0ul - (unsigned long)count->unread : (unsigned long)count->unread);
        at = xl_line_text(line, at, size, ")");
    } else {
        at = xl_line_number(line, at, size, count->arena >> 10);
        at = xl_line_text(line, at, size, " of ");
        at = xl_line_number(line, at, size, count->arena_size >> 10);
        at = xl_line_text(line, at, size, " KiB touched");
    }
    at = xl_line_text(line, at, size, ", opaque words ");
    at = xl_line_number(line, at, size, count->words);
    at = xl_line_text(line, at, size, " of ");
    at = xl_line_number(line, at, size, count->slots);
    at = xl_line_text(line, at, size, ", aliases ");
    at = xl_line_number(line, at, size, count->aliases >> 10);
    at = xl_line_text(line, at, size, " of ");
    at = xl_line_number(line, at, size, count->aliases_size >> 10);
    return xl_line_text(line, at, size, " KiB (0 of 0 is not set up yet)\n");
}
