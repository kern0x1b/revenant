// The port's five sixteen-bit alpha placement moves against the host's own, in the table form: one loop over
// the rows and the cases, so a case is a line of a table and not a block of code.
//
// The cases are chosen to pin the parts that are decisions rather than transcriptions:
//   - a NULL alpha buffer against a plane, because the header marks neither non-NULL and the host takes the
//     fill as the alpha rather than refusing;
//   - all three orders, because ARGB puts the alpha first and BGRA puts blue first and one table row cannot
//     serve both;
//   - premultiply on and off, and a pair of values whose product is exactly x.5 so the rounding of the
//     multiply is decided rather than assumed;
//   - two rows, and a width that ends mid-byte, so a stride mistake cannot pass.

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define PORT(name) charon_host_##name
#define HOST(name) name

vImage_Error charon_host_vImageConvert_RGB16UtoARGB16U(const vImage_Buffer *, const vImage_Buffer *, Pixel_16U,
                                                       const vImage_Buffer *, bool, vImage_Flags);
vImage_Error charon_host_vImageConvert_RGB16UtoRGBA16U(const vImage_Buffer *, const vImage_Buffer *, Pixel_16U,
                                                       const vImage_Buffer *, bool, vImage_Flags);
vImage_Error charon_host_vImageConvert_RGB16UtoBGRA16U(const vImage_Buffer *, const vImage_Buffer *, Pixel_16U,
                                                       const vImage_Buffer *, bool, vImage_Flags);
vImage_Error charon_host_vImageConvert_RGBA16UtoRGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_BGRA16UtoRGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);

// A width that ends in the middle of a two-byte pixel, and two rows, so a rowBytes mistake has somewhere to
// show itself.
#define WIDTH ((vImagePixelCount)7)
#define ROWS ((vImagePixelCount)2)

static int checks = 0;
static int failures = 0;

typedef vImage_Error (*widen_fn)(const vImage_Buffer *, const vImage_Buffer *, Pixel_16U, const vImage_Buffer *,
                                 bool, vImage_Flags);
typedef vImage_Error (*narrow_fn)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);

// The source values, per pixel, so the host and the port read the same row and a difference is the move and not
// the input. The sixteen values are deliberately unlike each other and not in ascending order, so a swap of two
// channels cannot pass as a match.
static const uint16_t rgb_values[16] = {
    0x1111, 0x2222, 0x4444, 0x5a5a, 0x8000, 0xffff, 0x0100, 0x00ff,
    0x0f0f, 0xf0f0, 0x8001, 0x7fff, 0x1234, 0x4321, 0x0000, 0xfffe,
};

static void fill(uint8_t *buffer, size_t bytes, vImagePixelCount channels, int plane)
{
    // plane 0 is the three-channel source, plane 1 the alpha plane; the two are never the same bytes
    memset(buffer, 0, bytes);
    for (vImagePixelCount row = 0; row < ROWS; row++) {
        uint16_t *out = (uint16_t *)(buffer + row * channels * WIDTH * 2);
        for (vImagePixelCount column = 0; column < WIDTH * channels; column++)
            out[column] = plane == 0 ? rgb_values[(row * WIDTH * channels + column) % 16] : (uint16_t)(0x2000 + column + row);
    }
}

