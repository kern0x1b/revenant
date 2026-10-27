// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <stdint.h>

enum {
    sys_exit = 1,
    sys_write = 4,
    arena_bytes = 256 * 1024,
    steps_per_line = 1 << 16,
};

static uint8_t arena[arena_bytes];

static long trap(long number, long first, long second, long third)
{
    register long r0 __asm__("r0") = first;
    register long r1 __asm__("r1") = second;
    register long r2 __asm__("r2") = third;
    register long r12 __asm__("r12") = number;
    __asm__ volatile("svc #0x80" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r12) : "memory", "cc");
    return r0;
}

static long length_of(const char *text)
{
    long length = 0;
    while (text[length] != '\0')
        length++;
    return length;
}

static void write_text(const char *text, long length)
{
    trap(sys_write, 1, (long)text, length);
}

static void write_line(const char *text)
{
    write_text(text, length_of(text));
}

static void write_number(uint32_t value)
{
    char digits[12];
    long start = sizeof digits;
    digits[--start] = '\n';
    do {
        digits[--start] = (char)('0' + value % 10);
        value /= 10;
    } while (value != 0);
    write_text(&digits[start], (long)sizeof digits - start);
}

int main(void)
{
    write_line("minimal: start\n");
    uint32_t state = 0x2545f491u;
    uint32_t step = 0;
    for (;;) {
        for (uint32_t index = 0; index < steps_per_line; index++) {
            state = state * 1664525u + 1013904223u;
            arena[(state >> 8) & (arena_bytes - 1)] += (uint8_t)state;
        }
        step++;
        write_line("minimal: step ");
        write_number(step);
    }
}
