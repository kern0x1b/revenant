#include <stdio.h>

#define TAIL __attribute__((musttail))

static unsigned trace[64];

#define LINK(n, next) \
    __attribute__((noinline)) static unsigned link##n(unsigned x) \
    { \
        volatile unsigned frame[8]; \
        for (int i = 0; i < 8; i++) { \
            frame[i] = x + i * n; \
        } \
        x = x * 2654435761u + frame[n % 8] + n; \
        trace[n] += x ^ (x >> 11); \
        TAIL return link##next(x ^ (x >> 7)); \
    }

__attribute__((noinline)) static unsigned link50(unsigned x)
{
    trace[50] += x;
    return x * 31 + 50;
}

LINK(49, 50) LINK(48, 49) LINK(47, 48) LINK(46, 47) LINK(45, 46) LINK(44, 45) LINK(43, 44) LINK(42, 43) LINK(41, 42) LINK(40, 41)
LINK(39, 40) LINK(38, 39) LINK(37, 38) LINK(36, 37) LINK(35, 36) LINK(34, 35) LINK(33, 34) LINK(32, 33) LINK(31, 32) LINK(30, 31)
LINK(29, 30) LINK(28, 29) LINK(27, 28) LINK(26, 27) LINK(25, 26) LINK(24, 25) LINK(23, 24) LINK(22, 23) LINK(21, 22) LINK(20, 21)
LINK(19, 20) LINK(18, 19) LINK(17, 18) LINK(16, 17) LINK(15, 16) LINK(14, 15) LINK(13, 14) LINK(12, 13) LINK(11, 12) LINK(10, 11)
LINK(9, 10) LINK(8, 9) LINK(7, 8) LINK(6, 7) LINK(5, 6) LINK(4, 5) LINK(3, 4) LINK(2, 3) LINK(1, 2) LINK(0, 1)

__attribute__((noinline)) static unsigned pong(unsigned n, unsigned acc);

__attribute__((noinline)) static unsigned ping(unsigned n, unsigned acc)
{
    if (!n) {
        return acc;
    }
    acc = acc * 33 + n;
    TAIL return pong(n - 1, acc ^ (acc >> 5));
}

__attribute__((noinline)) static unsigned pong(unsigned n, unsigned acc)
{
    if (!n) {
        return acc + 1;
    }
    acc = acc * 17 + n;
    TAIL return ping(n - 1, acc ^ (acc << 3));
}

static unsigned (*const table[4])(unsigned) = {link46, link47, link48, link49};

__attribute__((noinline)) static unsigned through_table(unsigned x)
{
    TAIL return table[x & 3](x >> 2);
}

int main(void)
{
    unsigned sum = 0;
    for (unsigned x = 1; x < 200; x += 37) {
        unsigned r = link0(x);
        sum += r;
        printf("chain %u %u\n", x, r);
    }
    unsigned marks = 0;
    for (int i = 0; i < 51; i++) {
        marks = marks * 31 + trace[i];
    }
    printf("marks %u\n", marks);
    printf("mutual %u\n", ping(300000, 7));
    for (unsigned x = 0; x < 16; x++) {
        printf("table %u %u\n", x, through_table(x * 5 + 1));
    }
    printf("sum %u\n", sum);
    return 0;
}
