#include <stdio.h>

#define CASES \
    X(0) X(1) X(2) X(3) X(4) X(5) X(6) X(7) X(8) X(9) X(10) X(11) X(12) X(13) X(14) X(15) X(16) X(17) X(18) X(19) X(20) X(21) X(22) X(23)

#define X(n) \
    __attribute__((noinline)) static unsigned part##n(unsigned x) { return (x ^ (n * 0x9e3779b1u + 7)) + (x >> (n % 7 + 1)) + n * 31; }
CASES
#undef X

static unsigned counters[8];

__attribute__((noinline)) static unsigned dispatch(unsigned k, unsigned x)
{
    switch (k) {
#define X(n) \
    case n: \
        x = part##n(x); \
        break;
        CASES
#undef X
    default:
        x ^= 0xdeadbeefu;
        break;
    }
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
#pragma clang loop unroll(full)
    for (unsigned i = 0; i < 48; i++) {
        x = x * 2654435761u + i;
        x ^= x >> (i % 13 + 3);
        counters[(x + i) & 7] += x >> 27;
    }
    x += counters[k & 7];
    x ^= x << 7;
    x ^= x >> 9;
    return x * 0x85ebca6bu;
}

int main(void)
{
    unsigned sum = 0;
    for (unsigned k = 0; k < 28; k++) {
        for (unsigned x = 1; x < 400; x += 97) {
            unsigned r = dispatch(k, x);
            sum += r;
            printf("%u %u %u\n", k, x, r);
        }
    }
    for (unsigned i = 0; i < 8; i++) {
        printf("counter %u %u\n", i, counters[i]);
    }
    printf("sum %u\n", sum);
    return 0;
}
