#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

vImage_Error charon_host_vImageConvert_16Q12to16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_16Q12to8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_16Q12toF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_Fto16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_8to16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_16Uto16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_16Uto16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_16Fto16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_16Fto16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageConvert_16Q12to16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);

#define COUNT 32

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
    fflush(stdout);
}

static void compare(const char *name, vImage_Error (*mine)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags),
                    vImage_Error (*theirs)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags),
                    const void *inputs, size_t in_width, size_t out_width, size_t at_offset)
{
    uint8_t mine_in[COUNT * 8], theirs_in[COUNT * 8], mine_out[COUNT * 8], theirs_out[COUNT * 8];
    vImage_Buffer mine_src, theirs_src, mine_dest, theirs_dest;
    for (size_t at = 0; at < COUNT; at++) {
        memcpy(mine_in + at * in_width, (const uint8_t *)inputs + at * at_offset, in_width);
        memcpy(theirs_in + at * in_width, (const uint8_t *)inputs + at * at_offset, in_width);
    }
    mine_src.data = mine_in;
    mine_src.width = COUNT;
    mine_src.height = 1;
    mine_src.rowBytes = COUNT * in_width;
    theirs_src = mine_src;
    theirs_src.data = theirs_in;
    mine_dest.data = mine_out;
    mine_dest.width = COUNT;
    mine_dest.height = 1;
    mine_dest.rowBytes = COUNT * out_width;
    theirs_dest = mine_dest;
    theirs_dest.data = theirs_out;
    memset(mine_out, 0xAA, sizeof mine_out);
    memset(theirs_out, 0xAA, sizeof theirs_out);
    mine(&mine_src, &mine_dest, 0);
    theirs(&theirs_src, &theirs_dest, 0);
    int agreed = memcmp(mine_out, theirs_out, COUNT * out_width) == 0;
    if (!agreed) {
        size_t at = 0;
        while (at < COUNT * out_width && mine_out[at] == theirs_out[at])
            at++;
        snprintf(detail, sizeof detail, "byte %zu of the answer is %02x and the host says %02x", at, mine_out[at],
                 theirs_out[at]);
    }
    report(agreed, name, agreed ? "" : detail);
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        const uint32_t ramp32[COUNT] = {0,        1,        2,        15,       16,       127,      128,      255,
                                        256,      1023,     1024,     2047,     2048,     4095,     4096,     16383,
                                        16384,    32767,    32768,    49151,    49152,    57343,    57344,    61439,
                                        61440,    64511,    64512,    65023,    65024,    65535,    65534,    65473};
        const int16_t q12[COUNT] = {0,     16,    -4,     -5,     -8,     265,    522,     1036,
                                    2048,  2049,  4094,   4095,   4096,   8192,    16384,   16385,
                                    0x7FFF, 0x8000, 0x8001, 0xC000, 0x3C00, 0x3800, 0x4000,  0x0400,
                                    0xFC00, 0x2000, 0xE000, 0x1000, 0x3000, 0x5000, 0x7000,  0x0800,
                                    0xF000, 0xBFFF, 0xCFFF, 0xFFFE};
        const uint16_t half[COUNT] = {0x0000, 0x8000, 0x3C00, 0x3C01, 0x3800, 0x4000, 0x7BFF, 0x0400,
                                      0x3555, 0x4900, 0x0001, 0x7C00, 0xFC00, 0x0200, 0x2E66, 0x6E66,
                                      0x5C00, 0x4400, 0x1400, 0x1F80, 0x2400, 0x2A00, 0x3000, 0x31FF,
                                      0x3200, 0x33FF, 0x3400, 0x3BFF, 0x7BFE, 0x0002, 0x03FF, 0x0401};
        const uint8_t small[COUNT] = {0,  1,  2,   3,   4,   5,   8,   16,  64,  100, 127, 128, 129, 150, 180, 191,
                                      200, 240, 250, 254, 255, 7,  9,   11,  13,  17,  33,  65,  99,  199, 249, 251};
        const float floats[COUNT] = {0.0f,       1.0f,        -1.0f,      0.5f,       2.0f,        -2.0f,      1.5f,
                                     0.75f,      0.625f,      0.25f,      0.875f,     3.0f,        10.0f,      0.3332519531f,
                                     -0.3332519531f, 0.0009765625f, -0.0009765625f, 16777216.0f, -16777216.0f,
                                     1.0e-7f,    -1.0e-7f,     0.99999988f, -0.99999988f, 65535.0f,    -65535.0f,
                                     0.000244140625f, 4096.0f,   -4096.0f,   0.001f,      1000.0f,     -0.5f};
        uint8_t ramp16[COUNT * 2], half8[COUNT * 2], q12_8[COUNT * 2], small8[COUNT], float8[COUNT * 4];
        for (int at = 0; at < COUNT; at++) {
            memcpy(ramp16 + at * 2, &ramp32[at], 2);
            memcpy(half8 + at * 2, &half[at], 2);
            memcpy(q12_8 + at * 2, &q12[at], 2);
            small8[at] = small[at];
            memcpy(float8 + at * 4, &floats[at], 4);
        }

        compare("vImageConvert_16Q12to16U", vImageConvert_16Q12to16U, charon_host_vImageConvert_16Q12to16U, q12_8, 2, 2, 2);
        compare("vImageConvert_16Q12to8", vImageConvert_16Q12to8, charon_host_vImageConvert_16Q12to8, q12_8, 2, 1, 2);
        compare("vImageConvert_16Q12toF", vImageConvert_16Q12toF, charon_host_vImageConvert_16Q12toF, q12_8, 2, 4, 2);
        compare("vImageConvert_16Q12to16F", vImageConvert_16Q12to16F, charon_host_vImageConvert_16Q12to16F, q12_8, 2, 2, 2);
        {
            uint16_t *halves = calloc(64, sizeof(uint16_t));
            uint16_t *out = calloc(64, sizeof(uint16_t));
            for (int at = 0; at < 64; at++) {
                halves[at] = 0xAAAA;
                out[at] = 0xAAAA;
            }
            halves[0] = 0x3800;
            halves[1] = 0x3C00;
            halves[2] = 0x0400;
            vImage_Buffer src = {halves, 32, 1, 64}, dest = {out, 32, 1, 64};
            vImageConvert_16Fto16U(&src, &dest, 0);
            {
                uint16_t first = out[0], second = out[1];
                free(halves);
                free(out);
                report(first == 32768, "the host's 16Fto16U rounds 0.5 up to 32768, which is what the port writes",
                       "the host wrote %u and %u", first, second);
            }
        }
        compare("vImageConvert_16Fto16Q12", vImageConvert_16Fto16Q12, charon_host_vImageConvert_16Fto16Q12, half8, 2, 2,
                2);
        compare("vImageConvert_16Uto16Q12", vImageConvert_16Uto16Q12, charon_host_vImageConvert_16Uto16Q12, ramp16, 2, 2, 2);
        compare("vImageConvert_16Uto16F", vImageConvert_16Uto16F, charon_host_vImageConvert_16Uto16F, ramp16, 2, 2, 2);
        compare("vImageConvert_8to16Q12", vImageConvert_8to16Q12, charon_host_vImageConvert_8to16Q12, small8, 1, 2, 1);
        compare("vImageConvert_Fto16Q12", vImageConvert_Fto16Q12, charon_host_vImageConvert_Fto16Q12, float8, 4, 2, 4);

        {
            vImage_Buffer small_buf = {ramp16, 1, 1, 8};
            vImage_Buffer large_buf = {ramp16, 4, 1, 8};
            vImage_Error mine_error = vImageConvert_16Q12to16U(&small_buf, &large_buf, 0);
            vImage_Error host_error = charon_host_vImageConvert_16Q12to16U(&small_buf, &large_buf, 0);
            report(mine_error == kvImageRoiLargerThanInputBuffer && host_error == kvImageRoiLargerThanInputBuffer,
                   "a destination larger than the source is kvImageRoiLargerThanInputBuffer on both sides", "");
            mine_error = vImageConvert_16Q12to16U(&small_buf, &small_buf, 0x4000);
            host_error = charon_host_vImageConvert_16Q12to16U(&small_buf, &small_buf, 0x4000);
            report(mine_error == kvImageUnknownFlagsBit && host_error == kvImageUnknownFlagsBit,
                   "a flag outside the set the header lists is kvImageUnknownFlagsBit on both sides", "");
            mine_error = vImageConvert_16Q12to16U(&small_buf, &small_buf, kvImageGetTempBufferSize);
            host_error = charon_host_vImageConvert_16Q12to16U(&small_buf, &small_buf, kvImageGetTempBufferSize);
            report(mine_error == 0 && host_error == 0,
                   "kvImageGetTempBufferSize does no work and answers zero on both sides", "");
        }
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
