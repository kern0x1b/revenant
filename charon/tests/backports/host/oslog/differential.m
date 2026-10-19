#import <Foundation/Foundation.h>
#import <os/log.h>
#include <stdarg.h>
#include <errno.h>
#include <stdio.h>
#include "battery.h"

char *charon_os_log_format(const char *format, va_list arguments, int error);

static FILE *ours_file;

static void ours(int index, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    char *text = charon_os_log_format(format, arguments, 0);
    va_end(arguments);
    fprintf(ours_file, "%d\x1f%s%c", index, text, 0);
    free(text);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        ours_file = fopen(argv[1], "wb");
        const char *s = "dyn", *nul = NULL;
        NSString *o = @"obj";
        id nilo = nil;
        int i = -7;
        unsigned u = 4000000000u;
        short sh = -5;
        signed char ch = -3;
        long long ll = 1234567890123LL;
        double d = 3.14159265;
        float f = 2.5f;
        void *p = (void *)0x1234;
        size_t z = 99;
        char c = 'q';
        unsigned char uu[16] = {0xde, 0xad, 0xbe, 0xef, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
        int index = 0;
#define CASE(format, ...) \
        do { \
            char category[16]; \
            snprintf(category, sizeof category, "c%d", ++index); \
            os_log_t log = os_log_create("probe", category); \
            errno = 0; \
            os_log(log, format, ##__VA_ARGS__); \
            ours(index, format, ##__VA_ARGS__); \
        } while (0);
        OSLOG_BATTERY(CASE)
        OSLOG_BATTERY_HOST(CASE)
        fclose(ours_file);
        printf("%d cases\n", index);
    }
    return 0;
}
