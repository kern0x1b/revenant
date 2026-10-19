#include <stdio.h>
#define __udivti3 xl_udivti3
#define __umodti3 xl_umodti3
#define __divti3 xl_divti3
#define __modti3 xl_modti3
#include "../../runtime/int128.c"

// Reads "op a_hi a_lo b_hi b_lo" lines (op is one of u, U, d, m: unsigned quotient, unsigned remainder,
// signed quotient, signed remainder; the words in hex) and prints the 128-bit result as 32 hex digits.
int main(void) {
  char op;
  unsigned long long ah, al, bh, bl;
  while (scanf(" %c %llx %llx %llx %llx", &op, &ah, &al, &bh, &bl) == 5) {
    u128 a = (u128)ah << 64 | al, b = (u128)bh << 64 | bl, r;
    switch (op) {
      case 'u': r = xl_udivti3(a, b); break;
      case 'U': r = xl_umodti3(a, b); break;
      case 'd': r = (u128)xl_divti3((s128)a, (s128)b); break;
      default: r = (u128)xl_modti3((s128)a, (s128)b); break;
    }
    printf("%016llx%016llx\n", (unsigned long long)(r >> 64), (unsigned long long)r);
  }
  return 0;
}
