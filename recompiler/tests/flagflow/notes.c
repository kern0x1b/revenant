int g_count, g_len;
char g_buf[64];

__attribute__((noinline)) void other(void)
{
    __asm__ volatile("");
}

#define NOTE(tag) do { g_count++; unsigned n = g_len + 1; if (n < 64) { g_len = n; g_buf[n - 1] = (tag); g_buf[n] = 0; } } while (0)
#define CLEAN(name, tag) __attribute__((noinline)) void name(void) { other(); NOTE(tag); other(); NOTE(tag + 1); }

CLEAN(f1, 'a')
CLEAN(f2, 'b')
CLEAN(f3, 'c')
CLEAN(f4, 'd')
CLEAN(f5, 'e')
CLEAN(f6, 'f')
