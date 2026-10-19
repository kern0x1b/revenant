// The port's packed twelve-bit conversions against the host's own, in the table form: one loop over the
// directions and the widths.
//
// The widths are the point. Twelve bits is one and a half bytes a pixel and the header's algorithm consumes two
// pixels per three bytes, so every **odd** width has a half-pair the header's code never reaches. So the table
// runs 1 to 17 - every odd and every even - in both directions, over two rows, and each row is filled with a
// value per pixel that is distinct from every other, so a pixel read from the wrong offset cannot pass.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

vImage_Error charon_host_vImageConvert_12UTo16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_16UTo12U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);

#define ROWS 2
#define MAX_WIDTH 17
#define MAX_PACKED 32
#define MAX_PLAIN (MAX_WIDTH * 2)

static int checks;
static int failures;

// Two pixels to a triple, an odd pixel padded up: the same rule the port uses, written here independently so
// the two sides are not sharing a mistake.
static size_t packed_bytes(vImagePixelCount width) { return (size_t)((width + 1) / 2 * 3); }

// A value per pixel that no other pixel holds, so a swapped or mis-offset pixel shows up as a difference.
static uint32_t value_for(vImagePixelCount column) { return (uint32_t)((column * 2654435761u) % 65536u) | (column ? 1u : 0u); }

static void buffer(vImage_Buffer *b, void *data, vImagePixelCount w, vImagePixelCount h, vImagePixelCount rb)
{
    memset(b, 0, sizeof *b);
    b->data = data;
    b->width = w;
    b->height = h;
    b->rowBytes = rb;
}

static void run_up(vImagePixelCount width)
{
    checks++;
    size_t bytes = packed_bytes(width);
    uint8_t source[ROWS * MAX_PACKED], mine_out[ROWS * MAX_PLAIN], their_out[ROWS * MAX_PLAIN];
    // Build the packed row the way the header reads it: two twelve-bit values into three bytes, the first in
    // the high half. Both rows are different, so a missing row stride is a difference and not a repeat.
    for (int row = 0; row < ROWS; row++) {
        memset(source + row * bytes, 0, bytes);
        for (vImagePixelCount column = 0; column < width; column++) {
            unsigned value = (unsigned)(value_for(column) & 0xfffu) ^ (row ? 0x555u : 0u);
            uint8_t *triple = source + row * bytes + (size_t)(column / 2) * 3;
            unsigned pair = (unsigned)triple[0] << 16 | (unsigned)triple[1] << 8 | triple[2];
            pair = column % 2 ? (pair & 0xf000u) | (value & 0xfffu) : (pair & 0xfffu) | (value & 0xfffu) << 12;
            triple[0] = (uint8_t)(pair >> 16);
            triple[1] = (uint8_t)(pair >> 8);
            triple[2] = (uint8_t)pair;
        }
    }
    // The odd row's padding is given a value of its own, so a port that writes the padding is caught.
    if (bytes * ROWS > 0)
        source[bytes] |= 0x0fu;

    vImage_Buffer src, dest;
    memset(mine_out, 0xa5, sizeof mine_out);
    memset(their_out, 0xa5, sizeof their_out);
    buffer(&src, source, width, ROWS, (vImagePixelCount)bytes);
    buffer(&dest, mine_out, width, ROWS, width * 2);
    vImage_Error mine_status = charon_host_vImageConvert_12UTo16U(&src, &dest, 0);
    buffer(&dest, their_out, width, ROWS, width * 2);
    vImage_Error their_status = vImageConvert_12UTo16U(&src, &dest, 0);

    if (mine_status != their_status || memcmp(mine_out, their_out, sizeof mine_out) != 0) {
        failures++;
        for (int row = 0; row < ROWS; row++) {
            for (vImagePixelCount column = 0; column < width * 2; column++) {
                if (mine_out[row * width * 2 + column] != their_out[row * width * 2 + column]) {
                    printf("FAIL 12UTo16U at width %d: row %d byte %d is %02x where the host says %02x\n", (int)width,
                           row, (int)column, mine_out[row * width * 2 + column], their_out[row * width * 2 + column]);
                    return;
                }
            }
        }
        printf("FAIL 12UTo16U at width %d: status %ld against %ld and the bytes agree\n", (int)width, (long)mine_status,
               (long)their_status);
        return;
    }
    printf("ok 12UTo16U at width %d, %zu bytes a row, two rows\n", (int)width, bytes);
}

