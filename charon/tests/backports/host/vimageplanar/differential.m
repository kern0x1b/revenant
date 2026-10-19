// The port's interleaved and planar moves held against the host's own vImage, case by case: the same
// channels in, the same channels out, and every byte of every destination row compared.
//
// The inputs are a gradient and the ends of each range, so a channel that lands in the wrong row is a
// difference rather than a coincidence, and the destinations are filled with a value neither side writes.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

vImage_Error charon_host_vImageConvert_ARGB16UtoPlanar16U(const vImage_Buffer *, const vImage_Buffer *,
                                                           const vImage_Buffer *, const vImage_Buffer *,
                                                           const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_RGB16UtoPlanar16U(const vImage_Buffer *, const vImage_Buffer *,
                                                          const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_Planar16UtoARGB16U(const vImage_Buffer *, const vImage_Buffer *,
                                                            const vImage_Buffer *, const vImage_Buffer *,
                                                            const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_Planar16UtoRGB16U(const vImage_Buffer *, const vImage_Buffer *,
                                                           const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_ARGB8888toPlanar16Q12(const vImage_Buffer *, const vImage_Buffer *,
                                                             const vImage_Buffer *, const vImage_Buffer *,
                                                             const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_RGB888toPlanar16Q12(const vImage_Buffer *, const vImage_Buffer *,
                                                            const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_Planar16Q12toARGB8888(const vImage_Buffer *, const vImage_Buffer *,
                                                              const vImage_Buffer *, const vImage_Buffer *,
                                                              const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_Planar16Q12toRGB888(const vImage_Buffer *, const vImage_Buffer *,
                                                            const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);

#define W 8
typedef vImage_Error (*CharonFive)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *,
                                           const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
typedef vImage_Error (*CharonFour)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *,
                                           const vImage_Buffer *, vImage_Flags);

static const uint8_t kFill8 = 0xA5;
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
    }
    va_end(args);
    fflush(stdout);
}

typedef vImage_Error (*CharonFive)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *,
                                   const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
typedef vImage_Error (*CharonFour)(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *,
                                   const vImage_Buffer *, vImage_Flags);

static vImage_Buffer row_of(void *data, vImagePixelCount width, vImagePixelCount height, size_t row_bytes)
{
    vImage_Buffer buffer = {0};
    buffer.data = data;
    buffer.width = width;
    buffer.height = height;
    buffer.rowBytes = row_bytes;
    return buffer;
}

// One interleaved row of `channels` values, at `bytes` bytes each, and the same values split into rows - so
// a channel that lands in the wrong place is a difference and not a coincidence.
static void spread_values(uint8_t *interleaved, uint8_t rows[4][W * 2], int channels, int bytes)
{
    for (int channel = 0; channel < channels; channel++) {
        for (int at = 0; at < W * 2; at++)
            rows[channel][at] = kFill8;
        for (int column = 0; column < W; column++) {
            for (int at = 0; at < bytes; at++) {
                int offset = (column * channels + channel) * bytes + at;
                rows[channel][column * 2 + at] = (uint8_t)(offset * 13 + channel * 61 + 5);
                interleaved[offset] = (uint8_t)(offset * 13 + channel * 61 + 5);
            }
        }
    }
}

static int spread(const char *name, const void *mine_fn, const void *theirs_fn, int channels, int in_bytes)
{
    static uint8_t source[W * 8], mine_rows[4][W * 2], theirs_rows[4][W * 2];
    vImage_Buffer src, mine_dest[4], theirs_dest[4];
    memset(source, kFill8, sizeof source);
    spread_values(source, mine_rows, channels, in_bytes);
    for (int channel = 0; channel < channels; channel++)
        memcpy(theirs_rows[channel], mine_rows[channel], W * 2);
    src = row_of(source, W, 1, W * channels * in_bytes);
    for (int channel = 0; channel < channels; channel++) {
        mine_dest[channel] = row_of(mine_rows[channel], W, 1, W * 2);
        theirs_dest[channel] = row_of(theirs_rows[channel], W, 1, W * 2);
    }
    if (channels == 3) {
        ((CharonFour)mine_fn)(&src, &mine_dest[0], &mine_dest[1], &mine_dest[2], 0);
        ((CharonFour)theirs_fn)(&src, &theirs_dest[0], &theirs_dest[1], &theirs_dest[2], 0);
    } else {
        ((CharonFive)mine_fn)(&src, &mine_dest[0], &mine_dest[1], &mine_dest[2], &mine_dest[3], 0);
        ((CharonFive)theirs_fn)(&src, &theirs_dest[0], &theirs_dest[1], &theirs_dest[2], &theirs_dest[3], 0);
    }
    for (int channel = 0; channel < channels; channel++) {
        for (int at = 0; at < W * 2; at++) {
            if (mine_rows[channel][at] != theirs_rows[channel][at]) {
                snprintf(detail, sizeof detail, "row %d byte %d is %02x and the host says %02x", channel, at,
                         mine_rows[channel][at], theirs_rows[channel][at]);
                return 0;
            }
        }
    }
    return 1;
}

static int gather(const char *name, const void *mine_fn, const void *theirs_fn, int channels, int out_bytes)
{
    static uint8_t mine_in[4][W * 2], theirs_in[4][W * 2], mine_bytes[W * 8], theirs_bytes[W * 8];
    vImage_Buffer mine_src[4], theirs_src[4], mine_dest, theirs_dest;
    for (int channel = 0; channel < channels; channel++) {
        for (int column = 0; column < W; column++)
            for (int at = 0; at < out_bytes; at++)
                mine_in[channel][column * 2 + at] = (uint8_t)(column * 31 + channel * 97 + at + 1);
        memcpy(theirs_in[channel], mine_in[channel], W * 2);
        mine_src[channel] = row_of(mine_in[channel], W, 1, W * 2);
        theirs_src[channel] = row_of(theirs_in[channel], W, 1, W * 2);
    }
    memset(mine_bytes, kFill8, sizeof mine_bytes);
    memset(theirs_bytes, kFill8, sizeof theirs_bytes);
    mine_dest = row_of(mine_bytes, W, 1, W * channels * out_bytes);
    theirs_dest = row_of(theirs_bytes, W, 1, W * channels * out_bytes);
    if (channels == 3) {
        ((CharonFour)mine_fn)(&mine_src[0], &mine_src[1], &mine_src[2], &mine_dest, 0);
        ((CharonFour)theirs_fn)(&theirs_src[0], &theirs_src[1], &theirs_src[2], &theirs_dest, 0);
    } else {
        ((CharonFive)mine_fn)(&mine_src[0], &mine_src[1], &mine_src[2], &mine_src[3], &mine_dest, 0);
        ((CharonFive)theirs_fn)(&theirs_src[0], &theirs_src[1], &theirs_src[2], &theirs_src[3], &theirs_dest, 0);
    }
    int size = W * channels * out_bytes;
    for (int at = 0; at < size; at++) {
        if (mine_bytes[at] != theirs_bytes[at]) {
            snprintf(detail, sizeof detail, "byte %d of the interleaved row is %02x and the host says %02x", at,
                     mine_bytes[at], theirs_bytes[at]);
            return 0;
        }
    }
    return 1;
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        report(spread("vImageConvert_ARGB16UtoPlanar16U", vImageConvert_ARGB16UtoPlanar16U, charon_host_vImageConvert_ARGB16UtoPlanar16U, 4, 2), "vImageConvert_ARGB16UtoPlanar16U", "the rows differ", 0);
        report(spread("vImageConvert_RGB16UtoPlanar16U", vImageConvert_RGB16UtoPlanar16U, charon_host_vImageConvert_RGB16UtoPlanar16U, 3, 2), "vImageConvert_RGB16UtoPlanar16U", "the rows differ", 0);
        report(spread("vImageConvert_ARGB8888toPlanar16Q12", vImageConvert_ARGB8888toPlanar16Q12, charon_host_vImageConvert_ARGB8888toPlanar16Q12, 4, 1), "vImageConvert_ARGB8888toPlanar16Q12", "the rows differ", 0);
        report(spread("vImageConvert_RGB888toPlanar16Q12", vImageConvert_RGB888toPlanar16Q12, charon_host_vImageConvert_RGB888toPlanar16Q12, 3, 1), "vImageConvert_RGB888toPlanar16Q12", "the rows differ", 0);
        report(gather("vImageConvert_Planar16UtoARGB16U", vImageConvert_Planar16UtoARGB16U, charon_host_vImageConvert_Planar16UtoARGB16U, 4, 2), "vImageConvert_Planar16UtoARGB16U", "the rows differ", 0);
        report(gather("vImageConvert_Planar16UtoRGB16U", vImageConvert_Planar16UtoRGB16U, charon_host_vImageConvert_Planar16UtoRGB16U, 3, 2), "vImageConvert_Planar16UtoRGB16U", "the rows differ", 0);
        report(gather("vImageConvert_Planar16Q12toARGB8888", vImageConvert_Planar16Q12toARGB8888, charon_host_vImageConvert_Planar16Q12toARGB8888, 4, 1), "vImageConvert_Planar16Q12toARGB8888", "the rows differ", 0);
        report(gather("vImageConvert_Planar16Q12toRGB888", vImageConvert_Planar16Q12toRGB888, charon_host_vImageConvert_Planar16Q12toRGB888, 3, 1), "vImageConvert_Planar16Q12toRGB888", "the rows differ", 0);
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
