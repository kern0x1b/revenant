#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

vImage_Error revenant_host_vImageConvert_12UTo16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error revenant_host_vImageConvert_16UTo12U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);

#define ROWS 2
#define MAX_WIDTH 17
#define MAX_PACKED 32
#define MAX_PLAIN (MAX_WIDTH * 2)

static int checks;
static int failures;

static size_t packed_bytes(vImagePixelCount width) { return (size_t)((width + 1) / 2 * 3); }

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
    if (bytes * ROWS > 0)
        source[bytes] |= 0x0fu;

    vImage_Buffer src, dest;
    memset(mine_out, 0xa5, sizeof mine_out);
    memset(their_out, 0xa5, sizeof their_out);
    buffer(&src, source, width, ROWS, (vImagePixelCount)bytes);
    buffer(&dest, mine_out, width, ROWS, width * 2);
    vImage_Error mine_status = revenant_host_vImageConvert_12UTo16U(&src, &dest, 0);
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

static void run_down(vImagePixelCount width)
{
    checks++;
    size_t bytes = packed_bytes(width);
    uint16_t source[ROWS * MAX_PLAIN];
    uint8_t mine_out[ROWS * MAX_PACKED], their_out[ROWS * MAX_PACKED];
    for (int row = 0; row < ROWS; row++)
        for (vImagePixelCount column = 0; column < width; column++) {
            uint16_t value = (uint16_t)(value_for(column) ^ (row ? 0x3456u : 0u));
            memcpy(source + row * width * 2 + column * 2, &value, sizeof value);
        }
    memset(mine_out, 0x0f, sizeof mine_out);
    memset(their_out, 0x0f, sizeof their_out);

    vImage_Buffer src, dest;
    buffer(&src, source, width, ROWS, width * 2);
    buffer(&dest, mine_out, width, ROWS, (vImagePixelCount)bytes);
    vImage_Error mine_status = revenant_host_vImageConvert_16UTo12U(&src, &dest, 0);
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
                revenant_host_vImageConvert_12UTo16U(&src, &dest, 0);
                buffer(&dest, their_out, 2, 1, 4);
                vImageConvert_12UTo16U(&src, &dest, 0);
            } else {
                mine_in[0] = their_in[0] = (uint16_t)t;
                mine_in[1] = their_in[1] = (uint16_t)(t ^ 0xffff);
                vImage_Buffer src, dest;
                buffer(&src, mine_in, 2, 1, 4);
                buffer(&dest, mine_out, 2, 1, 3);
                revenant_host_vImageConvert_16UTo12U(&src, &dest, 0);
                buffer(&src, their_in, 2, 1, 4);
                buffer(&dest, their_out, 2, 1, 3);
                vImageConvert_16UTo12U(&src, &dest, 0);
            }
            checks++;
            if (memcmp(mine_out, their_out, bits == 12 ? 4 : 3) != 0) {
                failures++;
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
        for (vImagePixelCount width = 1; width <= MAX_WIDTH; width++) {
            run_up(width);
            run_down(width);
        }
        run_scale();
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