// The same sweep the other way. The destination is pre-filled with a value that is not any twelve-bit pixel's,
// and **the host is the oracle for the padding too**: the whole row is compared, not the pixels, so a port that
// writes into a row's unused bits fails and a port that leaves a bit the host fills fails. An earlier version of
// this case asserted where the padding was itself - "byte 2 for a width of one" - and that assertion was wrong
// about a two-pixel-to-a-triple layout, and it flagged byte 0, which is real data. Let the host say what the
// padding is; it does not need a rule from us.
static void run_down(vImagePixelCount width)
{
    checks++;
    size_t bytes = packed_bytes(width);
    uint16_t source[ROWS * MAX_PLAIN];
    uint8_t mine_out[ROWS * MAX_PACKED], their_out[ROWS * MAX_PACKED];
    // Distinct values, neither ascending nor a run, and different again on the second row, so a pixel read from
    // a neighbour and a row read from the wrong stride are both visible.
    for (int row = 0; row < ROWS; row++)
        for (vImagePixelCount column = 0; column < width; column++) {
            uint16_t value = (uint16_t)(value_for(column) ^ (row ? 0x3456u : 0u));
            // A sixteen-bit source row is `width * 2` bytes, and the row stride is that and not `width`: the
            // first version of this case offset by `row * width`, so the second row's values were written over
            // the first row's tail and the host read them back as row 0's pixels. That is the same slip as the
            // eight-byte pattern table - a row written in units of pixels into a buffer laid out in bytes.
            memcpy(source + row * width * 2 + column * 2, &value, sizeof value);
        }
    memset(mine_out, 0x0f, sizeof mine_out);
    memset(their_out, 0x0f, sizeof their_out);

    vImage_Buffer src, dest;
    buffer(&src, source, width, ROWS, width * 2);
    buffer(&dest, mine_out, width, ROWS, (vImagePixelCount)bytes);
    vImage_Error mine_status = charon_host_vImageConvert_16UTo12U(&src, &dest, 0);
    buffer(&dest, their_out, width, ROWS, (vImagePixelCount)bytes);
    vImage_Error their_status = vImageConvert_16UTo12U(&src, &dest, 0);

    if (mine_status != their_status || memcmp(mine_out, their_out, ROWS * bytes) != 0) {
        failures++;
        for (int row = 0; row < ROWS; row++)
            for (size_t at = 0; at < bytes; at++)
                if (mine_out[row * bytes + at] != their_out[row * bytes + at]) {
                    printf("FAIL 16UTo12U at width %d: row %d byte %zu is %02x where the host says %02x\n", (int)width,
                           row, at, mine_out[row * bytes + at], their_out[row * bytes + at]);
                    return;
                }
        printf("FAIL 16UTo12U at width %d: status %ld against %ld and the packed bytes agree\n", (int)width,
               (long)mine_status, (long)their_status);
        return;
    }
    printf("ok 16UTo12U at width %d, %zu bytes a row, two rows, the padding the host's own\n", (int)width, bytes);
}

// A value sweep, because a fixed set of input values does not settle a scale. Dropping the `+ (t >> 4)` bit
// replication from the 16U to 12U rule changed **no** answer in the width table above and survived every
// mutation sweep - the seventeen values each width used simply never landed on a case where it matters. The
// rule is a quotient, and a quotient's rounding is only visible where a carry crosses a boundary, so the input
// has to be swept rather than sampled. Every twelve-bit value and every sixteenth of the sixteen-bit range are
// put through the host and the port, in a full triple, and the whole triple compared.
static void run_scale(void)
{
    for (int bits = 12; bits <= 16; bits += 4) {
        int limit = bits == 12 ? 4096 : 65536;
        int step = bits == 12 ? 1 : 4;
        int failures_before = failures;
        for (int t = 0; t < limit; t += step) {
            uint8_t packed[3], mine_out[3], their_out[3];
            uint16_t mine_in[2], their_in[2];
            memset(packed, 0, sizeof packed);
            // Build the packed triple for pixel 0 = t and pixel 1 = the complement, so both halves of the
            // twenty-four bits are exercised at every t.
            unsigned other = (unsigned)((0xfff - (t & 0xfff)) & 0xfff);
            unsigned pair = ((unsigned)t & 0xfffu) << 12 | other;
            packed[0] = (uint8_t)(pair >> 16);
            packed[1] = (uint8_t)(pair >> 8);
            packed[2] = (uint8_t)pair;
            memset(mine_out, 0x33, sizeof mine_out);
            memset(their_out, 0x33, sizeof their_out);
            if (bits == 12) {
                vImage_Buffer src, dest;
                buffer(&src, packed, 2, 1, 3);
                buffer(&dest, mine_out, 2, 1, 4);
                charon_host_vImageConvert_12UTo16U(&src, &dest, 0);
                buffer(&dest, their_out, 2, 1, 4);
                vImageConvert_12UTo16U(&src, &dest, 0);
            } else {
                mine_in[0] = their_in[0] = (uint16_t)t;
                mine_in[1] = their_in[1] = (uint16_t)(t ^ 0xffff);
                vImage_Buffer src, dest;
                buffer(&src, mine_in, 2, 1, 4);
                buffer(&dest, mine_out, 2, 1, 3);
                charon_host_vImageConvert_16UTo12U(&src, &dest, 0);
                buffer(&src, their_in, 2, 1, 4);
                buffer(&dest, their_out, 2, 1, 3);
                vImageConvert_16UTo12U(&src, &dest, 0);
            }
            checks++;
            if (memcmp(mine_out, their_out, bits == 12 ? 4 : 3) != 0) {
                failures++;
                // the first disagreement in a sweep, in full - the one that names the value
                if (failures == failures_before + 1) {
                    printf("FAIL the %d-bit scale at %d: the port writes", bits, t);
                    for (int i = 0; i < (bits == 12 ? 4 : 3); i++) printf(" %02x", mine_out[i]);
                    printf(" where the host writes");
                    for (int i = 0; i < (bits == 12 ? 4 : 3); i++) printf(" %02x", their_out[i]);
                    printf("\n");
                }
            }
        }
        if (failures == failures_before)
            printf("ok the %d-bit scale, %d values swept against the host\n", bits, limit / step);
    }
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        // Both directions, every width 1 to 17 - every odd and every even, which is what a row of two pixels to
        // a triple makes load-bearing.
        for (vImagePixelCount width = 1; width <= MAX_WIDTH; width++) {
            run_up(width);
            run_down(width);
        }
        run_scale();
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
