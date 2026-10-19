// The 5, 5, 5, 1, 5, 6, 5 and 1, 5, 5, 5 conversions of vImage, held against the host's own vImage, case by
// case: the same pixels through each, compared byte for byte.
//
// The port's sources are compiled with every API name they define renamed, so this translation unit can
// hold the port's objects and the host's side by side. The names come from the port's registry.
//
// The inputs are the corners of each word - all zero, all one, every channel at its maximum, every channel
// at its minimum but one, and a mixed value - because a conversion that is right at the ends and wrong in
// the middle is a rounding rule that a single value would hide, and this family is exactly where the
// rounding lives.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

vImage_Error charon_host_vImageConvert_RGB565toBGRA8888(Pixel_8 alpha, const vImage_Buffer *src, const vImage_Buffer *dest,
                                               vImage_Flags flags);
vImage_Error charon_host_vImageConvert_BGRA8888toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags);
vImage_Error charon_host_vImageConvert_RGB565toRGBA8888(Pixel_8 alpha, const vImage_Buffer *src, const vImage_Buffer *dest,
                                               vImage_Flags flags);
vImage_Error charon_host_vImageConvert_RGBA5551toRGBA8888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags);
vImage_Error charon_host_vImageConvert_RGBA8888toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags);
vImage_Error charon_host_vImageConvert_RGBA8888toRGBA5551(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags);
vImage_Error charon_host_vImageConvert_RGB565toRGB888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags);
vImage_Error charon_host_vImageConvert_ARGB1555toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags);
vImage_Error charon_host_vImageConvert_RGB565toARGB1555(const vImage_Buffer *src, const vImage_Buffer *dest, int dither,
                                                vImage_Flags flags);
vImage_Error charon_host_vImageConvert_RGB565toRGBA5551(const vImage_Buffer *src, const vImage_Buffer *dest, int dither,
                                                 vImage_Flags flags);
vImage_Error charon_host_vImageConvert_RGBA5551toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags);

static int checks;
static int failures;

// The pixels each direction is asked over, as the words themselves: 0x0000 and 0xFFFF bracket both ends of
// every channel, 0x07FF is red at its maximum, 0x07E0 green, 0x001F blue, 0xF81F a 1/5/5/5 word with its
// alpha and red and blue at their maxima, and the rest are mixed.
static const uint16_t words[] = {0x0000, 0xFFFF, 0x07FF, 0x07E0, 0x001F, 0xF81F, 0xF800, 0x8410, 0x1234, 0x7BDE, 0x0202, 0xFD75};
#define WORDS ((int)(sizeof words / sizeof *words))
#define PIXELS 16

// The byte-exact comparison for the conversions whose arithmetic Conversion.h writes out, and the
// divergence check for the two that take a dither - where the host's answer is what its own noise source
// gives and this port has no copy of that source, so the case passes while the two answers differ and fails
// on anything else.
static void report(int passed, const char *name, const char *why)
{
    checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: %s\n", name, why);
    }
    fflush(stdout);
}

static char detail[256];

// The words each direction is asked over: 0x0000 and 0xFFFF bracket both ends of every channel, 0x07FF is
// red at its maximum, 0x07E0 green, 0x001F blue, 0xF81F a 1/5/5/5 word with its alpha, red and blue at
// their maxima, and the rest are mixed. A conversion that is right at the ends and wrong in the middle is a
// rounding rule a single value would hide, and this family is where the rounding lives.
static void fill16(uint16_t *mine, uint16_t *theirs, int count)
{
    for (int at = 0; at < count; at++)
        mine[at] = theirs[at] = words[at % WORDS];
}

