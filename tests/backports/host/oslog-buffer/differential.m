// differential.m - the os_log macros' packed buffer, decoded by the port and written as the host's own
// developer output is. The same battery as host/oslog runs in both builds:
//
//   -DCHARON_PORT   the port's decoder answers. The macros call _os_log_impl, which this file defines to
//                   decode the buffer the compiler packed with charon_os_log_format_buffer, and os_log_type_enabled
//                   is the port's answer for the log objects the port makes.
//   (no define)     the host's own os_log answers, through its own _os_log_impl, and writes the developer
//                   output the comparator reads.
//
// The log of each case is named by its index, so the two outputs are read case by case.
#import <Foundation/Foundation.h>
#import <os/log.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "battery.h"

#ifdef CHARON_PORT
#include "CharonOSLog.h"

static FILE *ours_file;
static int current_index;
static int hex_output;

/* Writes the bytes to the output: as they are, or, for a run on the emulator (argument "-"), as hex digits, because
   the emulator's output is text and a NUL or a unit separator in it would not come back. */
static void put_bytes(const char *bytes, size_t count)
{
    for (size_t i = 0; i < count; i++) {
        if (hex_output)
            fprintf(ours_file, "%02x", (unsigned char)bytes[i]);
        else
            fputc(bytes[i], ours_file);
    }
}

/* A record is the index, a unit separator, the text and a NUL. In hex mode it is one line, "R " and its digits. */
static void emit_record(int index, const char *text)
{
    char prefix[16];
    snprintf(prefix, sizeof prefix, "%d\x1f", index);
    if (hex_output)
        fputs("R ", ours_file);
    put_bytes(prefix, strlen(prefix));
    put_bytes(text, strlen(text) + 1);
    if (hex_output)
        fputc('\n', ours_file);
}

bool os_log_type_enabled(os_log_t log, os_log_type_t type)
{
    return charon_os_log_type_enabled(log, type);
}

void _os_log_impl(void *dso, os_log_t log, os_log_type_t type, const char *format, uint8_t *buffer, uint32_t size)
{
    int error = errno;
    if (!charon_os_log_type_enabled(log, type))
        return;
    char *text = charon_os_log_format_buffer(format, buffer, size, error);
    emit_record(current_index, text);
    free(text);
}

#define LOG_FOR(category) charon_os_log_named("probe", category)
#else
#define LOG_FOR(category) os_log_create("probe", category)
#endif

// The formats of the buffers the macros never make (see CRAFT in main). Each is one call, one category.
#define OSLOG_CRAFTED(CASE) \
    CASE("a %d b %d c") \
    CASE("a %s b") \
    CASE("a %@ b") \
    CASE("a %f b") \
    CASE("a %m b") \
    CASE("a %.2s b") \
    CASE("a %c b")

/* A buffer built item by item at run time, for the buffers the macros never make. A pointer item points at this
   process's own data, so both runs read the same bytes. The host decodes the buffer with its own _os_log_impl. */
static uint8_t crafted[256];
static uint32_t crafted_size;

static void craft_begin(void)
{
    crafted[0] = 0x02;
    crafted[1] = 0;
    crafted_size = 2;
}

static void craft_item(unsigned type, unsigned privacy, const void *data, uint8_t length)
{
    crafted[crafted_size++] = (uint8_t)((type << 4) | privacy);
    crafted[crafted_size++] = length;
    memcpy(crafted + crafted_size, data, length);
    crafted_size += length;
    crafted[1]++;
}

static void craft_value(unsigned type, unsigned privacy, uint64_t value, uint8_t length)
{
    craft_item(type, privacy, &value, length);
}

static void craft_pointer(unsigned type, unsigned privacy, const void *target)
{
    craft_item(type, privacy, &target, sizeof target);
}

static void craft_count(uint32_t count)
{
    craft_item(1, 0, &count, sizeof count);
}

