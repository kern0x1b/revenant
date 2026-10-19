// The port's indexed and sub-byte planar expansions held against the host's own vImage, case by case: the
// same packed row in, every byte of the eight-bit row out compared.
//
// The inputs are chosen to catch the three things a sub-byte row can get wrong: the bit order inside a byte,
// which a row of 0xb8 or 0x93 separates at every width - 0xaa and 0x55 cannot, at two and four bits, and
// saying so is the point of the comment above the tables; a scanline that ends in the middle of a byte,
// which is every odd width; and the multiplier, which needs the levels a one-bit and a two-bit row do not
// have but a four-bit one does.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

vImage_Error charon_host_vImageConvert_Planar1toPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_Planar2toPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_Planar4toPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_Indexed1toPlanar8(const vImage_Buffer *, const vImage_Buffer *,
                                                       const Pixel_8[2], vImage_Flags);
vImage_Error charon_host_vImageConvert_Indexed2toPlanar8(const vImage_Buffer *, const vImage_Buffer *,
                                                       const Pixel_8[4], vImage_Flags);
vImage_Error charon_host_vImageConvert_Indexed4toPlanar8(const vImage_Buffer *, const vImage_Buffer *,
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
        // The detail carries no newline of its own, so without this four failures land on two lines and
        // `grep -c '^FAIL'` reports two where the counter says four.
        putchar('\n');
    }
    va_end(args);
    fflush(stdout);
}

// The patterns a packed row is read from.
//
// **The bit order inside a byte needs a pattern the reverse cannot read the same way, and 0xaa and 0x55 are
// not that pattern at two and four bits a pixel.** At two bits 0xaa is 10 10 10 10 and 0x55 is 01 01 01 01:
// every pixel holds the same level whichever end of the byte the read starts from, so a reversed group order
// reads an identical row and the suite stays green. It is only at one bit a pixel, where the two become
// genuinely alternating, that those two patterns can fail a reversed read at all. The two patterns added here
// are asymmetric under a group reversal at every width this poses: 0xb8 is 10 11 10 00 at two bits, so a
// reversed read gives 0, 2, 3, 2 against the forward 2, 3, 2, 0, and 0x93 is 1001 0011 at four bits, giving
// 3, 9 against the forward 9, 3. Each is also asymmetric at the other two widths, and each stays inside its
// colour table's index range at all three.
//
// Wide enough for the widest packed row this poses: nineteen pixels at four bits a pixel is ten
// bytes, and a table of eight is what made an earlier version of this read past its own data.
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

// One table of patterns, for both loops. Two separate lists of them is how the plain expansions gained a
// pattern the indexed ones did not, and a pattern only one half poses is a pattern half the rows are untested
// on.
#define PATTERN_COUNT 6
static const struct { const uint8_t *bytes; const char *label; } kPatterns[PATTERN_COUNT] = {
    {kZero, "all zero"}, {kOne, "all one"}, {kEven, "even pixels set"}, {kOdd, "odd pixels set"},
    {kB8, "0xb8"}, {k93, "0x93"},
};

// One expansion, over each of the six patterns, with a width of 19 pixels - which at one and two bits a pixel
// is three bytes with five and nine bits used and the rest of the last byte's bits unread, and at four bits is
// ten bytes with a nibble left over.
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
        // Two rows, the second the complement of the first, and each row packed: the header says sub-byte
        // scanlines cannot be strided and the host reads them packed whatever rowBytes says, so the row-to-row
        // stride is the packed size and a missing stride reads the wrong row.
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

// And the three indexed forms, where the index is looked up in a table whose entries are all distinct, so a
// table of the wrong size or an index off by one shows as a different byte.
static void expand_indexed(const char *name,
                          vImage_Error (*mine)(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, vImage_Flags),
                          vImage_Error (*theirs)(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, vImage_Flags),
                          int bits)
{
    Pixel_8 colors[16];
    for (int at = 0; at < (1 << bits); at++) {
        colors[at] = (Pixel_8)(0xF0 + at);   // a distinct byte per level
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
        expand("vImageConvert_Planar1toPlanar8", vImageConvert_Planar1toPlanar8, charon_host_vImageConvert_Planar1toPlanar8, 1);
        expand("vImageConvert_Planar2toPlanar8", vImageConvert_Planar2toPlanar8, charon_host_vImageConvert_Planar2toPlanar8, 2);
        expand("vImageConvert_Planar4toPlanar8", vImageConvert_Planar4toPlanar8, charon_host_vImageConvert_Planar4toPlanar8, 4);
        expand_indexed("vImageConvert_Indexed1toPlanar8", vImageConvert_Indexed1toPlanar8,
                       charon_host_vImageConvert_Indexed1toPlanar8, 1);
        expand_indexed("vImageConvert_Indexed2toPlanar8", vImageConvert_Indexed2toPlanar8,
                       charon_host_vImageConvert_Indexed2toPlanar8, 2);
        expand_indexed("vImageConvert_Indexed4toPlanar8", vImageConvert_Indexed4toPlanar8,
                       charon_host_vImageConvert_Indexed4toPlanar8, 4);
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
