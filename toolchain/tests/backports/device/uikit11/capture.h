#include <stdio.h>
#include <stdarg.h>
int charon_printf(const char *format, ...) __attribute__((format(printf, 1, 2)));
#define printf charon_printf