/* Sets the item count the buffer claims, whatever items it holds. */
static void craft_claim(uint8_t count)
{
    crafted[1] = count;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
#ifdef CHARON_PORT
        /* The time decorators are measured in UTC, as run.sh sets TZ for the host run; an emulator has its own zone. */
        setenv("TZ", "UTC", 1);
        tzset();
        hex_output = strcmp(argv[1], "-") == 0;
        ours_file = hex_output ? stdout : fopen(argv[1], "wb");
#else
        (void)argc;
        (void)argv;
#endif
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
            os_log_t log = LOG_FOR(category); \
            errno = 0; \
            CHARON_CURRENT(index) \
            os_log(log, format, ##__VA_ARGS__); \
        } while (0);
#ifdef CHARON_PORT
#define CHARON_CURRENT(n) current_index = (n);
#else
#define CHARON_CURRENT(n)
#endif
        /* A buffer that holds no item, which no os_log macro makes: the host writes its markers for it, and the
           port's decoder must write the same. The call is made on _os_log_impl directly, as a caller would. */
#define CRAFT(format) \
        do { \
            char category[16]; \
            snprintf(category, sizeof category, "c%d", ++index); \
            os_log_t log = LOG_FOR(category); \
            static const uint8_t empty[2] = {0x00, 0x00}; \
            CHARON_CURRENT(index) \
            _os_log_impl(&__dso_handle, log, OS_LOG_TYPE_DEFAULT, format, (uint8_t *)empty, sizeof empty); \
        } while (0);
        OSLOG_BATTERY(CASE)
        OSLOG_BATTERY_HOST(CASE)
        OSLOG_CRAFTED(CRAFT)
        /* Items of a kind the conversion does not take: the host writes its mismatch marker, consumes the item, and
           goes on to the next conversion, which takes the next item. The privacy nibbles, the sizes and the labels
           are the ones measured on the host. The arguments after the format are the items, in order. */
#define CRAFT_CASE(format, ...) \
        do { \
            char category[16]; \
            snprintf(category, sizeof category, "c%d", ++index); \
            os_log_t log = LOG_FOR(category); \
            errno = 0; \
            craft_begin(); \
            __VA_ARGS__; \
            CHARON_CURRENT(index) \
            _os_log_impl(&__dso_handle, log, OS_LOG_TYPE_DEFAULT, format, crafted, crafted_size); \
        } while (0);
        /* A string the host writes as private at nibble 0 is one in writable memory: the array below is on the stack. */
        char writable[] = "dyn";
        /* Type 5 items point at eight bytes of UTF-16LE units: a unit run, a zero first unit with the second unit at the
           edges of 1 to 16, a surrogate, a three-byte unit, no nul among the first two units, a nul at the second unit
           only, a nul at the third unit (not seen), and an empty text. */
        const uint8_t w5_ab[8] = {0x41, 0, 0x42, 0, 0, 0, 0, 0};
        const uint8_t w5_a_nul[8] = {0x41, 0, 0, 0, 0, 0, 0, 0};
        const uint8_t w5_abc_nul[8] = {0x41, 0, 0x42, 0, 0x43, 0, 0, 0};
        const uint8_t w5_zero_one[8] = {0, 0, 0x01, 0, 0, 0, 0, 0};
        const uint8_t w5_zero_sixteen[8] = {0, 0, 0x10, 0, 0, 0, 0, 0};
        const uint8_t w5_zero_seventeen[8] = {0, 0, 0x11, 0, 0, 0, 0, 0};
        const uint8_t w5_three_bytes[8] = {0x50, 0x39, 0, 0, 0, 0, 0, 0};
        const uint8_t w5_surrogate[8] = {0x41, 0, 0x00, 0xdc, 0, 0, 0, 0};
        const uint8_t w5_no_nul[8] = {0x41, 0, 0x42, 0, 0x43, 0, 0x44, 0};
        const uint8_t w5_empty[8] = {0};
        CRAFT_CASE("v %d w", craft_pointer(2, 0, writable))
        CRAFT_CASE("v %m w", craft_value(6, 0, 0, 4))
        CRAFT_CASE("v %d w", craft_value(0, 0, 1, 8))
        CRAFT_CASE("v %d w", craft_value(0, 0, 7, 4))
        CRAFT_CASE("v %d w %d x", craft_pointer(2, 0, s), craft_value(0, 0, 7, 4))
        CRAFT_CASE("v %d w %d x", craft_value(0, 0, 9, 8), craft_value(0, 0, 7, 4))
        CRAFT_CASE("v %s w", craft_pointer(2, 0, s))
        CRAFT_CASE("v %s w", craft_pointer(4, 0, (__bridge const void *)o))
        CRAFT_CASE("v %s w", craft_value(0, 0, 4, 4))
        CRAFT_CASE("v %s w", craft_pointer(3, 0, uu))
        CRAFT_CASE("v %@ w", craft_pointer(2, 0, s))
        CRAFT_CASE("v %@ w", craft_value(0, 0, 9, 8))
        CRAFT_CASE("v %d w", craft_pointer(2, 2, s))
        CRAFT_CASE("v %d w", craft_pointer(2, 3, s))
        CRAFT_CASE("v %d w", craft_pointer(2, 4, s))
        CRAFT_CASE("v %d w", craft_pointer(4, 1, (__bridge const void *)o))
        CRAFT_CASE("v %d w", craft_value(0, 3, 1, 8))
        CRAFT_CASE("v %d w", craft_count(3))
        CRAFT_CASE("v %.3P w", craft_count(3), craft_pointer(2, 0, s))
        CRAFT_CASE("v %.3P w", craft_count(3), craft_pointer(3, 0, uu))
        CRAFT_CASE("v %P w", craft_pointer(3, 0, uu))
        CRAFT_CASE("v %P w", (void)0)
        CRAFT_CASE("v %s w", craft_value(6, 0, 1, 4))
        CRAFT_CASE("v %d w", craft_value(6, 0, 1, 8))
        CRAFT_CASE("v %{public}s w", craft_value(0, 0, 1, 4))
        CRAFT_CASE("v %5d w", craft_pointer(3, 0, uu))
        CRAFT_CASE("v %d w %d x", craft_value(7, 0, 1, 8), craft_value(0, 0, 7, 4))
        /* A zero-length scalar is an item with no value; a zero-length errno item is still errno. */
        CRAFT_CASE("v %d w", craft_value(0, 0, 0, 0))
        CRAFT_CASE("v %d w %d x", craft_value(0, 0, 0, 0), craft_value(0, 0, 7, 4))
        CRAFT_CASE("v %d w %d x", craft_value(0, 0, 7, 4), craft_value(0, 0, 0, 0))
        CRAFT_CASE("v %d w", craft_value(6, 0, 0, 0))
        CRAFT_CASE("v %m w", craft_value(6, 0, 0, 0))
        /* NULL strings and objects: the size is 0, and a NULL string at nibble 0 has no privacy word. */
        CRAFT_CASE("v %d w", craft_pointer(2, 0, NULL))
        CRAFT_CASE("v %d w", craft_pointer(2, 2, NULL))
        CRAFT_CASE("v %s w", craft_pointer(2, 0, NULL))
        CRAFT_CASE("v %d w", craft_pointer(4, 0, NULL))
        CRAFT_CASE("v %s w", craft_pointer(4, 0, NULL))
        /* A buffer that claims more items than it holds: the decoder stops at the bytes it has. */
        CRAFT_CASE("v %d w %d x", craft_value(0, 0, 7, 4), craft_claim(2))
        CRAFT_CASE("v %d w %d x", craft_value(0, 0, 7, 4), craft_claim(3))
        CRAFT_CASE("v %d w %d x", craft_value(0, 0, 7, 4), craft_value(0, 0, 0, 0), craft_claim(2))
        CRAFT_CASE("v %d w", craft_value(7, 0, 1, 8))
        /* A type 5 item is a mismatch for %d, named 5 with its size from its units, and the next conversion takes the
           next item. The privacy nibbles are 0 (a writable pointer, so private), 1 (private) and 2 (public). */
        CRAFT_CASE("v %d w", craft_pointer(5, 0, w5_ab))
        CRAFT_CASE("v %d w", craft_pointer(5, 2, w5_ab))
        CRAFT_CASE("v %d w", craft_pointer(5, 0, w5_zero_one))
        CRAFT_CASE("v %d w", craft_pointer(5, 0, w5_zero_sixteen))
        CRAFT_CASE("v %d w", craft_pointer(5, 0, w5_zero_seventeen))
        CRAFT_CASE("v %d w", craft_pointer(5, 1, w5_three_bytes))
        CRAFT_CASE("v %d w", craft_pointer(5, 0, w5_surrogate))
        CRAFT_CASE("v %d w", craft_pointer(5, 0, w5_no_nul))
        CRAFT_CASE("v %d w", craft_pointer(5, 0, w5_empty))
        CRAFT_CASE("v %d w", craft_pointer(5, 0, w5_a_nul))
        CRAFT_CASE("v %d w", craft_pointer(5, 0, w5_abc_nul))
        CRAFT_CASE("v %d w", craft_pointer(5, 0, NULL))
        CRAFT_CASE("v %d w %d x", craft_pointer(5, 0, w5_ab), craft_value(0, 0, 7, 4))
#ifdef CHARON_PORT
        if (hex_output)
            fflush(stdout);
        else
            fclose(ours_file);
#endif
        printf("%d cases\n", index);
    }
    return 0;
}
