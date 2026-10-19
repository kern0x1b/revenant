#include <stdio.h>
#include <stdlib.h>

__attribute__((noinline)) static long classify(int code, long value)
{
    switch (code) {
    case 0: return value + 1;
    case 1: return value * 3;
    case 2: return value - 7;
    case 3: return value ^ 0x55;
    case 4: return value << 2;
    case 5: return value / 3;
    case 6: return -value;
    case 7: return value % 11;
    case 8: return value & 0xff;
    case 9: return value | 0x100;
    case 10: return value + 1000;
    case 11: return value * value;
    case 12: return value >> 1;
    case 13: return value + 13;
    case 14: return value * 14;
    case 15: return value - 15;
    default: return 0;
    }
}

__attribute__((noinline)) static const char *name(unsigned char c)
{
    switch (c) {
    case 'a': return "alpha";
    case 'b': return "bravo";
    case 'c': return "charlie";
    case 'd': return "delta";
    case 'e': return "echo";
    case 'f': return "foxtrot";
    case 'g': return "golf";
    case 'h': return "hotel";
    default: return "?";
    }
}

int main(int argc, char **argv)
{
    long sum = 0;
    for (int i = 0; i < 100000; i++)
        sum += classify(i % 17, i);
    printf("sum=%ld %s %s %s\n", sum, name('a'), name('e'), name('z'));
    return 0;
}