static void run_widen(const char *name, widen_fn mine, widen_fn theirs, bool with_plane, bool premultiply, Pixel_16U fill_value)
{
    checks++;
    uint8_t src[ROWS * WIDTH * 3 * 2 + 8], plane[ROWS * WIDTH * 2 + 8];
    uint8_t mine_out[ROWS * WIDTH * 4 * 2 + 8], their_out[ROWS * WIDTH * 4 * 2 + 8];
    vImage_Buffer src_buffer, plane_buffer, dest;
    fill(src, sizeof src, 3, 0);
    fill(plane, sizeof plane, 1, 1);
    memset(mine_out, 0x5a, sizeof mine_out);
    memset(their_out, 0x5a, sizeof their_out);
    memset(&src_buffer, 0, sizeof src_buffer);
    memset(&plane_buffer, 0, sizeof plane_buffer);
    memset(&dest, 0, sizeof dest);
    src_buffer.data = src;       src_buffer.width = WIDTH;   src_buffer.height = ROWS;   src_buffer.rowBytes = WIDTH * 6;
    plane_buffer.data = plane;   plane_buffer.width = WIDTH; plane_buffer.height = ROWS; plane_buffer.rowBytes = WIDTH * 2;
    dest.data = mine_out;        dest.width = WIDTH;         dest.height = ROWS;         dest.rowBytes = WIDTH * 8;

    vImage_Error mine_status = mine(&src_buffer, with_plane ? &plane_buffer : NULL, fill_value, &dest, premultiply, 0);
    dest.data = their_out;
    vImage_Error their_status = theirs(&src_buffer, with_plane ? &plane_buffer : NULL, fill_value, &dest, premultiply, 0);

    const char *what = with_plane ? (premultiply ? "a plane and premultiply" : "a plane") : "a NULL plane and the fill";
    if (mine_status != their_status || memcmp(mine_out, their_out, sizeof mine_out) != 0) {
        failures++;
        for (vImagePixelCount at = 0; at < WIDTH * 4; at++) {
            uint16_t mine_value, their_value;
            memcpy(&mine_value, mine_out + at * 2, sizeof mine_value);
            memcpy(&their_value, their_out + at * 2, sizeof their_value);
            if (mine_value != their_value) {
                printf("FAIL %s over %s: status %ld against %ld, and channel %d of pixel 0 is %u where the host says %u\n",
                       name, what, (long)mine_status, (long)their_status, (int)at, mine_value, their_value);
                break;
            }
        }
        return;
    }
    printf("ok %s over %s\n", name, what);
}

static void run_narrow(const char *name, narrow_fn mine, narrow_fn theirs)
{
    checks++;
    uint8_t src[ROWS * WIDTH * 4 * 2 + 8];
    uint8_t mine_out[ROWS * WIDTH * 3 * 2 + 8], their_out[ROWS * WIDTH * 3 * 2 + 8];
    vImage_Buffer src_buffer, dest;
    fill(src, sizeof src, 4, 0);
    memset(mine_out, 0x5a, sizeof mine_out);
    memset(their_out, 0x5a, sizeof their_out);
    memset(&src_buffer, 0, sizeof src_buffer);
    memset(&dest, 0, sizeof dest);
    src_buffer.data = src;   src_buffer.width = WIDTH; src_buffer.height = ROWS; src_buffer.rowBytes = WIDTH * 8;
    dest.data = mine_out;    dest.width = WIDTH;       dest.height = ROWS;       dest.rowBytes = WIDTH * 6;

    vImage_Error mine_status = mine(&src_buffer, &dest, 0);
    dest.data = their_out;
    vImage_Error their_status = theirs(&src_buffer, &dest, 0);

    if (mine_status != their_status || memcmp(mine_out, their_out, sizeof mine_out) != 0) {
        failures++;
        for (vImagePixelCount at = 0; at < WIDTH * 3; at++) {
            uint16_t mine_value, their_value;
            memcpy(&mine_value, mine_out + at * 2, sizeof mine_value);
            memcpy(&their_value, their_out + at * 2, sizeof their_value);
            if (mine_value != their_value) {
                printf("FAIL %s dropping the alpha: status %ld against %ld, and channel %d of pixel 0 is %u where the "
                       "host says %u\n", name, (long)mine_status, (long)their_status, (int)at, mine_value, their_value);
                break;
            }
        }
        return;
    }
    printf("ok %s dropping the alpha\n", name);
}