static vImage_Buffer buffer_of(void *data, size_t row_bytes, vImagePixelCount width, vImagePixelCount height)
{
    vImage_Buffer buffer = {0};
    buffer.data = data;
    buffer.width = width;
    buffer.height = height;
    buffer.rowBytes = row_bytes;
    return buffer;
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        uint8_t mine_out[PIXELS * 4], theirs_out[PIXELS * 4];
        uint16_t mine_word[PIXELS], theirs_word[PIXELS];
        uint8_t mine_pixel[PIXELS * 4], theirs_pixel[PIXELS * 4];
        vImage_Buffer mine_in16, theirs_in16, mine_to16, theirs_to16;
        vImage_Buffer mine_in32, theirs_in32, mine_to32, theirs_to32;
        fill16(mine_word, theirs_word, PIXELS);
        mine_in16 = buffer_of(mine_word, PIXELS * 2, PIXELS, 1);
        theirs_in16 = buffer_of(theirs_word, PIXELS * 2, PIXELS, 1);
        mine_to16 = buffer_of(mine_out, PIXELS * 4, PIXELS, 1);
        theirs_to16 = buffer_of(theirs_out, PIXELS * 4, PIXELS, 1);
        for (int at = 0; at < PIXELS; at++) {
            uint16_t w = words[at % WORDS];
            uint8_t pixel[4] = {(uint8_t)(w >> 8), (uint8_t)(w >> 4), (uint8_t)(w << 4), 255};
            memcpy(mine_pixel + at * 4, pixel, 4);
            memcpy(theirs_pixel + at * 4, pixel, 4);
        }
        mine_in32 = buffer_of(mine_pixel, PIXELS * 4, PIXELS, 1);
        theirs_in32 = buffer_of(theirs_pixel, PIXELS * 4, PIXELS, 1);
        mine_to32 = buffer_of(mine_out, PIXELS * 4, PIXELS, 1);
        theirs_to32 = buffer_of(theirs_out, PIXELS * 4, PIXELS, 1);

        // A 16-bit word in, a 16-bit word out. The two with a dither are asked with a dither of zero,
        // which is the answer the facts file measures; the host's own dither is a noise source no header
        // publishes, so a non-zero dither is not something this port can reproduce and says so.
        {
            struct {
                const char *name;
                vImage_Error (*mine)(const vImage_Buffer *, const vImage_Buffer *, int, vImage_Flags);
                vImage_Error (*theirs)(const vImage_Buffer *, const vImage_Buffer *, int, vImage_Flags);
            } cases[] = {
                {"vImageConvert_RGB565toARGB1555 with a dither of zero", vImageConvert_RGB565toARGB1555,
                 charon_host_vImageConvert_RGB565toARGB1555},
                {"vImageConvert_RGB565toRGBA5551 with a dither of zero", vImageConvert_RGB565toRGBA5551,
                 charon_host_vImageConvert_RGB565toRGBA5551},
            };
            for (unsigned at = 0; at < sizeof cases / sizeof *cases; at++) {
                int agreed = 1;
                memset(mine_out, 0xAA, sizeof mine_out);
                memset(theirs_out, 0xAA, sizeof theirs_out);
                cases[at].mine(&mine_in16, &mine_to16, 0, 0);
                cases[at].theirs(&theirs_in16, &theirs_to16, 0, 0);
                for (int byte = 0; byte < PIXELS * 2; byte++)
                    if (mine_out[byte] != theirs_out[byte])
                        agreed = 0;
                snprintf(detail, sizeof detail, "the port writes %02x %02x and the host %02x %02x for the first word",
                         mine_out[0], mine_out[1], theirs_out[0], theirs_out[1]);
                report(agreed, cases[at].name, agreed ? "" : detail);
            }
        }
        {
            struct {
                const char *name;
                vImage_Error (*mine)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
                vImage_Error (*theirs)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
                size_t bytes;   // how many of the output the case compares
            } cases[] = {
                {"vImageConvert_ARGB1555toRGB565", vImageConvert_ARGB1555toRGB565, charon_host_vImageConvert_ARGB1555toRGB565, PIXELS * 2},
                {"vImageConvert_RGBA5551toRGB565", vImageConvert_RGBA5551toRGB565, charon_host_vImageConvert_RGBA5551toRGB565,
                 PIXELS * 2},
                {"vImageConvert_RGBA5551toRGBA8888", vImageConvert_RGBA5551toRGBA8888, charon_host_vImageConvert_RGBA5551toRGBA8888,
                 PIXELS * 4},
            };
            for (unsigned at = 0; at < sizeof cases / sizeof *cases; at++) {
                int agreed = 1;
                memset(mine_out, 0xAA, sizeof mine_out);
                memset(theirs_out, 0xAA, sizeof theirs_out);
                cases[at].mine(&mine_in16, &mine_to16, 0);
                cases[at].theirs(&theirs_in16, &theirs_to16, 0);
                for (size_t byte = 0; byte < cases[at].bytes; byte++)
                    if (mine_out[byte] != theirs_out[byte])
                        agreed = 0;
                snprintf(detail, sizeof detail, "the port writes %02x %02x and the host %02x %02x for the first word",
                         mine_out[0], mine_out[1], theirs_out[0], theirs_out[1]);
                report(agreed, cases[at].name, agreed ? "" : detail);
            }
        }
        // A 16-bit word in, four bytes out.
        {
            uint8_t mine_rgb[PIXELS * 3], theirs_rgb[PIXELS * 3];
            vImage_Buffer mine_to24 = buffer_of(mine_rgb, PIXELS * 3, PIXELS, 1);
            vImage_Buffer theirs_to24 = buffer_of(theirs_rgb, PIXELS * 3, PIXELS, 1);
            struct {
                const char *name;
                vImage_Error (*mine)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
                vImage_Error (*theirs)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
            } cases[] = {
                {"vImageConvert_RGB565toRGB888", vImageConvert_RGB565toRGB888, charon_host_vImageConvert_RGB565toRGB888},
            };
            for (unsigned at = 0; at < sizeof cases / sizeof *cases; at++) {
                int agreed;
                memset(mine_rgb, 0xAA, sizeof mine_rgb);
                memset(theirs_rgb, 0xAA, sizeof theirs_rgb);
                cases[at].mine(&mine_in16, &mine_to24, 0);
                cases[at].theirs(&theirs_in16, &theirs_to24, 0);
                agreed = memcmp(mine_rgb, theirs_rgb, sizeof mine_rgb) == 0;
                snprintf(detail, sizeof detail, "the port writes %02x %02x %02x and the host %02x %02x %02x", mine_rgb[0],
                         mine_rgb[1], mine_rgb[2], theirs_rgb[0], theirs_rgb[1], theirs_rgb[2]);
                report(agreed, cases[at].name, agreed ? "" : detail);
            }
        }
        {
            struct {
                const char *name;
                vImage_Error (*mine)(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
                vImage_Error (*theirs)(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
            } cases[] = {
                {"vImageConvert_RGB565toRGBA8888", (vImage_Error(*)(Pixel_8, const vImage_Buffer *, const vImage_Buffer *,
                                                                  vImage_Flags))vImageConvert_RGB565toRGBA8888,
                 (vImage_Error(*)(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags))
                     charon_host_vImageConvert_RGB565toRGBA8888},
            };
            for (unsigned at = 0; at < sizeof cases / sizeof *cases; at++) {
                int agreed;
                memset(mine_out, 0xAA, sizeof mine_out);
                memset(theirs_out, 0xAA, sizeof theirs_out);
                cases[at].mine(128, &mine_in16, &mine_to16, 0);
                cases[at].theirs(128, &theirs_in16, &theirs_to16, 0);
                agreed = memcmp(mine_out, theirs_out, sizeof mine_out) == 0;
                snprintf(detail, sizeof detail, "the port writes %02x %02x %02x %02x and the host %02x %02x %02x %02x",
                         mine_out[0], mine_out[1], mine_out[2], mine_out[3], theirs_out[0], theirs_out[1], theirs_out[2],
                         theirs_out[3]);
                report(agreed, cases[at].name, agreed ? "" : detail);
            }
        }
        // Four bytes in, two bytes out - the BGRA8888 pair the 7.0 group already carries, asked again here so
        // this differential covers the whole shape.
        {
            struct {
                const char *name;
                vImage_Error (*mine)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
                vImage_Error (*theirs)(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
            } cases[] = {
                {"vImageConvert_BGRA8888toRGB565", vImageConvert_BGRA8888toRGB565, charon_host_vImageConvert_BGRA8888toRGB565},
                {"vImageConvert_RGBA8888toRGB565", vImageConvert_RGBA8888toRGB565, charon_host_vImageConvert_RGBA8888toRGB565},
                {"vImageConvert_RGBA8888toRGBA5551", vImageConvert_RGBA8888toRGBA5551, charon_host_vImageConvert_RGBA8888toRGBA5551},
            };
            vImage_Buffer mine_to16n = buffer_of(mine_out, PIXELS * 2, PIXELS, 1);
            vImage_Buffer theirs_to16n = buffer_of(theirs_out, PIXELS * 2, PIXELS, 1);
            for (unsigned at = 0; at < sizeof cases / sizeof *cases; at++) {
                int agreed;
                memset(mine_out, 0xAA, sizeof mine_out);
                memset(theirs_out, 0xAA, sizeof theirs_out);
                cases[at].mine(&mine_in32, &mine_to16n, 0);
                cases[at].theirs(&theirs_in32, &theirs_to16n, 0);
                agreed = memcmp(mine_out, theirs_out, PIXELS * 2) == 0;
                snprintf(detail, sizeof detail, "the port writes %02x %02x and the host %02x %02x", mine_out[0],
                         mine_out[1], theirs_out[0], theirs_out[1]);
                report(agreed, cases[at].name, agreed ? "" : detail);
            }
        }
        {
            memset(mine_out, 0xAA, sizeof mine_out);
            memset(theirs_out, 0xAA, sizeof theirs_out);
            vImageConvert_RGB565toBGRA8888(200, &mine_in16, &mine_to32, 0);
            vImageConvert_RGB565toBGRA8888(200, &theirs_in16, &theirs_to32, 0);
            int agreed = memcmp(mine_out, theirs_out, sizeof mine_out) == 0;
            snprintf(detail, sizeof detail, "the port writes %02x %02x %02x %02x and the host %02x %02x %02x %02x",
                     mine_out[0], mine_out[1], mine_out[2], mine_out[3], theirs_out[0], theirs_out[1], theirs_out[2],
                     theirs_out[3]);
            report(agreed, "vImageConvert_RGB565toBGRA8888", agreed ? "" : detail);
        }
        // The refusals, which are the release's own.
        {
            vImage_Buffer small = buffer_of(mine_out, 8, 1, 1);
            vImage_Buffer large = buffer_of(mine_out, 8, 4, 1);
            vImage_Error mine_error = vImageConvert_RGB565toRGB888(&small, &large, 0);
            vImage_Error host_error = charon_host_vImageConvert_RGB565toRGB888(&small, &large, 0);
            report(mine_error == kvImageRoiLargerThanInputBuffer && host_error == kvImageRoiLargerThanInputBuffer,
                   "a destination larger than the source is kvImageRoiLargerThanInputBuffer on both sides", "");
            mine_error = vImageConvert_RGB565toRGB888(&small, &small, 0x4000);
            host_error = charon_host_vImageConvert_RGB565toRGB888(&small, &small, 0x4000);
            report(mine_error == kvImageUnknownFlagsBit && host_error == kvImageUnknownFlagsBit,
                   "a flag outside the set the header lists is kvImageUnknownFlagsBit on both sides", "");
            mine_error = vImageConvert_RGB565toRGB888(&small, &small, kvImageGetTempBufferSize);
            host_error = charon_host_vImageConvert_RGB565toRGB888(&small, &small, kvImageGetTempBufferSize);
            report(mine_error == 0 && host_error == 0, "kvImageGetTempBufferSize does no work and answers zero on both sides",
                   "");
        }
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
