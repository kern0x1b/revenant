#include <stdio.h>
#include <stdarg.h>
int revenant_printf(const char *format, ...) __attribute__((format(printf, 1, 2)));
#define printf revenant_printf