// The rounding of the premultiply, asked directly: 0xffff times 0x8000 is 32767.5, and floor and round-to-
// nearest disagree about it by one. A separate table row, because it is a question about one instruction and
// not about the move.
static void run_rounding(void)
{
    static const uint16_t values[2] = { 0xffff, 0x8001 };
    static const uint16_t alphas[2] = { 0x8000, 0x4000 };
    for (int v = 0; v < 2; v++) {
        for (int a = 0; a < 2; a++) {
            checks++;
            uint8_t src[3 * 2], plane[2], mine_out[4 * 2], their_out[4 * 2];
            uint16_t *in = (uint16_t *)src;
            in[0] = values[v]; in[1] = 0x1111; in[2] = 0x2222;
            *(uint16_t *)plane = alphas[a];
            memset(mine_out, 0, sizeof mine_out);
            memset(their_out, 0, sizeof their_out);
            vImage_Buffer src_buffer, plane_buffer, dest;
            memset(&src_buffer, 0, sizeof src_buffer);
            memset(&plane_buffer, 0, sizeof plane_buffer);
            memset(&dest, 0, sizeof dest);
            src_buffer.data = src;      src_buffer.width = 1; src_buffer.height = 1; src_buffer.rowBytes = 6;
            plane_buffer.data = plane;  plane_buffer.width = 1; plane_buffer.height = 1; plane_buffer.rowBytes = 2;
            dest.data = mine_out;       dest.width = 1;       dest.height = 1;       dest.rowBytes = 8;
            charon_host_vImageConvert_RGB16UtoARGB16U(&src_buffer, &plane_buffer, 0, &dest, true, 0);
            dest.data = their_out;
            vImageConvert_RGB16UtoARGB16U(&src_buffer, &plane_buffer, 0, &dest, true, 0);
            uint16_t mine_value, their_value;
            memcpy(&mine_value, mine_out + 2, sizeof mine_value);   // red, the premultiplied channel
            memcpy(&their_value, their_out + 2, sizeof their_value);
            if (mine_value != their_value) {
                failures++;
                printf("FAIL the premultiply of %u by %u: the port writes %u where the host writes %u, and "
                       "%.2f is where they part\n", values[v], alphas[a], mine_value, their_value,
                       (double)values[v] * alphas[a] / 65535.0);
                continue;
            }
            printf("ok the premultiply of %u by %u is %u, and %.2f rounds to it\n", values[v], alphas[a], mine_value,
                   (double)values[v] * alphas[a] / 65535.0);
        }
    }
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        // one table, five rows, three cases each: a plane, a NULL plane and the fill, and premultiply on top of
        // the plane. The fill is 0x1234, which appears nowhere in the source, so a row that read the wrong
        // channel for its alpha could not pass.
        static const struct { const char *name; widen_fn mine; widen_fn theirs; } widen[3] = {
            { "vImageConvert_RGB16UtoARGB16U", charon_host_vImageConvert_RGB16UtoARGB16U, vImageConvert_RGB16UtoARGB16U },
            { "vImageConvert_RGB16UtoRGBA16U", charon_host_vImageConvert_RGB16UtoRGBA16U, vImageConvert_RGB16UtoRGBA16U },
            { "vImageConvert_RGB16UtoBGRA16U", charon_host_vImageConvert_RGB16UtoBGRA16U, vImageConvert_RGB16UtoBGRA16U },
        };
        for (int i = 0; i < 3; i++) {
            run_widen(widen[i].name, widen[i].mine, widen[i].theirs, true, false, 0x1234);
            run_widen(widen[i].name, widen[i].mine, widen[i].theirs, false, false, 0x1234);
            run_widen(widen[i].name, widen[i].mine, widen[i].theirs, true, true, 0x1234);
        }
        static const struct { const char *name; narrow_fn mine; narrow_fn theirs; } narrow[2] = {
            { "vImageConvert_RGBA16UtoRGB16U", charon_host_vImageConvert_RGBA16UtoRGB16U, vImageConvert_RGBA16UtoRGB16U },
            { "vImageConvert_BGRA16UtoRGB16U", charon_host_vImageConvert_BGRA16UtoRGB16U, vImageConvert_BGRA16UtoRGB16U },
        };
        for (int i = 0; i < 2; i++)
            run_narrow(narrow[i].name, narrow[i].mine, narrow[i].theirs);
        run_rounding();
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
