// The 128-bit division routines the arm64 compiler-rt provides to Swift's Int128 and libc++: guest code,
// compiled for arm64 and lifted with the image that calls it, so the armv7 result needs no 128-bit
// libcall of its own. Restoring long division, since the routines must not divide 128-bit values.
typedef unsigned __int128 u128;
typedef __int128 s128;

static u128 udivmod(u128 n, u128 d, u128 *rem) {
  if (d == 0) __builtin_trap();
  u128 q = 0, r = 0;
  for (int i = 127; i >= 0; --i) {
    int carry = (int)(r >> 127);
    r = (r << 1) | ((n >> i) & 1);
    if (carry || r >= d) {
      r -= d;
      q |= (u128)1 << i;
    }
  }
  if (rem) *rem = r;
  return q;
}

u128 __udivti3(u128 n, u128 d) { return udivmod(n, d, 0); }

u128 __umodti3(u128 n, u128 d) {
  u128 r;
  udivmod(n, d, &r);
  return r;
}

s128 __divti3(s128 n, s128 d) {
  int negative = (n < 0) != (d < 0);
  u128 q = udivmod(n < 0 ? -(u128)n : (u128)n, d < 0 ? -(u128)d : (u128)d, 0);
  return negative ? (s128)-q : (s128)q;
}

s128 __modti3(s128 n, s128 d) {
  u128 r;
  udivmod(n < 0 ? -(u128)n : (u128)n, d < 0 ? -(u128)d : (u128)d, &r);
  return n < 0 ? (s128)-r : (s128)r;
}
