#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

vImage_Error revenant_host_vImageConvert_Planar1toPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error revenant_host_vImageConvert_Planar2toPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error revenant_host_vImageConvert_Planar4toPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error revenant_host_vImageConvert_Indexed1toPlanar8(const vImage_Buffer *, const vImage_Buffer *,
                                                       const Pixel_8[2], vImage_Flags);
vImage_Error revenant_host_vImageConvert_Indexed2toPlanar8(const vImage_Buffer *, const vImage_Buffer *,
                                                       const Pixel_8[4], vImage_Flags);
vImage_Error revenant_host_vImageConvert_Indexed4toPlanar8(const vImage_Buffer *, const vImage_Buffer *,
                                                       const Pixel_8[16], vImage_Flags);

#define W 19
static int checks;
static int failures;
static char detail[256];

static void report(int passed, const char *name, const char *why, ...)
{
    va_list args;
    va_start(args, why);
    checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: ", name);
        if (why)
            vprintf(why, args);
        putchar('\n');
    }
    va_end(args);
    fflush(stdout);
}

static const uint8_t kZero[16] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
static const uint8_t kOne[16] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                               0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
static const uint8_t kEven[16] = {0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
                                0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA};
static const uint8_t kOdd[16] = {0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55,
                               0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55};
static const uint8_t kB8[16] = {0xB8, 0xB8, 0xB8, 0xB8, 0xB8, 0xB8, 0xB8, 0xB8,
                               0xB8, 0xB8, 0xB8, 0xB8, 0xB8, 0xB8, 0xB8, 0xB8};
static const uint8_t k93[16] = {0x93, 0x93, 0x93, 0x93, 0x93, 0x93, 0x93, 0x93,
                               0x93, 0x93, 0x93, 0x93, 0x93, 0x93, 0x93, 0x93};

#define PATTERN_COUNT 6
static const struct { const uint8_t *bytes; const char *label; } kPatterns[PATTERN_COUNT] = {
    {kZero, "all zero"}, {kOne, "all one"}, {kEven, "even pixels set"}, {kOdd, "odd pixels set"},
    {kB8, "0xb8"}, {k93, "0x93"},
};

#define ROWS 2

static void expand(const char *name, vImage_Error (*mine)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags),
                   vImage_Error (*theirs)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags), int bits)
{
    for (int at = 0; at < PATTERN_COUNT; at++) {
        uint8_t source[32], mine_out[W * ROWS], their_out[W * ROWS];
        vImage_Buffer src, dest;
        size_t bytes = (size_t)((W + (8 / bits) - 1) / (8 / bits));
        memset(source, 0, sizeof source);
        memcpy(source, kPatterns[at].bytes, bytes);
        for (size_t byte = 0; byte < bytes; byte++) {
            source[bytes + byte] = (uint8_t)~kPatterns[at].bytes[byte];
        }
        src.data = source;
        src.width = W;
        src.height = ROWS;
        src.rowBytes = bytes;
        memset(mine_out, 0xAA, sizeof mine_out);
        memset(their_out, 0xAA, sizeof their_out);
        dest.data = mine_out;
        dest.width = W;
        dest.height = ROWS;
        dest.rowBytes = W;
        vImage_Error mine_status = mine(&src, &dest, 0);
        dest.data = their_out;
        vImage_Error their_status = theirs(&src, &dest, 0);
        int agreed = mine_status == their_status;
        if (!agreed) {
            snprintf(detail, sizeof detail, "the port answers %ld and the host %ld", (long)mine_status,
                     (long)their_status);
        }
        for (int row = 0; row < ROWS && agreed; row++) {
            for (int column = 0; column < W; column++) {
                if (mine_out[row * W + column] != their_out[row * W + column]) {
                    agreed = 0;
                    snprintf(detail, sizeof detail, "%s, row %d pixel %d is %02x and the host says %02x", kPatterns[at].label,
                             row, column, mine_out[row * W + column], their_out[row * W + column]);
                    break;
                }
            }
        }
        char label[128];
        snprintf(label, sizeof label, "%s over a row of %s", name, kPatterns[at].label);
        report(agreed, label, agreed ? "" : detail, 0);
    }
}

static void expand_indexed(const char *name,
                          vImage_Error (*mine)(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, vImage_Flags),
                          vImage_Error (*theirs)(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, vImage_Flags),
                          int bits)
{
    Pixel_8 colors[16];
    for (int at = 0; at < (1 << bits); at++) {
        colors[at] = (Pixel_8)(0xF0 + at);
    }
    for (int at = 0; at < PATTERN_COUNT; at++) {
        uint8_t source[32], mine_out[W * ROWS], their_out[W * ROWS];
        vImage_Buffer src, dest;
        size_t bytes = (size_t)((W + (8 / bits) - 1) / (8 / bits));
        memset(source, 0, sizeof source);
        memcpy(source, kPatterns[at].bytes, bytes);
        for (size_t byte = 0; byte < bytes; byte++) {
            source[bytes + byte] = (uint8_t)~kPatterns[at].bytes[byte];
        }
        src.data = source;
        src.width = W;
        src.height = ROWS;
        src.rowBytes = bytes;
        memset(mine_out, 0xAA, sizeof mine_out);
        memset(their_out, 0xAA, sizeof their_out);
        dest.data = mine_out;
        dest.width = W;
        dest.height = ROWS;
        dest.rowBytes = W;
        vImage_Error mine_status = mine(&src, &dest, colors, 0);
        dest.data = their_out;
        vImage_Error their_status = theirs(&src, &dest, colors, 0);
        int agreed = mine_status == their_status;
        if (!agreed) {
            snprintf(detail, sizeof detail, "the port answers %ld and the host %ld", (long)mine_status,
                     (long)their_status);
        }
        for (int row = 0; row < ROWS && agreed; row++) {
            for (int column = 0; column < W; column++) {
                if (mine_out[row * W + column] != their_out[row * W + column]) {
                    agreed = 0;
                    snprintf(detail, sizeof detail, "%s, row %d pixel %d is %02x and the host says %02x", kPatterns[at].label,
                             row, column, mine_out[row * W + column], their_out[row * W + column]);
                    break;
                }
            }
        }
        char label[128];
        snprintf(label, sizeof label, "%s over a row of %s", name, kPatterns[at].label);
        report(agreed, label, agreed ? "" : detail, 0);
    }
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        expand("vImageConvert_Planar1toPlanar8", vImageConvert_Planar1toPlanar8, revenant_host_vImageConvert_Planar1toPlanar8, 1);
        expand("vImageConvert_Planar2toPlanar8", vImageConvert_Planar2toPlanar8, revenant_host_vImageConvert_Planar2toPlanar8, 2);
        expand("vImageConvert_Planar4toPlanar8", vImageConvert_Planar4toPlanar8, revenant_host_vImageConvert_Planar4toPlanar8, 4);
        expand_indexed("vImageConvert_Indexed1toPlanar8", vImageConvert_Indexed1toPlanar8,
                       revenant_host_vImageConvert_Indexed1toPlanar8, 1);
        expand_indexed("vImageConvert_Indexed2toPlanar8", vImageConvert_Indexed2toPlanar8,
                       revenant_host_vImageConvert_Indexed2toPlanar8, 2);
        expand_indexed("vImageConvert_Indexed4toPlanar8", vImageConvert_Indexed4toPlanar8,
                       revenant_host_vImageConvert_Indexed4toPlanar8, 4);
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
